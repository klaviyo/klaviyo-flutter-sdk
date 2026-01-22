import 'dart:async';
import 'dart:io';

import 'models/klaviyo_profile.dart';
import 'models/klaviyo_event.dart';
import 'models/klaviyo_location.dart';
import 'models/in_app_form_config.dart';
import 'enums/klaviyo_log_level.dart';
import 'enums/push_environment.dart';
import 'services/klaviyo_native_wrapper.dart';
import 'utils/logger.dart';
import 'exceptions/klaviyo_exception.dart';

/// Main Klaviyo SDK class for Flutter applications
/// This SDK acts as a thin wrapper around the native Klaviyo SDKs
/// All state is managed by the native SDKs - this class only forwards calls
class KlaviyoSDK {
  static final KlaviyoSDK _instance = KlaviyoSDK._internal();
  factory KlaviyoSDK() => _instance;
  KlaviyoSDK._internal();

  // Native wrapper service
  late KlaviyoNativeWrapper _nativeWrapper;
  late Logger _logger;

  // State
  bool _isInitialized = false;
  String? _apiKey;

  // Getters
  bool get isInitialized => _isInitialized;
  String? get apiKey => _apiKey;

  /// Initialize the Klaviyo SDK with your public API key
  Future<KlaviyoSDK> initialize({
    required String apiKey,
    KlaviyoLogLevel logLevel = KlaviyoLogLevel.none,
    PushEnvironment environment = PushEnvironment.development,
    Map<String, dynamic>? configuration,
  }) async {
    if (_isInitialized) {
      _logger.warning('SDK already initialized');
      return this;
    }

    try {
      _apiKey = apiKey;

      // Initialize logger
      _logger = Logger();
      _logger.setLogLevel(logLevel);

      // Initialize native wrapper
      _nativeWrapper = KlaviyoNativeWrapper();
      await _nativeWrapper.initialize(
        apiKey: apiKey,
        environment: environment,
        configuration: configuration,
      );

      // Set up native event listeners
      _setupNativeEventListeners();

      _isInitialized = true;
      _logger.info('Klaviyo SDK initialized successfully');

      return this;
    } catch (e) {
      throw KlaviyoException('Failed to initialize SDK: $e');
    }
  }

  /// Set user profile information
  /// Profile state is managed by the native SDK
  Future<void> setProfile(KlaviyoProfile profile) async {
    _ensureInitialized();

    try {
      await _nativeWrapper.setProfile(profile);
      _logger.info('Profile updated: ${profile.email}');
    } catch (e) {
      throw KlaviyoException('Failed to set profile: $e');
    }
  }

  /// Set profile email
  /// Calls the native SDK directly - native SDK manages profile state
  Future<void> setEmail(String email) async {
    _ensureInitialized();

    try {
      await _nativeWrapper.setEmail(email);
      _logger.info('Email set: $email');
    } catch (e) {
      throw KlaviyoException('Failed to set email: $e');
    }
  }

  /// Set profile phone number
  /// Calls the native SDK directly - native SDK manages profile state
  Future<void> setPhoneNumber(String phoneNumber) async {
    _ensureInitialized();

    try {
      await _nativeWrapper.setPhoneNumber(phoneNumber);
      _logger.info('Phone number set: $phoneNumber');
    } catch (e) {
      throw KlaviyoException('Failed to set phone number: $e');
    }
  }

  /// Set external ID for the profile
  /// Calls the native SDK directly - native SDK manages profile state
  Future<void> setExternalId(String externalId) async {
    _ensureInitialized();

    try {
      await _nativeWrapper.setExternalId(externalId);
      _logger.info('External ID set: $externalId');
    } catch (e) {
      throw KlaviyoException('Failed to set external ID: $e');
    }
  }

  /// Set profile properties
  /// Calls the native SDK directly - native SDK manages profile state
  Future<void> setProfileProperties(Map<String, dynamic> properties) async {
    _ensureInitialized();

    try {
      await _nativeWrapper.setProfileProperties(properties);
      _logger.info('Profile properties set');
    } catch (e) {
      throw KlaviyoException('Failed to set profile properties: $e');
    }
  }

  /// Set profile location
  /// Calls the native SDK directly - native SDK manages profile state
  Future<void> setLocation(KlaviyoLocation location) async {
    _ensureInitialized();

    try {
      await _nativeWrapper.setLocation(location);
      _logger.info('Location set');
    } catch (e) {
      throw KlaviyoException('Failed to set location: $e');
    }
  }

