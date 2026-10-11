import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../l10n/locale_preference.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/localized_message.dart';
import '../core/app_theme.dart';
import '../core/value_types.dart';
import 'png_share.dart';
import 'valuation_copy.dart';

/// Explicit export whitelist. Never accepts a server, payment or account object.
/// Quotation / settlement information is deliberately absent.
class CalculationShareData {
  const CalculationShareData({
    this.localizations,
    required this.amount,
    required this.currency,
    required this.converted,
    required this.asOf,
    required this.start,
    required this.end,
    required this.due,
    required this.ratio,
    required this.activeRemaining,
    required this.days,
    required this.remaining,
    required this.renewal,
    required this.daily,
    required this.futurePeriods,
    required this.fx,
    required this.fxSource,
    required this.periodBasis,
  });

  /// Captured when the export is requested; changing the UI locale cannot mix
  /// languages inside an in-flight image or previously created text export.
  final AppLocalizations? localizations;
  AppLocalizations get l10n => localizations ?? defaultLocalizations;
  final String amount, currency, converted, renewal, daily, fx, fxSource;
  final String periodBasis;
  final LedgerDate asOf, due;
  final LedgerDate? start, end;
  final double ratio;
  final int activeRemaining, days, remaining, futurePeriods;
  String get percent => '${(ratio.clamp(0, 1) * 100).toStringAsFixed(1)}%';
  String get periodLabel =>
      valuationPeriodLabel(asOf: asOf, start: start, end: end, l10n: l10n);
  String get plainText => [
    l10n.financeExportValue(amount, currency),
    converted,
    l10n.financeExportValuationDate(asOf.toString()),
    l10n.financeExportPeriod(
      periodLabel,
      start?.toString() ?? l10n.financeUnknown,
      end?.toString() ?? l10n.financeUnknown,
    ),
    l10n.financeExportPeriodRemaining(
      periodLabel,
      activeRemaining,
      days,
      percent,
    ),
    l10n.financeExportServiceRemaining(due.toString(), remaining),
    l10n.financeExportRenewalDaily(renewal, daily),
    if (futurePeriods > 0) l10n.financeExportFuturePeriods(futurePeriods),
    periodBasis,
    fx,
    fxSource,
    l10n.financeExportDisclaimer,
  ].join('\n');
}

typedef CalculationRenderer = Future<Uint8List> Function(CalculationShareData);
typedef CalculationSaver = Future<String> Function(Uint8List, LedgerDate);

/// Test hook: font family of the share card (tests render with a real font
/// to review the layout). Production keeps the platform default.
@visibleForTesting
String? calculationPngFontFamily;

