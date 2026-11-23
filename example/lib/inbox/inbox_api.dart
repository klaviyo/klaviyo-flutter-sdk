import 'package:klaviyo_flutter_sdk/klaviyo_flutter_sdk.dart';

/// Fetches one inbox page. Mirrors `KlaviyoSDK.fetchInboxPage`.
typedef InboxPageFetch = Future<InboxPage> Function({
  required int pageSize,
  String? cursor,
  required InboxReadFilter readFilter,
  required InboxArchiveFilter archiveFilter,
});

/// The SDK calls the Inbox tab makes, behind one seam so widget tests can
/// supply fakes instead of a platform channel.
class InboxApi {
  const InboxApi({
    required this.isInitialized,
    required this.fetchPage,
    required this.fetchUnreadCount,
    required this.updateMessageState,
    required this.onInboxChanged,
  });

  /// The real SDK, as the Inbox tab uses it.
  factory InboxApi.fromSdk(KlaviyoSDK sdk) => InboxApi(
        isInitialized: () => sdk.isInitialized,
        fetchPage: ({
          required int pageSize,
          String? cursor,
          required InboxReadFilter readFilter,
          required InboxArchiveFilter archiveFilter,
        }) =>
            sdk.fetchInboxPage(
          pageSize: pageSize,
          cursor: cursor,
          readFilter: readFilter,
          archiveFilter: archiveFilter,
        ),
        fetchUnreadCount: sdk.fetchInboxUnreadCount,
        updateMessageState: sdk.updateInboxMessageState,
        onInboxChanged: () => sdk.inboxChanged,
      );

  /// Whether the SDK has been initialized, so inbox calls can be made.
  final bool Function() isInitialized;

  /// Reads one page of the current company's messages.
  final InboxPageFetch fetchPage;

  /// Counts the current company's unread, unarchived messages.
  final Future<int> Function() fetchUnreadCount;

  /// Applies a state to one message. True when the device has the message.
  final Future<bool> Function(String messageId, InboxMessageState state)
      updateMessageState;

  /// The SDK's best-effort "the inbox may have changed" signal.
  final Stream<void> Function() onInboxChanged;
}
