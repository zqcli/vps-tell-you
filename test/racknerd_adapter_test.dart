import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vps_tell_you/cloud/cloud_account.dart';
import 'package:vps_tell_you/cloud/cloud_models.dart';
import 'package:vps_tell_you/cloud/solusvm_adapter.dart';

const _key = 'SYNTHETIC+KEY/&=';
const _hash = 'SYNTHETIC+HASH/&=';
final _observedAt = DateTime.utc(2026, 10, 6);
String _fixture() =>
    File('test/fixtures/solusvm/racknerd-info.json').readAsStringSync();
Matcher _failure(CloudFailureKind kind) => throwsA(
  isA<CloudFailure>()
      .having((e) => e.kind, 'kind', kind)
      .having((e) => e.toString(), 'safe key', isNot(contains(_key)))
      .having((e) => e.toString(), 'safe hash', isNot(contains(_hash))),
);

RackNerdAdapter _adapter(
  Future<http.Response> Function(http.Request) handler, {
  String key = _key,
  String hash = _hash,
  CloudReadLimits? limits,
}) => RackNerdAdapter(
  endpoint: CloudEndpoint.parse('https://panel.example.test:8443'),
  credentials: RackNerdCredentials(key: key, hash: hash),
  limits: limits,
  clock: () => _observedAt,
  clientFactory: () => MockClient(handler),
);

Future<CloudInstance> _parse(
  Map<String, Object?> fields, {
  String key = _key,
  String hash = _hash,
}) async => (await _adapter(
  (_) async => http.Response(jsonEncode(fields), 200),
  key: key,
  hash: hash,
).read(cancellation: CloudCancellation())).instances.single;

