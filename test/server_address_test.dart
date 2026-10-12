import 'package:flutter_test/flutter_test.dart';
import 'package:vps_tell_you/servers/server_record.dart';
import 'package:vps_tell_you/servers/server_resources.dart';

ServerRecord _server({String host = '', ServerResources? resources}) =>
    ServerRecord(
      id: 's',
      name: 'S',
      vendor: '',
      host: host,
      resources: resources,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

void main() {
  group('ServerRecord.primaryAddress', () {
    test('IPv4, then IPv6, then hostname, then the legacy host', () {
      final all = ServerResources(
        ip: '192.0.2.1',
        ipv6: '2001:db8::1',
        hostname: 'a.example',
      );
      expect(
        _server(host: 'old.example', resources: all).primaryAddress,
        '192.0.2.1',
      );
      expect(
        _server(
          host: 'old.example',
          resources: ServerResources(
            ipv6: '2001:db8::1',
            hostname: 'a.example',
          ),
        ).primaryAddress,
        '2001:db8::1',
      );
      expect(
        _server(
          host: 'old.example',
          resources: ServerResources(hostname: 'a.example'),
        ).primaryAddress,
        'a.example',
      );
      expect(
        _server(
          host: 'old.example',
          resources: ServerResources(),
        ).primaryAddress,
        'old.example',
      );
      expect(_server().primaryAddress, isEmpty);
    });
  });

  group('LegacyHost', () {
    test('empty and unplaceable hosts have no target', () {
      expect(LegacyHost.of(''), isNull);
      expect(LegacyHost.of('   '), isNull);
      expect(LegacyHost.of('fe80::1%en0'), isNull, reason: 'zone');
      expect(LegacyHost.of('0.0.0.0'), isNull, reason: 'unspecified');
      expect(LegacyHost.of('not a host'), isNull);
    });

    test('maps each kind to its field in canonical form', () {
      final v4 = LegacyHost.of('192.0.2.7')!;
      expect((v4.field, v4.value), (LegacyHostField.ipv4, '192.0.2.7'));
      final v6 = LegacyHost.of('2001:DB8:0:0:0:0:0:1')!;
      expect((v6.field, v6.value), (LegacyHostField.ipv6, '2001:db8::1'));
      final name = LegacyHost.of('Legacy.Example')!;
      expect(
        (name.field, name.value),
        (LegacyHostField.hostname, 'Legacy.Example'),
      );
    });

    test('prefill fills an empty field only', () {
      final host = LegacyHost.of('192.0.2.7')!;
      final filled = host.prefill(null)!;
      expect(filled.ip, '192.0.2.7');
      expect(host.isStoredIn(filled), isTrue);
      final other = ServerResources(ip: '192.0.2.8', vcpu: 2);
      expect(host.prefill(other), same(other));
      expect(host.isStoredIn(other), isFalse);
      // The rest of the configuration is carried along.
      final withHardware = host.prefill(
        ServerResources(vcpu: 2, hostname: 'x.example'),
      )!;
      expect((withHardware.vcpu, withHardware.hostname), (2, 'x.example'));
    });
  });
}
