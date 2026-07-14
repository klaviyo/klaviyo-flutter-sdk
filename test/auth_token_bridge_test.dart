import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klaviyo_flutter_sdk/klaviyo_flutter_sdk.dart';
import 'package:logging/logging.dart';

/// End-to-end bridge test for the auth-token request/response flow.
///
/// The native `auth_token_requested` event is delivered through the shared
/// `klaviyo_events` EventChannel. The wrapper attaches that channel's listener
/// exactly once (on first `initialize`), so the whole flow is exercised within
/// a single test — this file runs in its own isolate, giving a fresh singleton.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methodChannel = MethodChannel('klaviyo_sdk');
  const eventChannel = EventChannel('klaviyo_events');

  final List<MethodCall> log = [];
  MockStreamHandlerEventSink? capturedSink;

  setUp(() {
    log.clear();
    capturedSink = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (call) async {
      log.add(call);
      return null;
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(
      eventChannel,
      MockStreamHandler.inline(
        onListen: (_, sink) => capturedSink = sink,
        onCancel: (_) {},
      ),
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(eventChannel, null);
  });

  MethodCall lastRespond() =>
      log.lastWhere((c) => c.method == 'respondToAuthTokenRequest');

  test('bridges provider outcomes back to native by correlation id', () async {
    final sdk = KlaviyoSDK();
    final logMessages = <String>[];
    Logger('KlaviyoSDK').onRecord.listen((r) => logMessages.add(r.message));

    await sdk.initialize(apiKey: 'KEY');
    await pumpEventQueue();
    expect(
      capturedSink,
      isNotNull,
      reason: 'event channel should be listening',
    );

    // --- Success path -------------------------------------------------------
    await sdk.registerAuthTokenProvider(() async => 'jwt-success');
    expect(log.any((c) => c.method == 'registerAuthTokenProvider'), isTrue);

    capturedSink!.success({
      'type': 'auth_token_requested',
      'data': {'id': 'req-1'},
    });
    await pumpEventQueue();

    final success = lastRespond();
    expect(success.arguments['id'], 'req-1');
    expect(success.arguments['jwt'], 'jwt-success');
    expect(success.arguments['isConnectivityError'], isFalse);

    // --- Connectivity failure path (re-register with a throwing provider) ---
    await sdk.registerAuthTokenProvider(
      () async => throw const SocketException('offline'),
    );
    // Re-registration must tear the native provider down first.
    expect(log.any((c) => c.method == 'unregisterAuthTokenProvider'), isTrue);

    capturedSink!.success({
      'type': 'auth_token_requested',
      'data': {'id': 'req-2'},
    });
    await pumpEventQueue();

    final failure = lastRespond();
    expect(failure.arguments['id'], 'req-2');
    expect(failure.arguments['jwt'], isNull);
    expect(failure.arguments['isConnectivityError'], isTrue);

    // --- Token contents are never logged on the Dart side -------------------
    expect(
      logMessages.every((m) => !m.contains('jwt-success')),
      isTrue,
      reason: 'token contents must never be logged',
    );

    // --- Unregister cancels the subscription + forwards to native -----------
    final unregisterCountBefore =
        log.where((c) => c.method == 'unregisterAuthTokenProvider').length;
    await sdk.unregisterAuthTokenProvider();
    expect(
      log.where((c) => c.method == 'unregisterAuthTokenProvider').length,
      unregisterCountBefore + 1,
    );

    // Events arriving after unregister must not trigger further responses.
    final respondCountAfterUnregister =
        log.where((c) => c.method == 'respondToAuthTokenRequest').length;
    capturedSink!.success({
      'type': 'auth_token_requested',
      'data': {'id': 'req-3'},
    });
    await pumpEventQueue();
    expect(
      log.where((c) => c.method == 'respondToAuthTokenRequest').length,
      respondCountAfterUnregister,
    );
  });
}
