import 'dart:async';
import 'dart:io';

import 'package:meta/meta.dart';

import 'models/klaviyo_profile.dart';
import 'models/klaviyo_event.dart';
import 'models/in_app_form_config.dart';
import 'models/geofence.dart';
import 'models/form_lifecycle_event.dart';
import 'models/auth_token.dart';
import 'enums/klaviyo_log_level.dart';
import 'services/klaviyo_native_wrapper.dart';
import 'package:logging/logging.dart';

import 'exceptions/klaviyo_exception.dart';

/// Main Klaviyo SDK class for Flutter applications
/// This SDK acts as a thin wrapper around the native Klaviyo SDKs
/// All state is managed by the native SDKs - this class only forwards calls
class KlaviyoSDK {
  static final KlaviyoSDK _instance = KlaviyoSDK._internal();
  factory KlaviyoSDK() => _instance;
  KlaviyoSDK._internal() {
    // Required for per-logger level control. This is a global setting in
    // package:logging — without it, _logger.level is ignored and all loggers
    // share the root logger's level. Setting it to true is additive and is
    // the standard pattern for Dart libraries that manage their own log level.
    hierarchicalLoggingEnabled = true;
    _logger.level = Level.INFO;
  }

  // Native wrapper service — singleton, safe to construct eagerly
  final KlaviyoNativeWrapper _nativeWrapper = KlaviyoNativeWrapper();
  final Logger _logger = Logger('KlaviyoSDK');

  // State
  bool _isInitialized = false;
  String? _apiKey;

  // A single, permanent subscription to native `auth_token_requested` events,
  // attached lazily on first registration and never cancelled. The events flow
  // through a BufferedBroadcastStreamController, which queues events while it
  // has no listener; cancelling and re-subscribing would let a racing event
  // buffer during the gap and then replay a stale request id into a replacement
  // provider. Keeping one listener alive and gating on [_authTokenProvider]
  // avoids that — the handler consumes every event immediately and ignores any
  // that arrive while no provider is registered.
  StreamSubscription<Map<String, dynamic>>? _authTokenSubscription;
  AuthTokenProvider? _authTokenProvider;

  // Getters
  bool get isInitialized => _isInitialized;
  String? get apiKey => _apiKey;

