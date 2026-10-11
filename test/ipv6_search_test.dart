import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/servers/ledger_controller.dart';
import 'package:vps_tell_you/servers/server_record.dart';
import 'package:vps_tell_you/servers/server_resources.dart';

void main() {
  late Directory directory;
  late LedgerStore store;
  late LedgerController ledger;
  setUp(() async {
    sqfliteFfiInit();
    directory = await Directory.systemTemp.createTemp('ipv6-search-');
    store = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: '${directory.path}/ledger.sqlite3',
    );
    ledger = LedgerController(store);
    ServerRecord server(String id, String host, {ServerResources? res}) =>
        ServerRecord(
          id: id,
          name: 'srv-$id',
          vendor: 'V',
          host: host,
          resources: res,
          createdAt: DateTime.utc(2026, 10, 6),
          updatedAt: DateTime.utc(2026, 10, 6),
        );
    await store.saveServer(
      server(
        'a',
        'gateway.example',
        res: ServerResources(ip: '192.0.2.10', ipv6: '2001:db8::a'),
      ),
      isNew: true,
    );
    await store.saveServer(server('b', '2001:db8:0:1::b'), isNew: true);
    await store.saveServer(server('c', '198.51.100.7'), isNew: true);
    await ledger.refresh();
  });
  tearDown(() async {
    ledger.dispose();
    await store.close();
    await directory.delete(recursive: true);
  });

  List<String> find(String query) {
    ledger.search = query;
    return ledger.visible.map((s) => s.id).toList()..sort();
  }

  test('search matches the host and both hardware addresses', () {
    expect(find('192.0.2.10'), ['a'], reason: 'hardware IPv4');
    expect(find('2001:db8::a'), ['a'], reason: 'hardware IPv6');
    expect(find('2001:db8:0:1::b'), ['b'], reason: 'IPv6 host');
    expect(find('198.51.100'), ['c']);
    expect(find('2001:db8'), ['a', 'b']);
  });

  test('a pasted IPv6 in another spelling finds the canonical record', () {
    expect(find('2001:0DB8:0000:0000:0000:0000:0000:000A'), ['a']);
    expect(find('[2001:DB8:0:1:0:0:0:B]'), ['b']);
    expect(find('2001:db8::dead'), isEmpty);
  });
}