void main() {
  group('independent provider and endpoint contract', () {
    test(
      'single-instance semantics are exhaustive and credentials independent',
      () {
        expect(CloudProvider.solusVm1.isSingleInstance, isTrue);
        expect(CloudProvider.solusVm2.isSingleInstance, isFalse);
        expect(CloudProvider.rackNerd.isSingleInstance, isTrue);
        expect(CloudProvider.rackNerd.name, 'rackNerd');
        final credentials = RackNerdCredentials(key: _key, hash: _hash);
        expect(credentials, isNot(isA<SolusVm1Credentials>()));
        expect(credentials.toString(), isNot(contains(_key)));
        for (final value in ['', ' $_key', '$_key\n', 'x' * 8193]) {
          expect(
            () => RackNerdCredentials(key: value, hash: _hash),
            _failure(CloudFailureKind.invalidCredentials),
          );
          expect(
            () => RackNerdCredentials(key: _key, hash: value),
            _failure(CloudFailureKind.invalidCredentials),
          );
        }
      },
    );
    test(
      'only explicit RackNerd option accepts the exact full API address',
      () {
        const full = 'https://PANEL.example.test:8443/api/client/command.php';
        final parsed = CloudEndpoint.parse(full, allowRackNerdApiPath: true);
        expect(parsed.toString(), 'https://panel.example.test:8443');
        expect(parsed.normalizedApiPath, isTrue);
        expect(parsed.normalizedConsolePath, isFalse);
        expect(
          CloudEndpoint.parse('https://panel.example.test.').toString(),
          'https://panel.example.test.',
        );
        expect(
          () => CloudEndpoint.parse(full),
          _failure(CloudFailureKind.invalidEndpoint),
        );
        expect(
          () => CloudEndpoint.parse(full, allowSolusVm1ConsolePath: true),
          _failure(CloudFailureKind.invalidEndpoint),
        );
        for (final path in [
          '/home.php',
          '/api/client/command.php/',
          '/api/client/command.php.',
          '/api/client/command.php?key=$_key',
          '/api/client/command.php#fragment',
          '/api/client/../client/command.php',
          '/api/client/%63ommand.php',
          '/API/client/command.php',
          '/other',
        ]) {
          expect(
            () => CloudEndpoint.parse(
              'https://panel.example.test$path',
              allowRackNerdApiPath: true,
            ),
            _failure(CloudFailureKind.invalidEndpoint),
          );
        }
      },
    );
    test(
      'original V1 rejects ctrl wrapper/declaration and JSON differences',
      () async {
        for (final body in [
          '<?xml version="1.0" encoding="UTF-8"?><ctrl><status>success</status>'
              '<statusmsg>online</statusmsg><vmstat>online</vmstat></ctrl>',
          _fixture(),
        ]) {
          await expectLater(
            SolusVm1Adapter(
              endpoint: CloudEndpoint.parse('https://panel.example.test'),
              credentials: SolusVm1Credentials(key: _key, hash: _hash),
              clientFactory: () =>
                  MockClient((_) async => http.Response(body, 200)),
            ).read(cancellation: CloudCancellation()),
            _failure(CloudFailureKind.invalidResponse),
          );
        }
      },
    );
  });

  test(
    'one form info request encodes secrets and projects resources without CPU',
    () async {
      var calls = 0;
      final snapshot = await _adapter((request) async {
        calls++;
        expect(request.method, 'POST');
        expect(
          request.url.toString(),
          'https://panel.example.test:8443/api/client/command.php',
        );
        expect(request.url.query, isEmpty);
        expect(request.followRedirects, isFalse);
        expect(request.maxRedirects, 0);
        expect(
          request.headers['content-type'],
          startsWith('application/x-www-form-urlencoded'),
        );
        expect(request.headers.containsKey('authorization'), isFalse);
        expect(request.headers.containsKey('user-agent'), isFalse);
        expect(request.bodyFields, {
          'key': _key,
          'hash': _hash,
          'action': 'info',
          'rdtype': 'json',
          'status': 'true',
          'ipaddr': 'true',
          'bw': 'true',
          'hdd': 'true',
          'mem': 'true',
        });
        expect(request.body, contains('%2B'));
        expect(request.body, contains('%26'));
        expect(request.body, contains('%3D'));
        return http.Response(
          _fixture(),
          200,
          headers: {'content-type': 'application/json'},
        );
      }).read(cancellation: CloudCancellation());
      expect(calls, 1);
      expect(snapshot.provider, CloudProvider.rackNerd);
      expect(snapshot.remoteAccountId, isNull);
      expect(snapshot.projects, isEmpty);
      expect(snapshot.completedAt, _observedAt);
      final instance = snapshot.instances.single;
      expect(cloudInstanceKey(snapshot, instance), 'single');
      expect(instance.projectId, isNull);
      expect(instance.serverId, isNull);
      expect(instance.uuid, isNull);
      expect(instance.name, isNull);
      expect(instance.ipv4, '192.0.2.40');
      expect(instance.ipv6, '2001:db8::40');
      expect(instance.hostname, 'synthetic-vps.example.test');
      expect(instance.vcpu, isNull);
      expect(instance.ramBytes, 2147483648);
      expect(instance.diskBytes, 32212254720);
      expect(instance.trafficBytes, 1099511627776);
      expect(instance.trafficUsedBytes, 0);
      expect(instance.trafficUnlimited, isFalse);
      expect(instance.power, CloudPower.running);
      expect(instance.osImage, isNull);
    },
  );

  group('bounded whitelist JSON projection', () {
    test('unknown CPU/identity/secret fields are never projected', () async {
      final instance = await _parse({
        'status': 'success',
        'statusmsg': '',
        'vmstat': 'online',
        'vcpu': '4',
        'cpus': '4',
        'cpu': '4',
        'id': 12,
        'uuid': _key,
        'password': _hash,
        'name': _key,
        'unlimited': true,
      });
      expect(instance.vcpu, isNull);
      expect(instance.serverId, isNull);
      expect(instance.uuid, isNull);
      expect(instance.name, isNull);
      expect(instance.trafficUnlimited, isFalse);
    });
    for (final (message, vmstat, power) in [
      ('', 'online', CloudPower.running),
      ('', 'offline', CloudPower.stopped),
      ('online', 'offline', CloudPower.unknown),
      ('offline', 'online', CloudPower.unknown),
      ('unknown', 'unknown', CloudPower.unknown),
    ]) {
      test('reconciles $message/$vmstat conservatively', () async {
        expect(
          (await _parse({
            'status': 'success',
            'statusmsg': message,
            'vmstat': vmstat,
          })).power,
          power,
        );
      });
    }
    test('counter totals are byte quota, not usage, and malformed counters stay unknown', () async {
      for (final counter in [
        '0,4000,7000,0',
        '2048,4096,0,200.125',
        '2048,0,2048',
      ]) {
        final instance = await _parse({
          'status': 'success',
          'statusmsg': '',
          'mem': counter,
          'hdd': counter,
          'bw': counter,
        });
        final total = counter.startsWith('2048,4096') ? 2048 : null;
        expect(instance.ramBytes, total);
        expect(instance.diskBytes, total);
        expect(instance.trafficBytes, total);
        expect(
          instance.trafficUsedBytes,
          counter.startsWith('0,')
              ? 4000
              : total == null
              ? null
              : 4096,
        );
        expect(instance.trafficUnlimited, isFalse);
      }
    });
    test(
      'reflection filtering includes canonical IP and numeric resource echoes',
      () async {
        final numeric = await _parse({
          'status': 'success',
          'statusmsg': '',
          'mem': '42,0,42,0',
          'hdd': '42,0,42,0',
          'bw': '42,0,42,0',
        }, key: '42');
        expect(numeric.ramBytes, isNull);
        expect(numeric.diskBytes, isNull);
        expect(numeric.trafficBytes, isNull);
        expect(numeric.trafficUsedBytes, isNull);
        final reflected = await _parse(
          {
            'status': 'success',
            'statusmsg': '',
            'hostname': 'HOSTKEY.example.test',
            'ipaddr': '2001:0db8:0000:0000:0000:0000:0000:0001',
          },
          key: 'hostkey',
          hash: '2001:db8::1',
        );
        expect(reflected.hostname, isNull);
        expect(reflected.ipv6, isNull);
      },
    );
    for (final name in [
      'status',
      'statusmsg',
      'hostname',
      'ipaddress',
      'template',
      'os',
      'vmstat',
      'ipaddr',
      'bw',
      'hdd',
      'mem',
    ]) {
      test('rejects duplicate/nested/type ambiguity for $name', () async {
        final base = switch (name) {
          'status' => '"statusmsg":""',
          'statusmsg' => '"status":"success"',
          _ => '"status":"success","statusmsg":""',
        };
        for (final suffix in [
          '"$name":"value","$name":"value"',
          '"extra":{"$name":"value"}',
          '"$name":null',
          '"$name":12',
          '"$name":true',
          '"$name":[]',
          '"$name":{}',
        ]) {
          await expectLater(
            _adapter((_) async => http.Response('{$base,$suffix}', 200))
                .read(cancellation: CloudCancellation()),
            _failure(CloudFailureKind.invalidResponse),
          );
        }
      });
    }
    for (final body in [
      'null',
      '[]',
      '{}',
      '{"status":"success"}',
      '{"status":"unknown","statusmsg":""}',
      '{"status":"success","statusmsg":"","statu\\u0073":"success"}',
      '{"status":"success","statusmsg":"",}',
      '{"status":"success","statusmsg":""}{}',
      '<html>$_key</html>',
      '{"status":"success","statusmsg":"","unused":"bad\nstring"}',
      '{"status":"success","statusmsg":"","unused":${'[' * 17}0${']' * 17}}',
      '{"status":"success","statusmsg":"","unused":[${List.filled(2048, '0').join(',')}] }',
    ]) {
      test(
        'rejects malformed/unknown/HTML/deep/large JSON ${body.hashCode}',
        () async {
          await expectLater(
            _adapter((_) async => http.Response(body, 200))
                .read(cancellation: CloudCancellation()),
            _failure(CloudFailureKind.invalidResponse),
          );
        },
      );
    }
    test(
      'HTTP 200 API rejection remains distinct and body is never leaked',
      () async {
        await expectLater(
          _adapter(
            (_) async => http.Response(
              jsonEncode({'status': 'error', 'statusmsg': '$_key $_hash'}),
              200,
            ),
          ).read(cancellation: CloudCancellation()),
          _failure(CloudFailureKind.apiRejected),
        );
      },
    );
  });

  group('same strict bounded transport', () {
    for (final entry in {
      301: CloudFailureKind.redirect,
      307: CloudFailureKind.redirect,
      401: CloudFailureKind.unauthorized,
      403: CloudFailureKind.forbidden,
      429: CloudFailureKind.rateLimited,
      500: CloudFailureKind.unavailable,
    }.entries) {
      test('HTTP ${entry.key} does not retry or expose body', () async {
        var calls = 0;
        await expectLater(
          _adapter((_) async {
            calls++;
            return http.Response(
              '$_key $_hash',
              entry.key,
              headers: {'location': 'https://elsewhere.example.test'},
            );
          }).read(cancellation: CloudCancellation()),
          _failure(entry.value),
        );
        expect(calls, 1);
      });
    }
    for (final limits in [
      CloudReadLimits(),
      CloudReadLimits(responseBytes: 100),
      CloudReadLimits(totalBytes: 100),
    ]) {
      test(
        'response and operation byte caps ${limits.responseBytes}/${limits.totalBytes}',
        () async {
          await expectLater(
            _adapter(
              (_) async => http.Response('x' * 16385, 200),
              limits: limits,
            ).read(cancellation: CloudCancellation()),
            _failure(CloudFailureKind.responseTooLarge),
          );
        },
      );
    }
    test('pre-cancelled read never creates a request', () async {
      var calls = 0;
      await expectLater(
        _adapter((_) async {
          calls++;
          return http.Response(_fixture(), 200);
        }).read(cancellation: CloudCancellation()..cancel()),
        _failure(CloudFailureKind.cancelled),
      );
      expect(calls, 0);
    });
    test('cancellation and timeout fence late responses', () async {
      for (final cancelled in [true, false]) {
        final late = Completer<http.Response>();
        final started = Completer<void>();
        final cancellation = CloudCancellation();
        final pending = _adapter(
          (_) {
            started.complete();
            return late.future;
          },
          limits: CloudReadLimits(
            requestTimeout: const Duration(milliseconds: 20),
          ),
        ).read(cancellation: cancellation);
        final check = expectLater(
          pending,
          _failure(
            cancelled ? CloudFailureKind.cancelled : CloudFailureKind.timeout,
          ),
        );
        await started.future;
        if (cancelled) cancellation.cancel();
        await check;
        late.complete(http.Response(_fixture(), 200));
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    });
  });
}
