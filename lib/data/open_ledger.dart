import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as mobile;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'ledger_store.dart';

Future<LedgerStore> openLedger() async {
  final directory = await getApplicationSupportDirectory();
  await directory.create(recursive: true);
  final path = p.join(directory.path, 'ledger.sqlite3');
  if (Platform.isLinux || Platform.isWindows) {
    sqfliteFfiInit();
    return LedgerStore.open(factory: databaseFactoryFfi, path: path);
  }
  if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
    return LedgerStore.open(factory: mobile.databaseFactory, path: path);
  }
  throw UnsupportedError('This platform has no production ledger adapter');
}
