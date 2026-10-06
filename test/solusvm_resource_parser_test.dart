import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vps_tell_you/cloud/cloud_models.dart';
import 'package:vps_tell_you/cloud/solusvm_adapter.dart';

const _secret = 'SYNTHETIC_SECRET_NEVER_EXPOSE';
const _success = '<status>success</status><statusmsg></statusmsg>';
final _observedAt = DateTime.utc(2026, 10, 6, 5);

Future<CloudInstance> _parse(
  String body, {
  String key = _secret,
  String hash = '${_secret}_HASH',
}) async {
  final snapshot = await SolusVm1Adapter(
    endpoint: CloudEndpoint.parse('https://panel.example.test'),
    credentials: SolusVm1Credentials(key: key, hash: hash),
    clock: () => _observedAt,
    clientFactory: () => MockClient(
      (_) async => http.Response.bytes(
        utf8.encode(body),
        200,
        headers: {'content-type': 'application/xml; charset=utf-8'},
      ),
    ),
  ).read(cancellation: CloudCancellation());
  expect(snapshot.provider, CloudProvider.solusVm1);
  expect(snapshot.completedAt, _observedAt);
  expect(snapshot.instances, hasLength(1));
  return snapshot.instances.single;
}

void main() {
  group('SolusVM 1 typed resource projection', () {
    test('all six resources keep exact units and main IP priority', () async {
      final result = await _parse('''<response>$_success
<vmstat>online</vmstat><ipaddress>192.0.2.10</ipaddress>
<ipaddr>192.0.2.11,2001:db8::1,192.0.2.10,2001:db8::2</ipaddr>
<hostname>srv-1.example.test.</hostname><cpus>4</cpus>
<mem>1073741824,536870912,536870912,50</mem>
<hdd>21474836480,0,21474836480,0</hdd>
<bw>1099511627776,0,1099511627776,0</bw>
</response>''');
      expect(result.ipv4, '192.0.2.10');
      expect(result.ipv6, '2001:db8::1');
      expect(result.hostname, 'srv-1.example.test');
      expect(result.vcpu, 4);
      expect(result.ramBytes, 1073741824);
      expect(result.diskBytes, 21474836480);
      expect(result.trafficBytes, 1099511627776);
      expect(result.trafficUsedBytes, 0);
      expect(result.trafficUnlimited, false);
      expect(result.power, CloudPower.running);
      expect(result.observedAt, _observedAt);
      // Hostname and IP are descriptive resources, never inferred remote IDs.
      expect(result.serverId, isNull);
      expect(result.projectId, isNull);
      expect(result.uuid, isNull);
      expect(result.name, isNull);
      expect(result.diskGiB, isNull);
    });

    test(
      'byte totals remain allocation even when usage exceeds quota',
      () async {
        final result = await _parse('''$_success
<mem>1024,2048,0,200</mem><hdd>2048,4096,0,200</hdd>
<bw>4096,8192,0,200.125</bw>''');
        expect(result.ramBytes, 1024);
        expect(result.diskBytes, 2048);
        expect(result.trafficBytes, 4096);
        expect(result.trafficUsedBytes, 8192);
        expect(result.trafficUnlimited, false);
      },
    );

    test('resource omission keeps every quota unknown', () async {
      final result = await _parse(_success);
      expect(result.ipv4, isNull);
      expect(result.ipv6, isNull);
      expect(result.hostname, isNull);
      expect(result.vcpu, isNull);
      expect(result.ramBytes, isNull);
      expect(result.diskBytes, isNull);
      expect(result.trafficBytes, isNull);
      expect(result.trafficUsedBytes, isNull);
      expect(result.trafficUnlimited, false);
    });

    test('all-zero tuples are missing quotas, with valid zero usage', () async {
      final result = await _parse('''$_success
<mem>0,0,0,0</mem><hdd>0,0,0,0</hdd><bw>0,0,0,0</bw>
<cpus>0</cpus>''');
      expect(result.vcpu, isNull);
      expect(result.ramBytes, isNull);
      expect(result.diskBytes, isNull);
      expect(result.trafficBytes, isNull);
      expect(result.trafficUsedBytes, 0);
      expect(result.trafficUnlimited, false);
    });

    test('unknown quota with nonzero usage never becomes allocation', () async {
      final result = await _parse('''$_success
<mem>0,2000,5000,0</mem><hdd>0,3000,6000,0</hdd><bw>0,4000,7000,0</bw>''');
      expect(result.ramBytes, isNull);
      expect(result.diskBytes, isNull);
      expect(result.trafficBytes, isNull);
      expect(result.trafficUsedBytes, 4000);
      expect(result.trafficUnlimited, false);
    });

    test('bounded integer byte maxima remain exact', () async {
      final result = await _parse('''$_success
<mem>9007199254740991,0,9007199254740991,0</mem>
<hdd>9007199254740991,0,9007199254740991,0</hdd>
<bw>9007199254740991,9007199254740991,0,100</bw>''');
      expect(result.ramBytes, 9007199254740991);
      expect(result.diskBytes, 9007199254740991);
      expect(result.trafficBytes, 9007199254740991);
      expect(result.trafficUsedBytes, 9007199254740991);
    });

    test(
      'whitespace in tuples is safe, decimal quota is not guessed',
      () async {
        final result = await _parse('''$_success
<mem> 2048 , 0 , 2048 , 0.0 </mem><hdd>20.5,0,20.5,0</hdd>
<bw> 4096 , 100 , 3996 , 2.441406 </bw>''');
        expect(result.ramBytes, 2048);
        expect(result.diskBytes, isNull);
        expect(result.trafficBytes, 4096);
        expect(result.trafficUsedBytes, 100);
      },
    );

    final invalidCounters = [
      '',
      '0',
      '1024',
      '1,0,1',
      '1,0,1,0,0',
      '1,-1,2,0',
      '-1,0,0,0',
      '+1,0,1,0',
      '1.0,0,1,0',
      '1,0,1,NaN',
      '1,0,1,Infinity',
      '1,0,1,-1',
      '1,0,1,1e2',
      '1,0,1,0.1234567',
      '1,0,1,1000000000',
      '9007199254740992,0,0,0',
      '1,9007199254740992,0,0',
      '1,0,9007199254740992,0',
      '00000000000000001,0,1,0',
      '1,0,,0',
      '1 GiB,0,1 GiB,0',
      'unlimited',
      'Unlimited',
      _secret,
    ];
    for (var i = 0; i < invalidCounters.length; i++) {
      test('malformed optional counter $i remains missing', () async {
        final value = invalidCounters[i];
        final result = await _parse('''$_success
<mem>$value</mem><hdd>$value</hdd><bw>$value</bw>
<hostname>valid.example.test</hostname>''');
        expect(result.hostname, 'valid.example.test');
        expect(result.ramBytes, isNull);
        expect(result.diskBytes, isNull);
        expect(result.trafficBytes, isNull);
        expect(result.trafficUsedBytes, isNull);
        expect(result.trafficUnlimited, false);
      });
    }

    test('unknown aliases and unsolicited fields are never inferred', () async {
      final result = await _parse('''$_success
<cpu>4</cpu><cpu_usage>4</cpu_usage><cores>4</cores><cpu_percent>400</cpu_percent>
<memory>1073741824</memory><ram>1073741824</ram><disk>21474836480</disk>
<bandwidth>1099511627776</bandwidth><bandwidth_unlimited>true</bandwidth_unlimited>
<unlimited>true</unlimited><ip>192.0.2.10</ip><name>unknown.example.test</name>
<password>$_secret</password><os>Linux</os><location>example</location>''');
      expect(result.ipv4, isNull);
      expect(result.hostname, isNull);
      expect(result.vcpu, isNull);
      expect(result.ramBytes, isNull);
      expect(result.diskBytes, isNull);
      expect(result.trafficBytes, isNull);
      expect(result.trafficUnlimited, false);
      expect(result.osImage, isNull);
      expect(result.location, isNull);
    });
  });

  group('optional explicit CPU count extensions', () {
    for (final name in ['vcpu', 'cpus']) {
      test('$name is an integer count only', () async {
        expect((await _parse('$_success<$name>8</$name>')).vcpu, 8);
      });
      for (final value in [
        '',
        '0',
        '-1',
        '1.5',
        '4%',
        '4 CPUs',
        '400,20,380,5',
        '65537',
        '9007199254740991',
        '9007199254740992',
        'Infinity',
        _secret,
      ]) {
        test('$name rejects malformed count ${value.hashCode}', () async {
          expect((await _parse('$_success<$name>$value</$name>')).vcpu, isNull);
        });
      }
    }
    test(
      'equal aliases agree, conflicts or invalid alias stay missing',
      () async {
        expect((await _parse('$_success<vcpu>4</vcpu><cpus>4</cpus>')).vcpu, 4);
        for (final other in ['8', '0', '', '4%', _secret]) {
          expect(
            (await _parse('$_success<vcpu>4</vcpu><cpus>$other</cpus>')).vcpu,
            isNull,
          );
        }
      },
    );
  });

  group('bounded IP and hostname values', () {
    test('IPv6-only and canonicalized addresses remain typed', () async {
      final result = await _parse('''$_success
<ipaddr>2001:0db8:0000:0000:0000:0000:0000:0001</ipaddr>''');
      expect(result.ipv4, isNull);
      expect(result.ipv6, '2001:db8::1');
    });
    for (final value in [
      '',
      '192.0.2.1,',
      '192.0.2.1,not-an-ip',
      'fe80::1%eth0',
      'https://192.0.2.1',
      '192.0.2.1/24',
      List.filled(65, '192.0.2.1').join(','),
      _secret,
    ]) {
      test('invalid bound-address list ${value.hashCode} is ignored', () async {
        final result = await _parse('$_success<ipaddr>$value</ipaddr>');
        expect(result.ipv4, isNull);
        expect(result.ipv6, isNull);
      });
    }
    test('unspecified IP placeholders stay missing', () async {
      for (final value in ['0.0.0.0', '::', '::0', '::ffff:0.0.0.0']) {
        final result = await _parse('$_success<ipaddress>$value</ipaddress>');
        expect(result.ipv4, isNull, reason: value);
        expect(result.ipv6, isNull, reason: value);
      }
    });
    test(
      'unspecified main and bound IPs do not hide usable fallback IPs',
      () async {
        final result = await _parse('''$_success
<ipaddress>0.0.0.0</ipaddress>
<ipaddr>::,192.0.2.12,::ffff:0.0.0.0,2001:db8::2</ipaddr>''');
        expect(result.ipv4, '192.0.2.12');
        expect(result.ipv6, '2001:db8::2');
      },
    );
    test(
      'one malformed address alias does not erase the valid other',
      () async {
        final result = await _parse('''$_success
<ipaddress>$_secret</ipaddress><ipaddr>192.0.2.12,2001:db8::2</ipaddr>''');
        expect(result.ipv4, '192.0.2.12');
        expect(result.ipv6, '2001:db8::2');
      },
    );
    for (final value in [
      '',
      '.',
      '0',
      '0.',
      '192.0.2.1',
      '192.0.2.1.',
      '2001:db8::1',
      'bad..host',
      '-bad.host',
      'bad-.host',
      'bad_host',
      'host/name',
      'host name',
      'host\nname',
      '主机.example',
      '${'a' * 64}.test',
      List.filled(5, 'a' * 63).join('.'),
      _secret,
    ]) {
      test('invalid hostname ${value.hashCode} stays missing', () async {
        final result = await _parse('$_success<hostname>$value</hostname>');
        expect(result.hostname, isNull);
      });
    }
  });

  group('secret reflection and XML safety', () {
    test(
      'syntactically valid hostname echo is suppressed case-insensitively',
      () async {
        final result = await _parse(
          '$_success<hostname>HOSTKEY.example.test</hostname>',
          key: 'hostkey',
        );
        expect(result.hostname, isNull);
      },
    );
    test('valid numeric echoes never become resources', () async {
      final result = await _parse(
        '''$_success
<cpus>42</cpus><mem>42,0,42,0</mem><hdd>42,0,42,0</hdd><bw>42,0,42,0</bw>''',
        key: '42',
      );
      expect(result.vcpu, isNull);
      expect(result.ramBytes, isNull);
      expect(result.diskBytes, isNull);
      expect(result.trafficBytes, isNull);
      expect(result.trafficUsedBytes, isNull);
    });
    test(
      'canonicalized address cannot expose differently formatted secret',
      () async {
        final result = await _parse(
          '$_success<ipaddr>2001:0db8:0000:0000:0000:0000:0000:0001</ipaddr>',
          hash: '2001:db8::1',
        );
        expect(result.ipv6, isNull);
      },
    );
    for (final field in [
      'status',
      'statusmsg',
      'vmstat',
      'ipaddr',
      'ipaddress',
      'hostname',
      'mem',
      'hdd',
      'bw',
      'vcpu',
      'cpus',
    ]) {
      test('duplicate or nested $field is structurally ambiguous', () async {
        final prefix = switch (field) {
          'status' => '<statusmsg></statusmsg>',
          'statusmsg' => '<status>success</status>',
          _ => _success,
        };
        for (final body in [
          '$prefix<$field>1</$field><$field>1</$field>',
          '$prefix<extra><$field>1</$field></extra>',
          '$prefix<$field><nested>1</nested></$field>',
        ]) {
          await expectLater(
            _parse(body),
            throwsA(
              isA<CloudFailure>().having(
                (e) => e.kind,
                'kind',
                CloudFailureKind.invalidResponse,
              ),
            ),
          );
        }
      });
    }
    for (final body in [
      '<!DOCTYPE response [<!ENTITY steal SYSTEM "file:///unreadable">]>$_success',
      '<?dangerous value?>$_success',
      '${'<x>' * 17}${'</x>' * 17}$_success',
      '${'<x/>' * 2050}$_success',
      '<status>success</status>',
      '<html>$_secret</html>',
    ]) {
      test(
        'unsafe or incomplete envelope ${body.hashCode} is rejected',
        () async {
          await expectLater(
            _parse(body),
            throwsA(
              isA<CloudFailure>()
                  .having(
                    (e) => e.kind,
                    'kind',
                    CloudFailureKind.invalidResponse,
                  )
                  .having(
                    (e) => e.toString(),
                    'safe',
                    isNot(contains(_secret)),
                  ),
            ),
          );
        },
      );
    }
    test('API rejection never echoes provider text', () async {
      await expectLater(
        _parse('<status>error</status><statusmsg>$_secret</statusmsg>'),
        throwsA(
          isA<CloudFailure>()
              .having((e) => e.kind, 'kind', CloudFailureKind.apiRejected)
              .having((e) => e.toString(), 'safe', isNot(contains(_secret))),
        ),
      );
    });
  });

  group('status compatibility', () {
    for (final (message, vmstat, expected) in [
      ('', 'online', CloudPower.running),
      ('unknown', 'offline', CloudPower.stopped),
      ('online', 'unknown', CloudPower.running),
      ('offline', 'offline', CloudPower.stopped),
      ('online', 'offline', CloudPower.unknown),
      ('offline', 'online', CloudPower.unknown),
      ('suspended', 'processing', CloudPower.unknown),
    ]) {
      test('statusmsg $message and vmstat $vmstat reconcile safely', () async {
        final result = await _parse('''<status>success</status>
<statusmsg>$message</statusmsg><vmstat>$vmstat</vmstat>''');
        expect(result.power, expected);
      });
    }
  });
}
