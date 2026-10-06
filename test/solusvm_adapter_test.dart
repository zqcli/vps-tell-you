import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vps_tell_you/cloud/cloud_models.dart';
import 'package:vps_tell_you/cloud/solusvm_adapter.dart';

const sentinel = 'SYNTHETIC_SECRET_NEVER_EXPOSE';
final observedAt = DateTime.utc(2026, 10, 6, 5);
final endpoint = CloudEndpoint.parse('https://panel.example.test:8443');
String fixture(String name) =>
    File('test/fixtures/solusvm/$name').readAsStringSync();
Matcher fails(CloudFailureKind kind) => throwsA(
  isA<CloudFailure>()
      .having((e) => e.kind, 'kind', kind)
      .having((e) => e.toString().contains(sentinel), 'safe error', false),
);

SolusVm1Adapter v1(
  Future<http.Response> Function(http.Request) handler, {
  CloudReadLimits? limits,
}) => SolusVm1Adapter(
  endpoint: endpoint,
  credentials: SolusVm1Credentials(key: sentinel, hash: '${sentinel}_HASH'),
  clock: () => observedAt,
  limits: limits,
  clientFactory: () => MockClient(handler),
);

SolusVm2Adapter v2(
  Future<http.Response> Function(http.Request) handler, {
  CloudReadLimits? limits,
}) => SolusVm2Adapter(
  endpoint: endpoint,
  credentials: SolusVm2Credentials(sentinel),
  clock: () => observedAt,
  limits: limits,
  clientFactory: () => MockClient(handler),
);

Future<http.Response> minimalV2(http.Request request) async => http.Response(
  jsonEncode(
    request.url.path == '/api/v1/account'
        ? {
            'data': {'id': 12},
          }
        : {'data': []},
  ),
  200,
);

