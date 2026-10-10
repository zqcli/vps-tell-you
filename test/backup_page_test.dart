import 'package:vps_tell_you/l10n/generated/app_localizations.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart' show CupertinoAlertDialog;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/core/app_theme.dart';
import 'package:vps_tell_you/core/ui/ui.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/servers/ledger_controller.dart';
import 'package:vps_tell_you/settings/backup_page.dart';

import 'ledger_backup_test.dart' show backupNow, backupServer;

LedgerBackupSnapshot emptyBackup() => LedgerBackupSnapshot.decode(
  jsonEncode({
    'format': LedgerBackupSnapshot.format,
    'version': 1,
    'exported_at': backupNow.toIso8601String(),
    'groups': [],
    'servers': [],
    'payments': [],
    'service_periods': [],
    'fx': {
      'display_currency': 'CNY',
      'usd_to_cny': null,
      'eur_to_cny': null,
      'rate_date': null,
    },
  }),
);

class FakeBackupTransfer extends LedgerBackupTransfer {
  String? source;
  int picks = 0, saves = 0, shares = 0;
  bool mobile = false;
  String? savedJson;
  BackupShareOutcome outcome = BackupShareOutcome.dismissed;
  @override
  bool get canShare => mobile;
  @override
  Future<String?> pickBackup({AppLocalizations? l10n}) async {
    picks++;
    return source;
  }

  @override
  Future<String?> saveBackup(
    LedgerBackupSnapshot snapshot, {
    AppLocalizations? l10n,
  }) async {
    saves++;
    savedJson = snapshot.encode();
    return '/synthetic/backup.json';
  }

  @override
  Future<BackupShareOutcome> shareBackup(
    LedgerBackupSnapshot snapshot, {
    Rect? origin,
  }) async {
    shares++;
    savedJson = snapshot.encode();
    return outcome;
  }
}

