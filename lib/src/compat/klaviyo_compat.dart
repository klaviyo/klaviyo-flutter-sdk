import '../klaviyo_sdk.dart';
import '../models/klaviyo_event.dart';
import '../models/klaviyo_profile.dart';

/// Backwards-compatible wrapper that mirrors the `klaviyo_flutter` community
/// package API surface.
///
/// This class is provided **solely** to ease migration from the
/// `klaviyo_flutter` community package to the official `klaviyo_flutter_sdk`.
/// It delegates every call to [KlaviyoSDK] under the hood.
///
/// **Migration guide – swap your import and entry-point:**
///
/// ```dart
/// // Before (klaviyo_flutter)
/// import 'package:klaviyo_flutter/klaviyo_flutter.dart';
/// await Klaviyo.instance.initialize('KEY');
///
/// // After (klaviyo_flutter_sdk)
/// import 'package:klaviyo_flutter_sdk/klaviyo_flutter_sdk.dart';
/// await KlaviyoSDK().initialize(apiKey: 'KEY');
/// ```
///
/// All methods on this class will be removed in version 1.0. Please migrate to
/// the [KlaviyoSDK] API at your earliest convenience.
@Deprecated(
  'Use KlaviyoSDK instead. '
  'This class is provided for migration from the klaviyo_flutter community '
  'package and will be removed in 1.0.',
)
class Klaviyo {
  Klaviyo._();

  static final Klaviyo _instance = Klaviyo._();

  /// Returns the singleton [Klaviyo] instance.
  ///
  /// Migrate to [KlaviyoSDK] factory constructor:
  /// ```dart
  /// // Before
  /// Klaviyo.instance.setEmail('a@b.com');
  /// // After
  /// KlaviyoSDK().setEmail('a@b.com');
  /// ```
  @Deprecated(
    'Use KlaviyoSDK() instead. '
    'Will be removed in 1.0.',
  )
  static Klaviyo get instance => _instance;

  final KlaviyoSDK _sdk = KlaviyoSDK();

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  /// Whether the SDK has been initialized.
  @Deprecated(
    'Use KlaviyoSDK().isInitialized instead. '
    'Will be removed in 1.0.',
  )
  bool get isInitialized => _sdk.isInitialized;

  /// Initialize the Klaviyo SDK with your public API key.
  ///
  /// Migrate to:
  /// ```dart
  /// await KlaviyoSDK().initialize(apiKey: 'YOUR_KEY');
  /// ```
  @Deprecated(
    'Use KlaviyoSDK().initialize(apiKey: apiKey) instead. '
    'Will be removed in 1.0.',
  )
  Future<void> initialize(String apiKey) => _sdk.initialize(apiKey: apiKey);

  // ---------------------------------------------------------------------------
  // Event tracking
  // ---------------------------------------------------------------------------

  /// Log an event with an optional metadata map.
  ///
  /// Migrate to:
  /// ```dart
  /// await KlaviyoSDK().createEvent(
  ///   KlaviyoEvent.custom(metric: 'Event Name', properties: {...}),
  /// );
  /// ```
  @Deprecated(
    'Use KlaviyoSDK().createEvent(KlaviyoEvent.custom(...)) instead. '
    'Will be removed in 1.0.',
  )
  Future<String> logEvent(String name, [Map<String, dynamic>? metaData]) async {
    await _sdk.createEvent(
      KlaviyoEvent.custom(metric: name, properties: metaData),
    );
    // The community SDK returned a platform-specific result string.
    // We return an empty string for API compatibility.
    return '';
  }

  // ---------------------------------------------------------------------------
  // Push notifications
  // ---------------------------------------------------------------------------

  /// Send a push token to Klaviyo.
  ///
  /// Migrate to:
  /// ```dart
  /// await KlaviyoSDK().setPushToken(token);
  /// ```
  @Deprecated(
    'Use KlaviyoSDK().setPushToken(token) instead. '
    'Will be removed in 1.0.',
  )
  Future<void> sendTokenToKlaviyo(String token) => _sdk.setPushToken(token);

  /// Check if a push notification payload originated from Klaviyo.
  ///
  /// There is no direct equivalent in [KlaviyoSDK]. If you need this check,
  /// you can inline it: `message.containsKey('_k')`.
  @Deprecated(
    "Inline the check: message.containsKey('_k'). "
    'Will be removed in 1.0.',
  )
  bool isKlaviyoPush(Map<String, dynamic> message) => message.containsKey('_k');

