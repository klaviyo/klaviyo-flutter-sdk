import 'package:logging/logging.dart';

import 'inbox_message.dart';

/// One page of inbox messages, newest first.
class InboxPage {
  static final Logger _logger = Logger('KlaviyoSDK');

  /// The messages on this page.
  final List<InboxMessage> messages;

  /// Opaque token for the next page, or null on the last page.
  ///
  /// Pass it back as `cursor` to fetch the next page. Never parse or construct
  /// one: its contents are the native SDKs' business and its format may change.
  final String? nextCursor;

  const InboxPage({required this.messages, this.nextCursor});

  /// Create a page from the bridge map the native layer sends.
  ///
  /// A message missing a required field is logged and skipped rather than
  /// failing the page: the rest of the page and its [nextCursor] are still
  /// usable, so a consumer can keep paging past one bad record. The cursor is
  /// forwarded verbatim — it is opaque and never parsed here.
  factory InboxPage.fromMap(Map<String, dynamic> map) {
    final rawMessages = map['messages'];
    if (rawMessages is! List) {
      throw ArgumentError("Missing required field 'messages' in inbox page");
    }

    final messages = <InboxMessage>[];
    for (final raw in rawMessages) {
      if (raw is! Map) {
        _logger.warning('Ignoring inbox message that is not a map');
        continue;
      }
      final message = InboxMessage.tryFromMap(Map<String, dynamic>.from(raw));
      if (message == null) {
        // tryFromMap already rejected it; the reason is not repeated here so a
        // single bad record cannot flood the log with the same field names.
        _logger.warning('Ignoring inbox message with a missing required field');
        continue;
      }
      messages.add(message);
    }

    return InboxPage(
      messages: List.unmodifiable(messages),
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
