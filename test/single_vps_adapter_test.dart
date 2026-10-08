import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vps_tell_you/cloud/cloud_account.dart';
import 'package:vps_tell_you/cloud/cloud_models.dart';
// Intentionally retain the original public import and constructors.
import 'package:vps_tell_you/cloud/solusvm_adapter.dart';
import 'package:xml/xml.dart';

const _key = 'SYNTHETIC_SINGLE_KEY';
const _hash = 'SYNTHETIC_SINGLE_HASH';
const _providers = [CloudProvider.solusVm1, CloudProvider.rackNerd];
final _at = DateTime.utc(2026, 10, 6, 8);
final _endpoint = CloudEndpoint.parse('https://panel.example.test:8443');
const _fields = {
  'status': 'success',
  'statusmsg': '',
  'vmstat': 'online',
  'ipaddress': '192.0.2.40',
  'ipaddr': '192.0.2.40,2001:0db8:0:0:0:0:0:40',
  'hostname': 'synthetic.example.test.',
  'mem': '2147483648,0,2147483648,0',
  'hdd': '32212254720,0,32212254720,0',
  'bw': '1000,2000,0,200',
};

String _body(CloudProvider provider, Map<String, String> fields) =>
    provider == CloudProvider.rackNerd
    ? jsonEncode(fields)
    : XmlElement(XmlName('response'), [], [
        for (final entry in fields.entries)
          XmlElement(XmlName(entry.key), [], [XmlText(entry.value)]),
      ]).toXmlString();

CloudAdapter _adapter(
  CloudProvider provider, {
  required http.Client Function() clientFactory,
  DateTime Function()? clock,
  CloudReadLimits? limits,
  String key = _key,
  String hash = _hash,
}) => switch (provider) {
  CloudProvider.solusVm1 => SolusVm1Adapter(
    endpoint: _endpoint,
    credentials: SolusVm1Credentials(key: key, hash: hash),
    clientFactory: clientFactory,
    clock: clock ?? () => _at,
    limits: limits,
  ),
  CloudProvider.rackNerd => RackNerdAdapter(
    endpoint: _endpoint,
    credentials: RackNerdCredentials(key: key, hash: hash),
    clientFactory: clientFactory,
    clock: clock ?? () => _at,
    limits: limits,
  ),
  CloudProvider.solusVm2 => throw StateError('Not a single-VPS fixture'),
};

Future<CloudSnapshot> _read(
  CloudProvider provider,
  Map<String, String> fields, {
  String key = _key,
}) => _adapter(
  provider,
  key: key,
  clientFactory: () =>
      MockClient((_) async => http.Response(_body(provider, fields), 200)),
).read(cancellation: CloudCancellation());

Matcher _failure(CloudFailureKind kind) => throwsA(
  isA<CloudFailure>()
      .having((e) => e.kind, 'kind', kind)
      .having((e) => e.toString(), 'no key', isNot(contains(_key)))
      .having((e) => e.toString(), 'no hash', isNot(contains(_hash))),
);

