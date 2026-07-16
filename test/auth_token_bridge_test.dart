import 'dart:async';
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

    // --- Unregister forwards to native --------------------------------------
    final unregisterCountBefore =
        log.where((c) => c.method == 'unregisterAuthTokenProvider').length;
    await sdk.unregisterAuthTokenProvider();
    expect(
      log.where((c) => c.method == 'unregisterAuthTokenProvider').length,
      unregisterCountBefore + 1,
    );

    // --- Stale event after unregister is NOT replayed into a new provider ---
    // A request that races the unregister is answered with a failure (so native
    // resolves immediately) and must never be handed to a later-registered
    // provider. Regression test for the buffering-controller replay bug.
    capturedSink!.success({
      'type': 'auth_token_requested',
      'data': {'id': 'req-stale'},
    });
    await pumpEventQueue();

    // It was answered as a failure by the no-provider path, not invoked.
    final orphan = log.lastWhere(
      (c) => c.arguments is Map && c.arguments['id'] == 'req-stale',
    );
    expect(orphan.method, 'respondToAuthTokenRequest');
    expect(orphan.arguments['jwt'], isNull);

    var newProviderCalls = 0;
    await sdk.registerAuthTokenProvider(() async {
      newProviderCalls++;
      return 'jwt-new';
    });
    await pumpEventQueue();

    // Re-registering must not replay the stale req-stale event into the new
    // provider — it stays uninvoked until a genuinely new request arrives.
    expect(newProviderCalls, 0);

    capturedSink!.success({
      'type': 'auth_token_requested',
      'data': {'id': 'req-4'},
    });
    await pumpEventQueue();
    expect(newProviderCalls, 1);
    expect(lastRespond().arguments['id'], 'req-4');

    await sdk.unregisterAuthTokenProvider();

    // --- Token acquired after an in-flight unregister is NOT delivered ------
    // A slow provider that resolves after the user has logged out (unregister)
    // must not hand the (now stale) token to native. Its request is answered
    // with a failure, never a jwt.
    final inFlight = Completer<String>();
    await sdk.registerAuthTokenProvider(() => inFlight.future);

    capturedSink!.success({
      'type': 'auth_token_requested',
      'data': {'id': 'req-inflight'},
    });
    await pumpEventQueue();

    // Unregister while the provider future is still pending, then let it resolve.
    await sdk.unregisterAuthTokenProvider();
    inFlight.complete('jwt-after-logout');
    await pumpEventQueue();

    final inflightResponse = log.lastWhere(
      (c) => c.arguments is Map && c.arguments['id'] == 'req-inflight',
    );
    expect(inflightResponse.arguments['jwt'], isNull);
    expect(
      logMessages.every((m) => !m.contains('jwt-after-logout')),
      isTrue,
      reason: 'a token fetched after logout must never be delivered or logged',
    );
  });
}
