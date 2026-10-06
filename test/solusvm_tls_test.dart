import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/io_client.dart';
import 'package:vps_tell_you/cloud/cloud_models.dart';
import 'package:vps_tell_you/cloud/solusvm_adapter.dart';

/// Ephemeral local HTTPS fixture only. No certificate or private key is checked
/// in, and production TLS behavior is never weakened with badCertificateCallback.
void main() {
  late Directory temporary;
  late SecurityContext trusted, serverContext;
  late HttpServer server;
  final requests = <({String method, Uri uri, String body, String? auth})>[];
  Future<void> Function(HttpRequest)? handler;

  setUpAll(() async {
    temporary = await Directory.systemTemp.createTemp('vps-solusvm-tls-');
    final cert = '${temporary.path}/localhost.crt';
    final key = '${temporary.path}/localhost.key';
    final created = await Process.run('openssl', [
      'req',
      '-x509',
      '-newkey',
      'rsa:2048',
      '-nodes',
      '-keyout',
      key,
      '-out',
      cert,
      '-days',
      '1',
      '-subj',
      '/CN=localhost',
      '-addext',
      'subjectAltName=DNS:localhost',
    ]);
    if (created.exitCode != 0) {
      throw StateError('Local TLS fixture certificate generation failed');
    }
    serverContext = SecurityContext()
      ..useCertificateChain(cert)
      ..usePrivateKey(key);
    trusted = SecurityContext(withTrustedRoots: false)
      ..setTrustedCertificates(cert);
  });
  tearDownAll(() => temporary.delete(recursive: true));
  setUp(() async {
    requests.clear();
    handler = null;
    server = await HttpServer.bindSecure(
      InternetAddress.loopbackIPv4,
      0,
      serverContext,
    );
    server.listen(
      (request) async {
        final body = await utf8.decoder.bind(request).join();
        requests.add((
          method: request.method,
          uri: request.uri,
          body: body,
          auth: request.headers.value(HttpHeaders.authorizationHeader),
        ));
        if (handler != null) {
          await handler!(request);
          return;
        }
        request.response.headers.contentType = ContentType(
          'text',
          'xml',
          charset: 'utf-8',
        );
        request.response.write(
          '<status>success</status><statusmsg>online</statusmsg>',
        );
        await request.response.close();
      },
      onError: (Object _) {
        /* Expected rejected TLS handshakes. */
      },
    );
  });
  tearDown(() => server.close(force: true));

  SolusVm1Adapter adapter({
    bool trustFixture = true,
    String host = 'localhost',
    CloudReadLimits? limits,
  }) => SolusVm1Adapter(
    endpoint: CloudEndpoint.parse('https://$host:${server.port}'),
    credentials: SolusVm1Credentials(
      key: 'SYNTHETIC_KEY',
      hash: 'SYNTHETIC_HASH',
    ),
    limits: limits,
    clientFactory: trustFixture
        ? () => IOClient(HttpClient(context: trusted))
        : null,
  );
  Matcher failure(CloudFailureKind kind) =>
      throwsA(isA<CloudFailure>().having((e) => e.kind, 'kind', kind));

  test(
    'native HTTPS validates local trust and sends exactly status multipart',
    () async {
      final result = await adapter().read(cancellation: CloudCancellation());
      expect(result.instances.single.power, CloudPower.running);
      expect(requests.length, 1);
      expect(requests.single.method, 'POST');
      expect(requests.single.uri.toString(), '/api/client/command.php');
      expect(requests.single.auth, null);
      expect(requests.single.body, contains('SYNTHETIC_KEY'));
      expect(requests.single.body, contains('name="action"\r\n\r\nstatus'));
    },
  );
  test('default native client rejects untrusted self-signed TLS without any API request', () async {
    await expectLater(
      adapter(trustFixture: false).read(cancellation: CloudCancellation()),
      failure(CloudFailureKind.connection),
    );
    expect(requests, isEmpty);
  });
  test(
    'trusted certificate still rejects wrong host without API request',
    () async {
      await expectLater(
        adapter(host: '127.0.0.1').read(cancellation: CloudCancellation()),
        failure(CloudFailureKind.connection),
      );
      expect(requests, isEmpty);
    },
  );
  test('native client does not follow redirect or leak credentials to second origin', () async {
    final other = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var forwarded = 0;
    other.listen((request) async {
      forwarded++;
      await request.response.close();
    });
    try {
      handler = (request) async {
        request.response.statusCode = 307;
        request.response.headers.set(
          HttpHeaders.locationHeader,
          'http://127.0.0.1:${other.port}/steal',
        );
        await request.response.close();
      };
      await expectLater(
        adapter().read(cancellation: CloudCancellation()),
        failure(CloudFailureKind.redirect),
      );
      expect(requests.length, 1);
      expect(forwarded, 0);
    } finally {
      await other.close(force: true);
    }
  });
  test(
    'chunked native response enforces V1 16 KiB bound before XML decoding',
    () async {
      handler = (request) async {
        request.response.write(
          '<status>success</status><statusmsg>online</statusmsg><unused>',
        );
        request.response.write('&' * 17000);
        request.response.write('</unused>');
        await request.response.close();
      };
      await expectLater(
        adapter().read(cancellation: CloudCancellation()),
        failure(CloudFailureKind.responseTooLarge),
      );
    },
  );
  test(
    'response body stall observes timeout and aborts native request',
    () async {
      final arrived = Completer<void>();
      handler = (request) async {
        request.response.write('<status>');
        await request.response.flush();
        arrived.complete();
        // Deliberately do not close; transport must stop the stream itself.
      };
      final pending = adapter(
        limits: CloudReadLimits(
          requestTimeout: const Duration(milliseconds: 300),
        ),
      ).read(cancellation: CloudCancellation());
      final assertion = expectLater(pending, failure(CloudFailureKind.timeout));
      await arrived.future;
      await assertion;
    },
  );
  test(
    'cancel after headers aborts body and never yields a snapshot',
    () async {
      final arrived = Completer<void>();
      handler = (request) async {
        request.response.write('<status>');
        await request.response.flush();
        arrived.complete();
      };
      final cancel = CloudCancellation();
      final pending = adapter().read(cancellation: cancel);
      final assertion = expectLater(
        pending,
        failure(CloudFailureKind.cancelled),
      );
      await arrived.future;
      cancel.cancel();
      await assertion;
    },
  );
  test('native V2 token stays in header with project GET allowlist', () async {
    handler = (request) async {
      final payload = switch (request.uri.path) {
        '/api/v1/account' => {
          'data': {'id': 12},
        },
        '/api/v1/projects' => {
          'data': [
            {'id': 7},
          ],
        },
        '/api/v1/projects/7/servers' => {
          'data': [
            {'id': 101},
          ],
        },
        _ => throw StateError('Unexpected path'),
      };
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(payload));
      await request.response.close();
    };
    final result = await SolusVm2Adapter(
      endpoint: CloudEndpoint.parse('https://localhost:${server.port}'),
      credentials: SolusVm2Credentials('SYNTHETIC_TOKEN'),
      clientFactory: () => IOClient(HttpClient(context: trusted)),
    ).read(cancellation: CloudCancellation());
    expect(result.instances.single.serverId, 101);
    expect(requests.length, 3);
    for (final request in requests) {
      expect(request.method, 'GET');
      expect(request.body, isEmpty);
      expect(request.auth, 'Bearer SYNTHETIC_TOKEN');
      expect(request.uri.toString(), isNot(contains('SYNTHETIC')));
    }
  });
}
