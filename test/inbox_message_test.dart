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

      expect(message.sentAt!.isUtc, isTrue);
      expect(message.sentAt!.millisecondsSinceEpoch, 1700000000000);
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
      expect(message.sentAt, isNull);
      // Android's receivedAt is nullable, so the Dart model must accept null.
      expect(message.receivedAt, isNull);
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

  group('InboxMessage timestamp fields', () {
    Map<String, dynamic> mapWith(Map<String, dynamic> timestamps) =>
        fullMessageMap()..addAll(timestamps);

    test('maps every timestamp from epoch milliseconds to UTC', () {
      final message = InboxMessage.fromMap(
        mapWith({
          'readUpdatedAt': 1700000010000,
          'archivedUpdatedAt': 1700000020000,
          'updatedAt': 1700000030000,
          'expiredAt': 1700000040000,
        }),
      );

      expect(message.readUpdatedAt, DateTime.utc(2023, 11, 14, 22, 13, 30));
      expect(message.archivedUpdatedAt, DateTime.utc(2023, 11, 14, 22, 13, 40));
      expect(message.updatedAt, DateTime.utc(2023, 11, 14, 22, 13, 50));
      expect(message.expiredAt, DateTime.utc(2023, 11, 14, 22, 14));
      expect(message.readUpdatedAt!.isUtc, isTrue);
      expect(message.expiredAt!.isUtc, isTrue);
    });

    test('defaults every timestamp to null when absent', () {
      final message = InboxMessage.fromMap(fullMessageMap());

      expect(message.readUpdatedAt, isNull);
      expect(message.archivedUpdatedAt, isNull);
      expect(message.updatedAt, isNull);
      expect(message.expiredAt, isNull);
    });

    test('treats explicit nulls as absent', () {
      final message = InboxMessage.fromMap(
        mapWith({
          'readUpdatedAt': null,
          'archivedUpdatedAt': null,
          'updatedAt': null,
          'expiredAt': null,
        }),
      );

      expect(message.readUpdatedAt, isNull);
      expect(message.archivedUpdatedAt, isNull);
      expect(message.updatedAt, isNull);
      expect(message.expiredAt, isNull);
    });

    test('ignores malformed timestamps instead of failing the message', () {
      // These fields are optional and non-critical: one bad value must not
      // discard the whole message.
      final cases = <dynamic>[
        'not-a-number',
        '',
        true,
        <String, dynamic>{},
        <dynamic>[],
        1.5,
        double.nan,
        9223372036854775807,
      ];

      for (final bad in cases) {
        final message = InboxMessage.fromMap(mapWith({'readUpdatedAt': bad}));

        expect(message.readUpdatedAt, isNull, reason: 'value: $bad');
        // The rest of the message still parsed.
        expect(message.id, 'msg-1');
        expect(message.title, 'Your order shipped');
      }
    });

    test('accepts a whole-valued double as epoch milliseconds', () {
      final message = InboxMessage.fromMap(
        mapWith({'updatedAt': 1700000000000.0}),
      );

      expect(message.updatedAt, DateTime.utc(2023, 11, 14, 22, 13, 20));
    });

    test('round trips through toMap', () {
      final original = InboxMessage.fromMap(
        mapWith({
          'readUpdatedAt': 1700000010000,
          'archivedUpdatedAt': 1700000020000,
          'updatedAt': 1700000030000,
          'expiredAt': 1700000040000,
        }),
      );

      final restored = InboxMessage.fromMap(original.toMap());

      expect(restored, original);
      expect(restored.hashCode, original.hashCode);
      expect(restored.readUpdatedAt, original.readUpdatedAt);
      expect(restored.expiredAt, original.expiredAt);
    });

    test('toMap emits epoch milliseconds', () {
      final map = InboxMessage.fromMap(
        mapWith({'readUpdatedAt': 1700000010000, 'expiredAt': 1700000040000}),
      ).toMap();

      expect(map['readUpdatedAt'], 1700000010000);
      expect(map['expiredAt'], 1700000040000);
    });

    test('a present timestamp makes the message unequal to one without', () {
      final without = InboxMessage.fromMap(fullMessageMap());
      final withTimestamp = InboxMessage.fromMap(
        mapWith({'readUpdatedAt': 1700000010000}),
      );

      expect(without, isNot(withTimestamp));
    });

    test('differing timestamps make messages unequal', () {
      final first = InboxMessage.fromMap(mapWith({'updatedAt': 1700000010000}));
      final second =
          InboxMessage.fromMap(mapWith({'updatedAt': 1700000020000}));

      expect(first, isNot(second));
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
