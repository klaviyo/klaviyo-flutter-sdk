import 'package:flutter/material.dart';
import 'package:klaviyo_flutter_sdk/klaviyo_flutter_sdk.dart';

import '../inbox/inbox_api.dart';
import '../inbox/inbox_controller.dart';
import '../inbox/inbox_formatting.dart';
import '../widgets/test_id.dart';

/// Exercises the SDK's public Mobile Inbox API: `fetchInboxPage` with a page
/// size and cursor, `fetchInboxUnreadCount`, `updateInboxMessageState` for read,
/// unread, archive and unarchive, and the `inboxChanged` stream.
///
/// This is a validation screen, not a customer inbox: it never opens deep links
/// or runs message actions.
class InboxTab extends StatefulWidget {
  const InboxTab({super.key, this.api});

  /// The SDK calls to make. Defaults to the real SDK; tests pass fakes.
  final InboxApi? api;

  @override
  State<InboxTab> createState() => _InboxTabState();
}

class _InboxTabState extends State<InboxTab> {
  late final InboxController _controller;
  late final InboxApi _api;
  bool _diagnosticsExpanded = false;
  final Set<String> _expandedDetails = {};

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? InboxApi.fromSdk(KlaviyoSDK());
    _controller = InboxController(api: _api)..addListener(_onChanged);
    _controller.start();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inbox'),
        actions: [
          TestId(
            'inbox_page_size_stepper',
            merge: false,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Page ${_controller.pageSize}',
                  semanticsLabel: 'Page size ${_controller.pageSize}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                IconButton(
                  tooltip: 'Smaller pages',
                  onPressed: _controller.pageSize <= InboxController.minPageSize
                      ? null
                      : () => _controller.setPageSize(_controller.pageSize - 1),
                  icon: const Icon(Icons.remove),
                ),
                IconButton(
                  tooltip: 'Larger pages',
                  onPressed: _controller.pageSize >= InboxController.maxPageSize
                      ? null
                      : () => _controller.setPageSize(_controller.pageSize + 1),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ),
          TestId(
            'inbox_refresh_button',
            merge: false,
            child: IconButton(
              tooltip: 'Read the inbox again',
              onPressed: _controller.refresh,
              icon: const Icon(Icons.refresh),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _controller.refresh,
        child: ListView(
          children: [
            _summaryCard(context),
            _filters(context),
            if (_controller.stateNotice != null) _stateNotice(context),
            if (_controller.errorMessage != null) _error(context),
            ..._messageList(context),
            _footer(context),
          ],
        ),
      ),
    );
  }

  // MARK: Summary and diagnostics

