import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klaviyo_flutter_sdk/klaviyo_flutter_sdk.dart';
import 'package:klaviyo_flutter_sdk_example/inbox/inbox_api.dart';
import 'package:klaviyo_flutter_sdk_example/tabs/inbox_tab.dart';

/// An inbox API that answers from memory, so the tab can be tested without a
/// platform channel.
class _FakeInboxApi {
  _FakeInboxApi({
    this.isInitialized = true,
    List<InboxMessage>? messages,
    this.unreadCount = 0,
    this.fetchError,
  }) : messages = messages ?? [];

  final bool isInitialized;
  List<InboxMessage> messages;
  int unreadCount;
  Object? fetchError;

  int fetchCalls = 0;
  int countCalls = 0;
  final List<(String, InboxMessageState)> stateCalls = [];
  bool? lastUpdateResult;
  final _changes = StreamController<void>.broadcast();

  InboxApi build() => InboxApi(
        isInitialized: () => isInitialized,
        fetchPage: ({
          required int pageSize,
          String? cursor,
          required InboxReadFilter readFilter,
          required InboxArchiveFilter archiveFilter,
        }) async {
          fetchCalls++;
          final error = fetchError;
          if (error != null) throw error;
          return InboxPage(messages: messages, nextCursor: null);
        },
        fetchUnreadCount: () async {
          countCalls++;
          return unreadCount;
        },
        updateMessageState: (id, state) async {
          stateCalls.add((id, state));
          return lastUpdateResult ?? true;
        },
        onInboxChanged: () => _changes.stream,
      );

  void emitChange() => _changes.add(null);

  Future<void> close() => _changes.close();
}

InboxMessage _message({
  String id = 'msg-1',
  String? title = 'Hello',
  String? body = 'World',
  bool isRead = false,
  bool isArchived = false,
  List<InboxAction> actions = const [],
  Map<String, String> customData = const {},
}) =>
    InboxMessage(
      id: id,
      title: title,
      body: body,
      defaultDestination: const InboxDestination(
        type: InboxDestinationType.deepLink,
        url: 'app://product/1',
      ),
      customData: customData,
      actions: actions,
      sentAt: DateTime.utc(2026, 11, 23, 10, 41, 2),
      receivedAt: DateTime.utc(2026, 11, 23, 10, 41, 5),
      isRead: isRead,
      isArchived: isArchived,
      source: InboxMessageSource.captured,
    );

