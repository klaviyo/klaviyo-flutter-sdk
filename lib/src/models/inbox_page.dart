import 'inbox_message.dart';

/// One page of inbox messages, newest first.
class InboxPage {
  /// The messages on this page.
  final List<InboxMessage> messages;

  /// Opaque token for the next page, or null on the last page.
  ///
  /// Pass it back as `cursor` to fetch the next page. Never parse or construct
  /// one: its contents are the native SDKs' business and its format may change.
  final String? nextCursor;

  const InboxPage({required this.messages, this.nextCursor});

  /// Create a page from the bridge map the native layer sends.
  factory InboxPage.fromMap(Map<String, dynamic> map) {
    final rawMessages = map['messages'];
    if (rawMessages is! List) {
      throw ArgumentError("Missing required field 'messages' in inbox page");
    }

    return InboxPage(
      messages: rawMessages
          .whereType<Map>()
          .map(
            (message) =>
                InboxMessage.fromMap(Map<String, dynamic>.from(message)),
          )
          .toList(growable: false),
      nextCursor: map['nextCursor'] as String?,
    );
  }

  /// Convert to the bridge map shape.
  Map<String, dynamic> toMap() => {
        'messages': messages.map((message) => message.toMap()).toList(),
        'nextCursor': nextCursor,
      };

  @override
  String toString() =>
      'InboxPage(messages: ${messages.length}, nextCursor: $nextCursor)';
}
