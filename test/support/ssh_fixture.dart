import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:vps_tell_you/security/host_trust.dart';

/// An independent, loopback-only SSH server with a non-executing fake shell.
class SshFixture {
  SshFixture._(this.process) {
    process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
          final value = jsonDecode(line) as Map<String, dynamic>;
          events.add(value);
          _changes.add(null);
        });
    process.stderr.transform(utf8.decoder).listen(_stderr.write);
  }

  final Process process;
  final events = <Map<String, dynamic>>[];
  final _changes = StreamController<void>.broadcast();
  final _stderr = StringBuffer();
  var _closed = false;
  late int port;
  late String publicKey;

  static Future<SshFixture> start({
    String hostKey = 'ed25519.fixture',
    Duration delayAuth = Duration.zero,

    /// Enables the SFTP subsystem, confined to this existing directory.
    String? sftpRoot,
  }) async {
    final python = Platform.environment['VPS_SSH_FIXTURE_PYTHON'] ?? 'python3';
    final process = await Process.start(python, [
      '-u',
      'test/support/ssh_fixture/server.py',
      '--host-key',
      hostKey,
      '--delay-auth',
      '${delayAuth.inMilliseconds / 1000}',
      if (sftpRoot != null) ...['--sftp-root', sftpRoot],
    ]);
    final fixture = SshFixture._(process);
    try {
      final ready = await Future.any([
        fixture.waitFor('ready'),
        process.exitCode.then<Map<String, dynamic>>((code) async {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          throw StateError(
            'SSH fixture exited ($code). Install requirements from '
            'test/support/ssh_fixture/requirements.txt and set '
            'VPS_SSH_FIXTURE_PYTHON to that Python interpreter. '
            '${fixture._stderr}',
          );
        }),
      ]);
      fixture.port = ready['port'] as int;
      fixture.publicKey = ready['public_key'] as String;
      return fixture;
    } catch (_) {
      await fixture.close();
      rethrow;
    }
  }

  HostKeyIdentity get identity => HostKeyIdentity.validated(
    host: '127.0.0.1',
    port: port,
    algorithm: publicKey.split(' ').first,
    publicKey: publicKey,
  );

  List<Map<String, dynamic>> of(String kind) =>
      events.where((event) => event['event'] == kind).toList();

  Future<Map<String, dynamic>> waitFor(
    String kind, {
    bool Function(Map<String, dynamic>)? where,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    Map<String, dynamic>? find() {
      for (final event in events) {
        if (event['event'] == kind && (where == null || where(event))) {
          return event;
        }
      }
      return null;
    }

    final existing = find();
    if (existing != null) return existing;
    final value = Completer<Map<String, dynamic>>();
    final subscription = _changes.stream.listen((_) {
      final event = find();
      if (event != null && !value.isCompleted) value.complete(event);
    });
    try {
      return await value.future.timeout(timeout);
    } finally {
      await subscription.cancel();
    }
  }

  Future<void> disconnectClients() async {
    process.stdin.writeln(jsonEncode({'action': 'disconnect'}));
    await process.stdin.flush();
  }

  Future<void> finishWithOutput() async {
    process.stdin.writeln(jsonEncode({'action': 'finish'}));
    await process.stdin.flush();
  }

  Future<void> abortClients() async {
    process.stdin.writeln(jsonEncode({'action': 'abort'}));
    await process.stdin.flush();
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    try {
      process.stdin.writeln(jsonEncode({'action': 'stop'}));
      await process.stdin.flush();
      await process.stdin.close();
    } catch (_) {
      // A fixture startup error may have already closed stdin.
    }
    try {
      await process.exitCode.timeout(const Duration(seconds: 3));
    } on TimeoutException {
      process.kill();
      await process.exitCode;
    }
    await _changes.close();
  }
}

Future<void> eventually(
  bool Function() predicate, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!predicate()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('Condition did not become true', timeout);
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}
