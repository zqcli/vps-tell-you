import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

/// Channel/transport completion can precede delivery of queued stream events.
/// Keep both decoders alive until EOF, unless the owner explicitly cancels.
class SshSessionOutput {
  SshSessionOutput(
    Stream<Uint8List> stdout,
    Stream<Uint8List> stderr, {
    required void Function(String) onData,
  }) {
    for (final stream in [stdout, stderr]) {
      _subscriptions.add(
        stream
            .cast<List<int>>()
            .transform(const Utf8Decoder(allowMalformed: true))
            .listen(
              (text) {
                if (!_cancelled) onData(text);
              },
              // The owner observes SSH session/transport errors separately.
              // An error event alone does not mean this stream reached EOF.
              onError: (Object _) {},
              onDone: () {
                if (++_finished == 2 && !_done.isCompleted) _done.complete();
              },
            ),
      );
    }
  }

  final _subscriptions = <StreamSubscription<String>>[];
  final _done = Completer<void>();
  bool _cancelled = false;
  int _finished = 0;

  Future<void> get done => _done.future;

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
    if (!_done.isCompleted) _done.complete();
  }
}
