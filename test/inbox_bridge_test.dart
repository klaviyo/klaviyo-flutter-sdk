import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klaviyo_flutter_sdk/klaviyo_flutter_sdk.dart';

/// Bridge tests for the Mobile Inbox channel methods and the invalidation
/// stream. Each file runs in its own isolate, so the [KlaviyoSDK] and
/// [KlaviyoNativeWrapper] singletons start fresh here.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methodChannel = MethodChannel('klaviyo_sdk');
  const eventChannel = EventChannel('klaviyo_events');

  final calls = <MethodCall>[];
  MockStreamHandlerEventSink? eventSink;

  /// Replies for specific method names; anything else resolves to null.
  final replies = <String, Object? Function()>{};

  setUp(() {
    calls.clear();
    replies.clear();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (call) async {
      calls.add(call);
      final reply = replies[call.method];
      return reply == null ? null : reply();
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(eventChannel, null);
  });

  Map<String, dynamic> pageMap({String? nextCursor}) => {
        'messages': [
          {
            'id': 'msg-1',
            'title': 'Hello',
            'defaultDestination': {'type': 'open_app'},
            'customData': <String, String>{},
            'actions': <dynamic>[],
            'sentAt': 1700000000000,
            'receivedAt': 1700000005000,
            'isRead': false,
            'isArchived': false,
            'source': 'captured',
          },
        ],
        'nextCursor': nextCursor,
      };

  // The wrapper attaches its event-channel listener on the first initialize,
  // so one initialize covers every test in this file.
  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (call) async => null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(
      eventChannel,
      MockStreamHandler.inline(
        onListen: (_, sink) => eventSink = sink,
        onCancel: (_) {},
      ),
    );
    await KlaviyoSDK().initialize(apiKey: 'KEY');
    await pumpEventQueue();
  });

  group('fetchInboxPage', () {
    test('sends page size and cursor, and parses the page', () async {
      replies['fetchInboxPage'] = () => pageMap(nextCursor: 'cursor-2');

      final page = await KlaviyoSDK().fetchInboxPage(
        pageSize: 5,
        cursor: 'cursor-1',
      );

      final call = calls.lastWhere((c) => c.method == 'fetchInboxPage');
      expect(call.arguments['pageSize'], 5);
      expect(call.arguments['cursor'], 'cursor-1');
      expect(page.messages.single.id, 'msg-1');
      expect(page.nextCursor, 'cursor-2');
    });

    test('defaults to a page size of 20, no cursor, and the native filters',
        () async {
      replies['fetchInboxPage'] = () => pageMap();

      await KlaviyoSDK().fetchInboxPage();

      final call = calls.lastWhere((c) => c.method == 'fetchInboxPage');
      expect(call.arguments['pageSize'], 20);
      expect(call.arguments['cursor'], isNull);
      // Archived messages are hidden by default.
      expect(call.arguments['readFilter'], 'all');
      expect(call.arguments['archiveFilter'], 'active');
    });

    test('forwards both filters to native', () async {
      replies['fetchInboxPage'] = () => pageMap();

      await KlaviyoSDK().fetchInboxPage(
        readFilter: InboxReadFilter.unread,
        archiveFilter: InboxArchiveFilter.archived,
      );

      final call = calls.lastWhere((c) => c.method == 'fetchInboxPage');
      expect(call.arguments['readFilter'], 'unread');
      expect(call.arguments['archiveFilter'], 'archived');
    });

    test('sends every filter value as its wire value', () async {
      replies['fetchInboxPage'] = () => pageMap();

      for (final filter in InboxReadFilter.values) {
        await KlaviyoSDK().fetchInboxPage(readFilter: filter);
        final call = calls.lastWhere((c) => c.method == 'fetchInboxPage');
        expect(call.arguments['readFilter'], filter.name);
      }
      for (final filter in InboxArchiveFilter.values) {
        await KlaviyoSDK().fetchInboxPage(archiveFilter: filter);
        final call = calls.lastWhere((c) => c.method == 'fetchInboxPage');
        expect(call.arguments['archiveFilter'], filter.name);
      }
    });

    test('sends filters alongside a cursor unchanged', () async {
      replies['fetchInboxPage'] = () => pageMap();

      await KlaviyoSDK().fetchInboxPage(
        cursor: 'cursor-1',
        readFilter: InboxReadFilter.read,
        archiveFilter: InboxArchiveFilter.all,
      );

      final call = calls.lastWhere((c) => c.method == 'fetchInboxPage');
      expect(call.arguments['cursor'], 'cursor-1');
      expect(call.arguments['readFilter'], 'read');
      expect(call.arguments['archiveFilter'], 'all');
    });

    test('maps a filter-mismatched cursor to invalidCursor', () async {
      // Native rejects a cursor reused under different filters with the same
      // InvalidCursor error as any other unusable token.
      replies['fetchInboxPage'] = () => throw PlatformException(
            code: 'INBOX_INVALID_CURSOR',
            message: 'the cursor was issued for different filters',
          );

      await expectLater(
        KlaviyoSDK().fetchInboxPage(
          cursor: 'cursor-from-other-filters',
          readFilter: InboxReadFilter.unread,
        ),
        throwsA(
          isA<KlaviyoInboxException>().having(
            (e) => e.reason,
            'reason',
            KlaviyoInboxErrorReason.invalidCursor,
          ),
        ),
      );
    });

    test('forwards an out-of-range page size unclamped for native to clamp',
        () async {
      replies['fetchInboxPage'] = () => pageMap();

      await KlaviyoSDK().fetchInboxPage(pageSize: 500);

      final call = calls.lastWhere((c) => c.method == 'fetchInboxPage');
      expect(call.arguments['pageSize'], 500);
    });

    test('wraps a native failure in a typed inbox exception', () async {
      replies['fetchInboxPage'] = () => throw PlatformException(
            code: 'INBOX_INVALID_CURSOR',
            message: 'cursor is not from this inbox',
          );

      await expectLater(
        KlaviyoSDK().fetchInboxPage(cursor: 'garbage'),
        throwsA(
          isA<KlaviyoInboxException>()
              .having(
                (e) => e.reason,
                'reason',
                KlaviyoInboxErrorReason.invalidCursor,
              )
              .having((e) => e.code, 'code', 'INBOX_INVALID_CURSOR'),
        ),
      );
    });

    test('maps a storage failure distinctly from an invalid cursor', () async {
      replies['fetchInboxPage'] = () => throw PlatformException(
            code: 'INBOX_STORAGE_FAILURE',
          );

      await expectLater(
        KlaviyoSDK().fetchInboxPage(),
        throwsA(
          isA<KlaviyoInboxException>().having(
            (e) => e.reason,
            'reason',
            KlaviyoInboxErrorReason.storageFailure,
          ),
        ),
      );
    });
  });

  group('fetchInboxUnreadCount', () {
    test('returns the native count', () async {
      replies['fetchInboxUnreadCount'] = () => 7;

      expect(await KlaviyoSDK().fetchInboxUnreadCount(), 7);
    });

    test('treats a null native result as zero', () async {
      expect(await KlaviyoSDK().fetchInboxUnreadCount(), 0);
    });

    test('wraps a native failure in a typed inbox exception', () async {
      replies['fetchInboxUnreadCount'] = () => throw PlatformException(
            code: 'INBOX_STORAGE_FAILURE',
          );

      await expectLater(
        KlaviyoSDK().fetchInboxUnreadCount(),
        throwsA(isA<KlaviyoInboxException>()),
      );
    });
  });

  group('trackInboxMessageClick', () {
    test('sends only the message id for a body click', () async {
      replies['trackInboxMessageClick'] = () => true;

      final queued = await KlaviyoSDK().trackInboxMessageClick('msg-1');

      final call = calls.lastWhere((c) => c.method == 'trackInboxMessageClick');
      expect(call.arguments, {'messageId': 'msg-1'});
      expect(queued, isTrue);
    });

    test('sends the tapped button and the extra properties', () async {
      replies['trackInboxMessageClick'] = () => true;

      await KlaviyoSDK().trackInboxMessageClick(
        'msg-1',
        actionId: 'a1',
        properties: {'screen': 'inbox', 'position': 3},
      );

      final call = calls.lastWhere((c) => c.method == 'trackInboxMessageClick');
      expect(call.arguments['messageId'], 'msg-1');
      expect(call.arguments['actionId'], 'a1');
      expect(call.arguments['properties'], {'screen': 'inbox', 'position': 3});
    });

    test('returns false when no click was queued', () async {
      replies['trackInboxMessageClick'] = () => false;

      expect(await KlaviyoSDK().trackInboxMessageClick('gone'), isFalse);
    });

    test('does not change message state', () async {
      replies['trackInboxMessageClick'] = () => true;

      await KlaviyoSDK().trackInboxMessageClick('msg-1');

      expect(
        calls.where(
          (c) =>
              c.method == 'updateInboxMessageState' ||
              c.method == 'updateInboxMessageStates',
        ),
        isEmpty,
      );
    });

    test('rejects an empty message id without calling native', () async {
      await expectLater(
        KlaviyoSDK().trackInboxMessageClick(''),
        throwsArgumentError,
      );
      await expectLater(
        KlaviyoSDK().trackInboxMessageClick('   '),
        throwsArgumentError,
      );
      expect(calls.where((c) => c.method == 'trackInboxMessageClick'), isEmpty);
    });

    test('rejects an empty action id without calling native', () async {
      await expectLater(
        KlaviyoSDK().trackInboxMessageClick('msg-1', actionId: ''),
        throwsArgumentError,
      );
      expect(calls.where((c) => c.method == 'trackInboxMessageClick'), isEmpty);
    });

    test('wraps a native failure in a typed inbox exception', () async {
      replies['trackInboxMessageClick'] = () => throw PlatformException(
            code: 'INBOX_STORAGE_FAILURE',
          );

      await expectLater(
        KlaviyoSDK().trackInboxMessageClick('msg-1'),
        throwsA(isA<KlaviyoInboxException>()),
      );
    });
  });

  group('updateInboxMessageState', () {
    test('sends the message id and state wire value', () async {
      replies['updateInboxMessageState'] = () => true;

      final existed = await KlaviyoSDK().updateInboxMessageState(
        'msg-1',
        InboxMessageState.archived,
      );

      final call = calls.lastWhere(
        (c) => c.method == 'updateInboxMessageState',
      );
      expect(call.arguments['messageId'], 'msg-1');
      expect(call.arguments['state'], 'archived');
      expect(existed, isTrue);
    });

    test('returns false when the native side reports no such message',
        () async {
      replies['updateInboxMessageState'] = () => false;

      expect(
        await KlaviyoSDK().updateInboxMessageState(
          'gone',
          InboxMessageState.read,
        ),
        isFalse,
      );
    });

    test('sends every state as its wire value', () async {
      replies['updateInboxMessageState'] = () => true;

      for (final state in InboxMessageState.values) {
        await KlaviyoSDK().updateInboxMessageState('msg-1', state);
        final call = calls.lastWhere(
          (c) => c.method == 'updateInboxMessageState',
        );
        expect(call.arguments['state'], state.name);
      }
    });

    test('wraps a native failure in a typed inbox exception', () async {
      replies['updateInboxMessageState'] = () => throw PlatformException(
            code: 'INBOX_UNAVAILABLE',
          );

      await expectLater(
        KlaviyoSDK().updateInboxMessageState('msg-1', InboxMessageState.read),
        throwsA(
          isA<KlaviyoInboxException>().having(
            (e) => e.reason,
            'reason',
            KlaviyoInboxErrorReason.unavailable,
          ),
        ),
      );
    });
  });

  group('inboxChanged stream', () {
    test('emits nothing until native sends an invalidation', () async {
      final events = <void>[];
      final sub = KlaviyoSDK().inboxChanged.listen(events.add);

      await pumpEventQueue();

      expect(events, isEmpty);

      await sub.cancel();
    });

    test('emits once per native inbox_changed event', () async {
      final events = <void>[];
      final sub = KlaviyoSDK().inboxChanged.listen(events.add);

      eventSink!.success({'type': 'inbox_changed'});
      await pumpEventQueue();

      expect(events, hasLength(1));

      await sub.cancel();
    });

    test('ignores unrelated native events', () async {
      final events = <void>[];
      final sub = KlaviyoSDK().inboxChanged.listen(events.add);

      eventSink!.success({
        'type': 'push_notification_opened',
        'data': {'title': 'Hi'},
      });
      eventSink!.success({
        'type': 'form_lifecycle_event',
        'data': {'event': 'formShown', 'formId': 'f', 'formName': 'n'},
      });
      await pumpEventQueue();

      expect(events, isEmpty);

      await sub.cancel();
    });

    test('buffers one invalidation that arrives before a listener attaches',
        () async {
      // A change captured before the UI subscribed must still prompt a fetch.
      eventSink!.success({'type': 'inbox_changed'});
      await pumpEventQueue();

      final events = <void>[];
      final sub = KlaviyoSDK().inboxChanged.listen(events.add);
      await pumpEventQueue();

      expect(events, hasLength(1));

      await sub.cancel();
    });

    test('coalesces a burst of buffered invalidations into one', () async {
      // Payload-free signals carry no information beyond "re-read", so a burst
      // while nobody is listening collapses to a single notification.
      eventSink!.success({'type': 'inbox_changed'});
      eventSink!.success({'type': 'inbox_changed'});
      eventSink!.success({'type': 'inbox_changed'});
      await pumpEventQueue();

      final events = <void>[];
      final sub = KlaviyoSDK().inboxChanged.listen(events.add);
      await pumpEventQueue();

      expect(events, hasLength(1));

      await sub.cancel();
    });

    test('delivers live events individually to an attached listener', () async {
      final events = <void>[];
      final sub = KlaviyoSDK().inboxChanged.listen(events.add);
      await pumpEventQueue();

      eventSink!.success({'type': 'inbox_changed'});
      await pumpEventQueue();
      eventSink!.success({'type': 'inbox_changed'});
      await pumpEventQueue();

      expect(events, hasLength(2));

      await sub.cancel();
    });
  });
}
