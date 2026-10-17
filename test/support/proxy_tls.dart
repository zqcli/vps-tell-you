import 'dart:io';

/// Throw-away TLS material for the HTTPS-proxy tests, generated with the
/// system `openssl` into a temp directory on every run. Nothing is committed:
/// the repo ignores `*.pem` / `*.key`, and keys in a public repo would trip
/// secret scanners. The 30-day leaf also satisfies Apple's 398-day limit.
class ProxyTls {
  ProxyTls._(this.serverContext, this._caPath, this._otherCaPath);

  /// Server side: a leaf for 127.0.0.1 / localhost / ::1 signed by the test CA.
  final SecurityContext serverContext;
  final String _caPath, _otherCaPath;

  /// Trust roots for a client that accepts only the test CA.
  SecurityContext trustTestCa() =>
      SecurityContext(withTrustedRoots: false)..setTrustedCertificates(_caPath);

  /// Trust roots that do not include the issuer of the server certificate.
  SecurityContext trustOtherCa() =>
      SecurityContext(withTrustedRoots: false)
        ..setTrustedCertificates(_otherCaPath);

  static Future<ProxyTls> load() async {
    final temp = await Directory.systemTemp.createTemp('proxy-tls-');
    String path(String name) => '${temp.path}/$name';
    Future<void> run(List<String> args) async {
      final result = await Process.run(
        'openssl',
        args,
        workingDirectory: temp.path,
      );
      if (result.exitCode != 0) {
        throw StateError('openssl ${args.first} failed: ${result.stderr}');
      }
    }

    await File(path('leaf.ext')).writeAsString(
      'basicConstraints=CA:FALSE\n'
      'keyUsage=critical,digitalSignature,keyEncipherment\n'
      'extendedKeyUsage=serverAuth\n'
      'subjectAltName=DNS:localhost,IP:127.0.0.1,IP:::1\n',
    );
    for (final ca in ['ca', 'other_ca']) {
      await run([
        'req', '-x509', '-newkey', 'rsa:2048', '-nodes', //
        '-keyout', '$ca.key', '-out', '$ca.pem', '-days', '30',
        '-subj', '/CN=VPS Tell You test $ca',
        '-addext', 'basicConstraints=critical,CA:TRUE',
        '-addext', 'keyUsage=critical,keyCertSign,cRLSign',
      ]);
    }
    await run([
      'req', '-new', '-newkey', 'rsa:2048', '-nodes', //
      '-keyout', 'server.key', '-subj', '/CN=127.0.0.1', '-out', 'leaf.csr',
    ]);
    await run([
      'x509', '-req', '-in', 'leaf.csr', '-CA', 'ca.pem', '-CAkey', 'ca.key',
      '-CAcreateserial', '-out', 'leaf.pem', '-days', '30', //
      '-extfile', 'leaf.ext',
    ]);
    final server = SecurityContext(withTrustedRoots: false)
      ..useCertificateChain(path('leaf.pem'))
      ..usePrivateKey(path('server.key'));
    return ProxyTls._(server, path('ca.pem'), path('other_ca.pem'));
  }
}
