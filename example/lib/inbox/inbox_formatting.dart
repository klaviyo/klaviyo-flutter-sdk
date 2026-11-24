import 'package:klaviyo_flutter_sdk/klaviyo_flutter_sdk.dart';

/// The string forms the Inbox tab shows for a message's raw fields.
///
/// The tab is a validation tool: it shows what the SDK returns rather than
/// prettifying it, so a mismatch between platforms is visible.
class InboxFormatting {
  const InboxFormatting._();

  /// A local date and time for a UTC instant, or null when there is none.
  static String? dateTime(DateTime? value) {
    if (value == null) return null;
    return value.toLocal().toString().split('.').first;
  }

  /// When the inbox orders by.
  ///
  /// Both timestamps are required, and the native page is already newest first,
  /// so this only renders the send time the message was ordered by.
  static String sortTime(InboxMessage message) =>
      dateTime(message.sentAt) ?? 'no time';

  /// The destination as `type` or `type url`, for a message or an action.
  static String destination(InboxDestination destination) {
    final url = destination.url;
    return url == null || url.isEmpty
        ? destination.type.rawValue
        : '${destination.type.rawValue} $url';
  }

  /// The media as `url` or `url (mime)`, or null when the message has none.
  static String? media(InboxMessage message) {
    final url = message.mediaUrl;
    if (url == null || url.isEmpty) return null;
    final type = message.mediaType;
    return type == null || type.isEmpty ? url : '$url ($type)';
  }

  /// The message's custom data, sorted by key so two reads compare by eye.
  static List<MapEntry<String, String>> customData(InboxMessage message) {
    final entries = message.customData.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return entries;
  }

  /// A short time-of-day for "at 10:41:02", for the pages headline.
  static String timeOnly(DateTime value) =>
      value.toLocal().toString().split(' ').last.split('.').first;
}
