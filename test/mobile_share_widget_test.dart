import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';
import 'package:vps_tell_you/core/value_types.dart';
import 'package:vps_tell_you/finance/calculation_share.dart';
import 'package:vps_tell_you/finance/png_share.dart';

CalculationShareData data({String amount = r'$10.00'}) => CalculationShareData(
  amount: amount,
  currency: 'USD',
  converted: '参考汇率缺失',
  asOf: const LedgerDate(2026, 10, 6),
  start: const LedgerDate(2026, 1, 1),
  end: const LedgerDate(2027, 1, 1),
  due: const LedgerDate(2027, 1, 1),
  ratio: 0.5,
  activeRemaining: 100,
  days: 365,
  remaining: 100,
  renewal: r'$36.50',
  daily: '0.10 USD',
  futurePeriods: 0,
  fx: '未设置',
  fxSource: '手动汇率',
  periodBasis: '独立试算，不入账',
);

void main() {
  Future<Uint8List> render(WidgetTester tester) async {
    late Uint8List bytes;
    await tester.runAsync(() async {
      bytes = await renderCalculationPng(data());
    });
    return bytes;
  }

  Future<void> reveal(WidgetTester tester) async {
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('系统分享 PNG'), 300);
    await tester.pumpAndSettle();
  }

  testWidgets('share outcomes preserve preview and do not promise delivery', (
    tester,
  ) async {
    final bytes = await render(tester);
    for (final entry in {
      ShareResultStatus.success: '请在目标应用核对是否送达',
      ShareResultStatus.dismissed: '已取消分享',
      ShareResultStatus.unavailable: '未收到系统分享结果',
    }.entries) {
      ShareParams? sent;
      await tester.pumpWidget(
        MaterialApp(
          home: CalculationPreview(
            key: UniqueKey(),
            data: data(),
            renderer: (_) async => bytes,
            sharer: MobilePngShare(
              invoke: (params) async {
                sent = params;
                return ShareResult('', entry.key);
              },
            ),
          ),
        ),
      );
      await reveal(tester);
      await tester.tap(find.text('系统分享 PNG'));
      await tester.pumpAndSettle();
      expect(find.textContaining(entry.value), findsOneWidget);
      expect(find.byKey(const ValueKey('calculation-png')), findsOneWidget);
      expect(sent!.sharePositionOrigin!.isEmpty, isFalse);
      expect(sent!.files!.single.mimeType, 'image/png');
      expect(tester.takeException(), isNull);
    }
  }, variant: TargetPlatformVariant({TargetPlatform.android}));

  testWidgets('double tap sends once; dismissing route ignores late result', (
    tester,
  ) async {
    final bytes = await render(tester);
    final pending = Completer<ShareResult>();
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => CalculationPreview(
                    data: data(),
                    renderer: (_) async => bytes,
                    sharer: MobilePngShare(
                      invoke: (_) {
                        calls++;
                        return pending.future;
                      },
                    ),
                  ),
                ),
              ),
              child: const Text('打开预览'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开预览'));
    await reveal(tester);
    await tester.tap(find.text('系统分享 PNG'));
    await tester.tap(find.text('系统分享 PNG'));
    await tester.pump();
    expect(calls, 1);
    await tester.pageBack();
    await tester.pumpAndSettle();
    pending.complete(const ShareResult('', ShareResultStatus.success));
    await tester.pumpAndSettle();
    expect(find.text('打开预览'), findsOneWidget);
    expect(find.textContaining('是否送达'), findsNothing);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant({TargetPlatform.android}));

  testWidgets('newer render rejects old result but unlocks retry', (
    tester,
  ) async {
    final bytes = await render(tester);
    final pending = Completer<ShareResult>();
    final value = ValueNotifier(data());
    addTearDown(value.dispose);
    var calls = 0;
    final sharer = MobilePngShare(
      invoke: (_) {
        calls++;
        return calls == 1
            ? pending.future
            : Future.value(const ShareResult('', ShareResultStatus.dismissed));
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder(
          valueListenable: value,
          builder: (_, value, _) => CalculationPreview(
            data: value,
            renderer: (_) async => bytes,
            sharer: sharer,
          ),
        ),
      ),
    );
    await reveal(tester);
    await tester.tap(find.text('系统分享 PNG'));
    await tester.pump();
    value.value = data(amount: r'$11.00');
    await tester.pumpAndSettle();
    pending.complete(const ShareResult('', ShareResultStatus.success));
    await tester.pumpAndSettle();
    expect(find.textContaining('是否送达'), findsNothing);
    await reveal(tester);
    await tester.tap(find.text('系统分享 PNG'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.textContaining('已取消分享'), findsOneWidget);
  }, variant: TargetPlatformVariant({TargetPlatform.android}));

  testWidgets('Linux offers local save without unsupported share action', (
    tester,
  ) async {
    final bytes = await render(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: CalculationPreview(data: data(), renderer: (_) async => bytes),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('保存 PNG'), 300);
    expect(find.text('系统分享 PNG'), findsNothing);
    expect(find.text('保存 PNG'), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant({TargetPlatform.linux}));
}
