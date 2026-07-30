import 'package:flutter/foundation.dart' show setEquals;

/// Consent sub-types supported on the email channel.
enum EmailConsent {
  /// Email marketing consent.
  marketing('marketing'),

  /// Email open-tracking consent.
  openTracking('open_tracking');

  const EmailConsent(this.wireValue);

  /// The value used to represent this consent type across the platform channel.
  ///
  /// Spelled out explicitly rather than derived from [name] so the wire format
  /// stays stable if the Dart member is ever renamed.
  final String wireValue;
}

/// Consent sub-types supported on the SMS and WhatsApp channels.
enum MessagingConsent {
  /// Marketing consent.
  marketing('marketing'),

  /// Transactional messaging consent.
  transactional('transactional');

  const MessagingConsent(this.wireValue);

  /// The value used to represent this consent type across the platform channel.
  final String wireValue;
}

/// The channels and consent sub-types to request in a [KlaviyoSubscription].
///
/// Each channel exposes only the consent sub-types the API supports for it, so
/// invalid combinations (transactional email, open-tracking SMS) cannot be
/// expressed. A `null` channel is left untouched.
class KlaviyoSubscriptionChannels {
  /// Consent sub-types to request on the email channel,
  /// or `null` to leave email untouched.
  final Set<EmailConsent>? email;

  /// Consent sub-types to request on the SMS channel,
  /// or `null` to leave SMS untouched.
  final Set<MessagingConsent>? sms;

  /// Consent sub-types to request on the WhatsApp channel,
  /// or `null` to leave WhatsApp untouched.
  final Set<MessagingConsent>? whatsapp;

  /// Creates the set of channels to request consent for.
  ///
  /// At least one channel must be given. Leaving all three `null` serializes to
  /// an empty object, which the natives read as "touch nothing" rather than as
  /// the broad grant — a silent no-op that is never what the caller meant. Use
  /// [KlaviyoSubscription.allAvailableMarketing] to request the broad grant.
  ///
  /// Example:
  /// ```dart
  /// const channels = KlaviyoSubscriptionChannels(
  ///   email: {EmailConsent.marketing, EmailConsent.openTracking},
  ///   sms: {MessagingConsent.marketing},
  /// );
  /// ```
  const KlaviyoSubscriptionChannels({
    this.email,
    this.sms,
    this.whatsapp,
  }) : assert(
          email != null || sms != null || whatsapp != null,
          'Specify at least one channel; use '
          'KlaviyoSubscription.allAvailableMarketing for the broad grant.',
        );

  /// Convert to JSON for the platform channel
  ///
  /// Null channels are omitted. An explicitly empty set is preserved — the
  /// native SDKs warn and drop the request in that case, and hiding it here
  /// would mask a developer error.
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};

    if (email != null) {
      data['email'] = email!.map((consent) => consent.wireValue).toList();
    }

    if (sms != null) {
      data['sms'] = sms!.map((consent) => consent.wireValue).toList();
    }

    if (whatsapp != null) {
      data['whatsapp'] = whatsapp!.map((consent) => consent.wireValue).toList();
    }

    return data;
  }

  @override
  String toString() {
    return 'KlaviyoSubscriptionChannels(email: $email, sms: $sms, '
        'whatsapp: $whatsapp)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is KlaviyoSubscriptionChannels &&
        setEquals(other.email, email) &&
        setEquals(other.sms, sms) &&
        setEquals(other.whatsapp, whatsapp);
  }

  @override
  int get hashCode {
    return Object.hash(
      _setHash(email),
      _setHash(sms),
      _setHash(whatsapp),
    );
  }

  static int _setHash<T>(Set<T>? set) =>
      set == null ? 0 : Object.hashAllUnordered(set);
}

/// Represents a request to subscribe the current profile to a Klaviyo list,
/// with optional per-channel marketing and transactional consent.
///
/// Set the profile's email and/or phone number **before** subscribing — the
/// native SDKs validate the request against the current profile's identifiers
/// and drop it with a warning if a requested channel has no identifier.
///
/// Push subscriptions are not created through this API.
class KlaviyoSubscription {
  /// ID of the Klaviyo list to subscribe the profile to.
  final String listId;

  /// Channels and consent sub-types to request, or `null` to defer to the
  /// server's default (see [KlaviyoSubscription.allAvailableMarketing]).
  final KlaviyoSubscriptionChannels? channels;

  /// Optional signup-source label stored as the consent record's `$source`.
  /// Omitted from the request when `null`.
  final String? customSource;

  /// Creates a subscription request for the given [channels].
  ///
  /// [channels] is required so that a broad consent grant is never the result
  /// of an omitted argument — use [KlaviyoSubscription.allAvailableMarketing]
  /// to request that deliberately.
  ///
  /// Example:
  /// ```dart
  /// final subscription = KlaviyoSubscription(
  ///   listId: 'ABC123',
  ///   channels: const KlaviyoSubscriptionChannels(
  ///     email: {EmailConsent.marketing},
  ///     sms: {MessagingConsent.marketing},
  ///   ),
  ///   customSource: 'Checkout screen',
  /// );
  /// ```
  const KlaviyoSubscription({
    required this.listId,
    required KlaviyoSubscriptionChannels this.channels,
    this.customSource,
  });

  /// Creates a subscription that grants marketing consent on every channel the
  /// profile has an identifier for (email → email marketing, phone → SMS
  /// marketing).
  ///
  /// Mirrors the server's default behavior when no consent object is sent, but
  /// requesting it is a deliberate call.
  ///
  /// Example:
  /// ```dart
  /// final subscription = KlaviyoSubscription.allAvailableMarketing(
  ///   listId: 'ABC123',
  /// );
  /// ```
  const KlaviyoSubscription.allAvailableMarketing({
    required this.listId,
    this.customSource,
  }) : channels = null;

  /// Convert to JSON for the platform channel
  ///
  /// An absent `channels` key means "all available marketing" — the natives
  /// reconstitute it through their own `allAvailableMarketing` factory.
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'listId': listId,
    };

    if (channels != null) {
      data['channels'] = channels!.toJson();
    }

    if (customSource != null) {
      data['customSource'] = customSource;
    }

    return data;
  }

  @override
  String toString() {
    return 'KlaviyoSubscription(listId: $listId, channels: $channels, '
        'customSource: $customSource)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is KlaviyoSubscription &&
        other.listId == listId &&
        other.channels == channels &&
        other.customSource == customSource;
  }

  @override
  int get hashCode => Object.hash(listId, channels, customSource);
}