void main() {
  group('endpoint and credential boundary', () {
    test(
      'preserves origin and custom port, exposes known console normalization',
      () {
        expect(endpoint.toString(), 'https://panel.example.test:8443');
        expect(
          CloudEndpoint.parse(' HTTPS://EXAMPLE.TEST/ ').toString(),
          'https://example.test',
        );
        final console = CloudEndpoint.parse(
          'https://vps.virmach.com/home.php',
          allowSolusVm1ConsolePath: true,
        );
        expect(console.normalizedConsolePath, true);
        expect(console.toString(), 'https://vps.virmach.com');
        expect(
          CloudEndpoint.parse('https://[2001:db8::1]:5656').origin.port,
          5656,
        );
      },
    );
    for (final input in [
      'http://panel.test',
      'https://name:$sentinel@panel.test',
      'https://panel.test?token=$sentinel',
      'https://panel.test#fragment',
      'https://panel.test/api/v1',
      'https://panel.test/home.php',
      'https://panel.test:0',
      'https://panel.test:65536',
      '//panel.test',
      'https://panel.test\\@other.test',
      'https://panel.test/../',
      'https://panel.test\n.evil.test',
      'https://',
    ]) {
      test('rejects endpoint case ${input.hashCode}', () {
        expect(
          () => CloudEndpoint.parse(input),
          fails(CloudFailureKind.invalidEndpoint),
        );
      });
    }
    test(
      'rejects empty/control/oversized credentials without echoing values',
      () {
        for (final value in [
          '',
          ' $sentinel',
          '$sentinel\r\nHost: evil',
          'x' * 8193,
        ]) {
          expect(
            () => SolusVm1Credentials(key: value, hash: sentinel),
            fails(CloudFailureKind.invalidCredentials),
          );
          expect(
            () => SolusVm2Credentials(value),
            fails(CloudFailureKind.invalidCredentials),
          );
        }
        expect(
          () => SolusVm2Credentials('token with space'),
          fails(CloudFailureKind.invalidCredentials),
        );
        expect(
          SolusVm2Credentials(sentinel).toString(),
          isNot(contains(sentinel)),
        );
      },
    );
  });

  group('SolusVM 1 exact read-only protocol', () {
    test(
      'multipart body only key/hash/status, no URL secrets or redirects',
      () async {
        var calls = 0;
        final result = await v1((request) async {
          calls++;
          expect(request.method, 'POST');
          expect(
            request.url,
            Uri.parse('https://panel.example.test:8443/api/client/command.php'),
          );
          expect(request.followRedirects, false);
          expect(request.maxRedirects, 0);
          expect(
            request.headers['content-type'],
            startsWith('multipart/form-data; boundary='),
          );
          expect(request.headers.containsKey('authorization'), false);
          expect(
            RegExp('name="(.*?)"').allMatches(request.body).map((m) => m[1]),
            ['key', 'hash', 'action'],
          );
          expect(request.body, contains('\r\n\r\nstatus\r\n'));
          expect(request.body, contains(sentinel));
          return http.Response(fixture('v1-status-online.xml'), 200);
        }).read(cancellation: CloudCancellation());
        expect(calls, 1);
        expect(result.remoteAccountId, null);
        expect(result.instances.single.power, CloudPower.running);
        expect(result.instances.single.serverId, null);
        expect(result.instances.single.name, null);
        expect(result.instances.single.ramBytes, null);
        expect(result.completedAt, observedAt);
      },
    );
    for (final state in ['offline', 'online', 'suspended', 'processing', '']) {
      test('maps status $state conservatively', () async {
        final result = await v1(
          (_) async => http.Response(
            '<status>success</status><statusmsg>$state</statusmsg>',
            200,
          ),
        ).read(cancellation: CloudCancellation());
        expect(result.instances.single.power, switch (state) {
          'online' => CloudPower.running,
          'offline' => CloudPower.stopped,
          _ => CloudPower.unknown,
        });
      });
    }
    test('API failure does not return a fresh offline observation', () async {
      await expectLater(
        v1(
          (_) async => http.Response(
            '<status>error</status><statusmsg>$sentinel</statusmsg>',
            200,
          ),
        ).read(cancellation: CloudCancellation()),
        fails(CloudFailureKind.apiRejected),
      );
    });
    for (final body in [
      '<status>success',
      '<html>Cloudflare $sentinel</html>',
      '<status>success</status><statusmsg>online</statusmsg><statusmsg>offline</statusmsg>',
      '<status>success</status><statusmsg><nested>online</nested></statusmsg>',
      '<status>success</status><statusmsg>online</statusmsg><extra><status>error</status></extra>',
      '<!DOCTYPE response [<!ENTITY steal SYSTEM "file:///unreadable">]><status>success</status><statusmsg>&steal;</statusmsg>',
      '<?dangerous value?><status>success</status><statusmsg>online</statusmsg>',
      '${'<x>' * 17}${'</x>' * 17}<status>success</status><statusmsg>online</statusmsg>',
    ]) {
      test('rejects malformed/ambiguous/DTD XML ${body.hashCode}', () async {
        await expectLater(
          v1((_) async => http.Response(body, 200))
              .read(cancellation: CloudCancellation()),
          fails(CloudFailureKind.invalidResponse),
        );
      });
    }
  });

  group('SolusVM 2 inventory and projection', () {
    test('account -> projects -> paginated servers, exact GET allowlist and field units', () async {
      final paths = <String>[];
      final result = await v2((request) async {
        expect(request.method, 'GET');
        expect(request.body, isEmpty);
        expect(request.followRedirects, false);
        expect(request.headers['authorization'], 'Bearer $sentinel');
        expect(request.headers['accept'], 'application/json');
        expect(request.url.toString(), isNot(contains(sentinel)));
        paths.add(
          request.url.path +
              (request.url.hasQuery ? '?${request.url.query}' : ''),
        );
        return http.Response(
          fixture(switch (request.url.path) {
            '/api/v1/account' => 'v2-account.json',
            '/api/v1/projects' => 'v2-projects.json',
            '/api/v1/projects/7/servers' =>
              'v2-servers-page-${request.url.queryParameters['page']}.json',
            _ => throw StateError('Forbidden path'),
          }),
          200,
        );
      }).read(cancellation: CloudCancellation());
      expect(paths, [
        '/api/v1/account',
        '/api/v1/projects?page=1',
        '/api/v1/projects/7/servers?page=1',
        '/api/v1/projects/7/servers?page=2',
      ]);
      expect(result.remoteAccountId, 12);
      expect(result.projects.single.id, 7);
      final first = result.instances.first;
      expect(first.serverId, 101);
      expect(first.projectId, 7);
      expect(first.name, 'fixture-vps');
      expect(first.vcpu, 2);
      expect(first.ramBytes, 2147483648);
      expect(first.diskGiB, 40);
      expect(first.ipv4, '192.0.2.10');
      expect(first.ipv6, '2001:db8::10');
      expect(first.power, CloudPower.running);
      expect(first.suspended, false);
      expect(first.osImage, 'Debian 12');
      expect(first.location, 'Fixture region');
      expect(first.observedAt, observedAt);
      expect(result.instances.last.ramBytes, null);
      expect(result.instances.last.ipv4, null);
      expect(result.instances.last.power, CloudPower.unknown);
      expect(() => result.instances.clear(), throwsUnsupportedError);
    });
    test('successful empty and legacy non-paginated list', () async {
      final result = await v2(minimalV2)
          .read(cancellation: CloudCancellation());
      expect(result.instances, isEmpty);
      expect(result.projects, isEmpty);
      expect(result.remoteAccountId, 12);
    });
    test('unknown present real_status beats started status; optional fields remain unknown', () async {
      final result = await v2(
        (request) async => http.Response(
          jsonEncode(switch (request.url.path) {
            '/api/v1/account' => {
              'data': {'id': 12, 'billing_token': sentinel},
            },
            '/api/v1/projects' => {
              'data': [
                {'id': 7},
              ],
            },
            _ => {
              'data': [
                {
                  'id': 101,
                  'status': 'started',
                  'real_status': null,
                  'is_suspended': true,
                  'specifications': {'vcpu': '4', 'ram': -1, 'disk': 0},
                  'ips': [
                    {'ip': '192.0.2.20'},
                    {'ip': '192.0.2.21', 'is_primary': true},
                    {'ip': '2001:db8::20'},
                  ],
                  'settings': {'vnc_password': sentinel},
                },
              ],
            },
          }),
          200,
        ),
      ).read(cancellation: CloudCancellation());
      final instance = result.instances.single;
      expect(instance.power, CloudPower.unknown);
      expect(instance.suspended, true);
      expect(instance.vcpu, null);
      expect(instance.ramBytes, null);
      expect(instance.diskGiB, null);
      expect(instance.ipv4, '192.0.2.21');
      expect(instance.ipv6, '2001:db8::20');
    });
    test(
      'project lists paginate and shared projects are not filtered by owner',
      () async {
        final paths = <String>[];
        final result = await v2((request) async {
          paths.add(request.url.toString());
          final page = request.url.queryParameters['page'];
          return http.Response(
            jsonEncode(switch (request.url.path) {
              '/api/v1/account' => {
                'data': {'id': 12},
              },
              '/api/v1/projects' => {
                'data': [
                  {
                    'id': page == '1' ? 7 : 8,
                    'owner': {'id': 99},
                  },
                ],
                'meta': {'current_page': int.parse(page!), 'last_page': 2},
              },
              _ => {
                'data': [
                  {
                    'id': request.url.path.contains('/7/') ? 101 : 102,
                    'user': {'id': 99},
                  },
                ],
              },
            }),
            200,
          );
        }).read(cancellation: CloudCancellation());
        expect(result.projects.length, 2);
        expect(result.instances.length, 2);
        expect(paths.length, 5);
      },
    );
    for (final row in [
      {
        'id': 101,
        'project': {'id': 8},
      },
      {'id': 0},
      {'id': '101'},
      {'id': 101, 'uuid': sentinel},
    ]) {
      test('rejects invalid/cross-project identity ${row.hashCode}', () async {
        await expectLater(
          v2(
            (request) async => http.Response(
              jsonEncode(switch (request.url.path) {
                '/api/v1/account' => {
                  'data': {'id': 12},
                },
                '/api/v1/projects' => {
                  'data': [
                    {'id': 7},
                  ],
                },
                _ => {
                  'data': [row],
                },
              }),
              200,
            ),
          ).read(cancellation: CloudCancellation()),
          fails(CloudFailureKind.invalidResponse),
        );
      });
    }
    test(
      'duplicate remote identity fails rather than silently dropping',
      () async {
        await expectLater(
          v2(
            (request) async => http.Response(
              jsonEncode(switch (request.url.path) {
                '/api/v1/account' => {
                  'data': {'id': 12},
                },
                '/api/v1/projects' => {
                  'data': [
                    {'id': 7},
                  ],
                },
                _ => {
                  'data': [
                    {'id': 101},
                    {'id': 101},
                  ],
                },
              }),
              200,
            ),
          ).read(cancellation: CloudCancellation()),
          fails(CloudFailureKind.invalidResponse),
        );
      },
    );
    for (final body in [
      'not json $sentinel',
      '{"data":',
      'null',
      '[]',
      '{"data":{"id":-1}}',
      '${'[' * 34}0${']' * 34}',
    ]) {
      test('rejects invalid JSON/account/depth ${body.hashCode}', () async {
        await expectLater(
          v2((_) async => http.Response(body, 200))
              .read(cancellation: CloudCancellation()),
          fails(CloudFailureKind.invalidResponse),
        );
      });
    }
  });

  group('pagination cannot expand credential audience', () {
    for (final next in [
      'https://evil.test/api/v1/projects?page=2',
      'https://panel.example.test/api/v1/projects?page=2',
      'http://panel.example.test:8443/api/v1/projects?page=2',
      'https://$sentinel@panel.example.test:8443/api/v1/projects?page=2',
      '/api/v1/servers?page=2',
      '/api/v1/projects?page=2&extra=1',
      '/api/v1/projects?page=2&page=3',
      '/api/v1/projects?page=1',
      '/api/v1/projects?page=3',
      '/api/v1/projects?page=2#fragment',
      '/api/v1/projects?page=02',
    ]) {
      test('rejects hostile/repeated next ${next.hashCode}', () async {
        var calls = 0;
        await expectLater(
          v2((request) async {
            calls++;
            return http.Response(
              jsonEncode(
                request.url.path == '/api/v1/account'
                    ? {
                        'data': {'id': 12},
                      }
                    : {
                        'data': [],
                        'links': {'next': next},
                        'meta': {'current_page': 1, 'last_page': 2},
                      },
              ),
              200,
            );
          }).read(cancellation: CloudCancellation()),
          fails(CloudFailureKind.invalidResponse),
        );
        expect(calls, 2);
      });
    }
    test(
      'same-route relative next rebuilds page query; final page stops',
      () async {
        var calls = 0;
        final result = await v2((request) async {
          calls++;
          return http.Response(
            jsonEncode(
              request.url.path == '/api/v1/account'
                  ? {
                      'data': {'id': 12},
                    }
                  : {
                      'data': [],
                      'links': {
                        'next': request.url.queryParameters['page'] == '1'
                            ? '?page=2'
                            : null,
                      },
                    },
            ),
            200,
          );
        }).read(cancellation: CloudCancellation());
        expect(calls, 3);
        expect(result.instances, isEmpty);
      },
    );
    test(
      'contradictory explicit end and meta is incomplete, not success',
      () async {
        await expectLater(
          v2(
            (request) async => http.Response(
              jsonEncode(
                request.url.path == '/api/v1/account'
                    ? {
                        'data': {'id': 12},
                      }
                    : {
                        'data': [],
                        'links': {'next': null},
                        'meta': {'current_page': 1, 'last_page': 2},
                      },
              ),
              200,
            ),
          ).read(cancellation: CloudCancellation()),
          fails(CloudFailureKind.invalidResponse),
        );
      },
    );
  });

  group('transport budgets, cancellation and safe failures', () {
    for (final entry in {
      301: CloudFailureKind.redirect,
      302: CloudFailureKind.redirect,
      307: CloudFailureKind.redirect,
      308: CloudFailureKind.redirect,
      401: CloudFailureKind.unauthorized,
      403: CloudFailureKind.forbidden,
      429: CloudFailureKind.rateLimited,
      500: CloudFailureKind.unavailable,
    }.entries) {
      test('HTTP ${entry.key} does not expose remote body', () async {
        await expectLater(
          v1(
            (_) async => http.Response(
              sentinel,
              entry.key,
              headers: {'location': 'https://evil.test'},
            ),
          ).read(cancellation: CloudCancellation()),
          fails(entry.value),
        );
      });
    }
    test('transport exception is sanitized', () async {
      await expectLater(
        v1((_) async => throw Exception(sentinel))
            .read(cancellation: CloudCancellation()),
        fails(CloudFailureKind.connection),
      );
    });
    test('response size bound applies before parsing', () async {
      await expectLater(
        v1(
          (_) async => http.Response('x' * 50, 200),
          limits: CloudReadLimits(responseBytes: 49),
        ).read(cancellation: CloudCancellation()),
        fails(CloudFailureKind.responseTooLarge),
      );
    });
    test('pre-cancelled operation never creates a client', () async {
      var calls = 0;
      final cancel = CloudCancellation()..cancel();
      await expectLater(
        v1((_) async {
          calls++;
          return http.Response('', 200);
        }).read(cancellation: cancel),
        fails(CloudFailureKind.cancelled),
      );
      expect(calls, 0);
    });
    test(
      'cancel fences late response and does not affect another account',
      () async {
        final late = Completer<http.Response>();
        final started = Completer<void>();
        final cancel = CloudCancellation();
        final pending = v1((_) {
          started.complete();
          return late.future;
        }).read(cancellation: cancel);
        final assertion = expectLater(
          pending,
          fails(CloudFailureKind.cancelled),
        );
        await started.future;
        cancel.cancel();
        await assertion;
        final other = await v2(minimalV2)
            .read(cancellation: CloudCancellation());
        expect(other.remoteAccountId, 12);
        late.complete(http.Response(fixture('v1-status-online.xml'), 200));
        await Future<void>.delayed(const Duration(milliseconds: 5));
      },
    );
    test(
      'timeout includes connection and late completion is consumed',
      () async {
        final late = Completer<http.Response>();
        await expectLater(
          v1(
            (_) => late.future,
            limits: CloudReadLimits(
              requestTimeout: const Duration(milliseconds: 20),
            ),
          ).read(cancellation: CloudCancellation()),
          fails(CloudFailureKind.timeout),
        );
        late.complete(http.Response(fixture('v1-status-online.xml'), 200));
        await Future<void>.delayed(const Duration(milliseconds: 5));
      },
    );
    test('global page, item, and byte caps reject entire discovery', () async {
      await expectLater(
        v2(
          minimalV2,
          limits: CloudReadLimits(pages: 1),
        ).read(cancellation: CloudCancellation()),
        fails(CloudFailureKind.inventoryTooLarge),
      );
      await expectLater(
        v2(
          (request) async => http.Response(
            jsonEncode(
              request.url.path == '/api/v1/account'
                  ? {
                      'data': {'id': 12},
                    }
                  : {
                      'data': [
                        {'id': 7},
                        {'id': 8},
                      ],
                    },
            ),
            200,
          ),
          limits: CloudReadLimits(items: 1),
        ).read(cancellation: CloudCancellation()),
        fails(CloudFailureKind.inventoryTooLarge),
      );
      await expectLater(
        v2(
          minimalV2,
          limits: CloudReadLimits(totalBytes: 22),
        ).read(cancellation: CloudCancellation()),
        fails(CloudFailureKind.responseTooLarge),
      );
    });
    test('overall budget bounds individually fast endless pages', () async {
      await expectLater(
        v2(
          (request) async {
            await Future<void>.delayed(const Duration(milliseconds: 12));
            return http.Response(
              jsonEncode(
                request.url.path == '/api/v1/account'
                    ? {
                        'data': {'id': 12},
                      }
                    : {
                        'data': [],
                        'links': {
                          'next':
                              '?page=${int.parse(request.url.queryParameters['page']!) + 1}',
                        },
                      },
              ),
              200,
            );
          },
          limits: CloudReadLimits(
            requestTimeout: const Duration(seconds: 1),
            operationTimeout: const Duration(milliseconds: 45),
          ),
        ).read(cancellation: CloudCancellation()),
        fails(CloudFailureKind.timeout),
      );
    });
  });
}
