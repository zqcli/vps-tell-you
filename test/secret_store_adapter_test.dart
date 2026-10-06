import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vps_tell_you/security/secret_store.dart';
import 'package:vps_tell_you/security/security_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test(
    'adapter explicitly disables Android reset and redacts native failures',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      Map<Object?, Object?>? arguments;
      messenger.setMockMethodCallHandler(channel, (call) async {
        arguments = call.arguments as Map<Object?, Object?>;
        throw PlatformException(
          code: 'synthetic',
          message: 'SECRET-MUST-NOT-LEAK',
        );
      });
      final store = NativeSecretStore();
      await expectLater(
        store.write('synthetic-reference', 'synthetic-value'),
        throwsA(
          isA<SecurityFailure>().having(
            (e) => e.toString(),
            'redaction',
            isNot(contains('SECRET')),
          ),
        ),
      );
      final options = arguments!['options'] as Map<Object?, Object?>;
      expect(options['resetOnError'], 'false');
    },
  );

  test(
    'iOS items are local-only and accessible on unlocked original device',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      Map<Object?, Object?>? arguments;
      messenger.setMockMethodCallHandler(channel, (call) async {
        arguments = call.arguments as Map<Object?, Object?>;
        return null;
      });
      expect(await NativeSecretStore().read('synthetic-reference'), isNull);
      final options = arguments!['options'] as Map<Object?, Object?>;
      expect(options['synchronizable'], 'false');
      expect(options['accessibility'], 'unlocked_this_device');
    },
  );

  test('timed-out write stays serialized before cleanup so late write cannot resurrect an orphan', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final writeBarrier = Completer<void>();
    final events = <String>[];
    final values = <String, String>{};
    messenger.setMockMethodCallHandler(channel, (call) async {
      final arguments = call.arguments as Map<Object?, Object?>;
      final key = arguments['key'] as String;
      if (call.method == 'write') {
        events.add('write-start');
        await writeBarrier.future;
        values[key] = arguments['value'] as String;
        events.add('write-done');
      } else if (call.method == 'delete') {
        events.add('delete');
        values.remove(key);
      }
      return null;
    });
    final store = NativeSecretStore(timeout: const Duration(milliseconds: 10));
    await expectLater(
      store.write('synthetic-reference', 'synthetic-value'),
      throwsA(isA<SecurityFailure>()),
    );
    await expectLater(
      store.delete('synthetic-reference'),
      throwsA(isA<SecurityFailure>()),
    );
    expect(events, ['write-start']);
    writeBarrier.complete();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(events, ['write-start', 'write-done', 'delete']);
    expect(values, isEmpty);
    await store.delete('synthetic-reference');
    expect(values, isEmpty);
  });
}