  /// Initialize the Klaviyo SDK with your public API key.
  ///
  /// Can be called multiple times to re-initialize with a different API key,
  /// matching native Android and iOS SDK behavior.
  Future<KlaviyoSDK> initialize({
    required String apiKey,
  }) async {
    try {
      await _nativeWrapper.initialize(apiKey: apiKey);

      _apiKey = apiKey;
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

  /// Set a single profile attribute
  ///
  /// This is a convenience method to set a single profile property.
  /// To match the React Native SDK API.
  ///
  /// Example:
  /// ```dart
  /// await klaviyo.setProfileAttribute('first_name', 'John');
  /// ```
  Future<void> setProfileAttribute(String propertyKey, dynamic value) async {
    await setProfileProperties({propertyKey: value});
  }

  /// Create a new event to track a profile's activity.
  Future<void> createEvent(KlaviyoEvent event) async {
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
  ///     log('Token received: $token');
  ///   }
  /// });
  /// ```
  Future<void> registerForPushNotifications() async {
    _ensureInitialized();
    await _nativeWrapper.registerForPushNotifications();
  }

  /// Set push token
  Future<void> setPushToken(String token) async {
    _ensureInitialized();
    await _nativeWrapper.setPushToken(token);
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
    try {
      await _nativeWrapper.registerForInAppForms(
        configuration: configuration?.toJson(),
      );
      _logger.info('Registered for in-app forms');
    } on KlaviyoException catch (e) {
      _logger.warning('Failed to register for in-app forms: ${e.message}');
    }
  }

  /// Unregister from in-app forms
  Future<void> unregisterFromInAppForms() async {
    _ensureInitialized();
    try {
      await _nativeWrapper.unregisterFromInAppForms();
      _logger.info('Unregistered from in-app forms');
    } on KlaviyoException catch (e) {
      _logger.warning('Failed to unregister from in-app forms: ${e.message}');
    }
  }

  // ============================================================================
  // Auth Token (JWT) — personalized In-App Forms
  // ============================================================================

  /// Registers a provider that the native SDK invokes when it needs to acquire
  /// or refresh an authentication token (JWT) for the current end-user.
  ///
  /// The Flutter SDK is a thin bridge: all token state management (caching,
  /// proactive refresh, timeouts, WebView injection, and token logging) lives
  /// in the native iOS and Android SDKs. This wrapper only relays [provider]
  /// invocations across the platform channel.
  ///
  /// Calling this replaces any previously-registered provider. See
  /// [AuthTokenProvider] for the provider contract, including how to signal a
  /// connectivity failure so the native SDK can retry on reconnect.
  Future<void> registerAuthTokenProvider(AuthTokenProvider provider) async {
    _ensureInitialized();

    // Attach the single permanent listener once (see [_authTokenSubscription]).
    _authTokenSubscription ??=
        _nativeWrapper.onAuthTokenRequested.listen(_handleAuthTokenRequest);

    // Re-register: tear down the native provider first so it drains any pending
    // requests before the replacement takes over. The Dart listener stays put;
    // swapping [_authTokenProvider] is what redirects future requests.
    if (_authTokenProvider != null) {
      try {
        await _nativeWrapper.unregisterAuthTokenProvider();
      } catch (e) {
        _logger.warning('Failed to tear down previous auth token provider: $e');
      }
    }

    _authTokenProvider = provider;

    try {
      await _nativeWrapper.registerAuthTokenProvider();
      _logger.info('Auth token provider registered');
    } catch (e) {
      _authTokenProvider = null;
      throw KlaviyoException('Failed to register auth token provider: $e');
    }
  }

  /// Detaches a previously-registered auth token provider — e.g. on logout.
  ///
  /// Clears the active provider (so any further native request is ignored) and
  /// forwards to the native SDK's `unregisterAuthTokenProvider()`, which clears
  /// the provider and tears down its token state. Re-registering afterward
  /// works normally. The permanent event listener is intentionally left
  /// attached (see [_authTokenSubscription]).
  Future<void> unregisterAuthTokenProvider() async {
    _ensureInitialized();

    _authTokenProvider = null;

    try {
      await _nativeWrapper.unregisterAuthTokenProvider();
      _logger.info('Auth token provider unregistered');
    } catch (e) {
      throw KlaviyoException('Failed to unregister auth token provider: $e');
    }
  }

  /// Handles a single native `auth_token_requested` event: invokes the active
  /// host provider and relays the outcome back to native. Never logs the token.
  Future<void> _handleAuthTokenRequest(Map<String, dynamic> event) async {
    final id = parseAuthTokenRequestedEventId(event);
    if (id == null) {
      _logger.warning('Ignoring auth token request with invalid id');
      return;
    }

    // Gate on the currently-registered provider. An event that races an
    // unregister (or otherwise arrives with no provider) is answered with a
    // failure so the native side resolves immediately instead of waiting for
    // its timeout — and is never replayed into a later provider.
    final provider = _authTokenProvider;
    if (provider == null) {
      _logger.info('Auth token request received with no active provider');
      await _nativeWrapper.respondToAuthTokenRequest(
        id,
        error: 'No auth token provider registered',
      );
      return;
    }
    _logger.info('Auth token provider event received');

    try {
      final jwt = await provider();
      if (jwt.isEmpty) {
        // Route an empty resolution through the failure path so native gets a
        // clear signal rather than a bogus "success".
        throw const KlaviyoException(
          'Auth token provider resolved without a token',
        );
      }
      await _nativeWrapper.respondToAuthTokenRequest(id, jwt: jwt);
      _logger.info('Auth token response sent to native');
    } catch (error) {
      final classified = classifyAuthTokenProviderError(error);
      _logger.warning(
        'Auth token provider failed for request $id: ${classified.message}',
      );
      try {
        await _nativeWrapper.respondToAuthTokenRequest(
          id,
          error: classified.message,
          isConnectivityError: classified.isConnectivityError,
        );
      } catch (e) {
        _logger.warning('Failed to send auth token failure to native: $e');
      }
    }
  }

  /// Begin monitoring geofences configured in your Klaviyo account
  /// Requires location permissions to be granted by user
  Future<void> registerGeofencing() async {
    _ensureInitialized();
    try {
      await _nativeWrapper.registerGeofencing();
      _logger.info('Registered for geofencing');
    } on KlaviyoException catch (e) {
      _logger.warning('Failed to register for geofencing: ${e.message}');
    }
  }

  /// Stop monitoring all geofences
  Future<void> unregisterGeofencing() async {
    _ensureInitialized();
    try {
      await _nativeWrapper.unregisterGeofencing();
      _logger.info('Unregistered from geofencing');
    } on KlaviyoException catch (e) {
      _logger.warning('Failed to unregister from geofencing: ${e.message}');
    }
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
    try {
      return await _nativeWrapper.getCurrentGeofences();
    } on KlaviyoException catch (e) {
      _logger.warning('Failed to get current geofences: ${e.message}');
      return [];
    }
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
      _logger.warning('[DeepLink SDK] Error: Empty tracking link provided');
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
      _logger.warning('Failed to handle universal tracking link $url: $e');
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

  /// Set log level for Flutter-side logging only
  /// Note: This only affects Flutter console logs, not native SDK logs
  void setLogLevel(KlaviyoLogLevel logLevel) {
    _logger.level = logLevel.toLevel();
  }

  /// Get push notification events stream
  Stream<Map<String, dynamic>> get onPushNotification =>
      _nativeWrapper.onPushNotification;

  /// Get form events stream
  Stream<Map<String, dynamic>> get onFormEvent => _nativeWrapper.onFormEvent;

  /// Get typed form lifecycle events stream.
  ///
  /// Filters for `form_lifecycle_event` type and parses the native map into a
  /// [FormLifecycleEvent]. Malformed events are logged and dropped rather than
  /// crashing the stream.
  Stream<FormLifecycleEvent> get onFormLifecycleEvent =>
      _nativeWrapper.onFormEvent
          .where((event) => event['type'] == 'form_lifecycle_event')
          .expand((event) {
        try {
          return [FormLifecycleEvent.fromMap(event)];
        } catch (e) {
          _logger.warning('Dropping malformed form lifecycle event: $e');
          return [];
        }
      });

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
