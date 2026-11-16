/// Which messages an inbox page returns by read state.
///
/// Independent of [InboxArchiveFilter]: the two narrow the page together, so
/// "unread and not archived" is `unread` with the default archive filter.
enum InboxReadFilter {
  /// Read and unread messages. The default.
  all,

  /// Unread messages only.
  unread,

  /// Read messages only.
  read;

  /// The value the native bridge expects for this filter.
  ///
  /// Both native SDKs spell the values in lower case, so the Dart enum name is
  /// the wire value.
  String get wireValue => name;
}

/// Which messages an inbox page returns by archived state.
///
/// Archived messages are hidden by default: [active] is the default, so a page
/// holds only messages that are not archived unless a caller asks otherwise,
/// or asks for both.
enum InboxArchiveFilter {
  /// Messages that are not archived. The default.
  active,

  /// Archived messages only.
  archived,

  /// Archived and not archived messages.
  all;

  /// The value the native bridge expects for this filter.
  String get wireValue => name;
}
