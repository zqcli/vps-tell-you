import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart';

import '../core/ui/ui.dart';

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