  /// Track an event
  Future<void> trackEvent(KlaviyoEvent event) async {
    _ensureInitialized();

    try {
      await _nativeWrapper.trackEvent(event);
      _logger.info('Event tracked: ${event.name}');
    } catch (e) {
      throw KlaviyoException('Failed to track event: $e');
    }
  }

  /// Track event with just name and properties
  Future<void> track(String eventName,
      [Map<String, dynamic>? properties]) async {
    final event = KlaviyoEvent(
      name: eventName,
      properties: properties ?? {},
      timestamp: DateTime.now(),
    );
    await trackEvent(event);
  }

  /// Register for push notifications
  /// This is only required on iOS to trigger APNs registration.
  /// On Android, FCM handles registration automatically via KlaviyoPushService.
  Future<void> registerForPushNotifications() async {
    _ensureInitialized();

    // Only call native method on iOS
    if (Platform.isIOS) {
      await _nativeWrapper.registerForPushNotifications();
    }
    // No-op on Android - FCM handles this automatically
  }

  /// Set push token
  Future<void> setPushToken(String token,
      {PushEnvironment? environment}) async {
    _ensureInitialized();
    await _nativeWrapper.setPushToken(token, environment: environment);
  }

  /// Get push token
  Future<String?> getPushToken() async {
    _ensureInitialized();
    return await _nativeWrapper.getPushToken();
  }

  /// Handle push notification received
  Future<void> handlePushNotificationReceived(
      Map<String, dynamic> userInfo) async {
    _ensureInitialized();
    // Native SDK handles this automatically
    _logger.info('Push notification received');
  }

  /// Handle push notification opened
  Future<void> handlePushNotificationOpened(
      Map<String, dynamic> userInfo) async {
    _ensureInitialized();
    // Native SDK handles this automatically
    _logger.info('Push notification opened');
  }

  /// Register for in-app forms
  Future<void> registerForInAppForms({InAppFormConfig? configuration}) async {
    _ensureInitialized();
    await _nativeWrapper.registerForInAppForms(
      configuration: configuration?.toJson(),
    );
    _logger.info('Registered for in-app forms');
  }

  /// Unregister from in-app forms
  Future<void> unregisterFromInAppForms() async {
    _ensureInitialized();
    await _nativeWrapper.unregisterFromInAppForms();
    _logger.info('Unregistered from in-app forms');
  }

  /// Reset the current profile (useful for logout)
  /// Profile state is managed by the native SDK
  Future<void> resetProfile() async {
    _ensureInitialized();

    try {
      await _nativeWrapper.resetProfile();
      _logger.info('Profile reset');
    } catch (e) {
      throw KlaviyoException('Failed to reset profile: $e');
    }
  }

  /// Reset the current profile (useful for logout)
  /// Profile state is managed by the native SDK
  void setBadgeCount(int count) {
    if (Platform.isIOS) {
      _ensureInitialized();
      _nativeWrapper.setBadgeCount(count);
      _logger.info('Set the badge count to $count');
    } else {
      // Android does not support badge count
      _logger.warning('Setting badge count via the Klaviyo SDK is unsupported on Android.');
    }
  }

  /// Set log level
  void setLogLevel(KlaviyoLogLevel logLevel) {
    _logger.setLogLevel(logLevel);
    _nativeWrapper.setLogLevel(logLevel.toString());
  }

  /// Get push notification events stream
  Stream<Map<String, dynamic>> get onPushNotification =>
      _nativeWrapper.onPushNotification;

  /// Get form events stream
  Stream<Map<String, dynamic>> get onFormEvent => _nativeWrapper.onFormEvent;

  /// Set up native event listeners
  void _setupNativeEventListeners() {
    // Listen for push notification events from native SDK
    _nativeWrapper.onPushNotification.listen((eventData) {
      _logger.info('Native push notification event: $eventData');
      final eventType = eventData['type'] as String? ?? '';

      if (eventType == 'push_notification_opened') {
        final userInfo = eventData['data'] as Map<String, dynamic>? ?? {};
        _logger.info('Push notification opened with data: $userInfo');
        // The event is automatically forwarded via the stream
      }
    });

    // Listen for form events from native SDK
    _nativeWrapper.onFormEvent.listen((eventData) {
      _logger.info('Native form event: $eventData');
      // Handle form events
    });
  }

  /// Private methods
  void _ensureInitialized() {
    if (!_isInitialized) {
      throw const KlaviyoException(
          'SDK not initialized. Call initialize() first.');
    }
  }

  /// Dispose resources
  void dispose() {
    _nativeWrapper.dispose();
  }
}
