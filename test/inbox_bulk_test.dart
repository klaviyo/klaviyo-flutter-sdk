import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klaviyo_flutter_sdk/klaviyo_flutter_sdk.dart';

/// Bridge tests for the bulk inbox operations: putting every matching message
/// into a state, and clearing the current company's messages. Each test file
/// runs in its own isolate, so the singletons start fresh here.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methodChannel = MethodChannel('klaviyo_sdk');
  const eventChannel = EventChannel('klaviyo_events');

  final calls = <MethodCall>[];
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

  setUpAll(() async {
    // Register the method handler here too: setUp runs after setUpAll, so the
    // initialize call below would otherwise reach a channel with no handler.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (call) async => null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(
      eventChannel,
      MockStreamHandler.inline(onListen: (_, __) {}, onCancel: (_) {}),
    );
    await KlaviyoSDK().initialize(apiKey: 'KEY');
    await pumpEventQueue();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, null);
  });

  group('InboxFilter', () {
    test('allMessages matches both axes', () {
      expect(InboxFilter.allMessages.readFilter, InboxReadFilter.all);
      expect(InboxFilter.allMessages.archiveFilter, InboxArchiveFilter.all);
    });

    test('where carries both filters', () {
      final filter = InboxFilter.where(
        InboxReadFilter.unread,
        InboxArchiveFilter.active,
      );

      expect(filter.readFilter, InboxReadFilter.unread);
      expect(filter.archiveFilter, InboxArchiveFilter.active);
    });

    test('serializes to the wire shape', () {
      final map = InboxFilter.where(
        InboxReadFilter.read,
        InboxArchiveFilter.archived,
      ).toMap();

      expect(map, {'readFilter': 'read', 'archiveFilter': 'archived'});
    });

    test('equal filters compare and hash equal', () {
      final first = InboxFilter.where(
        InboxReadFilter.read,
        InboxArchiveFilter.all,
      );
      final second = InboxFilter.where(
        InboxReadFilter.read,
        InboxArchiveFilter.all,
      );

      expect(first, second);
      expect(first.hashCode, second.hashCode);
    });
  });

  group('updateInboxMessageStates', () {
    test('sends the state and filter, and returns the changed count', () async {
      replies['updateInboxMessageStates'] = () => 3;

      final changed = await KlaviyoSDK().updateInboxMessageStates(
        InboxMessageState.archived,
        InboxFilter.allMessages,
      );

      final call = calls.lastWhere(
        (c) => c.method == 'updateInboxMessageStates',
      );
      expect(call.arguments['state'], 'archived');
      expect(call.arguments['filter'], {
        'readFilter': 'all',
        'archiveFilter': 'all',
      });
      expect(changed, 3);
    });

    test('returns zero when nothing matched', () async {
      replies['updateInboxMessageStates'] = () => 0;

      expect(
        await KlaviyoSDK().updateInboxMessageStates(
          InboxMessageState.read,
          InboxFilter.where(InboxReadFilter.read, InboxArchiveFilter.active),
        ),
        0,
      );
    });

    test('treats a null native result as zero', () async {
      expect(
        await KlaviyoSDK().updateInboxMessageStates(
          InboxMessageState.unarchived,
          InboxFilter.allMessages,
        ),
        0,
      );
    });

    test('forwards every state as its wire value', () async {
      replies['updateInboxMessageStates'] = () => 1;

      for (final state in InboxMessageState.values) {
        await KlaviyoSDK().updateInboxMessageStates(
          state,
          InboxFilter.allMessages,
        );
        final call = calls.lastWhere(
          (c) => c.method == 'updateInboxMessageStates',
        );
        expect(call.arguments['state'], state.name);
      }
    });

    test('wraps a native failure in a typed inbox exception', () async {
      replies['updateInboxMessageStates'] = () => throw PlatformException(
            code: 'INBOX_STORAGE_FAILURE',
          );

      await expectLater(
        KlaviyoSDK().updateInboxMessageStates(
          InboxMessageState.read,
          InboxFilter.allMessages,
        ),
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

  group('updateInboxMessageStatesByIds', () {
    test('sends the state and ids, and returns the changed count', () async {
      replies['updateInboxMessageStatesByIds'] = () => 2;

      final changed = await KlaviyoSDK().updateInboxMessageStatesByIds(
        InboxMessageState.archived,
        ['msg-1', 'msg-2', 'msg-3'],
      );

      final call = calls.lastWhere(
        (c) => c.method == 'updateInboxMessageStatesByIds',
      );
      expect(call.arguments['state'], 'archived');
      expect(call.arguments['messageIds'], ['msg-1', 'msg-2', 'msg-3']);
      expect(changed, 2);
    });

    test('sends an empty list rather than dropping the argument', () async {
      replies['updateInboxMessageStatesByIds'] = () => 0;

      expect(
        await KlaviyoSDK().updateInboxMessageStatesByIds(
          InboxMessageState.read,
          const [],
        ),
        0,
      );
      final call = calls.lastWhere(
        (c) => c.method == 'updateInboxMessageStatesByIds',
      );
      expect(call.arguments['messageIds'], isEmpty);
    });

    test('treats a null native result as zero', () async {
      expect(
        await KlaviyoSDK().updateInboxMessageStatesByIds(
          InboxMessageState.unread,
          ['msg-1'],
        ),
        0,
      );
    });

    test('forwards every state as its wire value', () async {
      replies['updateInboxMessageStatesByIds'] = () => 1;

      for (final state in InboxMessageState.values) {
        await KlaviyoSDK().updateInboxMessageStatesByIds(state, ['msg-1']);
        final call = calls.lastWhere(
          (c) => c.method == 'updateInboxMessageStatesByIds',
        );
        expect(call.arguments['state'], state.name);
      }
    });

    test('wraps a native failure in a typed inbox exception', () async {
      replies['updateInboxMessageStatesByIds'] = () => throw PlatformException(
            code: 'INBOX_STORAGE_FAILURE',
          );

      await expectLater(
        KlaviyoSDK().updateInboxMessageStatesByIds(
          InboxMessageState.read,
          ['msg-1'],
        ),
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

  group('clearInbox', () {
    test('returns how many were removed', () async {
      replies['clearInbox'] = () => 5;

      expect(await KlaviyoSDK().clearInbox(), 5);
    });

    test('returns zero when there was nothing to remove', () async {
      replies['clearInbox'] = () => 0;

      expect(await KlaviyoSDK().clearInbox(), 0);
    });

    test('treats a null native result as zero', () async {
      expect(await KlaviyoSDK().clearInbox(), 0);
    });

    test('sends no arguments', () async {
      replies['clearInbox'] = () => 1;

      await KlaviyoSDK().clearInbox();

      final call = calls.lastWhere((c) => c.method == 'clearInbox');
      expect(call.arguments, isNull);
    });

    test('maps INBOX_UNAVAILABLE to the unavailable reason', () async {
      replies['clearInbox'] = () => throw PlatformException(
            code: 'INBOX_UNAVAILABLE',
          );

      await expectLater(
        KlaviyoSDK().clearInbox(),
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
}
