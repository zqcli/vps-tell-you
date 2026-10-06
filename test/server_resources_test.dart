import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vps_tell_you/servers/server_resources.dart';

ServerResources resourceFixture({
  String ip = '192.0.2.9',
  String hostname = 'VPS.Example',
  int vcpu = 2,
  int ramBytes = 2147483648,
  int diskBytes = 32212254720,
  int? trafficBytes = 1099511627776,
  bool trafficUnlimited = false,
  Set<String> apiFields = const {'ip', 'hostname', 'ramBytes'},
}) => ServerResources(
  ip: ip,
  hostname: hostname,
  vcpu: vcpu,
  ramBytes: ramBytes,
  diskBytes: diskBytes,
  trafficBytes: trafficBytes,
  trafficUnlimited: trafficUnlimited,
  apiFields: apiFields,
);

void main() {
  test('complete finite and unlimited resources round-trip losslessly', () {
    for (final resources in [
      resourceFixture(),
      resourceFixture(
        ip: '2001:db8::2',
        hostname: 'VPS',
        trafficBytes: null,
        trafficUnlimited: true,
      ),
    ]) {
      expect(resources.validate(), isNull);
      final decoded = ServerResources.decode(resources.encode());
      expect(decoded.toJson(), resources.toJson());
      expect(decoded.specSummary, contains('2 vCPU'));
      expect(decoded.specSummary, contains('2 GiB RAM'));
      expect(decoded.specSummary, contains('30 GiB'));
      expect(
        decoded.specSummary,
        contains(resources.trafficUnlimited ? '流量不限量' : '1 TiB 流量'),
      );
    }
  });

  test('IP requires a literal, assigned IPv4 or IPv6 address', () {
    for (final ip in [
      '',
      '0',
      '0.0.0.0',
      '::',
      '::0',
      '::ffff:0.0.0.0',
      'example.com',
      'https://192.0.2.9',
      '192.0.2.9:22',
      '999.0.0.1',
      ' 192.0.2.9',
      'fe80::1%eth0',
      '2001:db8::1/64',
    ]) {
      expect(resourceFixture(ip: ip).validate(), isNotNull, reason: ip);
    }
    for (final ip in ['192.0.2.9', '2001:DB8::1', '::ffff:192.0.2.9']) {
      expect(resourceFixture(ip: ip).validate(), isNull, reason: ip);
    }
  });

  test(
    'hostname accepts DNS labels and FQDN, not placeholders or endpoints',
    () {
      for (final hostname in ['VPS', 'Node-7', 'UPPER.Example.', 'a']) {
        expect(resourceFixture(hostname: hostname).validate(), isNull);
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
          resourceFixture(hostname: hostname).validate(),
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
        expect(resourceFixture(vcpu: bad).validate(), isNotNull);
      }
      for (final bad in [0, -1, ServerResources.maxBytes + 1]) {
        expect(resourceFixture(ramBytes: bad).validate(), isNotNull);
        expect(resourceFixture(diskBytes: bad).validate(), isNotNull);
        expect(resourceFixture(trafficBytes: bad).validate(), isNotNull);
      }
      expect(resourceFixture(trafficBytes: null).validate(), isNotNull);
      expect(resourceFixture(trafficUnlimited: true).validate(), isNotNull);
      expect(
        resourceFixture(
          vcpu: ServerResources.maxVcpu,
          ramBytes: ServerResources.maxBytes,
          diskBytes: 1,
          trafficBytes: 1,
        ).validate(),
        isNull,
      );
    },
  );

  test('provenance is whitelisted and defensively immutable', () {
    final fields = {'ip'};
    final resources = resourceFixture(apiFields: fields);
    fields.add('password');
    expect(resources.apiFields, {'ip'});
    expect(() => resources.apiFields.add('hostname'), throwsUnsupportedError);
    expect(
      resourceFixture(apiFields: {'trafficUnlimited'}).validate(),
      isNotNull,
    );
    expect(resourceFixture(apiFields: {'password'}).validate(), isNotNull);
    expect(resourceFixture(apiFields: {'trafficBytes'}).validate(), isNull);
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
        {
          ...map,
          'apiFields': ['ip', 'ip'],
        },
        {
          ...map,
          'apiFields': ['secretRef'],
        },
        {
          ...map,
          'apiFields': [1],
        },
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
