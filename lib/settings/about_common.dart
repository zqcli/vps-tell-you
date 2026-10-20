import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart';

import '../core/ui/ui.dart';
import 'changelog.dart' show parseBold;

/// Centered secondary-colour message used by the About pages for empty and
/// failed states.
class AboutNotice extends StatelessWidget {
  const AboutNotice(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(32, 40, 32, 0),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 15, color: context.palette.text2),
    ),
  );
}

class AboutLoading extends StatelessWidget {
  const AboutLoading({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(top: 48),
    child: Center(child: CupertinoActivityIndicator()),
  );
}

/// A bullet row (dot + wrapped text) for About-style text pages.
class AboutBullet extends StatelessWidget {
  const AboutBullet(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final style = TextStyle(fontSize: 15, height: 1.35, color: p.text);
    return AppRow.custom(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8, right: 10),
              child: Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: p.text3,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Expanded(child: Text.rich(boldSpans(text), style: style)),
          ],
        ),
      ),
    );
  }
}

/// [parseBold] as an [InlineSpan]; the base style comes from the [Text].
TextSpan boldSpans(String text) => TextSpan(
  children: [
    for (final (segment, bold) in parseBold(text))
      TextSpan(
        text: segment,
        style: bold ? const TextStyle(fontWeight: FontWeight.w700) : null,
      ),
  ],
);
