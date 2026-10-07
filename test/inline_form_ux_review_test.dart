import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/core/app_theme.dart';
import 'package:vps_tell_you/core/value_types.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/security/security_controller.dart';
import 'package:vps_tell_you/servers/ledger_controller.dart';
import 'package:vps_tell_you/servers/server_form.dart';
import 'package:vps_tell_you/servers/server_record.dart';
import 'package:vps_tell_you/servers/server_resources.dart';

import 'security_store_test.dart' show FakeSecretStore, FakeDeviceAuth;

void main() {
  final evidence = Platform.environment['VPS_INLINE_REVIEW_EVIDENCE_DIR'];
  var fontsLoaded = false;
  late Directory directory;
  late LedgerStore store;
  late LedgerController ledger;
  late ServerRecord record;
  late FakeSecretStore secrets;
  final now = DateTime.utc(2026, 10, 6, 12);

  setUp(() async {
    sqfliteFfiInit();
    directory = await Directory.systemTemp.createTemp('vps-inline-review-');
    store = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: '${directory.path}/ledger.sqlite3',
      clock: () => now,
    );
    record = ServerRecord(
      id: 'inline-review',
      name: 'Synthetic review VPS',
      vendor: 'Synthetic vendor',
      resources: ServerResources(
        diskBytes: 21474836480,
        trafficBytes: ServerResources.maxBytes,
        ramBytes: 1610612736,
        vcpu: 2,
      ),
      billing: BillingKind.prepaid,
      amountMinor: 1200,
      startDate: const LedgerDate(2026, 1, 1),
      dueDate: const LedgerDate(2027, 1, 1),
      createdAt: now,
      updatedAt: now,
    );
    await store.saveServer(record, isNew: true);
    secrets = FakeSecretStore();
    ledger = LedgerController(
      store,
      clock: () => now,
      security: SecurityController(
        store: store,
        secrets: secrets,
        authenticator: FakeDeviceAuth(),
      ),
    );
    await ledger.refresh();
    record = ledger.byId(record.id)!;
  });

  tearDown(() async {
    ledger.dispose();
    await store.close();
    await directory.delete(recursive: true);
  });

  Finder currency() => find.byKey(const ValueKey('field-currency'));
  Finder cycle() => find.byKey(const ValueKey('field-cycle'));
  Finder billing() => find.byKey(const ValueKey('field-billing'));

  Future<void> mount(WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    if (evidence != null && !fontsLoaded) {
      await tester.runAsync(() async {
        final font = FontLoader('Inline review Noto');
        font.addFont(
          File(
            Platform.environment['VPS_FORM_EVIDENCE_FONT_PATH'] ??
                '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',
          ).readAsBytes().then(ByteData.sublistView),
        );
        await font.load();
        final icons = FontLoader('MaterialIcons');
        icons.addFont(
          File(
            '${Platform.environment['FLUTTER_BOOTSTRAP_ROOT']}/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
          ).readAsBytes().then(ByteData.sublistView),
        );
        await icons.load();
      });
      fontsLoaded = true;
    }
    final theme = appTheme();
    await tester.pumpWidget(
      MaterialApp(
        theme: evidence == null
            ? theme
            : theme.copyWith(
                textTheme: theme.textTheme.apply(
                  fontFamily: 'Inline review Noto',
                ),
                appBarTheme: theme.appBarTheme.copyWith(
                  titleTextStyle: theme.appBarTheme.titleTextStyle?.copyWith(
                    fontFamily: 'Inline review Noto',
                  ),
                ),
              ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: RepaintBoundary(
            key: const ValueKey('inline-review-evidence'),
            child: child!,
          ),
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ServerForm(
                      controller: ledger,
                      record: ledger.byId(record.id),
                    ),
                  ),
                ),
                child: const Text('Open review form'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open review form'));
    await tester.pumpAndSettle();
  }

  Future<void> fill(WidgetTester tester, String id, String value) async {
    final target = find.byKey(ValueKey(id));
    await tester.ensureVisible(target);
    await tester.enterText(target, value);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
  }

  Future<void> select<T>(WidgetTester tester, Finder target, T value) async {
    await tester.ensureVisible(target);
    final input = tester.widget<DropdownButton<T>>(
      find.descendant(of: target, matching: find.byType(DropdownButton<T>)),
    );
    final option = input.items!.singleWhere((item) => item.value == value);
    await tester.tap(target);
    await tester.pumpAndSettle();
    await tester.tap(find.byWidget(option.child).last);
    await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (evidence == null) return;
    await tester.pumpAndSettle();
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('inline-review-evidence')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory(evidence).create(recursive: true);
      await File('$evidence/$name.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets(
    'inline financial controls keep locked history and save edits once',
    (tester) async {
      await store.recordPayment(
        id: 'synthetic-payment',
        server: record,
        amount: const Money('EUR', 9876),
        paidDate: const LedgerDate(2026, 10, 6),
        cycleCount: 1,
        until: const LedgerDate(2028, 1, 1),
        confirmed: true,
      );
      await ledger.refresh();
      record = ledger.byId(record.id)!;
      final payments = (await store.payments()).map((p) => p.toMap()).toList();
      final periods = (await store.servicePeriods())
          .map((p) => p.toMap())
          .toList();
      await mount(tester);
      expect(
        tester
            .widget<DropdownButtonFormField<BillingKind>>(billing())
            .onChanged,
        isNull,
      );
      expect(
        tester
            .widget<DropdownButton<int>>(
              find.descendant(
                of: cycle(),
                matching: find.byType(DropdownButton<int>),
              ),
            )
            .onChanged,
        isNull,
      );
      for (final key in ['field-start', 'field-due']) {
        expect(
          tester.widget<TextFormField>(find.byKey(ValueKey(key))).enabled,
          isFalse,
        );
      }
      expect(
        tester.widget<DropdownButtonFormField<String>>(currency()).onChanged,
        isNotNull,
      );
      await select(tester, currency(), 'CNY');
      await fill(tester, 'field-amount', '9999999999.99');
      await tester.tap(find.text('保存服务器'));
      await tester.tap(find.text('保存服务器'));
      await tester.pumpAndSettle();
      final saved = (await store.servers()).single;
      expect(saved.currency, 'CNY');
      expect(saved.amountMinor, Money.maxMinor);
      expect(saved.revision, record.revision + 1);
      expect(saved.startDate, record.startDate);
      expect(saved.dueDate, record.dueDate);
      expect(saved.cycleMonths, record.cycleMonths);
      expect(saved.resources!.toJson(), record.resources!.toJson());
      expect((await store.payments()).map((p) => p.toMap()).toList(), payments);
      expect(
        (await store.servicePeriods()).map((p) => p.toMap()).toList(),
        periods,
      );
      expect(find.text('Open review form'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'changing billing preserves unsaved price but free and unknown stay distinct',
    (tester) async {
      await mount(tester);
      await select(tester, currency(), 'EUR');
      await select(tester, cycle(), 3);
      await fill(tester, 'field-amount', '0');
      await select(tester, billing(), BillingKind.unknown);
      expect(find.byKey(const ValueKey('field-amount')), findsNothing);
      await select(tester, billing(), BillingKind.prepaid);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('field-amount')))
            .controller!
            .text,
        '0',
      );
      expect(
        tester.widget<DropdownButtonFormField<String>>(currency()).initialValue,
        'EUR',
      );
      expect(
        tester
            .widget<DropdownButton<int>>(
              find.descendant(
                of: cycle(),
                matching: find.byType(DropdownButton<int>),
              ),
            )
            .value,
        3,
      );
      await tester.tap(find.text('保存服务器'));
      await tester.pumpAndSettle();
      var saved = (await store.servers()).single;
      expect(saved.billing, BillingKind.prepaid);
      expect(saved.amountMinor, 0);
      expect(saved.currency, 'EUR');
      expect(saved.cycleMonths, 3);
      await tester.tap(find.text('Open review form'));
      await tester.pumpAndSettle();
      await select(tester, billing(), BillingKind.unknown);
      await tester.tap(find.text('保存服务器'));
      await tester.pumpAndSettle();
      saved = (await store.servers()).single;
      expect(saved.billing, BillingKind.unknown);
      expect(saved.amountMinor, isNull);
      expect(await store.payments(), isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('cancel discards edits without touching records or secrets', (
    tester,
  ) async {
    final before = (await store.servers()).single.toMap();
    await mount(tester);
    await fill(tester, 'resource-trafficBytes', '1.25');
    await select(tester, currency(), 'CNY');
    await fill(tester, 'field-notes', 'Synthetic unsaved note');
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('Open review form'), findsOneWidget);
    expect((await store.servers()).single.toMap(), before);
    expect(secrets.reads, 0);
    expect(secrets.writes, 0);
    expect(secrets.deletes, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'save from the bottom reveals the first error without losing edits',
    (tester) async {
      await mount(tester);
      await fill(tester, 'field-name', '');
      await fill(tester, 'resource-diskBytes', '0');
      await fill(tester, 'field-notes', 'Keep this draft');
      await tester.tap(find.text('保存服务器'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('field-name')).hitTestable(),
        findsOneWidget,
      );
      expect(find.text('请填写服务器名称').hitTestable(), findsOneWidget);
      expect((await store.servers()).single.notes, isEmpty);
      await fill(tester, 'field-name', 'Corrected synthetic name');
      await tester.tap(find.text('保存服务器'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('resource-diskBytes')).hitTestable(),
        findsOneWidget,
      );
      expect(find.text('请填写大于 0 的容量，精确到整字节').hitTestable(), findsOneWidget);
      await fill(tester, 'resource-diskBytes', '20');
      await tester.tap(find.text('保存服务器'));
      await tester.pumpAndSettle();
      final saved = (await store.servers()).single;
      expect(saved.name, 'Corrected synthetic name');
      expect(saved.notes, 'Keep this draft');
      expect(saved.resources!.diskBytes, record.resources!.diskBytes);
      expect(saved.resources!.trafficBytes, ServerResources.maxBytes);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('amount and date errors remain readable and lead to correction', (
    tester,
  ) async {
    await mount(tester);
    await fill(tester, 'field-amount', '1.234');
    await fill(tester, 'field-due', '2025-01-01');
    await fill(tester, 'field-notes', 'Keep corrections');
    await tester.tap(find.text('保存服务器'));
    await tester.pumpAndSettle();
    final amountError = find.text('请输入有效金额，最多两位小数');
    expect(amountError.hitTestable(), findsOneWidget);
    expect(
      tester.renderObject<RenderParagraph>(amountError).didExceedMaxLines,
      isFalse,
    );
    await fill(tester, 'field-amount', '1.23');
    await tester.tap(find.text('保存服务器'));
    await tester.pumpAndSettle();
    final dateError = find.text('到期日必须晚于开始日');
    expect(dateError.hitTestable(), findsOneWidget);
    expect(
      tester.renderObject<RenderParagraph>(dateError).didExceedMaxLines,
      isFalse,
    );
    await fill(tester, 'field-due', '2027-01-01');
    await tester.tap(find.text('保存服务器'));
    await tester.pumpAndSettle();
    final saved = (await store.servers()).single;
    expect(saved.amountMinor, 123);
    expect(saved.dueDate, const LedgerDate(2027, 1, 1));
    expect(saved.notes, 'Keep corrections');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'inline selectors and unlimited switch retain spoken labels and state',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await mount(tester);
        for (final entry in [
          (currency(), '原币种', 'USD'),
          (cycle(), '续费周期', '每年'),
          (billing(), '计费方式', '预付费'),
        ]) {
          await tester.ensureVisible(entry.$1);
          await tester.pumpAndSettle();
          final node = tester.getSemantics(entry.$1).getSemanticsData();
          expect(node.label, contains(entry.$2));
          expect(node.label, contains(entry.$3));
        }
        final toggle = find.byKey(const ValueKey('resource-traffic-unlimited'));
        await tester.ensureVisible(toggle);
        await tester.pumpAndSettle();
        final before = tester.getSemantics(toggle).getSemanticsData();
        expect(before.label, contains('流量不限量'));
        expect(before.flagsCollection.isToggled, ui.Tristate.isFalse);
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(
          tester
              .getSemantics(toggle)
              .getSemanticsData()
              .flagsCollection
              .isToggled,
          ui.Tristate.isTrue,
        );
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'metered mode presents a monthly amount without irrelevant dates or cycles',
    (tester) async {
      await mount(tester);
      await select(tester, billing(), BillingKind.metered);
      expect(find.byKey(const ValueKey('field-cycle')), findsNothing);
      expect(find.byKey(const ValueKey('field-start')), findsNothing);
      expect(find.byKey(const ValueKey('field-due')), findsNothing);
      final amount = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const ValueKey('field-amount')),
          matching: find.byType(TextField),
        ),
      );
      expect(amount.decoration!.labelText, '金额');
      expect(amount.decoration!.helperText, isNull);
      expect(find.textContaining('每月费用估算'), findsOneWidget);
      await select(tester, currency(), 'CNY');
      await fill(tester, 'field-amount', '0.01');
      await tester.tap(find.text('保存服务器'));
      await tester.pumpAndSettle();
      final saved = (await store.servers()).single;
      expect(saved.billing, BillingKind.metered);
      expect(saved.amountMinor, 1);
      expect(saved.currency, 'CNY');
      expect(saved.startDate, isNull);
      expect(saved.dueDate, isNull);
      expect(saved.resources!.toJson(), record.resources!.toJson());
      expect(await store.payments(), isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'long billing choices remain fully readable at narrow doubled text',
    (tester) async {
      await mount(tester);
      for (final entry in const [
        (BillingKind.unknown, '费用未知', 'unknown'),
        (BillingKind.metered, '按量付费', 'metered'),
      ]) {
        await select(tester, billing(), entry.$1);
        await Scrollable.ensureVisible(
          tester.element(find.byKey(const ValueKey('row-billing'))),
          alignment: 0.12,
        );
        await tester.pumpAndSettle();
        final text = find.descendant(
          of: billing(),
          matching: find.text(entry.$2),
        );
        final paragraph = tester.renderObject<RenderParagraph>(text);
        expect(paragraph.didExceedMaxLines, isFalse);
        expect(
          paragraph.getBoxesForSelection(
            TextSelection(baseOffset: 0, extentOffset: entry.$2.length),
          ),
          hasLength(1),
          reason: 'The short four-character billing choice fits without orphaning its last character',
        );
        final rect = tester.getRect(text);
        final control = tester.getRect(billing());
        expect(rect.top, greaterThanOrEqualTo(control.top));
        expect(rect.bottom, lessThanOrEqualTo(control.bottom + 0.01));
        expect(rect.right, lessThanOrEqualTo(control.right));
        expect(control.right, lessThanOrEqualTo(300));
        expect(control.height, greaterThanOrEqualTo(48));
        await capture(tester, 'billing-${entry.$3}-320-2x');
        expect(tester.takeException(), isNull);
      }
    },
  );
}
