import 'inbox_action.dart';
import 'inbox_destination.dart';

/// Where an inbox message came from.
///
/// Like [InboxDestinationType], this is a raw-value type rather than a Dart
/// enum so a later native release can add a source without breaking callers.
class InboxMessageSource {
  /// The value the native SDKs use for this source.
  ///
  /// One of `captured`, `server` or `external` today, but callers must not
  /// assume that set is closed.
  final String rawValue;

  const InboxMessageSource(this.rawValue);

  /// Captured on this device from a delivered push.
  static const InboxMessageSource captured = InboxMessageSource('captured');

  /// Fetched from Klaviyo's servers.
  static const InboxMessageSource server = InboxMessageSource('server');

  /// Supplied by the host app.
  static const InboxMessageSource external = InboxMessageSource('external');

  @override
  String toString() => 'InboxMessageSource($rawValue)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InboxMessageSource && other.rawValue == rawValue;

  @override
  int get hashCode => rawValue.hashCode;
}

/// A message in the Mobile Inbox.
///
/// This is the normalized shape both native SDKs expose. It carries no raw
/// APNs/FCM payload and no persistence types: only the fields below, already
/// mapped by the native layer.
class InboxMessage {
  /// Opaque message ID. Stable for the life of the message.
  final String id;

  /// The message title, when the push carried one.
  final String? title;

  /// The message body, when the push carried one.
  final String? body;

  /// What tapping the message does.
  final InboxDestination defaultDestination;

  /// The media URL to display alongside the message.
  ///
  /// The host downloads and caches the media; only the URL is stored.
  final String? mediaUrl;

  /// The media's MIME type, when known.
  final String? mediaType;

  /// The push's custom key/value data, as strings.
  final Map<String, String> customData;

  /// The message's action buttons, in the order the push configured them.
  final List<InboxAction> actions;

  /// Server send time, when known.
  ///
  /// UTC: the native SDKs report epoch milliseconds, which denote an instant.
  /// Call [DateTime.toLocal] to render it in the device's time zone.
  final DateTime? sentAt;

  /// When this device captured the message.
  ///
  /// Nullable because the Android SDK's `receivedAt` is nullable; iOS always
  /// populates it. UTC, like [sentAt].
  final DateTime? receivedAt;

  /// The push's collapse identifier, where the platform exposes one.
  final String? collapseId;

  /// The push's app-icon badge count, when the payload set one.
  ///
  /// The iOS SDK models the badge as a struct; the native bridge flattens it to
  /// this single integer, preferring the configured value and falling back to
  /// `aps.badge`. The inbox's own unread count is
  /// `KlaviyoSDK.inbox.fetchUnreadCount()`, not this field.
  final int? badge;

  /// Whether the message has been read.
  final bool isRead;

  /// Whether the message has been archived.
  final bool isArchived;

  /// Where the message came from.
  final InboxMessageSource source;

  const InboxMessage({
    required this.id,
    this.title,
    this.body,
    required this.defaultDestination,
    this.mediaUrl,
    this.mediaType,
    this.customData = const {},
    this.actions = const [],
    this.sentAt,
    this.receivedAt,
    this.collapseId,
    this.badge,
    required this.isRead,
    required this.isArchived,
    required this.source,
  });

