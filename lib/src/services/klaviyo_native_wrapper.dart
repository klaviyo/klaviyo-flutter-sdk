import 'dart:async';
import 'package:flutter/services.dart';
import '../models/klaviyo_profile.dart';
import '../models/klaviyo_event.dart';
import '../enums/push_environment.dart';
import '../exceptions/klaviyo_exception.dart';

class KlaviyoNativeWrapper {
  static const MethodChannel _channel = MethodChannel('klaviyo_sdk');
  static const EventChannel _eventChannel = EventChannel('klaviyo_events');

  static final KlaviyoNativeWrapper _instance =
      KlaviyoNativeWrapper._internal();

  factory KlaviyoNativeWrapper() => _instance;

  KlaviyoNativeWrapper._internal();

  bool _isInitialized = false;
  String? _apiKey;

  // Stream controllers for native events
  final StreamController<Map<String, dynamic>> _pushNotificationController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _formEventController =
      StreamController<Map<String, dynamic>>.broadcast();

  // Getters for streams
  Stream<Map<String, dynamic>> get onPushNotification =>
      _pushNotificationController.stream;

  Stream<Map<String, dynamic>> get onFormEvent => _formEventController.stream;

  /// Initialize the native SDK wrapper
  Future<void> initialize({
    required String apiKey,
    PushEnvironment environment = PushEnvironment.development,
    Map<String, dynamic>? configuration,
  }) async {
    if (_isInitialized) return;

    try {
      _apiKey = apiKey;

      // Set up event listeners
      _eventChannel.receiveBroadcastStream().listen(_handleNativeEvent);

      // Initialize native SDK
      await _channel.invokeMethod('initialize', {
        'apiKey': apiKey,
        'environment': environment.toString(),
        'configuration': configuration,
      });

      _isInitialized = true;
    } catch (e) {
      throw KlaviyoException('Failed to initialize native SDK: $e');
    }
  }

  /// Set user profile using native SDK
  Future<void> setProfile(KlaviyoProfile profile) async {
    _ensureInitialized();

    try {
      await _channel.invokeMethod('setProfile', {'profile': profile.toJson()});
    } catch (e) {
      throw KlaviyoException('Failed to set profile: $e');
    }
  }

  /// Set user email using native SDK
  Future<void> setEmail(String email) async {
    _ensureInitialized();

    try {
      await _channel.invokeMethod('setEmail', {'email': email});
    } catch (e) {
      throw KlaviyoException('Failed to set email: $e');
    }
  }

  /// Set user phone number using native SDK
  Future<void> setPhoneNumber(String phoneNumber) async {
    _ensureInitialized();

    try {
      await _channel.invokeMethod('setPhoneNumber', {
        'phoneNumber': phoneNumber,
      });
    } catch (e) {
      throw KlaviyoException('Failed to set phone number: $e');
    }
  }

  /// Set external ID using native SDK
  Future<void> setExternalId(String externalId) async {
    _ensureInitialized();

    try {
      await _channel.invokeMethod('setExternalId', {'externalId': externalId});
    } catch (e) {
      throw KlaviyoException('Failed to set external ID: $e');
    }
  }

  /// Set profile properties using native SDK
  Future<void> setProfileProperties(Map<String, dynamic> properties) async {
    _ensureInitialized();

    try {
      await _channel.invokeMethod('setProfileProperties', {
        'properties': properties,
      });
    } catch (e) {
      throw KlaviyoException('Failed to set profile properties: $e');
    }
  }

  /// Set profile location using native SDK
  Future<void> setLocation(dynamic location) async {
    _ensureInitialized();

    try {
      await _channel.invokeMethod('setLocation', {
        'location': location is Map ? location : (location as dynamic).toJson(),
      });
    } catch (e) {
      throw KlaviyoException('Failed to set location: $e');
    }
  }