  /// Handle a push notification payload.
  ///
  /// In the official SDK, push handling is performed automatically by the
  /// native layer. This method is a no-op and always returns `true`.
  ///
  /// You can safely remove calls to this method.
  @Deprecated(
    'Push handling is now automatic in the native layer. '
    'Remove calls to handlePush(). '
    'Will be removed in 1.0.',
  )
  Future<bool> handlePush(Map<String, dynamic> message) async => true;

  // ---------------------------------------------------------------------------
  // Profile management
  // ---------------------------------------------------------------------------

  /// Set a complete profile.
  ///
  /// Migrate to:
  /// ```dart
  /// await KlaviyoSDK().setProfile(profile);
  /// ```
  @Deprecated(
    'Use KlaviyoSDK().setProfile(profile) instead. '
    'Will be removed in 1.0.',
  )
  Future<String> updateProfile(KlaviyoProfile profile) async {
    await _sdk.setProfile(profile);
    return '';
  }

  /// Set the external ID of the currently tracked profile.
  @Deprecated(
    'Use KlaviyoSDK().setExternalId(id) instead. '
    'Will be removed in 1.0.',
  )
  Future<void> setExternalId(String id) => _sdk.setExternalId(id);

  /// Get the external ID of the currently tracked profile.
  @Deprecated(
    'Use KlaviyoSDK().getExternalId() instead. '
    'Will be removed in 1.0.',
  )
  Future<String?> getExternalId() => _sdk.getExternalId();

  /// Clear all stored profile identifiers and start a new tracked profile.
  @Deprecated(
    'Use KlaviyoSDK().resetProfile() instead. '
    'Will be removed in 1.0.',
  )
  Future<void> resetProfile() => _sdk.resetProfile();

  /// Set the email of the currently tracked profile.
  @Deprecated(
    'Use KlaviyoSDK().setEmail(email) instead. '
    'Will be removed in 1.0.',
  )
  Future<void> setEmail(String email) => _sdk.setEmail(email);

  /// Get the email of the currently tracked profile.
  @Deprecated(
    'Use KlaviyoSDK().getEmail() instead. '
    'Will be removed in 1.0.',
  )
  Future<String?> getEmail() => _sdk.getEmail();

  /// Set the phone number of the currently tracked profile.
  @Deprecated(
    'Use KlaviyoSDK().setPhoneNumber(phoneNumber) instead. '
    'Will be removed in 1.0.',
  )
  Future<void> setPhoneNumber(String phoneNumber) =>
      _sdk.setPhoneNumber(phoneNumber);

  /// Get the phone number of the currently tracked profile.
  @Deprecated(
    'Use KlaviyoSDK().getPhoneNumber() instead. '
    'Will be removed in 1.0.',
  )
  Future<String?> getPhoneNumber() => _sdk.getPhoneNumber();

  // ---------------------------------------------------------------------------
  // Individual profile attribute setters
  //
  // The community SDK exposed these as dedicated methods. In the official SDK,
  // use setProfileAttribute() or setProfile() with a KlaviyoProfile instead.
  // ---------------------------------------------------------------------------

  /// Set the first name of the currently tracked profile.
  ///
  /// Migrate to:
  /// ```dart
  /// await KlaviyoSDK().setProfileAttribute('first_name', firstName);
  /// ```
  @Deprecated(
    "Use KlaviyoSDK().setProfileAttribute('first_name', name) instead. "
    'Will be removed in 1.0.',
  )
  Future<void> setFirstName(String firstName) =>
      _sdk.setProfileAttribute('first_name', firstName);

  /// Set the last name of the currently tracked profile.
  @Deprecated(
    "Use KlaviyoSDK().setProfileAttribute('last_name', name) instead. "
    'Will be removed in 1.0.',
  )
  Future<void> setLastName(String lastName) =>
      _sdk.setProfileAttribute('last_name', lastName);

  /// Set the organization of the currently tracked profile.
  @Deprecated(
    "Use KlaviyoSDK().setProfileAttribute('organization', org) instead. "
    'Will be removed in 1.0.',
  )
  Future<void> setOrganization(String organization) =>
      _sdk.setProfileAttribute('organization', organization);