  /// Create a message from the bridge map the native layer sends.
  ///
  /// Required fields are validated: a map missing one cannot be turned into a
  /// message and throws an [ArgumentError] rather than yielding a message with
  /// invented values. Optional fields tolerate absence. Timestamps arrive as
  /// epoch milliseconds and are converted to UTC [DateTime]s.
  factory InboxMessage.fromMap(Map<String, dynamic> map) {
    final destination = map['defaultDestination'];
    if (destination is! Map) {
      throw ArgumentError(
        "Missing required field 'defaultDestination' in inbox message",
      );
    }

    return InboxMessage(
      id: _requireString(map, 'id'),
      title: map['title'] as String?,
      body: map['body'] as String?,
      defaultDestination: InboxDestination.fromMap(
        Map<String, dynamic>.from(destination),
      ),
      mediaUrl: map['mediaUrl'] as String?,
      mediaType: map['mediaType'] as String?,
      customData: _stringMap(map['customData']),
      actions: _actionList(map['actions']),
      sentAt: _epochMillis(map['sentAt']),
      receivedAt: _epochMillis(map['receivedAt']),
      collapseId: map['collapseId'] as String?,
      badge: map['badge'] as int?,
      isRead: _requireBool(map, 'isRead'),
      isArchived: _requireBool(map, 'isArchived'),
      source: InboxMessageSource(_requireString(map, 'source')),
    );
  }

  /// Convert to the bridge map shape.
  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'body': body,
        'defaultDestination': defaultDestination.toMap(),
        'mediaUrl': mediaUrl,
        'mediaType': mediaType,
        'customData': customData,
        'actions': actions.map((action) => action.toMap()).toList(),
        'sentAt': sentAt?.millisecondsSinceEpoch,
        'receivedAt': receivedAt?.millisecondsSinceEpoch,
        'collapseId': collapseId,
        'badge': badge,
        'isRead': isRead,
        'isArchived': isArchived,
        'source': source.rawValue,
      };

  /// Reads a required non-empty string, throwing a descriptive error when it is
  /// missing or the wrong type.
  static String _requireString(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is! String || value.isEmpty) {
      throw ArgumentError("Missing required field '$key' in inbox message");
    }
    return value;
  }

  static bool _requireBool(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is! bool) {
      throw ArgumentError("Missing required field '$key' in inbox message");
    }
    return value;
  }

  /// Converts a bridge map to `Map<String, String>`.
  ///
  /// The native contract is already `Map<String, String>`; keys and values are
  /// coerced through `toString()` so one unexpected scalar cannot drop a whole
  /// page of messages.
  static Map<String, String> _stringMap(dynamic value) {
    if (value is! Map) return const {};
    return value.map(
      (key, entryValue) => MapEntry(key.toString(), entryValue.toString()),
    );
  }

  /// Converts the bridge action list, preserving its order.
  static List<InboxAction> _actionList(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((action) => InboxAction.fromMap(Map<String, dynamic>.from(action)))
        .toList(growable: false);
  }

  /// Converts epoch milliseconds to a UTC [DateTime].
  static DateTime? _epochMillis(dynamic value) {
    if (value is! int) return null;
    return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
  }

  @override
  String toString() => 'InboxMessage(id: $id, source: ${source.rawValue}, '
      'isRead: $isRead, isArchived: $isArchived)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! InboxMessage) return false;

    if (other.id != id ||
        other.title != title ||
        other.body != body ||
        other.defaultDestination != defaultDestination ||
        other.mediaUrl != mediaUrl ||
        other.mediaType != mediaType ||
        other.sentAt != sentAt ||
        other.receivedAt != receivedAt ||
        other.collapseId != collapseId ||
        other.badge != badge ||
        other.isRead != isRead ||
        other.isArchived != isArchived ||
        other.source != source ||
        other.customData.length != customData.length ||
        other.actions.length != actions.length) {
      return false;
    }

    for (final entry in customData.entries) {
      if (other.customData[entry.key] != entry.value) return false;
    }
    for (var i = 0; i < actions.length; i++) {
      if (other.actions[i] != actions[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
        id,
        title,
        body,
        defaultDestination,
        mediaUrl,
        mediaType,
        // MapEntry has identity equality, so hash each key/value pair explicitly
        // rather than the entries themselves.
        Object.hashAllUnordered(
          customData.entries
              .map((entry) => Object.hash(entry.key, entry.value)),
        ),
        Object.hashAll(actions),
        sentAt,
        receivedAt,
        collapseId,
        badge,
        isRead,
        isArchived,
        source,
      );
}