  /// Track event using native SDK
  Future<void> trackEvent(KlaviyoEvent event) async {
    _ensureInitialized();

    try {
      await _channel.invokeMethod('trackEvent', {'event': event.toJson()});
    } catch (e) {
      throw KlaviyoException('Failed to track event: $e');
    }
  }

  /// Track simple event using native SDK
  Future<void> track(
    String eventName, [
    Map<String, dynamic>? properties,
  ]) async {
    final event = KlaviyoEvent(
      name: eventName,
      properties: properties ?? {},
      timestamp: DateTime.now(),
    );
    await trackEvent(event);
  }

  /// Register for push notifications using native SDK
  /// This should only be called on iOS to trigger APNs registration.
  /// Callers should check platform before calling this method.
  Future<void> registerForPushNotifications() async {
    _ensureInitialized();

    try {
      await _channel.invokeMethod('registerForPushNotifications');
    } catch (e) {
      throw KlaviyoException('Failed to register for push notifications: $e');
    }
  }

  /// Set push token using native SDK
  Future<void> setPushToken(
    String token, {
    PushEnvironment? environment,
  }) async {
    _ensureInitialized();

    try {
      await _channel.invokeMethod('setPushToken', {
        'token': token,
        'environment': environment?.toString(),
      });
    } catch (e) {
      throw KlaviyoException('Failed to set push token: $e');
    }
  }

  /// Get push token from native SDK
  /// Returns the raw token string or null if no token is available
  Future<String?> getPushToken() async {
    _ensureInitialized();

    try {
      final result = await _channel.invokeMethod<String>('getPushToken');
      return result;
    } catch (e) {
      throw KlaviyoException('Failed to get push token: $e');
    }
  }

  /// Register for in-app forms using native SDK
  Future<void> registerForInAppForms({
    Map<String, dynamic>? configuration,
  }) async {
    _ensureInitialized();
    try {
      await _channel.invokeMethod('registerForInAppForms', {
        'configuration': configuration,
      });
    } catch (e) {
      throw KlaviyoException('Failed to register for in-app forms: $e');
    }
  }

  /// Unregister from in-app forms using native SDK
  Future<void> unregisterFromInAppForms({
    Map<String, dynamic>? configuration,
  }) async {
    _ensureInitialized();
    try {
      await _channel.invokeMethod('unregisterFromInAppForms');
    } catch (e) {
      throw KlaviyoException('Failed to register for in-app forms: $e');
    }
  }

  /// Reset profile using native SDK
  Future<void> resetProfile() async {
    _ensureInitialized();

    try {
      await _channel.invokeMethod('resetProfile');
    } catch (e) {
      throw KlaviyoException('Failed to reset profile: $e');
    }
  }

  /// Set log level using native SDK
  Future<void> setLogLevel(String logLevel) async {
    _ensureInitialized();

    try {
      await _channel.invokeMethod('setLogLevel', {'logLevel': logLevel});
    } catch (e) {
      throw KlaviyoException('Failed to set log level: $e');
    }
  }

  /// Handle native events from platform channels
  void _handleNativeEvent(dynamic event) {
    try {
      final Map<String, dynamic> eventData = Map<String, dynamic>.from(event);
      final String eventType = eventData['type'] as String? ?? '';

      switch (eventType) {
        case 'push_notification_received':
        case 'push_notification_opened':
          _pushNotificationController.add(eventData);
          break;
        case 'form_event':
          _formEventController.add(eventData);
          break;
        default:
          // Handle unknown event types
          break;
      }
    } catch (e) {
      // Log error but don't crash
      print('Error handling native event: $e');
    }
  }

  /// Ensure SDK is initialized
  void _ensureInitialized() {
    if (!_isInitialized) {
      throw const KlaviyoNotInitializedException();
    }
  }

  /// Check if SDK is initialized
  bool get isInitialized => _isInitialized;

  /// Get current API key
  String? get apiKey => _apiKey;

  /// Dispose resources
  void dispose() {
    _pushNotificationController.close();
    _formEventController.close();
  }
}
