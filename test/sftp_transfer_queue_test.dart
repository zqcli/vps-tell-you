import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vps_tell_you/connections/sftp_session.dart';
import 'package:vps_tell_you/connections/sftp_support.dart';

import 'support/fake_sftp_session.dart';

class _UnknownSizeDownload extends FakeSftpSession {
  @override
  Future<void> download(
    String remotePath,
    File localFile, {
    bool overwrite = false,
    SftpProgress? onProgress,
    SftpCancelToken? cancel,
  }) async {
    for (var done = 1; done <= 1000; done++) {
      onProgress?.call(done, null);
    }
    await localFile.writeAsBytes(List.filled(1000, 1));
  }
}

void main() {
  test(
    'unknown-size progress is throttled and still publishes completion',
    () async {
      final directory = await Directory.systemTemp.createTemp('sftp-progress-');
      final finished = Completer<void>();
      final queue = SftpTransferQueue(
        session: _UnknownSizeDownload(),
        local: FakeLocalFiles(directory),
        resolveConflict: (_) async => false,
        onFinished: (_) => finished.complete(),
      );
      addTearDown(() async {
        await queue.shutdown();
        queue.dispose();
        await directory.delete(recursive: true);
      });
      var notifications = 0;
      queue.addListener(() => notifications++);
      final item = queue.enqueueDownload(
        const SftpEntry(
          name: 'unknown.bin',
          path: '/unknown.bin',
          isDir: false,
          isFile: true,
          isLink: false,
          size: null,
          mtime: null,
          mode: '',
        ),
      );
      await finished.future;
      expect(
        notifications,
        lessThan(20),
        reason: 'one tick per burst, not per chunk',
      );
      expect(item.state, SftpTransferState.done);
      expect(item.done, 1000);
      expect(item.total, isNull);
      expect(await File(item.savedPath!).length(), 1000);
    },
  );
}
