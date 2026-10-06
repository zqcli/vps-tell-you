import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../core/app_theme.dart';
import '../core/value_types.dart';
import 'png_share.dart';

/// Explicit export whitelist. Never accepts a server, payment or account object.
/// Quotation / settlement information is deliberately absent.
class CalculationShareData {
  const CalculationShareData({
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
  final String amount, currency, converted, renewal, daily, fx, fxSource;
  final String periodBasis;
  final LedgerDate asOf, due;
  final LedgerDate? start, end;
  final double ratio;
  final int activeRemaining, days, remaining, futurePeriods;
  static const disclaimer = '仅表示服务时长的价格折算，不代表退款承诺或成交价。';
  String get percent => '${(ratio.clamp(0, 1) * 100).toStringAsFixed(1)}%';
  String get plainText => [
    '剩余价值：$amount $currency',
    converted,
    '估值日期：$asOf',
    '本周期：${start ?? '未知'} 至 ${end ?? '未知'}',
    '本周期剩余：$activeRemaining / $days 天 · $percent',
    '服务到期日：$due；剩余有效期：$remaining 天',
    '续费 / 周期：$renewal；本周期日均：$daily',
    if (futurePeriods > 0) '含 $futurePeriods 个未来周期，进度仅表示当前周期。',
    periodBasis,
    fx,
    fxSource,
    disclaimer,
  ].join('\n');
}

typedef CalculationRenderer = Future<Uint8List> Function(CalculationShareData);
typedef CalculationSaver = Future<String> Function(Uint8List, LedgerDate);

/// TextPainter performs both layout and drawing, so Chinese and long values
/// determine the real image height rather than being clipped by a fixed canvas.
Future<Uint8List> renderCalculationPng(CalculationShareData data) async {
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
    )..layout(maxWidth: width - margin * 2);
    blocks.add((painter: painter, y: y));
    y += painter.height + 10;
  }

  line('vps tell you · 试算 · 不入账', size: 16, bold: true);
  y += 22;
  line('剩余价值 · 续费价口径', size: 20, bold: true);
  line('${data.amount} ${data.currency}', size: 36, bold: true);
  line(data.converted, color: AppColors.muted);
  y += 12;
  line('本周期剩余 ${data.percent} · ${data.activeRemaining} / ${data.days} 天');
  final progressY = y;
  y += 22;
  line(
    '${data.start ?? '未知'} 至 ${data.end ?? '未知'}',
    size: 12,
    color: AppColors.muted,
  );
  y += 12;
  for (final row in [
    '估值日期：${data.asOf}',
    '服务到期日：${data.due}',
    '剩余有效期：${data.remaining} 天',
    '续费 / 周期：${data.renewal}',
    '本周期日均：${data.daily}',
  ]) {
    line(row);
  }
  if (data.futurePeriods > 0) {
    line(
      '含 ${data.futurePeriods} 个未来周期；进度仅表示当前周期。',
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
    CalculationShareData.disclaimer,
    size: 14,
    bold: true,
    color: AppColors.blue,
  );
  line('独立试算 · 图片仅含计算信息', size: 12, color: AppColors.muted);
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
  String? status;
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
        status = '图片生成失败，原计算结果已保留。';
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
      setState(() => status = 'PNG 已保存：\n$savedPath');
    } catch (_) {
      if (!mounted || ticket != generation) return;
      setState(() => status = '保存未完成。预览仍保留，请检查空间与权限后重试。');
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
          PngShareOutcome.selected => '已选择系统分享操作，请在目标应用核对是否送达。',
          PngShareOutcome.dismissed => '已取消分享，预览仍保留。',
          PngShareOutcome.unknown => '未收到系统分享结果，预览仍保留。',
          PngShareOutcome.unsupported => '此平台不支持 PNG 系统分享，可保存到本地。',
          PngShareOutcome.busy => '请先完成当前系统分享操作。',
          PngShareOutcome.failed => '分享未完成，预览仍保留，请重试。',
        },
      );
    } catch (_) {
      if (mounted && ticket == generation) {
        setState(() => status = '分享未完成，预览仍保留，请重试。');
      }
    } finally {
      // A newer render must not inherit a permanently busy button from this
      // earlier native sheet. The result itself remains generation-fenced.
      if (mounted) setState(() => sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('图片预览')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const InfoNote('仅含金额、日期、周期和参考汇率。图片不含服务器名称、地址、账户、备注或转让结算。'),
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
            semanticLabel: '剩余价值计算结果 PNG',
          ),
        if (status != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: SelectableText(status!),
          ),
        if (!generating && bytes == null)
          FilledButton(onPressed: generate, child: const Text('重新生成')),
        if (bytes != null) ...[
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: saving || sharing ? null : save,
            icon: const Icon(Icons.download_outlined),
            label: Text(saving ? '正在保存…' : '保存 PNG'),
          ),
          if (sharer.supported) ...[
            const SizedBox(height: 10),
            Builder(
              builder: (buttonContext) => OutlinedButton.icon(
                onPressed: saving || sharing
                    ? null
                    : () => share(buttonContext),
                icon: const Icon(Icons.ios_share),
                label: Text(sharing ? '正在分享…' : '系统分享 PNG'),
              ),
            ),
          ],
          const InfoNote('保存位置可能是应用私有目录，不等于相册或公开下载目录。移动端可使用系统分享另存；取消分享不会关闭预览。'),
        ],
      ],
    ),
  );
}
