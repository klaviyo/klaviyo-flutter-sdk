import 'dart:async';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klaviyo_flutter_sdk/klaviyo_flutter_sdk.dart';
import 'package:klaviyo_flutter_sdk/src/services/background_silent_push.dart';

final List<Map<String, dynamic>> _received = [];
Completer<void>? _gate;

@pragma('vm:entry-point')
Future<void> _recordingHandler(Map<String, dynamic> data) async {
  _received.add(data);
  await _gate?.future;
}

@pragma('vm:entry-point')
Future<void> _throwingHandler(Map<String, dynamic> data) async {
  throw StateError('boom');
}

class _Handlers {
  @pragma('vm:entry-point')
  static Future<void> staticHandler(Map<String, dynamic> data) async {
    _received.add({'static': true, ...data});
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methodChannel = MethodChannel('klaviyo_sdk');
  const eventChannel = EventChannel('klaviyo_events');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final List<MethodCall> log = [];

  /// Delivers [call] to Dart on the background channel the way native code
  /// does, and returns the decoded reply envelope.
  Future<Object?> invokeFromNative(MethodCall call) async {
    const codec = StandardMethodCodec();
    final reply = await messenger.handlePlatformMessage(
      klaviyoBackgroundChannel.name,
      codec.encodeMethodCall(call),
      null,
    );
    return codec.decodeEnvelope(reply!);
  }

  setUp(() {
    log.clear();
    _received.clear();
    _gate = null;
    messenger.setMockMethodCallHandler(methodChannel, (call) async {
      log.add(call);
      return null;
    });
    messenger.setMockStreamHandler(
      eventChannel,
      MockStreamHandler.inline(onListen: (_, __) {}, onCancel: (_) {}),
    );
  });

  tearDown(() {
    resetBackgroundSilentPushHandler();
    messenger.setMockMethodCallHandler(methodChannel, null);
    messenger.setMockStreamHandler(eventChannel, null);
  });

  group('KlaviyoSDK.onBackgroundSilentPush registration', () {
    test('sends both callback handles to native', () async {
      await KlaviyoSDK.onBackgroundSilentPush(_recordingHandler);

      final call = log.singleWhere(
        (c) => c.method == 'registerBackgroundSilentPushHandler',
      );
      final args = call.arguments as Map;
      expect(
        args['handlerHandle'],
        PluginUtilities.getCallbackHandle(_recordingHandler)!.toRawHandle(),
      );
      expect(
        args['dispatcherHandle'],
        PluginUtilities.getCallbackHandle(
          klaviyoBackgroundSilentPushDispatcher,
        )!
            .toRawHandle(),
      );
    });

    test('accepts a static method', () async {
      await KlaviyoSDK.onBackgroundSilentPush(_Handlers.staticHandler);
      expect(
        log.where((c) => c.method == 'registerBackgroundSilentPushHandler'),
        hasLength(1),
      );
    });

    test('rejects a closure without calling native', () async {
      Future<void> closure(Map<String, dynamic> data) async {}

      await expectLater(
        KlaviyoSDK.onBackgroundSilentPush(closure),
        throwsArgumentError,
      );
      expect(log, isEmpty);
    });

    test('does not require initialize()', () async {
      expect(KlaviyoSDK().isInitialized, isFalse);
      await KlaviyoSDK.onBackgroundSilentPush(_recordingHandler);
      expect(log.map((c) => c.method), ['registerBackgroundSilentPushHandler']);
    });

    test('wraps a native failure in KlaviyoException', () async {
      messenger.setMockMethodCallHandler(methodChannel, (call) async {
        throw PlatformException(code: 'ERR');
      });

      await expectLater(
        KlaviyoSDK.onBackgroundSilentPush(_recordingHandler),
        throwsA(isA<KlaviyoException>()),
      );
    });
  });

  group('background channel dispatch', () {
    test('passes the payload to the registered handler', () async {
      await KlaviyoSDK.onBackgroundSilentPush(_recordingHandler);

      final result = await invokeFromNative(
        const MethodCall('handleBackgroundSilentPush', {
          'data': {
            '_k': {'c': 'abc'},
            'key_value_pairs': {'foo': 'bar'},
            'list': [
              {'nested': 1},
            ],
          },
        }),
      );

      expect(result, isNull);
      expect(_received, hasLength(1));
      final data = _received.single;
      expect(data['_k'], {'c': 'abc'});
      expect(data['key_value_pairs'], isA<Map<String, dynamic>>());
      expect(data['list'], [
        {'nested': 1},
      ]);
    });

    test('replies only after the handler future completes', () async {
      await KlaviyoSDK.onBackgroundSilentPush(_recordingHandler);
      _gate = Completer<void>();

      var replied = false;
      final reply = invokeFromNative(
        const MethodCall('handleBackgroundSilentPush', {'data': {}}),
      ).then((_) => replied = true);

      await Future<void>.delayed(Duration.zero);
      expect(_received, hasLength(1));
      expect(replied, isFalse);

      _gate!.complete();
      await reply;
      expect(replied, isTrue);
    });

    test('resolves the handler from handlerHandle when none is registered',
        () async {
      klaviyoBackgroundChannel
          .setMethodCallHandler(handleBackgroundChannelCall);
      final rawHandle =
          PluginUtilities.getCallbackHandle(_recordingHandler)!.toRawHandle();

      await invokeFromNative(
        MethodCall('handleBackgroundSilentPush', {
          'data': {'a': '1'},
          'handlerHandle': rawHandle,
        }),
      );

      expect(_received, [
        {'a': '1'},
      ]);
    });

    test('reports NO_HANDLER when nothing can be resolved', () async {
      klaviyoBackgroundChannel
          .setMethodCallHandler(handleBackgroundChannelCall);

      await expectLater(
        invokeFromNative(
          const MethodCall('handleBackgroundSilentPush', {'data': {}}),
        ),
        throwsA(
          isA<PlatformException>().having((e) => e.code, 'code', 'NO_HANDLER'),
        ),
      );
    });

    test('reports HANDLER_ERROR when the handler throws', () async {
      await KlaviyoSDK.onBackgroundSilentPush(_throwingHandler);

      await expectLater(
        invokeFromNative(
          const MethodCall('handleBackgroundSilentPush', {'data': {}}),
        ),
        throwsA(
          isA<PlatformException>()
              .having((e) => e.code, 'code', 'HANDLER_ERROR'),
        ),
      );
    });

    test('initializes the SDK with apiKey before running the handler',
        () async {
      await KlaviyoSDK.onBackgroundSilentPush(_recordingHandler);
      log.clear();

      await invokeFromNative(
        const MethodCall('handleBackgroundSilentPush', {
          'data': {},
          'apiKey': 'ABC123',
        }),
      );

      expect(log.map((c) => c.method), contains('initialize'));
      expect(
        (log.firstWhere((c) => c.method == 'initialize').arguments
            as Map)['apiKey'],
        'ABC123',
      );
      expect(_received, hasLength(1));
      expect(KlaviyoSDK().isInitialized, isTrue);
    });

    test('rejects unknown methods', () async {
      await KlaviyoSDK.onBackgroundSilentPush(_recordingHandler);

      final codec = const StandardMethodCodec();
      final reply = await messenger.handlePlatformMessage(
        klaviyoBackgroundChannel.name,
        codec.encodeMethodCall(const MethodCall('somethingElse')),
        null,
      );
      expect(reply, isNull);
    });
  });

  group('routing contract', () {
    test('a background push never reaches onPushNotification', () async {
      await KlaviyoSDK.onBackgroundSilentPush(_recordingHandler);
      final streamEvents = <Map<String, dynamic>>[];
      final sub = KlaviyoSDK().onPushNotification.listen(streamEvents.add);

      await invokeFromNative(
        const MethodCall('handleBackgroundSilentPush', {
          'data': {'k': 'v'},
        }),
      );
      await Future<void>.delayed(Duration.zero);

      expect(_received, hasLength(1));
      expect(streamEvents, isEmpty);
      await sub.cancel();
    });

    test('the dispatcher announces itself on the background channel', () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(klaviyoBackgroundChannel,
          (call) async {
        calls.add(call);
        return null;
      });

      klaviyoBackgroundSilentPushDispatcher();
      await Future<void>.delayed(Duration.zero);

      expect(calls.map((c) => c.method), ['backgroundDispatcherInitialized']);
      messenger.setMockMethodCallHandler(klaviyoBackgroundChannel, null);
    });
  });
}
