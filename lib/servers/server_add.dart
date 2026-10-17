import 'package:flutter/material.dart';

import '../core/ui/ui.dart';
import 'ledger_controller.dart';
import 'server_detail.dart';
import 'server_form.dart';
import 'server_record.dart';

Future<void> addServer(
  BuildContext context,
  LedgerController controller, {
  ServerRecord? template,
}) async {
  // Straight to the form: the provider and package are rows inside it.
  final id = await showAppModal<String>(
    context,
    builder: (_) => ServerForm(controller: controller, template: template),
  );
  if (id != null && context.mounted && controller.byId(id) != null) {
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => ServerDetail(controller: controller, id: id),
      ),
    );
  }
}
