import 'dart:async';

import 'package:flutter/material.dart';

/// Reveals the earliest invalid field in visual order after error text has
/// been laid out. All draft values and the current route remain unchanged.
void revealFirstInvalidField(Iterable<FormFieldState<Object?>> fields) {
  if (fields.isEmpty) return;
  FocusManager.instance.primaryFocus?.unfocus();
  final invalid = fields.toList();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final visible = <(BuildContext, double)>[];
    for (final field in invalid) {
      if (!field.mounted) continue;
      final box = field.context.findRenderObject();
      if (box is RenderBox && box.attached && box.hasSize) {
        visible.add((field.context, box.localToGlobal(Offset.zero).dy));
      }
    }
    visible.sort((a, b) => a.$2.compareTo(b.$2));
    if (visible.isEmpty) return;
    unawaited(
      Scrollable.ensureVisible(
        visible.first.$1,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        alignment: 0.1,
      ),
    );
  });
}