Future<void> _pumpTab(WidgetTester tester, _FakeInboxApi fake) async {
  await tester.pumpWidget(MaterialApp(home: InboxTab(api: fake.build())));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows a message with its test IDs', (tester) async {
    final semantics = tester.ensureSemantics();
    final fake = _FakeInboxApi(messages: [_message()], unreadCount: 1);
    await _pumpTab(tester, fake);

    for (final id in [
      'inbox_pages_result',
      'inbox_unread_badge',
      'inbox_read_filter_all',
      'inbox_read_filter_unread',
      'inbox_read_filter_read',
      'inbox_archive_filter_active',
      'inbox_archive_filter_archived',
      'inbox_archive_filter_all',
      'inbox_page_header_1',
      'inbox_message_msg-1',
      'inbox_read_toggle_msg-1',
      'inbox_archive_toggle_msg-1',
      'inbox_details_button_msg-1',
      'inbox_page_count_text',
    ]) {
      expect(find.bySemanticsIdentifier(id), findsOneWidget, reason: id);
      expect(find.byKey(ValueKey(id)), findsOneWidget, reason: id);
    }
    expect(find.text('Hello'), findsOneWidget);
    expect(find.text('World'), findsOneWidget);
    expect(find.text('End of inbox'), findsOneWidget);
    expect(fake.fetchCalls, 1);
    expect(fake.countCalls, 1);

    semantics.dispose();
    await tester.pumpWidget(const SizedBox());
    await fake.close();
  });

  testWidgets('marks a message read, then re-reads', (tester) async {
    final fake = _FakeInboxApi(messages: [_message()]);
    await _pumpTab(tester, fake);

    await tester.tap(find.byKey(const ValueKey('inbox_read_toggle_msg-1')));
    await tester.pumpAndSettle();

    expect(fake.stateCalls, [('msg-1', InboxMessageState.read)]);
    // The initial read, then the read after the change.
    expect(fake.fetchCalls, 2);
    // No notice: the message existed.
    expect(find.byKey(const ValueKey('inbox_state_notice')), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await fake.close();
  });

  testWidgets('archives an archived message when asked to unarchive', (
    tester,
  ) async {
    final fake = _FakeInboxApi(messages: [_message(isArchived: true)]);
    await _pumpTab(tester, fake);

    expect(find.text('Unarchive'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('inbox_archive_toggle_msg-1')));
    await tester.pumpAndSettle();

    expect(fake.stateCalls, [('msg-1', InboxMessageState.unarchived)]);

    await tester.pumpWidget(const SizedBox());
    await fake.close();
  });

  testWidgets('reports a message the device does not have', (tester) async {
    final fake = _FakeInboxApi(messages: [_message()]);
    fake.lastUpdateResult = false;
    await _pumpTab(tester, fake);

    await tester.tap(find.byKey(const ValueKey('inbox_read_toggle_msg-1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('inbox_state_notice')), findsOneWidget);
    expect(find.textContaining('not on this device'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await fake.close();
  });

  testWidgets('shows details only when asked', (tester) async {
    final fake = _FakeInboxApi(
      messages: [
        _message(
          actions: [
            const InboxAction(
              id: 'a1',
              label: 'Shop',
              destination: InboxDestination(
                type: InboxDestinationType.openUrl,
                url: 'https://example.com',
              ),
            ),
          ],
          customData: {'k': 'v'},
        ),
      ],
    );
    await _pumpTab(tester, fake);

    expect(
      find.byKey(const ValueKey('inbox_message_details_msg-1')),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('inbox_details_button_msg-1')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('inbox_message_details_msg-1')),
      findsOneWidget,
    );
    expect(find.text('deep_link app://product/1'), findsOneWidget);
    expect(find.text('a1'), findsNothing);
    expect(find.text('action 1 (a1)'), findsOneWidget);
    expect(find.text('Shop: open_url https://example.com'), findsOneWidget);
    expect(find.text('customData.k'), findsOneWidget);
    expect(find.text('v'), findsOneWidget);
    // Actions are shown, never run.
    expect(
      find.byKey(const ValueKey('inbox_details_button_msg-1')),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox());
    await fake.close();
  });

  testWidgets('shows the empty state when nothing is stored', (tester) async {
    final fake = _FakeInboxApi();
    await _pumpTab(tester, fake);

    expect(find.byKey(const ValueKey('inbox_empty_label')), findsOneWidget);
    expect(find.text('End of inbox'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await fake.close();
  });

  testWidgets('asks to initialize the SDK when it is not initialized', (
    tester,
  ) async {
    final fake = _FakeInboxApi(isInitialized: false);
    await _pumpTab(tester, fake);

    expect(find.textContaining('not initialized'), findsWidgets);

    await tester.pumpWidget(const SizedBox());
    await fake.close();
  });

  testWidgets('shows the failure from the SDK', (tester) async {
    final fake = _FakeInboxApi(
      fetchError: const KlaviyoInboxException(
        'inbox module absent',
        reason: KlaviyoInboxErrorReason.unavailable,
      ),
    );
    await _pumpTab(tester, fake);

    expect(find.byKey(const ValueKey('inbox_error_label')), findsOneWidget);
    expect(find.textContaining('unavailable'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await fake.close();
  });

  testWidgets('re-reads when the SDK reports a change', (tester) async {
    final fake = _FakeInboxApi(messages: [_message()]);
    await _pumpTab(tester, fake);
    expect(fake.fetchCalls, 1);

    fake.emitChange();
    await tester.pumpAndSettle();

    expect(fake.fetchCalls, 2);
    // The change is counted and shown in diagnostics.
    await tester.tap(find.byKey(const ValueKey('inbox_diagnostics_toggle')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('inbox_change_signal_count_text')),
      findsOneWidget,
    );
    expect(find.text('1'), findsWidgets);

    await tester.pumpWidget(const SizedBox());
    await fake.close();
  });

  testWidgets('a read filter change re-reads with the new filter', (
    tester,
  ) async {
    final fake = _FakeInboxApi(messages: [_message()]);
    await _pumpTab(tester, fake);

    await tester.tap(find.byKey(const ValueKey('inbox_read_filter_unread')));
    await tester.pumpAndSettle();

    expect(fake.fetchCalls, 2);

    await tester.pumpWidget(const SizedBox());
    await fake.close();
  });

  testWidgets('page size stepper changes the page size', (tester) async {
    final fake = _FakeInboxApi(messages: [_message()]);
    await _pumpTab(tester, fake);

    await tester.tap(find.byTooltip('Larger pages'));
    await tester.pumpAndSettle();

    expect(find.text('Page 6'), findsOneWidget);
    expect(fake.fetchCalls, 2);

    await tester.pumpWidget(const SizedBox());
    await fake.close();
  });
}
