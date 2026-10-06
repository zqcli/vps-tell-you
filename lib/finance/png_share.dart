import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

import '../core/value_types.dart';

enum PngShareOutcome { selected, dismissed, unknown, unsupported, busy, failed }

typedef PngShareInvoker = Future<ShareResult> Function(ShareParams);

/// The only external boundary is the platform share call. Feed it the PNG from
/// CalculationShareData's whitelist renderer, never a ledger/account object.
/// Keep one instance per preview to prevent duplicate native sheets.
class MobilePngShare {
  MobilePngShare({PngShareInvoker? invoke})
    : _invoke = invoke ?? SharePlus.instance.share;

  final PngShareInvoker _invoke;
  bool _sharing = false;

  bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Success means a sheet action was selected, not delivery to a recipient.
  /// Callers own mounted/generation checks before publishing this result.
  Future<PngShareOutcome> share(
    Uint8List png,
    LedgerDate asOf, {
    Rect? origin,
  }) async {
    if (!supported) return PngShareOutcome.unsupported;
    if (_sharing) return PngShareOutcome.busy;
    if (!asOf.isValid ||
        png.length < _signature.length ||
        !listEquals(png.take(_signature.length).toList(), _signature)) {
      throw ArgumentError('A rendered PNG and valid date are required');
    }
    if (origin != null && (!origin.isFinite || origin.isEmpty)) {
      throw ArgumentError('Invalid share-sheet origin');
    }
    _sharing = true;
    try {
      final result = await _invoke(
        ShareParams(
          files: [
            XFile.fromData(Uint8List.fromList(png), mimeType: 'image/png'),
          ],
          fileNameOverrides: ['vps-tell-you-value-$asOf.png'],
          sharePositionOrigin: origin,
          downloadFallbackEnabled: false,
        ),
      );
      return switch (result.status) {
        ShareResultStatus.success => PngShareOutcome.selected,
        ShareResultStatus.dismissed => PngShareOutcome.dismissed,
        ShareResultStatus.unavailable => PngShareOutcome.unknown,
      };
    } catch (_) {
      // Plugin errors may contain paths; UI gets a fixed, non-sensitive outcome.
      return PngShareOutcome.failed;
    } finally {
      _sharing = false;
    }
  }

  static const _signature = [137, 80, 78, 71, 13, 10, 26, 10];
}
