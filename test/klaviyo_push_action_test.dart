import 'package:flutter_test/flutter_test.dart';
import 'package:klaviyo_flutter_sdk/klaviyo_flutter_sdk.dart';

void main() {
  group('KlaviyoPushAction.fromMap', () {
    test('parses push_open_web_url event', () {
      final action = KlaviyoPushAction.fromMap({
        'type': 'push_open_web_url',
        'data': {'url': 'https://klaviyo.com'},
      });

      expect(action, isA<OpenWebUrl>());
      expect((action as OpenWebUrl).url, 'https://klaviyo.com');
      expect(action.eventName, 'openWebUrl');
    });

    test('parses open_url action button', () {
      final action = KlaviyoPushAction.fromMap({
        'type': 'push_action_button_tapped',
        'data': {
          'id': 'btn1',
          'label': 'Shop',
          'action': 'open_url',
          'url': 'https://klaviyo.com',
        },
      });

      expect(action, isA<ActionButtonTapped>());
      final tapped = action as ActionButtonTapped;
      expect(tapped.buttonId, 'btn1');
      expect(tapped.label, 'Shop');
      expect(tapped.action, 'open_url');
      expect(tapped.url, 'https://klaviyo.com');
      expect(tapped.eventName, 'actionButtonTapped');
    });

    test('parses deep_link action button', () {
      final action = KlaviyoPushAction.fromMap({
        'type': 'push_action_button_tapped',
        'data': {
          'id': 'btn2',
          'label': 'Open',
          'action': 'deep_link',
          'url': 'myapp://products',
        },
      });

      expect(action, isA<ActionButtonTapped>());
      final tapped = action as ActionButtonTapped;
      expect(tapped.action, 'deep_link');
      expect(tapped.url, 'myapp://products');
    });

    test('parses open_app action button with null url', () {
      final action = KlaviyoPushAction.fromMap({
        'type': 'push_action_button_tapped',
        'data': {
          'id': 'btn3',
          'label': 'Launch',
          'action': 'open_app',
        },
      });

      expect(action, isA<ActionButtonTapped>());
      final tapped = action as ActionButtonTapped;
      expect(tapped.action, 'open_app');
      expect(tapped.url, isNull);
    });

    group('forwards special URL schemes verbatim', () {
      // The model is intentionally scheme-agnostic: it forwards whatever URL it
      // receives without inspecting the scheme. Scheme policy lives in the
      // native SDK (allowlist: http/https/mailto/tel/sms/smsto), which decides
      // what to actually dispatch. `geo:` is included here precisely to prove
      // the model does NOT gate — even a scheme the native allowlist omits is
      // passed through untouched if it ever reaches the bridge.
      for (final url in [
        'mailto:hi@klaviyo.com',
        'tel:+15551234567',
        'sms:+15551234567',
        'smsto:+15551234567',
        'geo:37.7,-122.4',
      ]) {
        test('OpenWebUrl preserves "$url"', () {
          final action = KlaviyoPushAction.fromMap({
            'type': 'push_open_web_url',
            'data': {'url': url},
          });
          expect(action, isA<OpenWebUrl>());
          expect((action as OpenWebUrl).url, url);
        });

        test('ActionButtonTapped preserves "$url"', () {
          final action = KlaviyoPushAction.fromMap({
            'type': 'push_action_button_tapped',
            'data': {
              'id': 'btn',
              'label': 'Contact',
              'action': 'open_url',
              'url': url,
            },
          });
          expect(action, isA<ActionButtonTapped>());
          expect((action as ActionButtonTapped).url, url);
        });
      }
    });

    group('throws on invalid input', () {
      test('throws on missing data', () {
        expect(
          () => KlaviyoPushAction.fromMap({'type': 'push_open_web_url'}),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('data'),
            ),
          ),
        );
      });

      test('throws on unknown type', () {
        expect(
          () => KlaviyoPushAction.fromMap({
            'type': 'push_exploded',
            'data': {'url': 'https://x.com'},
          }),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('Unknown push action type'),
            ),
          ),
        );
      });

      test('throws on missing url in push_open_web_url', () {
        expect(
          () => KlaviyoPushAction.fromMap({
            'type': 'push_open_web_url',
            'data': <String, dynamic>{},
          }),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('url'),
            ),
          ),
        );
      });

      test('throws on empty url in push_open_web_url', () {
        expect(
          () => KlaviyoPushAction.fromMap({
            'type': 'push_open_web_url',
            'data': {'url': ''},
          }),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws on missing id in action button', () {
        expect(
          () => KlaviyoPushAction.fromMap({
            'type': 'push_action_button_tapped',
            'data': {
              'label': 'Shop',
              'action': 'open_url',
              'url': 'https://x.com',
            },
          }),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('id'),
            ),
          ),
        );
      });

      test('tolerates missing label (defaults to empty string)', () {
        // Native layers send label conditionally; a missing label must not
        // drop the event.
        final action = KlaviyoPushAction.fromMap({
          'type': 'push_action_button_tapped',
          'data': {
            'id': 'btn1',
            'action': 'open_url',
            'url': 'https://x.com',
          },
        });
        expect(action, isA<ActionButtonTapped>());
        expect((action as ActionButtonTapped).label, '');
      });

      test('throws on missing action in action button', () {
        expect(
          () => KlaviyoPushAction.fromMap({
            'type': 'push_action_button_tapped',
            'data': {
              'id': 'btn1',
              'label': 'Shop',
              'url': 'https://x.com',
            },
          }),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('action'),
            ),
          ),
        );
      });

      test('throws on unknown action value', () {
        expect(
          () => KlaviyoPushAction.fromMap({
            'type': 'push_action_button_tapped',
            'data': {
              'id': 'btn1',
              'label': 'Shop',
              'action': 'self_destruct',
              'url': 'https://x.com',
            },
          }),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('Unknown action'),
            ),
          ),
        );
      });

      test('throws on missing url for open_url action button', () {
        expect(
          () => KlaviyoPushAction.fromMap({
            'type': 'push_action_button_tapped',
            'data': {
              'id': 'btn1',
              'label': 'Shop',
              'action': 'open_url',
            },
          }),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('url'),
            ),
          ),
        );
      });

      test('throws on missing url for deep_link action button', () {
        expect(
          () => KlaviyoPushAction.fromMap({
            'type': 'push_action_button_tapped',
            'data': {
              'id': 'btn1',
              'label': 'Open',
              'action': 'deep_link',
            },
          }),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws on empty map', () {
        expect(
          () => KlaviyoPushAction.fromMap({}),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('KlaviyoPushAction equality', () {
      test('OpenWebUrl equals with same url', () {
        const a = OpenWebUrl(url: 'https://x.com');
        const b = OpenWebUrl(url: 'https://x.com');
        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('OpenWebUrl not equal with different url', () {
        const a = OpenWebUrl(url: 'https://a.com');
        const b = OpenWebUrl(url: 'https://b.com');
        expect(a, isNot(equals(b)));
      });

      test('ActionButtonTapped equals with same values', () {
        const a = ActionButtonTapped(
          buttonId: 'b',
          label: 'Go',
          action: 'open_url',
          url: 'https://x.com',
        );
        const b = ActionButtonTapped(
          buttonId: 'b',
          label: 'Go',
          action: 'open_url',
          url: 'https://x.com',
        );
        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('ActionButtonTapped not equal with different action', () {
        const a = ActionButtonTapped(
          buttonId: 'b',
          label: 'Go',
          action: 'open_url',
          url: 'https://x.com',
        );
        const b = ActionButtonTapped(
          buttonId: 'b',
          label: 'Go',
          action: 'deep_link',
          url: 'https://x.com',
        );
        expect(a, isNot(equals(b)));
      });

      test('OpenWebUrl not equal to ActionButtonTapped', () {
        const a = OpenWebUrl(url: 'https://x.com');
        const b = ActionButtonTapped(
          buttonId: 'b',
          label: 'Go',
          action: 'open_url',
          url: 'https://x.com',
        );
        expect(a, isNot(equals(b)));
      });
    });

    group('KlaviyoPushAction toString', () {
      test('OpenWebUrl toString', () {
        const action = OpenWebUrl(url: 'https://x.com');
        expect(action.toString(), 'OpenWebUrl(url: https://x.com)');
      });

      test('ActionButtonTapped toString', () {
        const action = ActionButtonTapped(
          buttonId: 'b1',
          label: 'Shop',
          action: 'open_url',
          url: 'https://x.com',
        );
        expect(
          action.toString(),
          'ActionButtonTapped(buttonId: b1, label: Shop, '
          'action: open_url, url: https://x.com)',
        );
      });
    });

    group('KlaviyoPushAction exhaustive pattern matching', () {
      test('switch covers all subtypes', () {
        final actions = <KlaviyoPushAction>[
          const OpenWebUrl(url: 'https://x.com'),
          const ActionButtonTapped(
            buttonId: 'b',
            label: 'Go',
            action: 'open_app',
          ),
        ];

        final names = actions.map((action) {
          return switch (action) {
            OpenWebUrl() => 'web',
            ActionButtonTapped() => 'button',
          };
        }).toList();

        expect(names, ['web', 'button']);
      });
    });
  });
}
