import 'package:flutter/services.dart';
import 'package:meta/meta.dart';
import '../models/klaviyo_profile.dart';
import '../models/klaviyo_event.dart';
import '../models/geofence.dart';
import '../exceptions/klaviyo_exception.dart';
import '../utils/buffered_broadcast_stream_controller.dart';
import '../utils/logger.dart';

class KlaviyoNativeWrapper {
  static const MethodChannel _channel = MethodChannel('klaviyo_sdk');
  static const EventChannel _eventChannel = EventChannel('klaviyo_events');

  static final KlaviyoNativeWrapper _instance =
      KlaviyoNativeWrapper._internal();

  factory KlaviyoNativeWrapper() => _instance;

  KlaviyoNativeWrapper._internal();

  final Logger _logger = Logger();
  bool _isInitialized = false;
  String? _apiKey;

  // Stream controllers for native events – buffer events that arrive
  // before any listener subscribes, then flush on first subscription.
  final _pushNotificationController =
      BufferedBroadcastStreamController<Map<String, dynamic>>();
  final _formEventController =
      BufferedBroadcastStreamController<Map<String, dynamic>>();

  // Getters for streams
  Stream<Map<String, dynamic>> get onPushNotification =>
      _pushNotificationController.stream;

  Stream<Map<String, dynamic>> get onFormEvent => _formEventController.stream;

  /// Initialize the native SDK wrapper
  Future<void> initialize({
    required String apiKey,
  }) async {
    if (_isInitialized) return;

    try {
      _apiKey = apiKey;

      // Set up event listeners
      _eventChannel.receiveBroadcastStream().listen(_handleNativeEvent);

      // Initialize native SDK
      await _channel.invokeMethod('initialize', {
        'apiKey': apiKey,
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

  /// Get the email of the currently tracked profile from native SDK
  Future<String?> getEmail() async {
    _ensureInitialized();

    try {
      final result = await _channel.invokeMethod<String>('getEmail');
      return result;
    } catch (e) {
      throw KlaviyoException('Failed to get email: $e');
    }
  }

  /// Get the phone number of the currently tracked profile from native SDK
  Future<String?> getPhoneNumber() async {
    _ensureInitialized();

    try {
      final result = await _channel.invokeMethod<String>('getPhoneNumber');
      return result;
    } catch (e) {
      throw KlaviyoException('Failed to get phone number: $e');
    }
  }

  /// Get the external ID of the currently tracked profile from native SDK
  Future<String?> getExternalId() async {
    _ensureInitialized();

    try {
      final result = await _channel.invokeMethod<String>('getExternalId');
      return result;
    } catch (e) {
      throw KlaviyoException('Failed to get external ID: $e');
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
    final event = KlaviyoEvent.custom(
      metric: eventName,
      properties: properties,
    );
    await trackEvent(event);
  }

  /// Register for push notifications using native SDK
  ///
  /// On iOS, this triggers APNs registration.
  /// On Android, this fetches the FCM token and registers it with Klaviyo.
  ///
  /// Both platforms emit the token via the event channel as a
  /// `push_token_received` event.
  Future<void> registerForPushNotifications() async {
    _ensureInitialized();

    try {
      await _channel.invokeMethod('registerForPushNotifications');
    } catch (e) {
      throw KlaviyoException('Failed to register for push notifications: $e');
    }
  }

  /// Set push token using native SDK
  Future<void> setPushToken(String token) async {
    _ensureInitialized();

    try {
      await _channel.invokeMethod('setPushToken', {
        'token': token,
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
  Future<void> unregisterFromInAppForms() async {
    _ensureInitialized();
    try {
      await _channel.invokeMethod('unregisterFromInAppForms');
    } catch (e) {
      throw KlaviyoException('Failed to unregister from in-app forms: $e');
    }
  }

  /// Register for geofencing using native SDK
  Future<void> registerGeofencing() async {
    _ensureInitialized();
    try {
      await _channel.invokeMethod('registerGeofencing');
    } catch (e) {
      throw KlaviyoException('Failed to register for geofencing: $e');
    }
  }

  /// Unregister from geofencing using native SDK
  Future<void> unregisterGeofencing() async {
    _ensureInitialized();
    try {
      await _channel.invokeMethod('unregisterGeofencing');
    } catch (e) {
      throw KlaviyoException('Failed to unregister from geofencing: $e');
    }
  }

  /// Get currently monitored geofences from native SDK
  ///
  /// **This is for internal use only and should not be used in production applications.**
  ///
  /// This method is provided for demonstration and debugging purposes only.
  @internal
  Future<List<Geofence>> getCurrentGeofences() async {
    _ensureInitialized();
    try {
      final result = await _channel.invokeMethod('getCurrentGeofences');
      final List<dynamic> geofencesJson = result['geofences'];
      return geofencesJson
          .map((json) => Geofence.fromJson(Map<String, dynamic>.from(json)))
          .toList();
    } catch (e) {
      throw KlaviyoException('Failed to get current geofences: $e');
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

  /// Set badge count on the app icon (iOS only)
  /// This is a synchronous fire-and-forget operation
  void setBadgeCount(int count) {
    _ensureInitialized();

    // Fire-and-forget - we don't await or handle errors
    // since this is a synchronous operation from the caller's perspective
    _channel.invokeMethod('setBadgeCount', {'count': count});
  }

  /// Handle a Klaviyo universal tracking link URL
  /// Returns true if the URL is a valid Klaviyo tracking link, false otherwise
  Future<bool> handleUniversalTrackingLink(String url) async {
    _ensureInitialized();

    try {
      final result = await _channel.invokeMethod<bool>(
        'handleUniversalTrackingLink',
        {'url': url},
      );
      return result ?? false;
    } catch (e) {
      throw KlaviyoException('Failed to handle universal tracking link: $e');
    }
  }

  /// Handle native events from platform channels
  void _handleNativeEvent(dynamic event) {
    try {
      final Map<String, dynamic> eventData = _deepConvertMap(event);
      final String eventType = eventData['type'] as String? ?? '';

      switch (eventType) {
        case 'push_notification_received':
        case 'push_notification_opened':
        case 'silent_push_received':
        case 'push_token_received':
        case 'push_token_error':
          _logger.info('Native push notification event: $eventData');
          _pushNotificationController.add(eventData);
          break;
        case 'form_event':
          _logger.info('Native form event: $eventData');
          _formEventController.add(eventData);
          break;
        default:
          // Handle unknown event types
          break;
      }
    } catch (e) {
      _logger.error('Error handling native event: $e');
    }
  }

  /// Recursively convert platform channel maps to Map<String, dynamic>
  Map<String, dynamic> _deepConvertMap(dynamic value) {
    assert(
      value == null || value is Map,
      '_deepConvertMap expected Map but got ${value.runtimeType}',
    );

    if (value is Map) {
      return value.map(
        (key, val) => MapEntry(key.toString(), _deepConvertValue(val)),
      );
    }
    return <String, dynamic>{};
  }

  /// Recursively convert values, handling nested maps and lists
  dynamic _deepConvertValue(dynamic value) {
    if (value is Map) {
      return _deepConvertMap(value);
    } else if (value is List) {
      return value.map(_deepConvertValue).toList();
    }
    return value;
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
