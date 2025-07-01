import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

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
/// This SDK acts as a wrapper around the native Klaviyo SDKs
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
  KlaviyoProfile? _currentProfile;
  final StreamController<KlaviyoProfile?> _profileController =
      StreamController<KlaviyoProfile?>.broadcast();

  // Getters
  bool get isInitialized => _isInitialized;
  String? get apiKey => _apiKey;
  KlaviyoProfile? get currentProfile => _currentProfile;
  Stream<KlaviyoProfile?> get profileStream => _profileController.stream;

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

      // Load persisted profile
      await _loadPersistedProfile();

      _isInitialized = true;
      _logger.info('Klaviyo SDK initialized successfully');

      return this;
    } catch (e) {
      throw KlaviyoException('Failed to initialize SDK: $e');
    }
  }

  /// Set user profile information
  Future<void> setProfile(KlaviyoProfile profile) async {
    _ensureInitialized();

    try {
      _currentProfile = profile;
      _profileController.add(_currentProfile);

      await _persistProfile(profile);
      await _nativeWrapper.setProfile(profile);

      _logger.info('Profile updated: ${profile.email}');
    } catch (e) {
      throw KlaviyoException('Failed to set profile: $e');
    }
  }

  /// Set profile email
  Future<void> setEmail(String email) async {
    _ensureInitialized();

    final profile =
        _currentProfile?.copyWith(email: email) ?? KlaviyoProfile(email: email);
    await setProfile(profile);
  }

  /// Set profile phone number
  Future<void> setPhoneNumber(String phoneNumber) async {
    _ensureInitialized();

    final profile = _currentProfile?.copyWith(phoneNumber: phoneNumber) ??
        KlaviyoProfile(phoneNumber: phoneNumber);
    await setProfile(profile);
  }

  /// Set external ID for the profile
  Future<void> setExternalId(String externalId) async {
    _ensureInitialized();

    final profile = _currentProfile?.copyWith(externalId: externalId) ??
        KlaviyoProfile(externalId: externalId);
    await setProfile(profile);
  }

  /// Set profile properties
  Future<void> setProfileProperties(Map<String, dynamic> properties) async {
    _ensureInitialized();

    final profile = _currentProfile?.copyWith(properties: {
          ...(_currentProfile?.properties ?? {}),
          ...properties,
        }) ??
        KlaviyoProfile(properties: properties);

    await setProfile(profile);
  }

  /// Set profile location
  Future<void> setLocation(KlaviyoLocation location) async {
    _ensureInitialized();

    final profile = _currentProfile?.copyWith(location: location) ??
        KlaviyoProfile(location: location);
    await setProfile(profile);
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
  Future<void> registerForPushNotifications() async {
    _ensureInitialized();
    await _nativeWrapper.registerForPushNotifications();
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
    final tokenInfo = await _nativeWrapper.getPushToken();
    return tokenInfo?.token;
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
  }

  /// Unregister from in-app forms
  Future<void> unregisterFromInAppForms() async {
    _ensureInitialized();
    // TODO: Implement unregistration in native wrapper
    _logger.info('Unregistered from in-app forms');
  }

  /// Reset the current profile (useful for logout)
  Future<void> resetProfile() async {
    _ensureInitialized();

    _currentProfile = null;
    _profileController.add(null);

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('klaviyo_profile');

    await _nativeWrapper.resetProfile();
    _logger.info('Profile reset');
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
      throw KlaviyoException('SDK not initialized. Call initialize() first.');
    }
  }

  Future<void> _loadPersistedProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final profileJson = prefs.getString('klaviyo_profile');

      if (profileJson != null) {
        _currentProfile = KlaviyoProfile.fromJsonString(profileJson);
        _profileController.add(_currentProfile);
        _logger.debug('Loaded persisted profile');
      }
    } catch (e) {
      _logger.warning('Failed to load persisted profile: $e');
    }
  }

  Future<void> _persistProfile(KlaviyoProfile profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('klaviyo_profile', profile.toJsonString());
    } catch (e) {
      _logger.warning('Failed to persist profile: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _profileController.close();
    _nativeWrapper.dispose();
  }
}
