import 'package:flutter/cupertino.dart'
    show
        CupertinoDatePicker,
        CupertinoDatePickerMode,
        CupertinoTextThemeData,
        CupertinoTheme,
        CupertinoThemeData;
import 'package:flutter/material.dart';

import '../../l10n/locale_preference.dart';
import '../app_palette.dart';
import '../value_types.dart';
import 'app_overlays.dart';
import 'app_controls.dart';

/// Date wheel in a bottom sheet with "Set Unknown" and "Done".
///
/// Returns the chosen ISO date (`YYYY-MM-DD`), `''` for "Set Unknown", or
/// `null` when the sheet is closed any other way (keep the draft unchanged).
/// Set [allowUnknown] to `false` for a required date: only "Done" is shown.
///
/// Keys: `date-sheet-unknown`, `date-sheet-done`.
Future<String?> showAppDateSheet(
  BuildContext context, {
  required String title,
  required LedgerDate initial,
  bool allowUnknown = true,
}) => showAppSheet<String>(
  context,
  title: title,
  builder: (_) => _DateSheet(initial: initial, allowUnknown: allowUnknown),
);

class _DateSheet extends StatefulWidget {
  const _DateSheet({required this.initial, required this.allowUnknown});
  final LedgerDate initial;
  final bool allowUnknown;
  @override
  State<_DateSheet> createState() => _DateSheetState();
}

class _DateSheetState extends State<_DateSheet> {
  late DateTime _value = DateTime(
    widget.initial.year,
    widget.initial.month,
    widget.initial.day,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 216,
          child: CupertinoTheme(
            data: CupertinoThemeData(
              brightness: p.isDark ? Brightness.dark : Brightness.light,
              textTheme: CupertinoTextThemeData(
                dateTimePickerTextStyle: TextStyle(fontSize: 21, color: p.text),
              ),
            ),
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.date,
              initialDateTime: _value,
              minimumYear: 1,
              maximumYear: 9999,
              onDateTimeChanged: (value) => _value = value,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              if (widget.allowUnknown) ...[
                Expanded(
                  child: AppButton(
                    key: const ValueKey('date-sheet-unknown'),
                    label: l10n.uiFormSetUnknown,
                    kind: AppButtonKind.tonal,
                    onPressed: () => Navigator.pop(context, ''),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: AppButton(
                  key: const ValueKey('date-sheet-done'),
                  label: l10n.uiFormDone,
                  onPressed: () => Navigator.pop(
                    context,
                    LedgerDate(
                      _value.year,
                      _value.month,
                      _value.day,
                    ).toString(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