void main() {
  test(
    'XML and JSON retain one anonymous snapshot and identical common resources',
    () async {
      final v1 = await _read(CloudProvider.solusVm1, _fields);
      final rack = await _read(CloudProvider.rackNerd, _fields);
      expect(
        encodeCloudInstance(v1.instances.single),
        encodeCloudInstance(rack.instances.single),
      );
      for (final snapshot in [v1, rack]) {
        expect(snapshot.completedAt, _at);
        expect(snapshot.projects, isEmpty);
        expect(snapshot.remoteAccountId, isNull);
        final instance = snapshot.instances.single;
        expect(instance.observedAt, snapshot.completedAt);
        expect(cloudInstanceKey(snapshot, instance), 'single');
        expect(instance.projectId, isNull);
        expect(instance.serverId, isNull);
        expect(instance.uuid, isNull);
        expect(instance.power, CloudPower.running);
        expect(instance.ipv4, '192.0.2.40');
        expect(instance.ipv6, '2001:db8::40');
        expect(instance.hostname, 'synthetic.example.test');
        expect(instance.ramBytes, 2147483648);
        expect(instance.diskBytes, 32212254720);
        expect(instance.trafficBytes, 1000);
        expect(instance.trafficUsedBytes, 2000);
        expect(instance.trafficUnlimited, isFalse);
        expect(instance.vcpu, isNull);
      }
    },
  );

  for (final counts in [
    {'vcpu': '4', 'cpus': '4'},
    {'vcpu': '4', 'cpus': '8'},
    {'vcpu': '0'},
  ]) {
    test('CPU allowlists stay separate for $counts', () async {
      final fields = {..._fields, ...counts};
      final v1 = await _read(CloudProvider.solusVm1, fields);
      final rack = await _read(CloudProvider.rackNerd, fields);
      expect(
        v1.instances.single.vcpu,
        counts['vcpu'] == '4' && counts['cpus'] == '4' ? 4 : null,
      );
      expect(rack.instances.single.vcpu, isNull);
      expect(v1.instances.single.ramBytes, rack.instances.single.ramBytes);
    });
  }

  test('shared projection keeps unknown quotas and numeric/canonical secret filtering', () async {
    for (final fields in [
      {..._fields, 'mem': '0,0,0,0', 'hdd': '2048,0,2048', 'bw': 'unlimited'},
      {
        ..._fields,
        'ipaddress': '192.0.2.42',
        'ipaddr': '192.0.2.42,2001:db8::42',
        'hostname': 'host42.example.test',
        'mem': '42,0,42,0',
        'hdd': '42,0,42,0',
        'bw': '42,0,42,0',
      },
      {
        ..._fields,
        'ipaddress': '192.0.2.40',
        'ipaddr': '2001:0db8:0:0:0:0:0:40',
      },
    ]) {
      final key = fields['mem'] == '42,0,42,0'
          ? '42'
          : fields['mem'] == '0,0,0,0'
          ? _key
          : 'db8::40';
      final v1 = (await _read(
        CloudProvider.solusVm1,
        fields,
        key: key,
      )).instances.single;
      final rack = (await _read(
        CloudProvider.rackNerd,
        fields,
        key: key,
      )).instances.single;
      expect(encodeCloudInstance(v1), encodeCloudInstance(rack));
      if (key == '42') {
        expect(v1.ipv4, isNull);
        expect(v1.ipv6, isNull);
        expect(v1.hostname, isNull);
        expect(v1.ramBytes, isNull);
        expect(v1.diskBytes, isNull);
        expect(v1.trafficBytes, isNull);
        expect(v1.trafficUsedBytes, isNull);
      } else if (key == 'db8::40') {
        expect(v1.ipv6, isNull);
        expect(v1.ipv4, '192.0.2.40');
      } else {
        expect(v1.ramBytes, isNull);
        expect(v1.diskBytes, isNull);
        expect(v1.trafficBytes, isNull);
        expect(v1.trafficUnlimited, isFalse);
      }
    }
  });

  for (final provider in _providers) {
    for (final (label, fields, kind) in [
      (
        'API error',
        {'status': 'error', 'statusmsg': _key},
        CloudFailureKind.apiRejected,
      ),
      (
        'missing statusmsg',
        {'status': 'success'},
        CloudFailureKind.invalidResponse,
      ),
      (
        'unknown status',
        {'status': 'unknown', 'statusmsg': ''},
        CloudFailureKind.invalidResponse,
      ),
      ('malformed input', null, CloudFailureKind.invalidResponse),
    ]) {
      test(
        '${provider.name}: $label preserves clock placement relative to parsing and API validation',
        () async {
          var clocks = 0;
          final events = <String>[];
          final adapter = _adapter(
            provider,
            clock: () {
              clocks++;
              events.add('clock');
              return _at;
            },
            clientFactory: () => MockClient((_) async {
              events.add('request');
              return http.Response(
                fields == null
                    ? 'not XML or JSON $_key'
                    : _body(provider, fields),
                200,
              );
            }),
          );
          await expectLater(
            adapter.read(cancellation: CloudCancellation()),
            _failure(kind),
          );
          expect(clocks, provider == CloudProvider.solusVm1 ? 1 : 0);
          expect(
            events,
            provider == CloudProvider.solusVm1
                ? ['request', 'clock']
                : ['request'],
          );
        },
      );
    }

    test(
      '${provider.name}: successful read uses one injected UTC observation time',
      () async {
        var clocks = 0, requests = 0;
        final adapter = _adapter(
          provider,
          clock: () {
            clocks++;
            return _at.toLocal();
          },
          clientFactory: () => MockClient((_) async {
            requests++;
            return http.Response(_body(provider, _fields), 200);
          }),
        );
        final snapshot = await adapter.read(cancellation: CloudCancellation());
        expect(requests, 1);
        expect(clocks, 1);
        expect(snapshot.completedAt, _at);
        expect(snapshot.completedAt.isUtc, isTrue);
        expect(snapshot.instances.single.observedAt, snapshot.completedAt);
      },
    );

    test(
      '${provider.name}: cancellation during clock is caught by the final session check',
      () async {
        final cancellation = CloudCancellation();
        var requests = 0, clocks = 0;
        final adapter = _adapter(
          provider,
          clock: () {
            clocks++;
            cancellation.cancel();
            return _at;
          },
          clientFactory: () => MockClient((_) async {
            requests++;
            return http.Response(_body(provider, _fields), 200);
          }),
        );
        await expectLater(
          adapter.read(cancellation: cancellation),
          _failure(CloudFailureKind.cancelled),
        );
        expect(clocks, 1);
        expect(requests, 1);
      },
    );

    test(
      '${provider.name}: pre-cancellation never creates a client or calls clock',
      () async {
        var clients = 0, clocks = 0;
        final adapter = _adapter(
          provider,
          clock: () {
            clocks++;
            return _at;
          },
          clientFactory: () {
            clients++;
            return MockClient(
              (_) async => http.Response(_body(provider, _fields), 200),
            );
          },
        );
        await expectLater(
          adapter.read(cancellation: CloudCancellation()..cancel()),
          _failure(CloudFailureKind.cancelled),
        );
        expect(clients, 0);
        expect(clocks, 0);
      },
    );

    test(
      '${provider.name}: transport error does not call the injected clock',
      () async {
        var clocks = 0;
        final adapter = _adapter(
          provider,
          clock: () {
            clocks++;
            return _at;
          },
          clientFactory: () =>
              MockClient((_) async => http.Response(_key, 401)),
        );
        await expectLater(
          adapter.read(cancellation: CloudCancellation()),
          _failure(CloudFailureKind.unauthorized),
        );
        expect(clocks, 0);
      },
    );

    test(
      '${provider.name}: exact 16 KiB succeeds and one extra byte fails before parsing',
      () async {
        final body = _body(provider, _fields);
        final padded = body + ' ' * (16 * 1024 - utf8.encode(body).length);
        for (final overflow in [false, true]) {
          var requests = 0, clocks = 0;
          final adapter = _adapter(
            provider,
            clock: () {
              clocks++;
              return _at;
            },
            clientFactory: () => MockClient((_) async {
              requests++;
              return http.Response(padded + (overflow ? ' ' : ''), 200);
            }),
          );
          final read = adapter.read(cancellation: CloudCancellation());
          if (overflow) {
            await expectLater(
              read,
              _failure(CloudFailureKind.responseTooLarge),
            );
            expect(clocks, 0);
          } else {
            expect(
              (await read).instances.single.hostname,
              'synthetic.example.test',
            );
            expect(clocks, 1);
          }
          expect(requests, 1);
        }
      },
    );

    for (final cancel in [true, false]) {
      test(
        '${provider.name}: ${cancel ? 'cancellation' : 'timeout'} fences late response and clock',
        () async {
          final started = Completer<void>();
          final release = Completer<http.Response>();
          final cancellation = CloudCancellation();
          var clocks = 0;
          final adapter = _adapter(
            provider,
            limits: CloudReadLimits(
              requestTimeout: const Duration(milliseconds: 30),
            ),
            clock: () {
              clocks++;
              return _at;
            },
            clientFactory: () => MockClient((_) {
              started.complete();
              return release.future;
            }),
          );
          final pending = adapter.read(cancellation: cancellation);
          final assertion = expectLater(
            pending,
            _failure(
              cancel ? CloudFailureKind.cancelled : CloudFailureKind.timeout,
            ),
          );
          await started.future;
          if (cancel) cancellation.cancel();
          await assertion;
          release.complete(http.Response(_body(provider, _fields), 200));
          await Future<void>.delayed(Duration.zero);
          expect(clocks, 0);
        },
      );
    }
  }
}
