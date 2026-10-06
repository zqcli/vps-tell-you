import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';
import 'package:vps_tell_you/core/value_types.dart';
import 'package:vps_tell_you/finance/png_share.dart';

void main() {
  const asOf = LedgerDate(2026, 4, 20);
  Uint8List png() => base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLbtAAAAABJRU5ErkJggg==',
  );
  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.android);
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test(
    'shares only PNG bytes with safe filename and explicit popover origin',
    () async {
      late ShareParams sent;
      final share = MobilePngShare(
        invoke: (params) async {
          sent = params;
          return const ShareResult(
            'untrusted-platform-text',
            ShareResultStatus.success,
          );
        },
      );
      const origin = Rect.fromLTWH(12, 40, 140, 48);
      expect(
        await share.share(png(), asOf, origin: origin),
        PngShareOutcome.selected,
      );
      expect(sent.files, hasLength(1));
      expect(sent.files!.single.mimeType, 'image/png');
      expect(await sent.files!.single.readAsBytes(), png());
      expect(sent.fileNameOverrides, ['vps-tell-you-value-2026-04-20.png']);
      expect(sent.sharePositionOrigin, origin);
      expect(sent.text, isNull);
      expect(sent.uri, isNull);
      expect(sent.subject, isNull);
      expect(sent.title, isNull);
      expect(sent.downloadFallbackEnabled, isFalse);
    },
  );

  test(
    'iOS uses native sharing and distinguishes dismissal from unknown',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      for (final entry in {
        ShareResultStatus.dismissed: PngShareOutcome.dismissed,
        ShareResultStatus.unavailable: PngShareOutcome.unknown,
      }.entries) {
        final share = MobilePngShare(
          invoke: (_) async => ShareResult('', entry.key),
        );
        expect(share.supported, isTrue);
        expect(await share.share(png(), asOf), entry.value);
      }
    },
  );

  test(
    'Linux and other non-mobile platforms never invoke native sharing',
    () async {
      var calls = 0;
      final share = MobilePngShare(
        invoke: (_) async {
          calls++;
          return const ShareResult('', ShareResultStatus.success);
        },
      );
      for (final platform in [
        TargetPlatform.linux,
        TargetPlatform.macOS,
        TargetPlatform.windows,
        TargetPlatform.fuchsia,
      ]) {
        debugDefaultTargetPlatformOverride = platform;
        expect(share.supported, isFalse);
        expect(await share.share(png(), asOf), PngShareOutcome.unsupported);
      }
      expect(calls, 0);
    },
  );

  test(
    'double tap opens one sheet and holds an immutable byte snapshot',
    () async {
      final pending = Completer<ShareResult>();
      late ShareParams sent;
      var calls = 0;
      final share = MobilePngShare(
        invoke: (params) {
          calls++;
          sent = params;
          return pending.future;
        },
      );
      final original = png();
      final first = share.share(original, asOf);
      original.fillRange(0, original.length, 0);
      expect(await share.share(png(), asOf), PngShareOutcome.busy);
      expect(calls, 1);
      expect(await sent.files!.single.readAsBytes(), png());
      pending.complete(const ShareResult('', ShareResultStatus.dismissed));
      expect(await first, PngShareOutcome.dismissed);
      expect(await share.share(png(), asOf), PngShareOutcome.dismissed);
      expect(calls, 2);
    },
  );

  test(
    'native failures expose no plugin text and release the retry guard',
    () async {
      var calls = 0;
      final share = MobilePngShare(
        invoke: (_) async {
          if (++calls == 1) {
            throw PlatformException(
              code: 'error',
              message: '/private/fixture-only',
            );
          }
          return const ShareResult('', ShareResultStatus.success);
        },
      );
      expect(await share.share(png(), asOf), PngShareOutcome.failed);
      expect(await share.share(png(), asOf), PngShareOutcome.selected);
    },
  );

  test('invalid PNG/date/origin never invokes the plugin', () async {
    var calls = 0;
    final share = MobilePngShare(
      invoke: (_) async {
        calls++;
        return const ShareResult('', ShareResultStatus.success);
      },
    );
    for (final bytes in [
      Uint8List(0),
      Uint8List(8),
      Uint8List.fromList([137, 80]),
    ]) {
      await expectLater(share.share(bytes, asOf), throwsArgumentError);
    }
    await expectLater(
      share.share(png(), const LedgerDate(2026, 2, 30)),
      throwsArgumentError,
    );
    for (final origin in [
      Rect.zero,
      const Rect.fromLTWH(0, 0, -1, 4),
      const Rect.fromLTWH(double.nan, 0, 4, 4),
    ]) {
      await expectLater(
        share.share(png(), asOf, origin: origin),
        throwsArgumentError,
      );
    }
    expect(calls, 0);
    expect(await share.share(png(), asOf), PngShareOutcome.selected);
  });
}
