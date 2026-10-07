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

/// TextPainter performs both layout and drawing, so Chinese and long values
/// determine the real image height rather than being clipped by a fixed canvas.
Future<Uint8List> renderCalculationPng(CalculationShareData data) async {
  final l10n = data.l10n;
  const width = 540.0;
  const margin = 32.0;
  final blocks = <({TextPainter painter, double y})>[];
  var y = 30.0;
  void line(String text, {double size = 14, bool bold = false, Color? color}) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: size,
          height: 1.5,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          color: color ?? AppColors.ink,
          fontFamilyFallback: const [
            'Noto Sans CJK SC',
            'PingFang SC',
            'Microsoft YaHei',
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
      locale: Locale(l10n.localeName),
    )..layout(maxWidth: width - margin * 2);
    blocks.add((painter: painter, y: y));
    y += painter.height + 10;
  }

  line(l10n.financeExportHeading, size: 16, bold: true);
  y += 22;
  line(l10n.financeValueTitle, size: 20, bold: true);
  line('${data.amount} ${data.currency}', size: 36, bold: true);
  line(data.converted, color: AppColors.muted);
  y += 12;
  line(
    l10n.financePeriodProgress(
      data.periodLabel,
      (data.ratio.clamp(0, 1) * 100).toStringAsFixed(1),
      data.activeRemaining,
      data.days,
    ),
  );
  final progressY = y;
  y += 22;
  line(
    l10n.financePeriodDates(
      data.start?.toString() ?? l10n.financeUnknown,
      data.end?.toString() ?? l10n.financeUnknown,
    ),
    size: 12,
    color: AppColors.muted,
  );
  y += 12;
  for (final row in [
    l10n.financeExportValuationDate(data.asOf.toString()),
    l10n.financeExportDue(data.due.toString()),
    l10n.financeExportRemainingDays(data.remaining),
    l10n.financeExportRenewal(data.renewal),
    l10n.financeExportDaily(data.daily),
  ]) {
    line(row);
  }
  if (data.futurePeriods > 0) {
    line(
      l10n.financeExportFuturePeriods(data.futurePeriods),
      size: 12,
      color: AppColors.muted,
    );
  }
  line(data.periodBasis, size: 12, color: AppColors.muted);
  y += 14;
  line(data.fx, size: 12, color: AppColors.muted);
  line(data.fxSource, size: 12, color: AppColors.muted);
  y += 14;
  line(
    l10n.financeExportDisclaimer,
    size: 14,
    bold: true,
    color: AppColors.blue,
  );
  line(l10n.financeExportFooter, size: 12, color: AppColors.muted);
  final height = (y + 24).ceil();
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..scale(2);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width, height.toDouble()),
    Paint()..color = AppColors.canvas,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(16, 16, width - 32, height - 32),
      const Radius.circular(18),
    ),
    Paint()..color = Colors.white,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(margin, progressY, width - margin * 2, 7),
      const Radius.circular(4),
    ),
    Paint()..color = AppColors.line,
  );
  if (data.ratio > 0) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          margin,
          progressY,
          (width - margin * 2) * data.ratio.clamp(0, 1),
          7,
        ),
        const Radius.circular(4),
      ),
      Paint()..color = AppColors.blue,
    );
  }
  for (final block in blocks) {
    block.painter.paint(canvas, Offset(margin, block.y));
    block.painter.dispose();
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
