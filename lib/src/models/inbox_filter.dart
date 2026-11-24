import 'inbox_filters.dart';

/// Which messages a bulk call such as [KlaviyoSDK.updateInboxMessageStates]
/// applies to, by read state and archived state.
///
/// Unlike [KlaviyoSDK.fetchInboxPage], whose archive filter leaves archived
/// messages out unless it asks for them, a filter has no default: a call that
/// changes many messages always says which ones. Build one with
/// [InboxFilter.where], or use [InboxFilter.allMessages] for every message.
class InboxFilter {
  /// Whether read messages, unread messages, or both match.
  final InboxReadFilter readFilter;

  /// Whether archived messages, messages that are not archived, or both match.
  final InboxArchiveFilter archiveFilter;

  const InboxFilter({
    required this.readFilter,
    required this.archiveFilter,
  });

  /// Matches every message, read or unread, archived or not.
  static const InboxFilter allMessages = InboxFilter(
    readFilter: InboxReadFilter.all,
    archiveFilter: InboxArchiveFilter.all,
  );

  /// Matches the messages in the given read and archive states.
  ///
  /// [read] narrows on whether a message is read; [archive] on whether it is
  /// archived. They are independent, so
  /// `where(InboxReadFilter.unread, InboxArchiveFilter.active)` means "unread
  /// and not archived".
  static InboxFilter where(
    InboxReadFilter read,
    InboxArchiveFilter archive,
  ) =>
      InboxFilter(readFilter: read, archiveFilter: archive);

  /// The map the native bridge expects.
  Map<String, dynamic> toMap() => {
        'readFilter': readFilter.wireValue,
        'archiveFilter': archiveFilter.wireValue,
      };

  @override
  String toString() => 'InboxFilter(read: ${readFilter.name}, '
      'archive: ${archiveFilter.name})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InboxFilter &&
          other.readFilter == readFilter &&
          other.archiveFilter == archiveFilter;

  @override
  int get hashCode => Object.hash(readFilter, archiveFilter);
}
