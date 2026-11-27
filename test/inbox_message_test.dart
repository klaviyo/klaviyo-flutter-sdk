import 'package:flutter_test/flutter_test.dart';
import 'package:klaviyo_flutter_sdk/klaviyo_flutter_sdk.dart';

/// A complete bridge map, in exactly the shape the native layers send:
/// camelCase keys, epoch-millisecond timestamps, and a nested destination.
Map<String, dynamic> fullMessageMap() => {
      'id': 'msg-1',
      'title': 'Your order shipped',
      'body': 'Track your package',
      'defaultDestination': {'type': 'deep_link', 'url': 'myapp://orders/1'},
      'mediaUrl': 'https://cdn.example.com/hero.png',
      'mediaType': 'image/png',
      'customData': {'order_id': 'A123', 'kind': 'shipping'},
      'actions': [
        {
          'id': 'btn-track',
          'label': 'Track',
          'destination': {
            'type': 'open_url',
            'url': 'https://example.com/track',
          },
        },
        {
          'id': 'btn-home',
          'label': 'Home',
          'destination': {'type': 'open_app', 'url': null},
        },
      ],
      'sentAt': 1700000000000,
      'receivedAt': 1700000005000,
      'collapseId': 'collapse-1',
      'badge': 3,
      'isRead': true,
      'isArchived': false,
      'source': 'captured',
    };

