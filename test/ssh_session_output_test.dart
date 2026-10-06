import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vps_tell_you/connections/ssh_session_output.dart';

Uint8List _bytes(String text) => Uint8List.fromList(utf8.encode(text));

void main() {
  test(
    'close signal cannot discard queued final output or split UTF-8',
    () async {
      final stdout = StreamController<Uint8List>();
      final stderr = StreamController<Uint8List>();
      final received = StringBuffer();
      final output = SshSessionOutput(
        stdout.stream,
        stderr.stream,
        onData: received.write,
      );
      var drained = false;
      unawaited(output.done.then((_) => drained = true));
      final remoteClosed = Completer<void>();
      const stderrText = 'fixture-final-stderr\r\n';
      final stdoutText = '${'f' * 65536}fixture-final-你好\r\n';

      // Like SSHSession's asynchronous controllers, these already hold bytes
      // when a separate channel/transport completion signal becomes observable.
      stdout.add(_bytes('f' * 32768));
      stdout.add(_bytes('f' * 32768));
      stdout.add(_bytes('fixture-final-'));
      stdout.add(Uint8List.fromList([0xe4]));
      stdout.add(Uint8List.fromList([0xbd, 0xa0, 0xe5]));
      stdout.add(Uint8List.fromList([0xa5, 0xbd, 0x0d, 0x0a]));
      stderr.add(_bytes(stderrText));
      final stdoutClosed = stdout.close();
      final stderrClosed = stderr.close();
      remoteClosed.complete();

      await remoteClosed.future;
      expect(drained, isFalse);
      expect(received.length, lessThan(stdoutText.length + stderrText.length));
      await output.done;
      expect(drained, isTrue);
      final text = received.toString();
      expect(stderrText.allMatches(text), hasLength(1));
      // stdout/stderr have independent queues and may interleave. Removing the
      // one exact stderr event still requires every stdout character in order.
      expect(text.replaceFirst(stderrText, ''), stdoutText);
      expect(text.length, stdoutText.length + stderrText.length);
      expect(text, isNot(contains('\uFFFD')));
      await Future.wait([stdoutClosed, stderrClosed]);
      output.cancel();
    },
  );

  test('completion waits for both stream EOFs', () async {
    final stdout = StreamController<Uint8List>();
    final stderr = StreamController<Uint8List>();
    final received = StringBuffer();
    final output = SshSessionOutput(
      stdout.stream,
      stderr.stream,
      onData: received.write,
    );
    var drained = false;
    unawaited(output.done.then((_) => drained = true));

    stdout.add(_bytes('stdout finished'));
    await stdout.close();
    expect(drained, isFalse);
    stderr.add(_bytes('stderr tail'));
    await stderr.close();
    await output.done;
    expect(received.toString(), 'stdout finishedstderr tail');
    expect(drained, isTrue);
    output.cancel();
  });

  test(
    'a stream error does not finish draining before later data and EOF',
    () async {
      final stdout = StreamController<Uint8List>();
      final stderr = StreamController<Uint8List>();
      final received = StringBuffer();
      final laterData = Completer<void>();
      final output = SshSessionOutput(
        stdout.stream,
        stderr.stream,
        onData: (text) {
          received.write(text);
          if (text == 'after error') laterData.complete();
        },
      );
      var drained = false;
      unawaited(output.done.then((_) => drained = true));

      stdout.addError(StateError('synthetic recoverable stream error'));
      stdout.add(_bytes('after error'));
      await stderr.close();
      await laterData.future;
      expect(drained, isFalse);
      stdout.add(_bytes(' and final bytes'));
      await stdout.close();
      await output.done;
      expect(received.toString(), 'after error and final bytes');
      expect(drained, isTrue);
      output.cancel();
    },
  );

  test(
    'stdout and stderr keep independent incremental UTF-8 decoders',
    () async {
      final stdout = StreamController<Uint8List>();
      final stderr = StreamController<Uint8List>();
      final received = <String>[];
      final output = SshSessionOutput(
        stdout.stream,
        stderr.stream,
        onData: received.add,
      );

      stdout.add(Uint8List.fromList([0xe4]));
      stderr.add(Uint8List.fromList([0xe5]));
      stdout.add(Uint8List.fromList([0xbd, 0xa0]));
      stderr.add(Uint8List.fromList([0xa5, 0xbd]));
      await Future.wait([stdout.close(), stderr.close()]);
      await output.done;
      expect(received, unorderedEquals(['你', '好']));
      output.cancel();
    },
  );

  test(
    'explicit cancellation releases open streams and discards late output',
    () async {
      final stdout = StreamController<Uint8List>();
      final stderr = StreamController<Uint8List>();
      final received = StringBuffer();
      final output = SshSessionOutput(
        stdout.stream,
        stderr.stream,
        onData: received.write,
      );

      stdout.add(_bytes('queued stdout'));
      stderr.add(_bytes('queued stderr'));
      output.cancel();
      output.cancel();
      await output.done;
      expect(received.isEmpty, isTrue);

      stdout.add(_bytes('late stdout'));
      stderr.add(_bytes('late stderr'));
      await Future.wait([stdout.close(), stderr.close()]);
      expect(received.isEmpty, isTrue);
    },
  );
}