  /// Set the title of the currently tracked profile.
  @Deprecated(
    "Use KlaviyoSDK().setProfileAttribute('title', title) instead. "
    'Will be removed in 1.0.',
  )
  Future<void> setTitle(String title) =>
      _sdk.setProfileAttribute('title', title);

  /// Set the image URL of the currently tracked profile.
  @Deprecated(
    "Use KlaviyoSDK().setProfileAttribute('image', url) instead. "
    'Will be removed in 1.0.',
  )
  Future<void> setImage(String image) =>
      _sdk.setProfileAttribute('image', image);

  // ---------------------------------------------------------------------------
  // Location setters
  // ---------------------------------------------------------------------------

  /// Set address line 1 of the currently tracked profile.
  @Deprecated(
    "Use KlaviyoSDK().setProfileAttribute('address1', addr) instead. "
    'Will be removed in 1.0.',
  )
  Future<void> setAddress1(String address) =>
      _sdk.setProfileAttribute('address1', address);

  /// Set address line 2 of the currently tracked profile.
  @Deprecated(
    "Use KlaviyoSDK().setProfileAttribute('address2', addr) instead. "
    'Will be removed in 1.0.',
  )
  Future<void> setAddress2(String address) =>
      _sdk.setProfileAttribute('address2', address);

  /// Set the city of the currently tracked profile.
  @Deprecated(
    "Use KlaviyoSDK().setProfileAttribute('city', city) instead. "
    'Will be removed in 1.0.',
  )
  Future<void> setCity(String city) => _sdk.setProfileAttribute('city', city);

  /// Set the country of the currently tracked profile.
  @Deprecated(
    "Use KlaviyoSDK().setProfileAttribute('country', country) instead. "
    'Will be removed in 1.0.',
  )
  Future<void> setCountry(String country) =>
      _sdk.setProfileAttribute('country', country);

  /// Set the latitude of the currently tracked profile.
  @Deprecated(
    "Use KlaviyoSDK().setProfileAttribute('latitude', lat) instead. "
    'Will be removed in 1.0.',
  )
  Future<void> setLatitude(double latitude) =>
      _sdk.setProfileAttribute('latitude', latitude);

  /// Set the longitude of the currently tracked profile.
  @Deprecated(
    "Use KlaviyoSDK().setProfileAttribute('longitude', lng) instead. "
    'Will be removed in 1.0.',
  )
  Future<void> setLongitude(double longitude) =>
      _sdk.setProfileAttribute('longitude', longitude);

  /// Set the region of the currently tracked profile.
  @Deprecated(
    "Use KlaviyoSDK().setProfileAttribute('region', region) instead. "
    'Will be removed in 1.0.',
  )
  Future<void> setRegion(String region) =>
      _sdk.setProfileAttribute('region', region);

  /// Set the zip code of the currently tracked profile.
  @Deprecated(
    "Use KlaviyoSDK().setProfileAttribute('zip', zip) instead. "
    'Will be removed in 1.0.',
  )
  Future<void> setZip(String zip) => _sdk.setProfileAttribute('zip', zip);

  /// Set the timezone of the currently tracked profile.
  @Deprecated(
    "Use KlaviyoSDK().setProfileAttribute('timezone', tz) instead. "
    'Will be removed in 1.0.',
  )
  Future<void> setTimezone(String timezone) =>
      _sdk.setProfileAttribute('timezone', timezone);

  /// Set a custom attribute on the currently tracked profile.
  ///
  /// Migrate to:
  /// ```dart
  /// await KlaviyoSDK().setProfileAttribute(key, value);
  /// ```
  @Deprecated(
    'Use KlaviyoSDK().setProfileAttribute(key, value) instead. '
    'Will be removed in 1.0.',
  )
  Future<void> setCustomAttribute(String key, String value) =>
      _sdk.setProfileAttribute(key, value);

  // ---------------------------------------------------------------------------
  // Badge count
  // ---------------------------------------------------------------------------

  /// Set the app icon badge count (iOS only).
  ///
  /// Migrate to:
  /// ```dart
  /// KlaviyoSDK().setBadgeCount(count);
  /// ```
  @Deprecated(
    'Use KlaviyoSDK().setBadgeCount(count) instead. '
    'Will be removed in 1.0.',
  )
  Future<void> setBadgeCount(int count) async => _sdk.setBadgeCount(count);
}
