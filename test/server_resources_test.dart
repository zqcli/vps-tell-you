import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vps_tell_you/servers/server_resources.dart';

ServerResources resourceFixture({
  String ip = '192.0.2.9',
  String ipv6 = '',
  String hostname = 'VPS.Example',
  int vcpu = 2,
  int ramBytes = 2147483648,
  int diskBytes = 32212254720,
  int? trafficBytes = 1099511627776,
  bool trafficUnlimited = false,
}) => ServerResources(
  ip: ip,
  ipv6: ipv6,
  hostname: hostname,
  vcpu: vcpu,
  ramBytes: ramBytes,
  diskBytes: diskBytes,
  trafficBytes: trafficBytes,
  trafficUnlimited: trafficUnlimited,
);

void main() {
  test('complete finite and unlimited resources round-trip losslessly', () {
    for (final resources in [
      resourceFixture(),
      resourceFixture(
        ip: '192.0.2.10',
        ipv6: '2001:db8::2',
        hostname: 'VPS',
        trafficBytes: null,
        trafficUnlimited: true,
      ),
    ]) {
      expect(resources.validate(requireComplete: true), isNull);
      final decoded = ServerResources.decode(resources.encode());
      expect(decoded.toJson(), resources.toJson());
      // Language-neutral: vCPU · memory · disk (traffic has its own row).
      expect(decoded.specSummary, '2 vCPU · 2 GiB · 30 GiB');
    }
  });

  test('IPv4 field requires an assigned dotted-quad address', () {
    for (final ip in [
      '',
      '0',
      '0.0.0.0',
      'example.com',
      'https://192.0.2.9',
      '192.0.2.9:22',
      '999.0.0.1',
      '01.2.3.4',
      '127.1',
      ' 192.0.2.9',
      // The IPv4 field no longer takes IPv6 in any form.
      '2001:db8::1',
      '::ffff:192.0.2.9',
      '::',
    ]) {
      expect(
        resourceFixture(ip: ip).validate(requireComplete: true),
        isNotNull,
        reason: ip,
      );
    }
    expect(resourceFixture(ip: '192.0.2.9').validate(), isNull);
  });

  test('IPv6 field requires an assigned bare address, any spelling', () {
    for (final ipv6 in [
      '::',
      '::0',
      '::ffff:0.0.0.0',
      '192.0.2.9',
      'example.com',
      'fe80::1%eth0', // a zone is a connection detail, not hardware data
      '[2001:db8::1]',
      '2001:db8::1/64',
      '2001:db8::1:2:3:4:5:6',
      ' 2001:db8::1',
    ]) {
      expect(resourceFixture(ipv6: ipv6).validate(), isNotNull, reason: ipv6);
    }
    for (final ipv6 in ['2001:db8::1', '2001:DB8:0:0::1', '::ffff:192.0.2.9']) {
      expect(resourceFixture(ipv6: ipv6).validate(), isNull, reason: ipv6);
    }
  });

  test('a complete record needs one address, either family', () {
    expect(
      resourceFixture(
        ip: '',
        ipv6: '2001:db8::1',
      ).validate(requireComplete: true),
      isNull,
    );
    expect(resourceFixture(ip: '').validate(requireComplete: true), isNotNull);
  });

  test('ipv6 is an optional JSON key and only written when set', () {
    final v4 = resourceFixture();
    expect(v4.toJson().containsKey('ipv6'), isFalse);
    expect(jsonDecode(v4.encode()), isNot(contains('ipv6')));
    final dual = resourceFixture(ipv6: '2001:db8::1');
    expect(dual.toJson()['ip'], '192.0.2.9');
    expect(dual.toJson()['ipv6'], '2001:db8::1');
    expect(ServerResources.decode(dual.encode()).ipv6, '2001:db8::1');
    expect(ServerResources.decode(dual.encode()).ip, '192.0.2.9');
    expect(ServerResources.decode(v4.encode()).ipv6, '');
    // An explicit empty value is accepted too (but never written).
    final withEmpty = {...v4.toJson(), 'ipv6': ''};
    expect(ServerResources.fromJson(withEmpty).ipv6, '');
    // Still strict: unknown keys and wrong types fail.
    expect(
      () => ServerResources.fromJson({...dual.toJson(), 'ipv7': 'x'}),
      throwsFormatException,
    );
    expect(
      () => ServerResources.fromJson({...dual.toJson(), 'ipv6': 5}),
      throwsFormatException,
    );
    expect(
      () => ServerResources.fromJson({...dual.toJson(), 'ipv6': 'nope'}),
      throwsFormatException,
    );
    expect(
      () => ServerResources.fromJson({...dual.toJson(), 'ip': '2001:db8::1'}),
      throwsFormatException,
      reason: 'IPv6 in ip is only migrated when ipv6 is empty',
    );
  });

  test('legacy IPv6 stored in ip moves to ipv6', () {
    final legacy = resourceFixture(ip: '2001:db8::7');
    final decoded = ServerResources.decode(legacy.encode());
    expect(decoded.ip, '');
    expect(decoded.ipv6, '2001:db8::7');
    expect(decoded.validate(requireComplete: true), isNull);
    // Re-encoding is stable and no longer needs the migration.
    expect(ServerResources.decode(decoded.encode()).toJson(), decoded.toJson());
  });

  test(
    'hostname accepts DNS labels and FQDN, not placeholders or endpoints',
    () {
      for (final hostname in ['VPS', 'Node-7', 'UPPER.Example.', 'a']) {
        expect(
          resourceFixture(hostname: hostname).validate(requireComplete: true),
          isNull,
        );
      }
      for (final hostname in [
        '',
        '0',
        '0.',
        '192.0.2.9',
        '192.0.2.9.',
        '2001:db8::1',
        'https://vps.example',
        '-vps',
        'vps-',
        'bad_name',
        'two labels',
        'a..b',
        'vps:22',
        'a' * 64,
        '${'a' * 63}.${'b' * 63}.${'c' * 63}.${'d' * 63}',
      ]) {
        expect(
          resourceFixture(hostname: hostname).validate(requireComplete: true),
          isNotNull,
          reason: hostname,
        );
      }
    },
  );

  test(
    'counts and byte quotas are positive, bounded and traffic is exclusive',
    () {
      for (final bad in [0, -1, ServerResources.maxVcpu + 1]) {
        expect(
          resourceFixture(vcpu: bad).validate(requireComplete: true),
          isNotNull,
        );
      }
      for (final bad in [0, -1, ServerResources.maxBytes + 1]) {
        expect(
          resourceFixture(ramBytes: bad).validate(requireComplete: true),
          isNotNull,
        );
        expect(
          resourceFixture(diskBytes: bad).validate(requireComplete: true),
          isNotNull,
        );
        expect(
          resourceFixture(trafficBytes: bad).validate(requireComplete: true),
          isNotNull,
        );
      }
      expect(
        resourceFixture(trafficBytes: null).validate(requireComplete: true),
        isNotNull,
      );
      expect(
        resourceFixture(trafficUnlimited: true).validate(requireComplete: true),
        isNotNull,
      );
      expect(
        resourceFixture(
          vcpu: ServerResources.maxVcpu,
          ramBytes: ServerResources.maxBytes,
          diskBytes: 1,
          trafficBytes: 1,
        ).validate(requireComplete: true),
        isNull,
      );
    },
  );

  test('the retired apiFields marker is tolerated on read, never written', () {
    final resources = resourceFixture();
    expect(resources.toJson().containsKey('apiFields'), isFalse);
    final legacy = {
      ...resources.toJson(),
      'apiFields': ['ip', 'ramBytes'],
    };
    final decoded = ServerResources.decode(jsonEncode(legacy));
    expect(decoded.toJson(), resources.toJson());
    expect(decoded.encode(), resources.encode());
    expect(
      () => ServerResources.decode(
        jsonEncode({...resources.toJson(), 'apiFields': 'ip'}),
      ),
      throwsFormatException,
    );
  });

  test(
    'strict persisted JSON rejects missing, unknown and mistyped values',
    () {
      final map = resourceFixture().toJson();
      final malformed = <Object?>[
        null,
        [],
        {...map}..remove('hostname'),
        {...map, 'password': 'synthetic-excluded'},
        {...map, 'ramBytes': '2147483648'},
        {...map, 'vcpu': 2.5},
        {...map, 'trafficUnlimited': 1},
        {...map, 'ip': '0.0.0.0'},
        {...map, 'trafficBytes': 0},
        {...map, 'trafficUnlimited': true},
      ];
      for (final value in malformed) {
        expect(
          () => ServerResources.decode(jsonEncode(value)),
          throwsFormatException,
        );
      }
      expect(() => ServerResources.decode('x' * 4097), throwsFormatException);
    },
  );
}
