import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';

import '../klaviyo_sdk.dart';
import '../models/klaviyo_push_data.dart';

/// Signature for [KlaviyoSDK.onBackgroundPushData] handlers.
@experimental
typedef KlaviyoBackgroundPushDataHandler = Future<void> Function(
  KlaviyoPushData data,
);

/// Channel native code uses to run the background push data handler.
@internal
const MethodChannel klaviyoBackgroundChannel =
    MethodChannel('klaviyo_sdk_background');

/// Native -> Dart: run the handler for one push.
@internal
const String handleBackgroundPushDataMethod = 'handleBackgroundPushData';

/// Dart -> native, headless engine only: the dispatcher is listening.
@internal
const String backgroundDispatcherInitializedMethod =
    'backgroundDispatcherInitialized';

final Logger _logger = Logger('KlaviyoSDK');

KlaviyoBackgroundPushDataHandler? _registeredHandler;

/// Stores [handler] for this isolate and starts answering
/// [handleBackgroundPushDataMethod] calls on [klaviyoBackgroundChannel].
///
/// Returns the raw callback handles native code needs to start a headless
/// engine: `dispatcherHandle` and `handlerHandle`.
///
/// Throws [ArgumentError] if [handler] is not a top-level or static function.
@internal
Map<String, int> attachBackgroundPushDataHandler(
  KlaviyoBackgroundPushDataHandler handler,
) {
  final handlerHandle = PluginUtilities.getCallbackHandle(handler);
  if (handlerHandle == null) {
    throw ArgumentError.value(
      handler,
      'handler',
      'must be a top-level or static function annotated with '
          "@pragma('vm:entry-point')",
    );
  }
  final dispatcherHandle =
      PluginUtilities.getCallbackHandle(klaviyoBackgroundPushDataDispatcher)!;

  _registeredHandler = handler;
  klaviyoBackgroundChannel.setMethodCallHandler(handleBackgroundChannelCall);

  return {
    'dispatcherHandle': dispatcherHandle.toRawHandle(),
    'handlerHandle': handlerHandle.toRawHandle(),
  };
}

/// Clears the handler stored by [attachBackgroundPushDataHandler].
@visibleForTesting
void resetBackgroundPushDataHandler() {
  _registeredHandler = null;
  klaviyoBackgroundChannel.setMethodCallHandler(null);
}

/// Answers a call from native code on [klaviyoBackgroundChannel].
///
/// For [handleBackgroundPushDataMethod], the arguments are:
/// - `data`: the push payload.
/// - `handlerHandle` (optional): raw callback handle, used when no handler was
///   registered in this isolate (the Android headless engine).
/// - `apiKey` (optional): initializes [KlaviyoSDK] first if it isn't already.
///
/// Completes once the handler's future completes. Handler errors are logged
/// and reported to native code as a `HANDLER_ERROR` [PlatformException].
@internal
Future<Object?> handleBackgroundChannelCall(MethodCall call) async {
  if (call.method != handleBackgroundPushDataMethod) {
    throw MissingPluginException('No implementation for ${call.method}');
  }

  final args = call.arguments is Map ? call.arguments as Map : const {};
  final handler = _registeredHandler ?? _handlerFromRawHandle(args);
  if (handler == null) {
    _logger.warning('Background push data received with no handler');
    throw PlatformException(
      code: 'NO_HANDLER',
      message: 'No background push data handler is registered',
    );
  }

  final apiKey = args['apiKey'];
  if (apiKey is String && apiKey.isNotEmpty && !KlaviyoSDK().isInitialized) {
    try {
      await KlaviyoSDK().initialize(apiKey: apiKey);
    } catch (e) {
      _logger.warning('Failed to initialize Klaviyo in background: $e');
    }
  }

  try {
    await handler(KlaviyoPushData(_deepConvertMap(args['data'])));
    return null;
  } catch (e, stackTrace) {
    _logger.warning(
      'Background push data handler threw an error',
      e,
      stackTrace,
    );
    throw PlatformException(code: 'HANDLER_ERROR', message: e.toString());
  }
}

KlaviyoBackgroundPushDataHandler? _handlerFromRawHandle(Map args) {
  final rawHandle = args['handlerHandle'];
  if (rawHandle is! int) return null;
  final callback = PluginUtilities.getCallbackFromHandle(
    CallbackHandle.fromRawHandle(rawHandle),
  );
  return callback is KlaviyoBackgroundPushDataHandler ? callback : null;
}

Map<String, dynamic> _deepConvertMap(Object? value) {
  if (value is! Map) return <String, dynamic>{};
  return value.map(
    (key, val) => MapEntry(key.toString(), _deepConvertValue(val)),
  );
}

Object? _deepConvertValue(Object? value) {
  if (value is Map) return _deepConvertMap(value);
  if (value is List) return value.map(_deepConvertValue).toList();
  return value;
}

/// Entry point of the headless engine Android starts for a push that
/// arrives while the app process has no Flutter engine.
@pragma('vm:entry-point')
@internal
void klaviyoBackgroundPushDataDispatcher() {
  WidgetsFlutterBinding.ensureInitialized();
  klaviyoBackgroundChannel.setMethodCallHandler(handleBackgroundChannelCall);
  klaviyoBackgroundChannel.invokeMethod<void>(
    backgroundDispatcherInitializedMethod,
  );
}
