import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/cloud/cloud_controller.dart';
import 'package:vps_tell_you/cloud/cloud_models.dart';
import 'package:vps_tell_you/cloud/cloud_provider_definition.dart';
import 'package:vps_tell_you/cloud/solusvm_adapter.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/l10n/generated/app_localizations_en.dart';
import 'package:vps_tell_you/l10n/generated/app_localizations_zh.dart';

import 'cloud_controller_test.dart' show CallbackCloudAdapter, CloudTestSecrets;

const _key = 'SYNTHETIC+KEY/&=';
const _hash = 'SYNTHETIC+HASH/&=';
const _token = 'SYNTHETIC_TOKEN';
// Handwritten old envelopes, independent of the definition's encoder.
const _oldEnvelopes = {
  CloudProvider.solusVm1: '{"version":1,"provider":"solusVm1","key":"SYNTHETIC+KEY/&=","hash":"SYNTHETIC+HASH/&="}',
  CloudProvider.solusVm2:
      '{"version":1,"provider":"solusVm2","token":"SYNTHETIC_TOKEN"}',
  CloudProvider.rackNerd: '{"version":1,"provider":"rackNerd","key":"SYNTHETIC+KEY/&=","hash":"SYNTHETIC+HASH/&="}',
};
final _at = DateTime.utc(2026, 10, 6);
final _endpoint = CloudEndpoint.parse('https://panel.example.test:8443');