  Widget _summaryCard(BuildContext context) {
    final theme = Theme.of(context);
    final headline = !_controller.hasLoaded
        ? 'Not fetched yet'
        : '${_controller.messages.length} '
            '${noun(_controller.messages.length, 'message')} in '
            '${_controller.pagesLoaded} '
            '${noun(_controller.pagesLoaded, 'page')}';

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TestId(
                    'inbox_pages_result',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(headline, style: theme.textTheme.titleMedium),
                        if (_controller.lastChangeAt != null)
                          Text(
                            'last change '
                            '${InboxFormatting.timeOnly(_controller.lastChangeAt!)}',
                            style: theme.textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                ),
                if (_controller.unreadCount > 0)
                  TestId(
                    'inbox_unread_badge',
                    merge: false,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: const BoxDecoration(
                        color: Color(0xFFD32F2F),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${_controller.unreadCount}',
                        semanticsLabel:
                            '${_controller.unreadCount} unread, not archived',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const Divider(height: 20),
            TestId(
              'inbox_diagnostics_toggle',
              child: InkWell(
                onTap: () => setState(
                  () => _diagnosticsExpanded = !_diagnosticsExpanded,
                ),
                child: Row(
                  children: [
                    Icon(
                      _diagnosticsExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                    ),
                    const SizedBox(width: 4),
                    Text('Diagnostics', style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
            ),
            if (_diagnosticsExpanded) ...[
              const SizedBox(height: 8),
              _labeled(
                context,
                'SDK initialized',
                _api.isInitialized() ? 'Yes' : 'No',
                'inbox_sdk_initialized_text',
              ),
              _labeled(
                context,
                'Change signals',
                '${_controller.changeSignalCount}',
                'inbox_change_signal_count_text',
              ),
              _labeled(
                context,
                'Last change',
                InboxFormatting.dateTime(_controller.lastChangeAt) ?? 'None',
                'inbox_last_change_text',
              ),
              _labeled(
                context,
                'Next cursor',
                _controller.hasNextPage ? 'Present' : 'None (last page)',
                'inbox_next_cursor_text',
              ),
              _labeled(
                context,
                'Filters',
                'read ${_controller.readFilter.name}, '
                    'archive ${_controller.archiveFilter.name}',
                'inbox_filters_text',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _labeled(BuildContext context, String title, String value, String id) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: TestId(
        id,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.bodySmall),
            const Spacer(),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // MARK: Filters

  Widget _filters(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          _filterRow<InboxReadFilter>(
            context,
            label: 'Read',
            options: InboxReadFilter.values,
            selected: _controller.readFilter,
            name: (option) => option.name,
            tag: (name) => 'inbox_read_filter_$name',
            onSelect: _controller.setReadFilter,
          ),
          _filterRow<InboxArchiveFilter>(
            context,
            label: 'Archive',
            options: InboxArchiveFilter.values,
            selected: _controller.archiveFilter,
            name: (option) => option.name,
            tag: (name) => 'inbox_archive_filter_$name',
            onSelect: _controller.setArchiveFilter,
          ),
        ],
      ),
    );
  }

  /// One button per option, the selected one filled. Each is named by its enum
  /// value, so the buttons read the way the SDK's filters do.
  Widget _filterRow<T>(
    BuildContext context, {
    required String label,
    required List<T> options,
    required T selected,
    required String Function(T) name,
    required String Function(String) tag,
    required Future<void> Function(T) onSelect,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: Wrap(
              spacing: 8,
              children: [
                for (final option in options)
                  TestId(
                    tag(name(option)),
                    child: option == selected
                        ? FilledButton(
                            onPressed: () => onSelect(option),
                            child: Text(capitalize(name(option))),
                          )
                        : OutlinedButton(
                            onPressed: () => onSelect(option),
                            child: Text(capitalize(name(option))),
                          ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // MARK: Notices

  Widget _stateNotice(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFFBDADA),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TestId(
        'inbox_state_notice',
        child: Text(
          _controller.stateNotice!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
    );
  }

  Widget _error(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TestId(
        'inbox_error_label',
        child: Text(
          'Inbox failed: ${_controller.errorMessage}',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
    );
  }

  // MARK: Messages

  List<Widget> _messageList(BuildContext context) {
    if (!_controller.hasLoaded) {
      return [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (_controller.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
          child: TestId(
            'inbox_empty_label',
            child: Text(
              _emptyText(),
              style: TextStyle(color: Theme.of(context).disabledColor),
            ),
          ),
        ),
      ];
    }

    final widgets = <Widget>[];
    for (var index = 0; index < _controller.pages.length; index++) {
      final page = _controller.pages[index];
      widgets.add(_pageHeader(context, index, page.length));
      for (final message in page) {
        widgets.add(_messageRow(context, message));
      }
    }
    return widgets;
  }

  /// Marks where each `fetchInboxPage` call's messages start, so paging reads
  /// as pages stacking up.
  Widget _pageHeader(BuildContext context, int index, int count) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: TestId(
        'inbox_page_header_${index + 1}',
        child: Row(
          children: [
            Text(
              'Page ${index + 1}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            Text('$count ${noun(count, 'message')}'),
          ],
        ),
      ),
    );
  }

  Widget _messageRow(BuildContext context, InboxMessage message) {
    final theme = Theme.of(context);
    final expanded = _expandedDetails.contains(message.id);
    final isRead = message.isRead;

    return TestId(
      'inbox_message_${message.id}',
      merge: false,
      child: Container(
        color: message.isArchived
            ? const Color(0xFFFBDADA)
            : isRead
                ? theme.colorScheme.surfaceContainerHigh
                : theme.colorScheme.surface,
        padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 5, right: 8),
                  child: CircleAvatar(
                    radius: 4,
                    backgroundColor: isRead ? Colors.transparent : Colors.blue,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.title ?? message.body ?? '(no title)',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight:
                              isRead ? FontWeight.normal : FontWeight.bold,
                        ),
                      ),
                      if (message.title != null && message.body != null)
                        Text(
                          message.body!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium,
                        ),
                      Text(
                        InboxFormatting.sortTime(message),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Row(
              children: [
                TestId(
                  'inbox_read_toggle_${message.id}',
                  child: TextButton.icon(
                    onPressed: () => _controller.setMessageState(
                      message.id,
                      isRead
                          ? InboxMessageState.unread
                          : InboxMessageState.read,
                    ),
                    icon: Icon(
                      isRead ? Icons.mark_email_unread : Icons.mark_email_read,
                      size: 18,
                    ),
                    label: Text(isRead ? 'Mark unread' : 'Mark read'),
                  ),
                ),
                TestId(
                  'inbox_archive_toggle_${message.id}',
                  child: TextButton.icon(
                    onPressed: () => _controller.setMessageState(
                      message.id,
                      message.isArchived
                          ? InboxMessageState.unarchived
                          : InboxMessageState.archived,
                    ),
                    icon: Icon(
                      message.isArchived ? Icons.unarchive : Icons.archive,
                      size: 18,
                    ),
                    label: Text(message.isArchived ? 'Unarchive' : 'Archive'),
                  ),
                ),
                const Spacer(),
                TestId(
                  'inbox_details_button_${message.id}',
                  child: TextButton(
                    onPressed: () => setState(() {
                      if (expanded) {
                        _expandedDetails.remove(message.id);
                      } else {
                        _expandedDetails.add(message.id);
                      }
                    }),
                    child: Text(expanded ? 'Hide details' : 'Details'),
                  ),
                ),
              ],
            ),
            if (expanded) _details(context, message),
          ],
        ),
      ),
    );
  }

  /// The raw SDK values, kept for validation but out of the way until asked for.
  Widget _details(BuildContext context, InboxMessage message) {
    final fields = <MapEntry<String, String?>>[
      MapEntry('id', message.id),
      MapEntry('source', message.source.rawValue),
      MapEntry('sentAt', InboxFormatting.dateTime(message.sentAt)),
      MapEntry('receivedAt', InboxFormatting.dateTime(message.receivedAt)),
      MapEntry(
        'defaultDestination',
        InboxFormatting.destination(message.defaultDestination),
      ),
      MapEntry('media', InboxFormatting.media(message)),
      MapEntry('collapseId', message.collapseId),
      MapEntry('badge', message.badge?.toString()),
      MapEntry('isRead', '${message.isRead}'),
      MapEntry('isArchived', '${message.isArchived}'),
    ];

    return Padding(
      padding: const EdgeInsets.only(left: 20, top: 8),
      child: TestId(
        'inbox_message_details_${message.id}',
        merge: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final field in fields)
              if (field.value != null && field.value!.isNotEmpty)
                _detailLine(context, field.key, field.value!),
            for (var i = 0; i < message.actions.length; i++)
              _detailLine(
                context,
                'action ${i + 1} (${message.actions[i].id})',
                '${message.actions[i].label}: '
                    '${InboxFormatting.destination(message.actions[i].destination)}',
              ),
            for (final entry in InboxFormatting.customData(message))
              _detailLine(context, 'customData.${entry.key}', entry.value),
          ],
        ),
      ),
    );
  }

  Widget _detailLine(BuildContext context, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  // MARK: Footer

  Widget _footer(BuildContext context) {
    final nextPage = _controller.pagesLoaded + 1;
    final children = <Widget>[];

    if (_controller.isLoading &&
        _controller.hasLoaded &&
        _controller.messages.isNotEmpty) {
      children.add(
        TestId(
          'inbox_loading_next_page_text',
          merge: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 8),
              Text('Loading page $nextPage...'),
            ],
          ),
        ),
      );
    } else if (_controller.hasNextPage) {
      children.add(
        TestId(
          'inbox_fetch_next_page_button',
          child: OutlinedButton(
            onPressed: _controller.loadNextPage,
            child: Text('Load page $nextPage'),
          ),
        ),
      );
    } else if (_controller.hasLoaded && _controller.messages.isNotEmpty) {
      children.add(const Text('End of inbox'));
    }

    if (_controller.hasLoaded && _controller.messages.isNotEmpty) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: TestId(
            'inbox_page_count_text',
            child: Text(
              '${_controller.messages.length} messages - '
              '${_controller.pagesLoaded} '
              '${noun(_controller.pagesLoaded, 'page')} - '
              'page size ${_controller.pageSize}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(children: children),
    );
  }

  /// Why there is nothing to show, in the order the SDK needs things in place.
  String _emptyText() {
    if (!_api.isInitialized()) {
      return 'The SDK is not initialized, so fetchInboxPage returns an empty '
          'page. Set a company ID and initialize on the Profile tab first.';
    }
    if (_controller.readFilter == InboxReadFilter.unread &&
        _controller.unreadCount == 0) {
      return 'No unread messages. Try the "All" read filter, or send a push.';
    }
    return 'The page is empty. Send a Klaviyo push to this device, then pull '
        'to refresh. Messages appear only once the SDK has captured a push.';
  }

  static String capitalize(String value) =>
      value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);

  static String noun(int count, String singular) =>
      count == 1 ? singular : '${singular}s';
}