/// Share card: 540 × N logical px drawn at 2× (1080 px wide), light theme
/// regardless of the app theme so the image looks the same everywhere.
///
/// A gradient header with the brand line and the big value, a ring for the
/// unused part of the shown period, a start → valuation → due timeline, the key
/// figures and the reference-only footer. It draws nothing but
/// [CalculationShareData] (no server, account, note or quote information).
/// TextPainter performs both layout and drawing, so Chinese and long values
/// determine the real image height rather than being clipped by a fixed canvas.
/// Everything is deterministic: no clock, no random, no platform widgets.
Future<Uint8List> renderCalculationPng(CalculationShareData data) async {
  final l10n = data.l10n;
  const width = 540.0, cardX = 16.0, pad = 28.0;
  const cardW = width - cardX * 2, contentX = cardX + pad;
  const contentW = cardW - pad * 2;
  const violet = Color(0xFF6A5AE8), indigo = Color(0xFF4C6FF0);
  const fallback = ['Noto Sans CJK SC', 'PingFang SC', 'Microsoft YaHei'];
  final ops = <void Function(Canvas)>[];

  TextPainter painter(
    String text, {
    double size = 14,
    bool bold = false,
    Color color = AppColors.ink,
    double maxWidth = contentW,
    TextAlign align = TextAlign.start,
    double height = 1.4,
  }) => TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontSize: size,
        height: height,
        fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
        color: color,
        fontFamily: calculationPngFontFamily,
        fontFeatures: const [FontFeature.tabularFigures()],
        fontFamilyFallback: fallback,
      ),
    ),
    textAlign: align,
    textWidthBasis: TextWidthBasis.longestLine,
    textDirection: TextDirection.ltr,
    locale: Locale(l10n.localeName),
  )..layout(maxWidth: maxWidth);

  // Draws [tp] at ([x], [y]) and returns its height.
  double put(TextPainter tp, double x, double y) {
    ops.add((canvas) {
      tp.paint(canvas, Offset(x, y));
      tp.dispose();
    });
    return tp.height;
  }

  // ---- gradient header ----
  const headerTop = cardX;
  var y = headerTop + 24;
  ops.add((canvas) {
    final icon = RRect.fromRectAndRadius(
      Rect.fromLTWH(contentX, headerTop + 24, 24, 24),
      const Radius.circular(7),
    );
    canvas.drawRRect(
      icon,
      Paint()..color = Colors.white.withValues(alpha: .22),
    );
    final bar = Paint()..color = Colors.white;
    for (var i = 0; i < 3; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(contentX + 5, headerTop + 24 + 5.5 + i * 5.5, 14, 3),
          const Radius.circular(1.5),
        ),
        bar,
      );
    }
  });
  final heading = painter(
    l10n.financeExportHeading,
    size: 14,
    bold: true,
    color: Colors.white,
    maxWidth: contentW - 34,
  );
  put(heading, contentX + 34, y + (24 - heading.height) / 2);
  y += 24 + 22;
  y += put(
    painter(
      l10n.financeValueTitle,
      size: 14,
      color: Colors.white.withValues(alpha: .86),
    ),
    contentX,
    y,
  );
  y += 4;
  // Shrink the figure before wrapping so long amounts stay one line.
  final amountText = '${data.amount} ${data.currency}';
  var amountSize = 48.0;
  var amount = painter(
    amountText,
    size: amountSize,
    bold: true,
    color: Colors.white,
    maxWidth: 10000,
    height: 1.2,
  );
  while (amount.width > contentW && amountSize > 24) {
    amount.dispose();
    amountSize -= 2;
    amount = painter(
      amountText,
      size: amountSize,
      bold: true,
      color: Colors.white,
      maxWidth: 10000,
      height: 1.2,
    );
  }
  if (amount.width > contentW) {
    amount.dispose();
    amount = painter(
      amountText,
      size: amountSize,
      bold: true,
      color: Colors.white,
      height: 1.2,
    );
  }
  y += put(amount, contentX, y);
  y += 4;
  y += put(
    painter(
      data.converted,
      size: 14,
      color: Colors.white.withValues(alpha: .9),
    ),
    contentX,
    y,
  );
  final headerBottom = y + 26;
  y = headerBottom + 26;

  // ---- ring + period progress ----
  const ringSize = 116.0, ringStroke = 12.0;
  final ringTop = y;
  final ratio = data.ratio.isFinite ? data.ratio.clamp(0, 1).toDouble() : 0.0;
  ops.add((canvas) {
    final rect = Rect.fromLTWH(
      contentX,
      ringTop,
      ringSize,
      ringSize,
    ).deflate(ringStroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringStroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      rect,
      0,
      6.283185307179586,
      false,
      paint..color = AppColors.line,
    );
    if (ratio > 0) {
      paint.shader = ui.Gradient.linear(rect.topLeft, rect.bottomRight, [
        AppColors.blue,
        violet,
      ]);
      canvas.drawArc(
        rect,
        -1.5707963267948966,
        6.283185307179586 * ratio,
        false,
        paint,
      );
    }
  });
  final pct = painter(
    data.percent,
    size: 24,
    bold: true,
    maxWidth: ringSize - ringStroke * 2 - 6,
    align: TextAlign.center,
    height: 1.1,
  );
  put(
    pct,
    contentX + (ringSize - pct.width) / 2,
    ringTop + (ringSize - pct.height) / 2,
  );
  const textX = contentX + ringSize + 22;
  const textW = contentW - ringSize - 22;
  final dates = painter(
    l10n.financePeriodDates(
      data.start?.toString() ?? l10n.financeUnknown,
      data.end?.toString() ?? l10n.financeUnknown,
    ),
    size: 12,
    color: AppColors.muted,
    maxWidth: textW,
  );
  final progress = painter(
    l10n.financePeriodProgress(
      data.periodLabel,
      (ratio * 100).toStringAsFixed(1),
      data.activeRemaining,
      data.days,
    ),
    size: 15,
    bold: true,
    maxWidth: textW,
  );
  // Centre the caption beside the ring when it is shorter than the ring.
  final blockH = progress.height + 4 + dates.height;
  var ty = ringTop + (blockH < ringSize ? (ringSize - blockH) / 2 : 0);
  ty += put(progress, textX, ty) + 4;
  ty += put(dates, textX, ty);
  y = (ringTop + ringSize > ty ? ringTop + ringSize : ty) + 26;

  // ---- timeline: period start -> valuation date -> due ----
  final start = data.start;
  final due = data.due;
  if (start != null) {
    final total = start.daysUntil(due);
    final fraction = total <= 0
        ? 0.0
        : (start.daysUntil(data.asOf) / total).clamp(0, 1).toDouble();
    final lineY = y + 10;
    ops.add((canvas) {
      final line = Paint()
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round;
      final x0 = contentX + 8, x1 = contentX + contentW - 8;
      final x = x0 + (x1 - x0) * fraction;
      canvas.drawLine(
        Offset(x0, lineY),
        Offset(x1, lineY),
        line..color = AppColors.line,
      );
      if (x > x0) {
        canvas.drawLine(
          Offset(x0, lineY),
          Offset(x, lineY),
          line..color = AppColors.blue,
        );
      }
      canvas.drawCircle(Offset(x0, lineY), 6, Paint()..color = AppColors.blue);
      canvas.drawCircle(Offset(x1, lineY), 6, Paint()..color = AppColors.muted);
      canvas.drawCircle(Offset(x, lineY), 11, Paint()..color = AppColors.blue);
      canvas.drawCircle(Offset(x, lineY), 5.5, Paint()..color = Colors.white);
    });
    y += 30;
    const colW = contentW / 3;
    var rowH = 0.0;
    final labels = [
      (l10n.r3FinanceTimelineStart, start, TextAlign.start),
      (l10n.r3FinanceTimelineAsOf, data.asOf, TextAlign.center),
      (l10n.r3FinanceTimelineDue, due, TextAlign.end),
    ];
    for (var i = 0; i < 3; i++) {
      final caption = painter(
        labels[i].$1,
        size: 12,
        color: AppColors.muted,
        maxWidth: colW,
        align: labels[i].$3,
      );
      final date = painter(
        labels[i].$2.toString(),
        size: 13,
        bold: true,
        maxWidth: colW,
        align: labels[i].$3,
      );
      final cx = contentX + colW * i;
      // TextPainter aligns inside its own width, so give every column the
      // same box and let the alignment do the rest.
      put(caption, cx + (colW - caption.width) * (i / 2), y);
      put(date, cx + (colW - date.width) * (i / 2), y + caption.height);
      final h = caption.height + date.height;
      if (h > rowH) rowH = h;
    }
    y += rowH + 22;
  }

  // ---- key figures ----
  double tile(String label, String value, double x, double w, double top) {
    final cap = painter(
      label,
      size: 12,
      color: AppColors.muted,
      maxWidth: w - 24,
    );
    final val = painter(
      value,
      size: 16,
      bold: true,
      maxWidth: w - 24,
      height: 1.3,
    );
    final h = 12 + cap.height + 2 + val.height + 12;
    ops.add((canvas) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, top, w, h),
          const Radius.circular(14),
        ),
        Paint()..color = AppColors.soft,
      );
    });
    put(cap, x + 12, top + 12);
    put(val, x + 12, top + 12 + cap.height + 2);
    return h;
  }

  const gap = 10.0;
  const half = (contentW - gap) / 2;
  final h1 = tile(
    l10n.financeRemainingDays,
    l10n.financeDaysValue(data.remaining),
    contentX,
    half,
    y,
  );
  final h2 = tile(
    l10n.financeDailyShown,
    data.daily,
    contentX + half + gap,
    half,
    y,
  );
  y += (h1 > h2 ? h1 : h2) + gap;
  y += tile(l10n.financeRenewalCycle, data.renewal, contentX, contentW, y) + 20;

  // ---- notes ----
  if (data.futurePeriods > 0) {
    y +=
        put(
          painter(
            l10n.financeExportFuturePeriods(data.futurePeriods),
            size: 12,
            color: AppColors.muted,
          ),
          contentX,
          y,
        ) +
        4;
  }
  y +=
      put(
        painter(data.periodBasis, size: 12, color: AppColors.muted),
        contentX,
        y,
      ) +
      4;
  y += put(painter(data.fx, size: 12, color: AppColors.muted), contentX, y);
  y +=
      put(
        painter(data.fxSource, size: 12, color: AppColors.muted),
        contentX,
        y,
      ) +
      14;
  final ruleY = y;
  ops.add((canvas) {
    canvas.drawLine(
      Offset(contentX, ruleY),
      Offset(contentX + contentW, ruleY),
      Paint()
        ..color = AppColors.line
        ..strokeWidth = 1,
    );
  });
  y += 14;
  y +=
      put(
        painter(
          l10n.financeExportDisclaimer,
          size: 13,
          bold: true,
          color: AppColors.blue,
        ),
        contentX,
        y,
      ) +
      4;
  y += put(
    painter(l10n.financeExportFooter, size: 12, color: AppColors.muted),
    contentX,
    y,
  );
  final cardBottom = y + 24;
  final height = (cardBottom + cardX).ceil();

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..scale(2);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width, height.toDouble()),
    Paint()..color = AppColors.canvas,
  );
  final cardRect = RRect.fromRectAndRadius(
    Rect.fromLTWH(cardX, cardX, cardW, cardBottom - cardX),
    const Radius.circular(24),
  );
  canvas.drawRRect(cardRect, Paint()..color = Colors.white);
  canvas.save();
  canvas.clipRRect(cardRect);
  canvas.drawRect(
    Rect.fromLTRB(cardX, headerTop, cardX + cardW, headerBottom),
    Paint()
      ..shader = ui.Gradient.linear(
        Offset(cardX, headerTop),
        Offset(cardX + cardW, headerBottom),
        [AppColors.blue, indigo, violet],
        const [0, .55, 1],
      ),
  );
  canvas.restore();
  for (final op in ops) {
    op(canvas);
  }
  final picture = recorder.endRecording();
  final image = await picture.toImage((width * 2).round(), height * 2);
  picture.dispose();
  try {
    final encoded = await image.toByteData(format: ui.ImageByteFormat.png);
    if (encoded == null) throw StateError('PNG encoding failed');
    return encoded.buffer.asUint8List(
      encoded.offsetInBytes,
      encoded.lengthInBytes,
    );
  } finally {
    image.dispose();
  }
}

