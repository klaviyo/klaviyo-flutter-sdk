import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';

import '../klaviyo_sdk.dart';

/// Signature for [KlaviyoSDK.onBackgroundSilentPush] handlers.
///
/// Receives the silent push payload, in the same shape as the `data` field of
/// a `silent_push_received` event.
@experimental
typedef KlaviyoBackgroundSilentPushHandler = Future<void> Function(
  Map<String, dynamic> data,
);

/// Channel native code uses to run the background silent push handler.
@internal
const MethodChannel klaviyoBackgroundChannel =
    MethodChannel('klaviyo_sdk_background');

/// Native -> Dart: run the handler for one silent push.
@internal
const String handleBackgroundSilentPushMethod = 'handleBackgroundSilentPush';

/// Dart -> native, headless engine only: the dispatcher is listening.
@internal
const String backgroundDispatcherInitializedMethod =
    'backgroundDispatcherInitialized';

final Logger _logger = Logger('KlaviyoSDK');

KlaviyoBackgroundSilentPushHandler? _registeredHandler;

/// Stores [handler] for this isolate and starts answering
/// [handleBackgroundSilentPushMethod] calls on [klaviyoBackgroundChannel].
///
/// Returns the raw callback handles native code needs to start a headless
/// engine: `dispatcherHandle` and `handlerHandle`.
///
/// Throws [ArgumentError] if [handler] is not a top-level or static function.
@internal
Map<String, int> attachBackgroundSilentPushHandler(
  KlaviyoBackgroundSilentPushHandler handler,
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
      PluginUtilities.getCallbackHandle(klaviyoBackgroundSilentPushDispatcher)!;

  _registeredHandler = handler;
  klaviyoBackgroundChannel.setMethodCallHandler(handleBackgroundChannelCall);

  return {
    'dispatcherHandle': dispatcherHandle.toRawHandle(),
    'handlerHandle': handlerHandle.toRawHandle(),
  };
}

/// Clears the handler stored by [attachBackgroundSilentPushHandler].
@visibleForTesting
void resetBackgroundSilentPushHandler() {
  _registeredHandler = null;
  klaviyoBackgroundChannel.setMethodCallHandler(null);
}

/// Answers a call from native code on [klaviyoBackgroundChannel].
///
/// For [handleBackgroundSilentPushMethod], the arguments are:
/// - `data`: the silent push payload.
/// - `handlerHandle` (optional): raw callback handle, used when no handler was
///   registered in this isolate (the Android headless engine).
/// - `apiKey` (optional): initializes [KlaviyoSDK] first if it isn't already.
///
/// Completes once the handler's future completes. Handler errors are logged
/// and reported to native code as a `HANDLER_ERROR` [PlatformException].
@internal
Future<Object?> handleBackgroundChannelCall(MethodCall call) async {
  if (call.method != handleBackgroundSilentPushMethod) {
    throw MissingPluginException('No implementation for ${call.method}');
  }

  final args = call.arguments is Map ? call.arguments as Map : const {};
  final handler = _registeredHandler ?? _handlerFromRawHandle(args);
  if (handler == null) {
    _logger.warning('Background silent push received with no handler');
    throw PlatformException(
      code: 'NO_HANDLER',
      message: 'No background silent push handler is registered',
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
    await handler(_deepConvertMap(args['data']));
    return null;
  } catch (e, stackTrace) {
    _logger.warning(
      'Background silent push handler threw an error',
      e,
      stackTrace,
    );
    throw PlatformException(code: 'HANDLER_ERROR', message: e.toString());
  }
}

KlaviyoBackgroundSilentPushHandler? _handlerFromRawHandle(Map args) {
  final rawHandle = args['handlerHandle'];
  if (rawHandle is! int) return null;
  final callback = PluginUtilities.getCallbackFromHandle(
    CallbackHandle.fromRawHandle(rawHandle),
  );
  return callback is KlaviyoBackgroundSilentPushHandler ? callback : null;
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

/// Entry point of the headless engine Android starts for a silent push that
/// arrives while the app process has no Flutter engine.
@pragma('vm:entry-point')
@internal
void klaviyoBackgroundSilentPushDispatcher() {
  WidgetsFlutterBinding.ensureInitialized();
  klaviyoBackgroundChannel.setMethodCallHandler(handleBackgroundChannelCall);
  klaviyoBackgroundChannel.invokeMethod<void>(
    backgroundDispatcherInitializedMethod,
  );
}