CloudCredentials _credentials(CloudProvider provider) => switch (provider) {
  CloudProvider.solusVm1 => SolusVm1Credentials(key: _key, hash: _hash),
  CloudProvider.solusVm2 => SolusVm2Credentials(_token),
  CloudProvider.rackNerd => RackNerdCredentials(key: _key, hash: _hash),
};
Matcher _invalidCredentials = throwsA(
  isA<CloudFailure>()
      .having((e) => e.kind, 'kind', CloudFailureKind.invalidCredentials)
      .having((e) => e.toString(), 'no key', isNot(contains(_key)))
      .having((e) => e.toString(), 'no hash', isNot(contains(_hash)))
      .having((e) => e.toString(), 'no token', isNot(contains(_token))),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  test(
    'closed definitions preserve names, forms and locale-dependent copy',
    () {
      final en = AppLocalizationsEn();
      final zh = AppLocalizationsZh();
      final expected = [
        (
          CloudProvider.solusVm1,
          'SolusVM 1',
          CloudCredentialKind.keyHash,
          'https://panel.example.com:5656',
        ),
        (
          CloudProvider.solusVm2,
          'SolusVM 2',
          CloudCredentialKind.token,
          'https://panel.example.com',
        ),
        (
          CloudProvider.rackNerd,
          'RackNerd ctrl',
          CloudCredentialKind.keyHash,
          'https://panel.example.com',
        ),
      ];
      expect(expected.map((row) => row.$1), CloudProvider.values);
      for (final (provider, name, kind, hint) in expected) {
        final definition = CloudProviderDefinition.of(provider);
        expect(definition.provider, provider);
        expect(definition.displayName, name);
        expect(definition.credentialKind, kind);
        expect(definition.endpointHint, hint);
        for (final l10n in [en, zh, en]) {
          final (
            template,
            validation,
            endpointInfo,
            credentialsInfo,
            resources,
          ) = switch (provider) {
            CloudProvider.solusVm1 => (
              l10n.cloudV1TemplateInfo,
              l10n.cloudEndpointValidation,
              l10n.cloudEndpointInfo,
              l10n.cloudV1CredentialsInfo,
              l10n.cloudV1ResourcesInfo,
            ),
            CloudProvider.solusVm2 => (
              l10n.cloudV2TemplateInfo,
              l10n.cloudEndpointValidation,
              l10n.cloudEndpointInfo,
              l10n.cloudV2CredentialsInfo,
              null,
            ),
            CloudProvider.rackNerd => (
              l10n.cloudRackNerdTemplateInfo,
              l10n.cloudRackNerdEndpointValidation,
              l10n.cloudRackNerdEndpointInfo,
              l10n.cloudRackNerdCredentialsInfo,
              l10n.cloudRackNerdResourcesInfo,
            ),
          };
          expect(definition.templateInfo(l10n), template);
          expect(definition.endpointValidation(l10n), validation);
          expect(definition.endpointInfo(l10n), endpointInfo);
          expect(definition.credentialsInfo(l10n), credentialsInfo);
          expect(definition.resourceCompletionInfo(l10n), resources);
        }
      }
    },
  );

  test('shared KeyHash validation retains distinct public nominal types', () {
    final v1 = SolusVm1Credentials(key: _key, hash: _hash);
    final rack = RackNerdCredentials(key: _key, hash: _hash);
    expect(v1, isA<KeyHashCredentials>());
    expect(rack, isA<KeyHashCredentials>());
    expect(rack, isNot(isA<SolusVm1Credentials>()));
    expect(v1, isNot(isA<RackNerdCredentials>()));
    for (final provider in [CloudProvider.solusVm1, CloudProvider.rackNerd]) {
      final definition = CloudProviderDefinition.of(provider);
      for (final value in [
        '',
        ' $_key',
        '$_key ',
        '$_key\n',
        '\x7f',
        'x' * 8193,
      ]) {
        expect(
          () => definition.createCredentials(key: value, hash: _hash),
          _invalidCredentials,
        );
        expect(
          () => definition.createCredentials(key: _key, hash: value),
          _invalidCredentials,
        );
      }
      final credentials = definition.createCredentials(
        key: 'x' * 8192,
        hash: 'internal space',
      ) as KeyHashCredentials;
      expect(credentials.key.length, 8192);
      expect(credentials.hash, 'internal space');
      expect(credentials.toString(), isNot(contains('internal space')));
    }
    expect(
      () =>
          CloudProviderDefinition.of(CloudProvider.solusVm2)
              .createCredentials(token: 'with space'),
      _invalidCredentials,
    );
    expect(
      () =>
          CloudProviderDefinition.of(CloudProvider.rackNerd)
              .createCredentials(),
      _invalidCredentials,
    );
  });

  for (final provider in CloudProvider.values) {
    final definition = CloudProviderDefinition.of(provider);
    for (final credentialProvider in CloudProvider.values) {
      test(
        '${provider.name}/${credentialProvider.name}: validation, factory and encoding preserve identity',
        () {
          final credentials = _credentials(credentialProvider);
          var clients = 0;
          http.Client clientFactory() {
            clients++;
            return MockClient((_) async => http.Response('', 200));
          }

          if (provider == credentialProvider) {
            definition.validateCredentials(credentials);
            expect(
              definition.encodeCredentials(credentials),
              _oldEnvelopes[provider],
            );
            final adapter = definition.createAdapter(
              _endpoint,
              credentials,
              clientFactory: clientFactory,
            );
            // Compile-check the inherited public fields' original concrete types.
            switch (provider) {
              case CloudProvider.solusVm1:
                final typed = adapter as SolusVm1Adapter;
                final SolusVm1Credentials originalType = typed.credentials;
                expect(originalType, same(credentials));
                expect(typed.endpoint, same(_endpoint));
              case CloudProvider.solusVm2:
                final typed = adapter as SolusVm2Adapter;
                final SolusVm2Credentials originalType = typed.credentials;
                expect(originalType, same(credentials));
                expect(typed.endpoint, same(_endpoint));
              case CloudProvider.rackNerd:
                final typed = adapter as RackNerdAdapter;
                final RackNerdCredentials originalType = typed.credentials;
                expect(originalType, same(credentials));
                expect(typed.endpoint, same(_endpoint));
            }
          } else {
            expect(
              () => definition.validateCredentials(credentials),
              _invalidCredentials,
            );
            expect(
              () => definition.encodeCredentials(credentials),
              _invalidCredentials,
            );
            expect(
              () => definition.createAdapter(
                _endpoint,
                credentials,
                clientFactory: clientFactory,
              ),
              _invalidCredentials,
            );
          }
          expect(clients, 0);
        },
      );

      test(
        '${provider.name}/${credentialProvider.name}: controller rejects before injected factory or secret write',
        () async {
          final directory = await Directory.systemTemp.createTemp(
            'provider-definition-',
          );
          final store = await LedgerStore.open(
            factory: databaseFactoryFfiNoIsolate,
            path: '${directory.path}/ledger.sqlite',
          );
          final secrets = CloudTestSecrets();
          var calls = 0;
          final controller = CloudController(
            store: store,
            secrets: secrets,
            adapterFactory: (requested, _, _) {
              calls++;
              return CallbackCloudAdapter(
                (_) async => CloudSnapshot(
                  provider: requested,
                  completedAt: _at,
                  remoteAccountId: requested == CloudProvider.solusVm2
                      ? 7
                      : null,
                  instances: [
                    CloudInstance(
                      observedAt: _at,
                      power: CloudPower.running,
                      projectId: requested == CloudProvider.solusVm2
                          ? 11
                          : null,
                      serverId: requested == CloudProvider.solusVm2
                          ? 101
                          : null,
                    ),
                  ],
                ),
              );
            },
          );
          addTearDown(() async {
            controller.dispose();
            await store.close();
            await directory.delete(recursive: true);
          });
          expect(await controller.initialize(), isTrue);
          final verification = await controller.verifyConnection(
            provider: provider,
            endpoint: _endpoint.toString(),
            credentials: _credentials(credentialProvider),
          );
          if (provider == credentialProvider) {
            expect(verification, isNotNull);
            expect(calls, 1);
          } else {
            expect(verification, isNull);
            expect(calls, 0);
            expect(
              controller.localizedError,
              isA<CloudFailure>().having(
                (e) => e.kind,
                'kind',
                CloudFailureKind.invalidCredentials,
              ),
            );
          }
          expect(secrets.writes, 0);
        },
      );
    }

    test(
      '${provider.name}: handwritten old envelope and unchanged permissive extra fields',
      () {
        final raw = _oldEnvelopes[provider]!;
        final decoded = definition.decodeCredentials(raw);
        definition.validateCredentials(decoded);
        expect(definition.encodeCredentials(decoded), raw);
        final created = definition.createCredentials(
          key: _key,
          hash: _hash,
          token: _token,
        );
        expect(created.runtimeType, decoded.runtimeType);
        expect(definition.encodeCredentials(created), raw);
        expect(
          definition.encodeCredentials(
            definition.decodeCredentials(
              jsonEncode({
                ...jsonDecode(raw) as Map<String, dynamic>,
                'unknown': _key,
              }),
            ),
          ),
          raw,
        );
      },
    );

    test(
      '${provider.name}: malformed or cross-provider envelopes never reflect secrets',
      () {
        final correct =
            jsonDecode(_oldEnvelopes[provider]!) as Map<String, dynamic>;
        for (final other in CloudProvider.values.where(
          (other) => other != provider,
        )) {
          expect(
            () => definition.decodeCredentials(_oldEnvelopes[other]!),
            _invalidCredentials,
          );
        }
        for (final raw in [
          'broken JSON $_key $_hash $_token',
          'null',
          '[]',
          jsonEncode({...correct, 'version': 2}),
          jsonEncode({...correct, 'provider': null}),
          jsonEncode({'version': 1, 'provider': provider.name}),
          jsonEncode({
            ...correct,
            definition.credentialKind == CloudCredentialKind.keyHash
                    ? 'key'
                    : 'token':
                42,
          }),
          jsonEncode({
            ...correct,
            definition.credentialKind == CloudCredentialKind.keyHash
                    ? 'hash'
                    : 'token':
                null,
          }),
        ]) {
          expect(() => definition.decodeCredentials(raw), _invalidCredentials);
        }
      },
    );

    test(
      '${provider.name}: exact endpoint normalization matrix and strict persisted-origin parser',
      () {
        for (final input in [
          'https://PANEL.example.test:8443',
          'https://PANEL.example.test:8443/',
        ]) {
          final endpoint = definition.parseEndpoint(input);
          expect(endpoint.toString(), 'https://panel.example.test:8443');
          expect(endpoint.normalizedConsolePath, isFalse);
          expect(endpoint.normalizedApiPath, isFalse);
        }
        expect(
          definition.parseEndpoint('https://panel.example.test.').origin.host,
          'panel.example.test.',
        );
        for (final path in ['/home.php', '/api/client/command.php']) {
          final allowed =
              provider == CloudProvider.solusVm1 && path == '/home.php' ||
              provider == CloudProvider.rackNerd &&
                  path == '/api/client/command.php';
          final input = 'https://panel.example.test:8443$path';
          if (allowed) {
            final parsed = definition.parseEndpoint(input);
            expect(parsed.toString(), 'https://panel.example.test:8443');
            expect(
              parsed.normalizedConsolePath,
              provider == CloudProvider.solusVm1,
            );
            expect(
              parsed.normalizedApiPath,
              provider == CloudProvider.rackNerd,
            );
          } else {
            expect(
              () => definition.parseEndpoint(input),
              throwsA(
                isA<CloudFailure>().having(
                  (e) => e.kind,
                  'kind',
                  CloudFailureKind.invalidEndpoint,
                ),
              ),
            );
          }
          expect(
            () => CloudEndpoint.parse(input),
            throwsA(isA<CloudFailure>()),
          );
        }
        for (final input in [
          'http://panel.example.test',
          'https://user:$_key@panel.example.test',
          'https://panel.example.test?key=$_key',
          'https://panel.example.test#fragment',
          'https://panel.example.test/other',
          'https://panel.example.test/api/client/command.php/',
          'https://panel.example.test/api/client/command.php.',
          'https://panel.example.test/api/client/%63ommand.php',
          'https://panel.example.test/api/client/../client/command.php',
          'https://panel.example.test/home.php?key=$_key',
        ]) {
          expect(
            () => definition.parseEndpoint(input),
            throwsA(
              isA<CloudFailure>().having(
                (e) => e.kind,
                'kind',
                CloudFailureKind.invalidEndpoint,
              ),
            ),
          );
        }
      },
    );

    test(
      '${provider.name}: factory forwards client, clock and exact original wire protocol',
      () async {
        var clients = 0, requests = 0, clocks = 0;
        final paths = <String>[];
        final adapter = definition.createAdapter(
          _endpoint,
          _credentials(provider),
          clock: () {
            clocks++;
            return _at.toLocal();
          },
          clientFactory: () {
            clients++;
            return MockClient((request) async {
              requests++;
              paths.add(request.url.path);
              expect(request.url.host, 'panel.example.test');
              expect(request.url.port, 8443);
              expect(request.followRedirects, isFalse);
              expect(request.maxRedirects, 0);
              expect(request.headers.containsKey('user-agent'), isFalse);
              switch (provider) {
                case CloudProvider.solusVm1:
                  expect(request.method, 'POST');
                  expect(request.url.query, isEmpty);
                  expect(request.headers.containsKey('authorization'), isFalse);
                  expect(
                    request.headers['content-type'],
                    startsWith('multipart/form-data; boundary='),
                  );
                  expect(
                    RegExp('name="(.*?)"')
                        .allMatches(request.body)
                        .map((m) => m[1]),
                    [
                      'key',
                      'hash',
                      'action',
                      'ipaddr',
                      'mem',
                      'hdd',
                      'bw',
                      'status',
                    ],
                  );
                  expect(request.body, contains('\r\n\r\nstatus\r\n'));
                  expect(request.body, contains(_key));
                  expect(
                    RegExp(r'\r\n\r\ntrue\r\n').allMatches(request.body).length,
                    5,
                  );
                  return http.Response(
                    '<status>success</status><statusmsg>online</statusmsg>',
                    200,
                  );
                case CloudProvider.rackNerd:
                  expect(request.method, 'POST');
                  expect(request.url.query, isEmpty);
                  expect(request.headers.containsKey('authorization'), isFalse);
                  expect(
                    request.headers['content-type'],
                    startsWith('application/x-www-form-urlencoded'),
                  );
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
                  for (final encoding in ['%2B', '%26', '%3D']) {
                    expect(request.body, contains(encoding));
                  }
                  return http.Response(
                    '{"status":"success","statusmsg":"","vmstat":"online"}',
                    200,
                  );
                case CloudProvider.solusVm2:
                  expect(request.method, 'GET');
                  expect(request.body, isEmpty);
                  expect(request.headers['authorization'], 'Bearer $_token');
                  return switch (request.url.path) {
                    '/api/v1/account' => http.Response(
                      '{"data":{"id":7}}',
                      200,
                    ),
                    '/api/v1/projects' => http.Response(
                      '{"data":[{"id":11}]}',
                      200,
                    ),
                    '/api/v1/projects/11/servers' => http.Response(
                      '{"data":[{"id":101,"status":"started"}]}',
                      200,
                    ),
                    _ => throw StateError('Unexpected synthetic request'),
                  };
              }
            });
          },
        );
        final snapshot = await adapter.read(cancellation: CloudCancellation());
        expect(snapshot.provider, provider);
        expect(snapshot.completedAt, _at);
        expect(snapshot.completedAt.isUtc, isTrue);
        expect(snapshot.instances.single.observedAt, _at);
        expect(snapshot.instances.single.power, CloudPower.running);
        expect(requests, provider == CloudProvider.solusVm2 ? 3 : 1);
        expect(clients, requests);
        expect(clocks, provider == CloudProvider.solusVm2 ? 2 : 1);
        expect(
          paths,
          provider == CloudProvider.solusVm2
              ? [
                  '/api/v1/account',
                  '/api/v1/projects',
                  '/api/v1/projects/11/servers',
                ]
              : ['/api/client/command.php'],
        );
      },
    );

    test(
      '${provider.name}: factory forwards stricter custom response limit',
      () async {
        var requests = 0;
        final adapter = definition.createAdapter(
          _endpoint,
          _credentials(provider),
          limits: CloudReadLimits(responseBytes: 1),
          clientFactory: () => MockClient((_) async {
            requests++;
            return http.Response('oversized synthetic body', 200);
          }),
        );
        await expectLater(
          adapter.read(cancellation: CloudCancellation()),
          throwsA(
            isA<CloudFailure>().having(
              (e) => e.kind,
              'kind',
              CloudFailureKind.responseTooLarge,
            ),
          ),
        );
        expect(requests, 1);
      },
    );
  }
}