class MisreportedBackupFile extends XFile {
  MisreportedBackupFile() : super('/never-open-this-synthetic-file');
  @override
  Future<int> length() async => 0;
  @override
  Stream<Uint8List> openRead([int? start, int? end]) async* {
    yield Uint8List(LedgerBackupSnapshot.maxBytes);
    yield Uint8List(1);
    throw StateError('reader must stop before consuming more input');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('backup native share boundary', () {
    setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.android);
    tearDown(() => debugDefaultTargetPlatformOverride = null);
    test('bounded file reader rejects stale sizes and invalid UTF-8', () async {
      final transfer = LedgerBackupTransfer();
      expect(
        await transfer.readBackupFile(
          XFile.fromData(
            Uint8List.fromList(utf8.encode(emptyBackup().encode())),
          ),
        ),
        emptyBackup().encode(),
      );
      await expectLater(
        transfer.readBackupFile(MisreportedBackupFile()),
        throwsFormatException,
      );
      await expectLater(
        transfer.readBackupFile(
          XFile.fromData(Uint8List.fromList([0xff, 0xfe])),
        ),
        throwsFormatException,
      );
    });
    test(
      'JSON only, safe filename, explicit origin and no delivery claim',
      () async {
        late ShareParams sent;
        final transfer = LedgerBackupTransfer(
          invoke: (params) async {
            sent = params;
            return const ShareResult(
              'not-trusted-result-text',
              ShareResultStatus.success,
            );
          },
        );
        const origin = Rect.fromLTWH(10, 20, 100, 40);
        expect(
          await transfer.shareBackup(emptyBackup(), origin: origin),
          BackupShareOutcome.selected,
        );
        expect(sent.files!.single.mimeType, 'application/json');
        expect(await sent.files!.single.readAsString(), emptyBackup().encode());
        expect(sent.fileNameOverrides, ['vps-tell-you-ledger-2026-10-06.json']);
        expect(sent.text, isNull);
        expect(sent.uri, isNull);
        expect(sent.sharePositionOrigin, origin);
        expect(sent.downloadFallbackEnabled, isFalse);
      },
    );
    test('dismissed and unavailable remain distinct on iOS', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      for (final entry in {
        ShareResultStatus.dismissed: BackupShareOutcome.dismissed,
        ShareResultStatus.unavailable: BackupShareOutcome.unknown,
      }.entries) {
        final transfer = LedgerBackupTransfer(
          invoke: (_) async => ShareResult('', entry.key),
        );
        expect(await transfer.shareBackup(emptyBackup()), entry.value);
      }
    });
    test(
      'Linux never invokes native share; JSON picker has MIME and UTI',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.linux;
        var calls = 0;
        final transfer = LedgerBackupTransfer(
          invoke: (_) async {
            calls++;
            return const ShareResult('', ShareResultStatus.success);
          },
        );
        expect(
          await transfer.shareBackup(emptyBackup()),
          BackupShareOutcome.unsupported,
        );
        expect(calls, 0);
        expect(LedgerBackupTransfer.jsonType.extensions, ['json']);
        expect(LedgerBackupTransfer.jsonType.mimeTypes, ['application/json']);
        expect(LedgerBackupTransfer.jsonType.uniformTypeIdentifiers, [
          'public.json',
        ]);
      },
    );
    test(
      'single native sheet, invalid origin rejected, failure guard releases',
      () async {
        final pending = Completer<ShareResult>();
        var calls = 0;
        final transfer = LedgerBackupTransfer(
          invoke: (_) {
            calls++;
            return pending.future;
          },
        );
        await expectLater(
          transfer.shareBackup(emptyBackup(), origin: Rect.zero),
          throwsArgumentError,
        );
        final first = transfer.shareBackup(emptyBackup());
        expect(
          await transfer.shareBackup(emptyBackup()),
          BackupShareOutcome.busy,
        );
        expect(calls, 1);
        pending.completeError(StateError('private plugin details'));
        expect(await first, BackupShareOutcome.failed);
        expect(
          await transfer.shareBackup(emptyBackup()),
          BackupShareOutcome.failed,
        );
        expect(calls, 2);
      },
    );
  });

  group('backup page', () {
    late Directory directory;
    late LedgerStore source, target;
    late LedgerController controller;
    late FakeBackupTransfer transfer;
    setUp(() async {
      sqfliteFfiInit();
      directory = await Directory.systemTemp.createTemp('backup-widget-');
      source = await LedgerStore.open(
        factory: databaseFactoryFfiNoIsolate,
        path: '${directory.path}/source.sqlite',
        clock: () => backupNow,
      );
      target = await LedgerStore.open(
        factory: databaseFactoryFfiNoIsolate,
        path: '${directory.path}/target.sqlite',
        clock: () => backupNow,
      );
      await source.saveServer(backupServer(), isNew: true);
      controller = LedgerController(target, clock: () => backupNow);
      await controller.refresh();
      transfer = FakeBackupTransfer()
        ..source = (await source.exportLedgerBackup()).encode();
    });
    tearDown(() async {
      controller.dispose();
      await source.close();
      await target.close();
      await directory.delete(recursive: true);
    });
    Future<void> mount(WidgetTester tester) async {
      tester.view.physicalSize = const Size(430, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(),
          home: BackupPage(controller: controller, transfer: transfer),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> tap(WidgetTester tester, String text) async {
      await tester.ensureVisible(find.text(text));
      await tester.tap(find.text(text));
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 300));
      if (find.byType(AlertDialog).evaluate().isEmpty &&
          find.byType(CupertinoAlertDialog).evaluate().isEmpty) {
        await tester.pumpAndSettle();
      }
    }

    testWidgets(
      'restore previews counts, cancellation is read-only, confirmation restores',
      (tester) async {
        await mount(tester);
        expect(find.textContaining('文件未加密'), findsOneWidget);
        await tap(tester, '选择 JSON 并预览恢复');
        expect(find.text('恢复预览'), findsOneWidget);
        expect(controller.records, isEmpty);
        await tap(tester, '恢复到空台账');
        expect(find.text('恢复到当前空台账？'), findsOneWidget);
        await tap(tester, '取消');
        expect(controller.records, isEmpty);
        await tap(tester, '恢复到空台账');
        await tap(tester, '确认恢复');
        expect(controller.records.single.id, 'server');
        expect(find.textContaining('台账已恢复'), findsOneWidget);
        expect(transfer.saves, 0);
        expect(transfer.shares, 0);
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      'nonempty destination disables restore and invalid file clears old preview',
      (tester) async {
        await target.saveGroup('Existing');
        await controller.refresh();
        await mount(tester);
        await tap(tester, '选择 JSON 并预览恢复');
        expect(find.text('目标台账已有分组'), findsOneWidget);
        expect(
          tester
              .widget<AppButton>(find.widgetWithText(AppButton, '恢复到空台账'))
              .onPressed,
          isNull,
        );
        transfer.source = '{invalid';
        await tap(tester, '选择 JSON 并预览恢复');
        expect(find.text('恢复预览'), findsNothing);
        expect(find.textContaining('读取或校验失败'), findsOneWidget);
        expect(controller.groups.single.name, 'Existing');
      },
    );
    testWidgets('desktop export requires separate preview and explicit save', (
      tester,
    ) async {
      await mount(tester);
      await tap(tester, '生成导出预览');
      expect(transfer.saves, 0);
      expect(find.text('导出预览'), findsOneWidget);
      await tap(tester, '保存 JSON 备份');
      expect(transfer.saves, 1);
      expect(transfer.shares, 0);
      expect(LedgerBackupSnapshot.decode(transfer.savedJson!).servers, isEmpty);
      expect(find.textContaining('备份已保存'), findsOneWidget);
    });
    testWidgets(
      'mobile dismissal preserves export preview, never claims saved',
      (tester) async {
        transfer.mobile = true;
        await mount(tester);
        await tap(tester, '生成导出预览');
        await tap(tester, '分享未加密备份');
        expect(transfer.shares, 1);
        expect(transfer.saves, 0);
        expect(find.text('导出预览'), findsOneWidget);
        expect(find.text('已取消分享，备份预览仍保留。'), findsOneWidget);
        expect(find.textContaining('备份已保存'), findsNothing);
      },
    );
  });
}
