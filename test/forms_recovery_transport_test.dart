import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klaviyo_flutter_sdk/klaviyo_flutter_sdk.dart';
import 'package:logging/logging.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const methods = MethodChannel('klaviyo_sdk');
  const events = EventChannel('klaviyo_events');
  final calls = <MethodCall>[];
  late MockStreamHandlerEventSink sink;
  Object? listenerEpoch;
  int listens = 0;
  int cancels = 0;
  final sdk = KlaviyoSDK();

  Future<void> flush() => Future<void>.delayed(Duration.zero);
  String epoch() => calls
      .lastWhere((call) => call.method == 'registerForInAppForms')
      .arguments['formsEpoch'] as String;
  void failure(String value) => sink.success({
        'type': '_forms_failure',
        'formsEpoch': value,
      });

  void installEventHandler() {
    messenger.setMockStreamHandler(
      events,
      MockStreamHandler.inline(
        onListen: (arguments, eventSink) {
          sink = eventSink;
          listenerEpoch = (arguments as Map?)?['listenerEpoch'];
          listens++;
        },
        onCancel: (_) => cancels++,
      ),
    );
  }

  setUpAll(() async {
    messenger.setMockMethodCallHandler(methods, (call) async {
      calls.add(call);
      return null;
    });
    installEventHandler();
    await sdk.initialize(apiKey: 'test');
  });

  tearDownAll(() {
    messenger.setMockMethodCallHandler(methods, null);
    messenger.setMockStreamHandler(events, null);
  });

  test('registration awaits private listener acknowledgement', () async {
    final pending = sdk.registerForInAppForms();
    await flush();
    expect(
      calls.where((call) => call.method == 'registerForInAppForms'),
      isEmpty,
    );
    sink.success(
      {'type': '_forms_listener_ready', 'listenerEpoch': 'old-listener'},
    );
    await flush();
    expect(
      calls.where((call) => call.method == 'registerForInAppForms'),
      isEmpty,
    );
    sink.success(
      {'type': '_forms_listener_ready', 'listenerEpoch': listenerEpoch},
    );
    await pending;
    expect(calls.last.method, 'registerForInAppForms');
    expect(calls.last.arguments['listenerEpoch'], listenerEpoch);
    expect(listens, 1);
  });

  test('duplicate registration immediately selects latest callback', () async {
    int first = 0;
    int second = 0;
    await sdk.registerForInAppForms(
      configuration: InAppFormConfig(onFailure: () => first++),
    );
    final original = epoch();
    final duplicate = sdk.registerForInAppForms(
      configuration: InAppFormConfig(
        loadTimeout: const Duration(milliseconds: 1250),
        onFailure: () => second++,
      ),
    );
    failure(original);
    await duplicate;
    await flush();
    expect(first, 0);
    expect(second, 1);
    expect(epoch(), original);
    expect(calls.last.arguments['configuration']['loadTimeout'], 1.25);
    failure(original);
    await flush();
    expect(second, 2);
    await sdk.registerForInAppForms();
    failure(original);
    await flush();
    expect(second, 2);
    expect(listens, 1);
  });

  test(
      'callback can be added after initial omission and private events stay private',
      () async {
    final publicEvents = <FormLifecycleEvent>[];
    final subscription = sdk.onFormLifecycleEvent.listen(publicEvents.add);
    int failures = 0;
    await sdk.registerForInAppForms(
      configuration: InAppFormConfig(onFailure: () => failures++),
    );
    failure(epoch());
    await flush();
    expect(failures, 1);
    expect(publicEvents, isEmpty);
    await subscription.cancel();
  });

  test('unregister rejects queued old epoch and retry remains active',
      () async {
    int old = 0;
    int retried = 0;
    await sdk.registerForInAppForms(
      configuration: InAppFormConfig(onFailure: () => old++),
    );
    final previous = epoch();
    await sdk.unregisterFromInAppForms();
    await sdk.registerForInAppForms(
      configuration: InAppFormConfig(onFailure: () => retried++),
    );
    failure(previous);
    failure(epoch());
    await flush();
    expect(old, 0);
    expect(retried, 1);
  });

  test('reentrant retry and callback exceptions do not break later failures',
      () async {
    final records = <LogRecord>[];
    final logging = Logger('KlaviyoSDK').onRecord.listen(records.add);
    int retries = 0;
    final retry = Completer<void>();
    await sdk.registerForInAppForms(
      configuration: InAppFormConfig(
        onFailure: () {
          sdk
              .registerForInAppForms(
                configuration: InAppFormConfig(onFailure: () => retries++),
              )
              .then((_) => retry.complete());
          throw StateError('host callback');
        },
      ),
    );
    failure(epoch());
    await retry.future;
    failure(epoch());
    await flush();
    expect(retries, 1);
    expect(records.any((record) => record.level >= Level.WARNING), isTrue);
    expect(listens, 1);
    await logging.cancel();
  });

  test('native stream end and error reject pending registration', () async {
    sink.endOfStream();
    await flush();
    installEventHandler();
    var pending = KlaviyoNativeWrapper().registerForInAppForms();
    var settled = expectLater(pending, throwsA(isA<KlaviyoException>()));
    await flush();
    sink.endOfStream();
    await settled;
    installEventHandler();

    pending = KlaviyoNativeWrapper().registerForInAppForms();
    settled = expectLater(pending, throwsA(isA<KlaviyoException>()));
    await flush();
    sink.error(code: 'DETACHED', message: 'engine detached');
    await settled;
  });

  testWidgets('missing readiness acknowledgement fails within bounded wait',
      (tester) async {
    installEventHandler();
    final previousCancels = cancels;
    final pending = KlaviyoNativeWrapper().registerForInAppForms();
    final settled = expectLater(pending, throwsA(isA<KlaviyoException>()));
    await tester.pump(const Duration(seconds: 11));
    await settled;
    await tester.pump();
    expect(cancels, greaterThan(previousCancels));
  });

  test('unregister cancels a command waiting for listener readiness', () async {
    installEventHandler();
    final registrations =
        calls.where((call) => call.method == 'registerForInAppForms').length;
    final pending = KlaviyoNativeWrapper().registerForInAppForms();
    final settled = expectLater(pending, throwsA(isA<KlaviyoException>()));
    await flush();
    await sdk.unregisterFromInAppForms();
    sink.success(
      {'type': '_forms_listener_ready', 'listenerEpoch': listenerEpoch},
    );
    await settled;
    expect(
      calls.where((call) => call.method == 'registerForInAppForms').length,
      registrations,
    );
    sink.error(code: 'DETACHED', message: 'engine detached');
    await flush();
  });

  test('dispose rejects pending registration and cancels owned listener',
      () async {
    final previousCancels = cancels;
    final pending = KlaviyoNativeWrapper().registerForInAppForms();
    bool rejected = false;
    final settled = expectLater(pending, throwsA(isA<KlaviyoException>()))
        .then((_) => rejected = true);
    await flush();
    KlaviyoNativeWrapper().dispose();
    await flush();
    expect(rejected, isTrue);
    await settled;
    expect(cancels, greaterThan(previousCancels));
  });
}
