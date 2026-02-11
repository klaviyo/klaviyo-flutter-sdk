import 'dart:async';
import 'dart:io';

import 'package:meta/meta.dart';

import 'models/klaviyo_profile.dart';
import 'models/klaviyo_event.dart';
import 'models/klaviyo_location.dart';
import 'models/in_app_form_config.dart';
import 'models/geofence.dart';
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
  final Logger _logger = Logger();

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

      // Set logger level
      _logger.setLogLevel(logLevel);

      // Initialize native wrapper
      _nativeWrapper = KlaviyoNativeWrapper();
      await _nativeWrapper.initialize(
        apiKey: apiKey,
        environment: environment,
        configuration: configuration,
      );

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

  /// Get the email of the currently tracked profile, if set
  Future<String?> getEmail() async {
    _ensureInitialized();

    try {
      return await _nativeWrapper.getEmail();
    } catch (e) {
      throw KlaviyoException('Failed to get email: $e');
    }
  }

  /// Get the phone number of the currently tracked profile, if set
  Future<String?> getPhoneNumber() async {
    _ensureInitialized();

    try {
      return await _nativeWrapper.getPhoneNumber();
    } catch (e) {
      throw KlaviyoException('Failed to get phone number: $e');
    }
  }

  /// Get the external ID of the currently tracked profile, if set
  Future<String?> getExternalId() async {
    _ensureInitialized();

    try {
      return await _nativeWrapper.getExternalId();
    } catch (e) {
      throw KlaviyoException('Failed to get external ID: $e');
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
      _logger.info('Event tracked: ${event.name.name}');
    } catch (e) {
      throw KlaviyoException('Failed to track event: $e');
    }
  }

  /// Register for push notifications
  ///
  /// This method triggers push notification registration on both platforms:
  /// - **iOS**: Triggers APNs registration. The token is automatically captured
  ///   and forwarded to the Klaviyo SDK.
  /// - **Android**: Fetches the FCM token and registers it with the Klaviyo SDK.
  ///
  /// After calling this method, you can listen for the token via [onPushNotification]:
  /// ```dart
  /// klaviyo.onPushNotification.listen((event) {
  ///   if (event['type'] == 'push_token_received') {
  ///     final token = event['data']['token'];
  ///     print('Token received: $token');
  ///   }
  /// });
  /// ```
  Future<void> registerForPushNotifications() async {
    _ensureInitialized();
    await _nativeWrapper.registerForPushNotifications();
  }

  /// Set push token
  Future<void> setPushToken(
    String token, {
    PushEnvironment? environment,
  }) async {
    _ensureInitialized();
    await _nativeWrapper.setPushToken(token, environment: environment);
  }

  /// Get push token
  ///
  /// Note: On iOS, the token may not be immediately available after calling
  /// [registerForPushNotifications]. For immediate access to the token,
  /// listen to [onPushNotification] for `push_token_received` events instead.
  Future<String?> getPushToken() async {
    _ensureInitialized();
    return await _nativeWrapper.getPushToken();
  }

  /// Handle push notification received
  Future<void> handlePushNotificationReceived(
    Map<String, dynamic> userInfo,
  ) async {
    _ensureInitialized();
    // Native SDK handles this automatically
    _logger.info('Push notification received');
  }

  /// Handle push notification opened
  Future<void> handlePushNotificationOpened(
    Map<String, dynamic> userInfo,
  ) async {
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

  /// Begin monitoring geofences configured in your Klaviyo account
  /// Requires location permissions to be granted by user
  Future<void> registerGeofencing() async {
    _ensureInitialized();
    await _nativeWrapper.registerGeofencing();
    _logger.info('Registered for geofencing');
  }

  /// Stop monitoring all geofences
  Future<void> unregisterGeofencing() async {
    _ensureInitialized();
    await _nativeWrapper.unregisterGeofencing();
    _logger.info('Unregistered from geofencing');
  }

  /// Get currently monitored geofences
  ///
  /// **This is for internal use only and should not be used in production applications.**
  ///
  /// This method is provided for demonstration and debugging purposes only.
  /// It provides the same functionality as the native platform's geofence monitoring APIs.
  @internal
  Future<List<Geofence>> getCurrentGeofences() async {
    _ensureInitialized();
    return await _nativeWrapper.getCurrentGeofences();
  }

  // ============================================================================
  // Deep Linking
  // ============================================================================

  /// Handle a Klaviyo universal tracking link
  ///
  /// Checks if the provided URL is a Klaviyo tracking link (format: `https://domain/u/...`).
  /// If it is, the native SDK will track the click event and resolve the destination URL.
  /// Our native SDK will then broadcast the deeplink to Flutter for navigation
  ///
  /// **Integration Pattern:**
  /// ```dart
  /// // Using go_router
  /// final router = GoRouter(
  ///   routes: [...],
  ///   redirect: (context, state) {
  ///     // Fire-and-forget - Klaviyo tracks in background
  ///     Klaviyo.handleUniversalTrackingLink(state.uri.toString());
  ///     return null; // Continue with normal navigation
  ///   },
  /// );
  /// ```
  ///
  /// This is a synchronous operation that validates the URL and returns immediately.
  /// The native SDK handles tracking and link resolution in the background (fire-and-forget).
  ///
  /// Returns `true` if the URL matches the Klaviyo tracking link pattern, `false` otherwise.
  bool handleUniversalTrackingLink(String url) {
    _ensureInitialized();

    // Validate empty/null URL
    if (url.trim().isEmpty) {
      _logger.error('[DeepLink SDK] Error: Empty tracking link provided');
      return false;
    }

    // Validate that the URL is a Klaviyo universal tracking link using regex
    // Pattern: https://domain/u/path
    final klaviyoTrackingLinkPattern = RegExp(r'^https:\/\/[^/]+\/u\/.*$');

    if (!klaviyoTrackingLinkPattern.hasMatch(url)) {
      _logger.warning(
        '[DeepLink SDK] URL does not match Klaviyo tracking link pattern',
      );
      return false;
    }

    // Fire-and-forget the native call - we don't await or handle errors
    // since this is a synchronous operation from the caller's perspective
    _nativeWrapper.handleUniversalTrackingLink(url).then((isKlaviyoLink) {
      if (isKlaviyoLink) {
        _logger.info('Link $url handled by native layer');
      } else {
        _logger.warning('Link $url rejected by native SDK');
      }
    }).catchError((e) {
      _logger.error('Failed to handle universal tracking link $url: $e');
    });

    return true;
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
      _logger.warning(
        'Setting badge count via the Klaviyo SDK is unsupported on Android.',
      );
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

  /// Private methods
  void _ensureInitialized() {
    if (!_isInitialized) {
      throw const KlaviyoException(
        'SDK not initialized. Call initialize() first.',
      );
    }
  }

  /// Dispose resources
  void dispose() {
    _nativeWrapper.dispose();
  }
}
