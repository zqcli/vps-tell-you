import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vps_tell_you/core/ui/ui.dart';

import 'ui_components_test.dart' show pumpApp;

class _StatefulRow extends StatefulWidget {
  const _StatefulRow(this.id);
  final int id;
  @override
  State<_StatefulRow> createState() => _StatefulRowState();
}

class _StatefulRowState extends State<_StatefulRow> {
  int taps = 0;
  @override
  Widget build(BuildContext context) => AppRow(
    title: '${widget.id}: $taps',
    onTap: () => setState(() => taps++),
  );
}

void main() {
  testWidgets('lazy sections keep the eager header, row and footer geometry', (tester) async {
    for (final scale in [1.0, 2.0]) {
      for (final header in [null, 'Section']) {
        const rows = [
          AppRow(key: ValueKey('first'), title: 'First', icon: Icons.dns),
          AppRow(key: ValueKey('second'), title: 'Second', subtitle: 'Details'),
        ];
        await pumpApp(tester, Scaffold(body: CustomScrollView(slivers: [
          SliverToBoxAdapter(child: AppSection(header: header, footer: 'Footer', children: rows)),
        ])), scale: scale);
        final first = tester.getRect(find.byKey(const ValueKey('first')));
        final second = tester.getRect(find.byKey(const ValueKey('second')));
        final footer = tester.getRect(find.text('Footer'));
        final title = header == null ? null : tester.getTopLeft(find.text(header));
        await pumpApp(tester, Scaffold(body: CustomScrollView(slivers: [
          AppLazySections(sections: [AppListSection(
            header: header,
            footer: 'Footer',
            topSpacing: header == null ? 16 : 22,
            count: rows.length,
            itemBuilder: (_, i) => rows[i],
          )]),
        ])), scale: scale);
        expect(tester.getRect(find.byKey(const ValueKey('first'))), first);
        expect(tester.getRect(find.byKey(const ValueKey('second'))), second);
        expect(tester.getRect(find.text('Footer')), footer);
        if (header != null) expect(tester.getTopLeft(find.text(header)), title);
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets('stable keys retain row state when a list is reordered', (tester) async {
    final order = ValueNotifier([1, 2, 3]);
    addTearDown(order.dispose);
    await pumpApp(tester, Scaffold(body: ValueListenableBuilder<List<int>>(
      valueListenable: order,
      builder: (_, ids, _) => CustomScrollView(slivers: [
        AppLazySections(sections: [AppListSection(
          count: ids.length,
          itemKey: (i) => ValueKey(ids[i]),
          itemBuilder: (_, i) => _StatefulRow(ids[i]),
        )]),
      ]),
    )));
    await tester.tap(find.text('2: 0'));
    await tester.pump();
    order.value = [3, 1, 2];
    await tester.pumpAndSettle();
    expect(find.text('2: 1'), findsOneWidget);
    expect(tester.getTopLeft(find.text('3: 0')).dy, lessThan(tester.getTopLeft(find.text('2: 1')).dy));
    expect(tester.takeException(), isNull);
  });
}
