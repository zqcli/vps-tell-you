import 'dart:io';

/// TLS material for the HTTPS-proxy tests; see test/fixtures/proxy_tls/README.md.
class ProxyTls {
  ProxyTls._(this.serverContext, this._caPath, this._otherCaPath);

  /// Server side: a leaf for 127.0.0.1 / localhost / ::1 signed by the test CA.
  final SecurityContext serverContext;
  final String _caPath, _otherCaPath;

  static const _dir = 'test/fixtures/proxy_tls';

  /// Trust roots for a client that accepts only the test CA.
  SecurityContext trustTestCa() =>
      SecurityContext(withTrustedRoots: false)..setTrustedCertificates(_caPath);

  /// Trust roots that do not include the issuer of the server certificate.
  SecurityContext trustOtherCa() =>
      SecurityContext(withTrustedRoots: false)
        ..setTrustedCertificates(_otherCaPath);

  static Future<ProxyTls> load() async {
    var cert = '$_dir/server.pem';
    if (Platform.isMacOS || Platform.isIOS) {
      // Security.framework refuses TLS server certificates valid for more than
      // 398 days, so sign a short-lived leaf for this run.
      final temp = await Directory.systemTemp.createTemp('proxy-tls-');
      for (final name in ['ca.pem', 'ca.key', 'leaf.ext', 'server.key']) {
        await File('$_dir/$name').copy('${temp.path}/$name');
      }
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

      await run([
        'req', '-new', '-key', 'server.key', '-subj', '/CN=127.0.0.1',
        '-out', 'leaf.csr', //
      ]);
      await run([
        'x509', '-req', '-in', 'leaf.csr', '-CA', 'ca.pem', '-CAkey', 'ca.key',
        '-CAcreateserial', '-out', 'leaf.pem', '-days', '30', //
        '-extfile', 'leaf.ext',
      ]);
      cert = '${temp.path}/leaf.pem';
    }
    final server = SecurityContext(withTrustedRoots: false)
      ..useCertificateChain(cert)
      ..usePrivateKey('$_dir/server.key');
    return ProxyTls._(server, '$_dir/ca.pem', '$_dir/other_ca.pem');
  }
}
