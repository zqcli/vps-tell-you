// Manual native GUI fixture entry point, excluded from production main.dart.
// Requires an isolated test keyring and a loopback HTTPS fixture. It accepts no
// external origin; only this process's temporary certificate is trusted here.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/io_client.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/app.dart';
import 'package:vps_tell_you/cloud/cloud_controller.dart';
import 'package:vps_tell_you/cloud/cloud_models.dart';
import 'package:vps_tell_you/cloud/solusvm_adapter.dart';
import 'package:vps_tell_you/core/app_theme.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/security/security_controller.dart';
import 'package:vps_tell_you/security/security_pages.dart';
import 'package:vps_tell_you/servers/ledger_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final directory = Platform.environment['VPS_CLOUD_FIXTURE_DIR'];
  final port = int.tryParse(
    Platform.environment['VPS_CLOUD_FIXTURE_PORT'] ?? '',
  );
  if (directory == null || port == null) {
    throw StateError('Explicit isolated fixture directory and port required');
  }
  final trust = SecurityContext(withTrustedRoots: false)
    ..setTrustedCertificates('$directory/localhost.crt');
  sqfliteFfiInit();
  final store = await LedgerStore.open(
    factory: databaseFactoryFfi,
    path: '$directory/ledger.sqlite3',
  );
  final security = SecurityController(store: store);
  final cloud = CloudController(
    store: store,
    secrets: security.secrets,
    adapterFactory: (provider, endpoint, credentials) {
      if (endpoint.origin.host != 'localhost' || endpoint.origin.port != port) {
        throw const CloudFailure(CloudFailureKind.invalidEndpoint);
      }
      IOClient clientFactory() => IOClient(HttpClient(context: trust));
      return switch (provider) {
        CloudProvider.solusVm1 => SolusVm1Adapter(
          endpoint: endpoint,
          credentials: credentials as SolusVm1Credentials,
          clientFactory: clientFactory,
        ),
        CloudProvider.solusVm2 => SolusVm2Adapter(
          endpoint: endpoint,
          credentials: credentials as SolusVm2Credentials,
          clientFactory: clientFactory,
        ),
      };
    },
  );
  final ledger = LedgerController(store, security: security, cloud: cloud);
  await ledger.refresh();
  await cloud.initialize();
  runApp(
    MaterialApp(
      title: 'vps tell you · LOCAL SYNTHETIC FIXTURE',
      debugShowCheckedModeBanner: false,
      theme: appTheme(),
      navigatorObservers: [securityRouteObserver],
      builder: (context, child) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: child!,
        ),
      ),
      home: HomeShell(controller: ledger),
    ),
  );
}