void main() {
  group('InboxMessage.fromMap', () {
    test('maps every field from the native bridge shape', () {
      final message = InboxMessage.fromMap(fullMessageMap());

      expect(message.id, 'msg-1');
      expect(message.title, 'Your order shipped');
      expect(message.body, 'Track your package');
      expect(message.defaultDestination.type, InboxDestinationType.deepLink);
      expect(message.defaultDestination.url, 'myapp://orders/1');
      expect(message.mediaUrl, 'https://cdn.example.com/hero.png');
      expect(message.mediaType, 'image/png');
      expect(message.customData, {
        'order_id': 'A123',
        'kind': 'shipping',
      });
      expect(message.sentAt, DateTime.utc(2023, 11, 14, 22, 13, 20));
      expect(message.receivedAt, DateTime.utc(2023, 11, 14, 22, 13, 25));
      expect(message.collapseId, 'collapse-1');
      expect(message.badge, 3);
      expect(message.isRead, isTrue);
      expect(message.isArchived, isFalse);
      expect(message.source, InboxMessageSource.captured);
    });

    test('converts epoch milliseconds to UTC DateTimes', () {
      final message = InboxMessage.fromMap(fullMessageMap());

      expect(message.sentAt.isUtc, isTrue);
      expect(message.sentAt.millisecondsSinceEpoch, 1700000000000);
    });

    test('preserves action order', () {
      final message = InboxMessage.fromMap(fullMessageMap());

      expect(message.actions.map((a) => a.id), ['btn-track', 'btn-home']);
      expect(message.actions.first.label, 'Track');
      expect(
        message.actions.first.destination.type,
        InboxDestinationType.openUrl,
      );
      expect(
        message.actions.last.destination.type,
        InboxDestinationType.openApp,
      );
      expect(message.actions.last.destination.url, isNull);
    });

    test('tolerates every optional field being absent', () {
      final message = InboxMessage.fromMap({
        'id': 'msg-2',
        'defaultDestination': {'type': 'open_app'},
        'sentAt': 1700000000000,
        'receivedAt': 1700000005000,
        'isRead': false,
        'isArchived': false,
        'source': 'server',
      });

      expect(message.id, 'msg-2');
      expect(message.title, isNull);
      expect(message.body, isNull);
      expect(message.mediaUrl, isNull);
      expect(message.mediaType, isNull);
      expect(message.customData, isEmpty);
      expect(message.actions, isEmpty);
      expect(message.collapseId, isNull);
      expect(message.badge, isNull);
      expect(message.source, InboxMessageSource.server);
    });

    test('keeps an unknown source as a raw value', () {
      final message = InboxMessage.fromMap(
        fullMessageMap()..['source'] = 'some-future-source',
      );

      expect(message.source.rawValue, 'some-future-source');
    });

    test('keeps an unknown destination type as a raw value', () {
      final message = InboxMessage.fromMap(
        fullMessageMap()
          ..['defaultDestination'] = {'type': 'future_type', 'url': null},
      );

      expect(message.defaultDestination.type.rawValue, 'future_type');
    });

    test('throws when a required field is missing', () {
      for (final key in [
        'id',
        'defaultDestination',
        'sentAt',
        'receivedAt',
        'isRead',
        'isArchived',
        'source',
      ]) {
        final map = fullMessageMap()..remove(key);
        expect(
          () => InboxMessage.fromMap(map),
          throwsArgumentError,
          reason: 'removing $key should throw',
        );
      }
    });

    test('throws when the destination has no type', () {
      final map = fullMessageMap()
        ..['defaultDestination'] = {'url': 'https://example.com'};

      expect(() => InboxMessage.fromMap(map), throwsArgumentError);
    });
  });

  group('InboxMessage round trip', () {
    test('toMap then fromMap yields an equal message', () {
      final original = InboxMessage.fromMap(fullMessageMap());
      final restored = InboxMessage.fromMap(original.toMap());

      expect(restored, original);
      expect(restored.hashCode, original.hashCode);
    });

    test('toMap emits epoch milliseconds', () {
      final map = InboxMessage.fromMap(fullMessageMap()).toMap();

      expect(map['sentAt'], 1700000000000);
      expect(map['receivedAt'], 1700000005000);
      expect(map['source'], 'captured');
      expect((map['defaultDestination'] as Map)['type'], 'deep_link');
    });
  });

  group('InboxMessage equality', () {
    test('two messages from the same map are equal', () {
      expect(
        InboxMessage.fromMap(fullMessageMap()),
        InboxMessage.fromMap(fullMessageMap()),
      );
    });

    test('messages differing in a scalar field are not equal', () {
      final base = InboxMessage.fromMap(fullMessageMap());
      final changed = InboxMessage.fromMap(fullMessageMap()..['badge'] = 4);

      expect(base, isNot(changed));
    });

    test('messages differing in customData are not equal', () {
      final base = InboxMessage.fromMap(fullMessageMap());
      final changed = InboxMessage.fromMap(
        fullMessageMap()..['customData'] = {'order_id': 'A123'},
      );

      expect(base, isNot(changed));
    });

    test('messages differing only in action order are not equal', () {
      final base = InboxMessage.fromMap(fullMessageMap());
      final reordered = InboxMessage.fromMap(
        fullMessageMap()
          ..['actions'] =
              (fullMessageMap()['actions'] as List).reversed.toList(),
      );

      expect(base, isNot(reordered));
    });
  });

  group('InboxDestination', () {
    test('exposes the three known types', () {
      expect(InboxDestinationType.openApp.rawValue, 'open_app');
      expect(InboxDestinationType.deepLink.rawValue, 'deep_link');
      expect(InboxDestinationType.openUrl.rawValue, 'open_url');
    });

    test('equality is by raw value', () {
      expect(
        const InboxDestinationType('deep_link'),
        InboxDestinationType.deepLink,
      );
      expect(
        const InboxDestinationType('deep_link').hashCode,
        InboxDestinationType.deepLink.hashCode,
      );
    });

    test('round trips through a map', () {
      const destination = InboxDestination(
        type: InboxDestinationType.openUrl,
        url: 'https://example.com',
      );

      expect(InboxDestination.fromMap(destination.toMap()), destination);
    });
  });

  group('inbox filters', () {
    test('read filter wire values match the native contract', () {
      expect(InboxReadFilter.all.wireValue, 'all');
      expect(InboxReadFilter.unread.wireValue, 'unread');
      expect(InboxReadFilter.read.wireValue, 'read');
    });

    test('archive filter wire values match the native contract', () {
      // Archived messages are hidden by default, so `active` is what a caller
      // gets without asking.
      expect(InboxArchiveFilter.active.wireValue, 'active');
      expect(InboxArchiveFilter.archived.wireValue, 'archived');
      expect(InboxArchiveFilter.all.wireValue, 'all');
    });

    test('each filter has exactly the values the native SDKs expose', () {
      expect(
        InboxReadFilter.values.map((f) => f.wireValue),
        ['all', 'unread', 'read'],
      );
      expect(
        InboxArchiveFilter.values.map((f) => f.wireValue),
        ['active', 'archived', 'all'],
      );
    });
  });

  group('InboxMessage sentAt and receivedAt', () {
    Map<String, dynamic> mapWith(Map<String, dynamic> timestamps) =>
        fullMessageMap()..addAll(timestamps);

    test('rejects a malformed timestamp', () {
      // Both native SDKs guarantee these fields and drop a push without a valid
      // one, so a message that arrives without them is unusable rather than
      // carrying a null timestamp. InboxPage.fromMap skips such a message and
      // keeps the rest of the page.
      final cases = <dynamic>[
        'not-a-number',
        '',
        true,
        <String, dynamic>{},
        <dynamic>[],
        1.5,
        double.nan,
        9223372036854775807,
        null,
      ];

      for (final bad in cases) {
        expect(
          () => InboxMessage.fromMap(mapWith({'sentAt': bad})),
          throwsArgumentError,
          reason: 'sentAt: $bad',
        );
        expect(
          () => InboxMessage.fromMap(mapWith({'receivedAt': bad})),
          throwsArgumentError,
          reason: 'receivedAt: $bad',
        );
      }
    });

    test('accepts a whole-valued double as epoch milliseconds', () {
      final message = InboxMessage.fromMap(
        mapWith({'sentAt': 1700000000000.0, 'receivedAt': 1700000005000.0}),
      );

      expect(message.sentAt, DateTime.utc(2023, 11, 14, 22, 13, 20));
      expect(message.receivedAt, DateTime.utc(2023, 11, 14, 22, 13, 25));
    });

    test('differing timestamps make messages unequal', () {
      final first = InboxMessage.fromMap(mapWith({'sentAt': 1700000010000}));
      final second = InboxMessage.fromMap(mapWith({'sentAt': 1700000020000}));

      expect(first, isNot(second));
    });
  });

  group('InboxMessage.tryFromMap', () {
    test('returns the message when every required field is present', () {
      final message = InboxMessage.tryFromMap(fullMessageMap());

      expect(message, isNotNull);
      expect(message!.id, 'msg-1');
    });

    test('returns null instead of throwing for an unusable message', () {
      expect(InboxMessage.tryFromMap(fullMessageMap()..remove('id')), isNull);
      expect(
        InboxMessage.tryFromMap(fullMessageMap()..remove('sentAt')),
        isNull,
      );
      expect(
        InboxMessage.tryFromMap(fullMessageMap()..['receivedAt'] = 'soon'),
        isNull,
      );
    });
  });

  group('InboxMessageState', () {
    test('wire values match the native contract', () {
      expect(InboxMessageState.read.wireValue, 'read');
      expect(InboxMessageState.unread.wireValue, 'unread');
      expect(InboxMessageState.archived.wireValue, 'archived');
      expect(InboxMessageState.unarchived.wireValue, 'unarchived');
    });
  });
}