Future<String> saveCalculationPng(Uint8List bytes, LedgerDate asOf) async {
  Directory? root;
  try {
    root = await getDownloadsDirectory();
  } on MissingPlatformDirectoryException {
    // A location lookup is unavailable; no write has been attempted.
  } on UnsupportedError {
    // Some platforms do not expose a Downloads directory.
  }
  if (root == null) {
    try {
      root = await getApplicationDocumentsDirectory();
    } on MissingPlatformDirectoryException {
      // For example, a minimal Linux runtime without xdg-user-dir.
    } on UnsupportedError {
      // Only an unavailable location is eligible for the support fallback.
    }
  }
  if (root == null) {
    final support = await getApplicationSupportDirectory();
    root = Directory(path.join(support.path, 'exports'));
  }
  // Permission, disk and other write failures propagate. Never silently change
  // the destination once a usable directory path has been selected.
  return saveCalculationPngIn(root, bytes, asOf);
}

/// A unique directory avoids silent replacement even for simultaneous saves.
Future<String> saveCalculationPngIn(
  Directory root,
  Uint8List bytes,
  LedgerDate asOf,
) async {
  await root.create(recursive: true);
  final folder = await root.createTemp('vps-value-');
  final file = File(path.join(folder.path, 'vps-tell-you-value-$asOf.png'));
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

class CalculationPreview extends StatefulWidget {
  const CalculationPreview({
    super.key,
    required this.data,
    this.renderer = renderCalculationPng,
    this.saver = saveCalculationPng,
    this.sharer,
  });
  final CalculationShareData data;
  final CalculationRenderer renderer;
  final CalculationSaver saver;
  final MobilePngShare? sharer;
  @override
  State<CalculationPreview> createState() => _CalculationPreviewState();
}

class _CalculationPreviewState extends State<CalculationPreview> {
  Uint8List? bytes;
  LocalizedText? status;
  bool generating = true, saving = false, sharing = false;
  late final MobilePngShare sharer;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    sharer = widget.sharer ?? MobilePngShare();
    generate();
  }

  @override
  void didUpdateWidget(CalculationPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) generate();
  }

  @override
  void dispose() {
    generation++;
    super.dispose();
  }

  Future<void> generate() async {
    final ticket = ++generation;
    setState(() {
      generating = true;
      saving = false;
      bytes = null;
      status = null;
    });
    try {
      final result = await widget.renderer(widget.data);
      if (!mounted || ticket != generation) return;
      setState(() {
        bytes = result;
        generating = false;
      });
    } catch (_) {
      if (!mounted || ticket != generation) return;
      setState(() {
        generating = false;
        status = LocalizedText((l10n) => l10n.financePngRenderFailed);
      });
    }
  }

  Future<void> save() async {
    if (saving || sharing || bytes == null) return;
    final ticket = generation;
    setState(() {
      saving = true;
      status = null;
    });
    try {
      final savedPath = await widget.saver(bytes!, widget.data.asOf);
      if (!mounted || ticket != generation) return;
      setState(
        () => status = LocalizedText(
          (l10n) => l10n.financePngSavedPath(savedPath),
        ),
      );
    } catch (_) {
      if (!mounted || ticket != generation) return;
      setState(
        () => status = LocalizedText((l10n) => l10n.financePngSaveFailed),
      );
    } finally {
      if (mounted && ticket == generation) setState(() => saving = false);
    }
  }

  Future<void> share(BuildContext buttonContext) async {
    if (saving || sharing || bytes == null) return;
    final ticket = generation;
    final box = buttonContext.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    setState(() {
      sharing = true;
      status = null;
    });
    try {
      final result = await sharer.share(
        bytes!,
        widget.data.asOf,
        origin: origin,
      );
      if (!mounted || ticket != generation) return;
      setState(
        () => status = switch (result) {
          PngShareOutcome.selected => LocalizedText(
            (l10n) => l10n.financePngShareSelected,
          ),
          PngShareOutcome.dismissed => LocalizedText(
            (l10n) => l10n.financePngShareDismissed,
          ),
          PngShareOutcome.unknown => LocalizedText(
            (l10n) => l10n.financePngShareUnknown,
          ),
          PngShareOutcome.unsupported => LocalizedText(
            (l10n) => l10n.financePngShareUnsupported,
          ),
          PngShareOutcome.busy => LocalizedText(
            (l10n) => l10n.financePngShareBusy,
          ),
          PngShareOutcome.failed => LocalizedText(
            (l10n) => l10n.financePngShareFailed,
          ),
        },
      );
    } catch (_) {
      if (mounted && ticket == generation) {
        setState(
          () => status = LocalizedText((l10n) => l10n.financePngShareFailed),
        );
      }
    } finally {
      // A newer render must not inherit a permanently busy button from this
      // earlier native sheet. The result itself remains generation-fenced.
      if (mounted) setState(() => sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.financePngPreview)),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        InfoNote(context.l10n.financePngPrivacy),
        if (generating)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(),
            ),
          ),
        if (bytes != null)
          Image.memory(
            bytes!,
            key: const ValueKey('calculation-png'),
            semanticLabel: context.l10n.financePngSemantic,
          ),
        if (status != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: SelectableText(status!.messageFor(context.l10n)),
          ),
        if (!generating && bytes == null)
          FilledButton(
            onPressed: generate,
            child: Text(context.l10n.financeRegenerate),
          ),
        if (bytes != null) ...[
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: saving || sharing ? null : save,
            icon: const Icon(Icons.download_outlined),
            label: Text(
              saving ? context.l10n.financeSaving : context.l10n.financeSavePng,
            ),
          ),
          if (sharer.supported) ...[
            const SizedBox(height: 10),
            Builder(
              builder: (buttonContext) => OutlinedButton.icon(
                onPressed: saving || sharing
                    ? null
                    : () => share(buttonContext),
                icon: const Icon(Icons.ios_share),
                label: Text(
                  sharing
                      ? context.l10n.financeSharing
                      : context.l10n.financeSharePng,
                ),
              ),
            ),
          ],
          InfoNote(context.l10n.financePngLocationNote),
        ],
      ],
    ),
  );
}
