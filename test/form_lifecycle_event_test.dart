import 'package:flutter_test/flutter_test.dart';
import 'package:klaviyo_flutter_sdk/klaviyo_flutter_sdk.dart';

void main() {
  group('FormLifecycleEvent.fromMap', () {
    test('parses formShown event', () {
      final event = FormLifecycleEvent.fromMap({
        'type': 'form_lifecycle_event',
        'data': {
          'event': 'formShown',
          'formId': 'abc123',
          'formName': 'Welcome Form',
        },
      });

      expect(event, isA<FormShown>());
      expect(event.formId, 'abc123');
      expect(event.formName, 'Welcome Form');
      expect(event.eventName, 'formShown');
    });

    test('parses formDismissed event', () {
      final event = FormLifecycleEvent.fromMap({
        'type': 'form_lifecycle_event',
        'data': {
          'event': 'formDismissed',
          'formId': 'abc123',
          'formName': 'Welcome Form',
        },
      });

      expect(event, isA<FormDismissed>());
      expect(event.formId, 'abc123');
      expect(event.formName, 'Welcome Form');
      expect(event.eventName, 'formDismissed');
    });

    test('parses formCtaClicked event with all fields', () {
      final event = FormLifecycleEvent.fromMap({
        'type': 'form_lifecycle_event',
        'data': {
          'event': 'formCtaClicked',
          'formId': 'abc123',
          'formName': 'Welcome Form',
          'buttonLabel': 'Shop Now',
          'deepLinkUrl': 'myapp://products',
        },
      });

      expect(event, isA<FormCtaClicked>());
      final cta = event as FormCtaClicked;
      expect(cta.formId, 'abc123');
      expect(cta.formName, 'Welcome Form');
      expect(cta.buttonLabel, 'Shop Now');
      expect(cta.deepLinkUrl, 'myapp://products');
      expect(cta.eventName, 'formCtaClicked');
    });

    test('throws on null deepLinkUrl in formCtaClicked', () {
      expect(
        () => FormLifecycleEvent.fromMap({
          'type': 'form_lifecycle_event',
          'data': {
            'event': 'formCtaClicked',
            'formId': 'abc123',
            'formName': 'Welcome Form',
            'buttonLabel': 'Shop Now',
            'deepLinkUrl': null,
          },
        }),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('deepLinkUrl'),
          ),
        ),
      );
    });

    test('throws on missing deepLinkUrl in formCtaClicked', () {
      expect(
        () => FormLifecycleEvent.fromMap({
          'type': 'form_lifecycle_event',
          'data': {
            'event': 'formCtaClicked',
            'formId': 'abc123',
            'formName': 'Welcome Form',
            'buttonLabel': 'Shop Now',
          },
        }),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('deepLinkUrl'),
          ),
        ),
      );
    });

    test('throws on empty deepLinkUrl in formCtaClicked', () {
      expect(
        () => FormLifecycleEvent.fromMap({
          'type': 'form_lifecycle_event',
          'data': {
            'event': 'formCtaClicked',
            'formId': 'abc123',
            'formName': 'Welcome Form',
            'buttonLabel': 'Shop Now',
            'deepLinkUrl': '',
          },
        }),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('deepLinkUrl'),
          ),
        ),
      );
    });

    group('throws on missing required fields', () {
      test('throws on null formId', () {
        expect(
          () => FormLifecycleEvent.fromMap({
            'type': 'form_lifecycle_event',
            'data': {
              'event': 'formShown',
              'formId': null,
              'formName': 'Welcome Form',
            },
          }),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('formId'),
            ),
          ),
        );
      });

      test('throws on empty formId', () {
        expect(
          () => FormLifecycleEvent.fromMap({
            'type': 'form_lifecycle_event',
            'data': {
              'event': 'formShown',
              'formId': '',
              'formName': 'Welcome Form',
            },
          }),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('formId'),
            ),
          ),
        );
      });

      test('throws on missing formId key', () {
        expect(
          () => FormLifecycleEvent.fromMap({
            'type': 'form_lifecycle_event',
            'data': {
              'event': 'formShown',
              'formName': 'Welcome Form',
            },
          }),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('formId'),
            ),
          ),
        );
      });

      test('throws on null formName', () {
        expect(
          () => FormLifecycleEvent.fromMap({
            'type': 'form_lifecycle_event',
            'data': {
              'event': 'formShown',
              'formId': 'abc123',
              'formName': null,
            },
          }),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('formName'),
            ),
          ),
        );
      });

      test('throws on empty formName', () {
        expect(
          () => FormLifecycleEvent.fromMap({
            'type': 'form_lifecycle_event',
            'data': {
              'event': 'formShown',
              'formId': 'abc123',
              'formName': '',
            },
          }),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('formName'),
            ),
          ),
        );
      });

      test('throws on null buttonLabel in formCtaClicked', () {
        expect(
          () => FormLifecycleEvent.fromMap({
            'type': 'form_lifecycle_event',
            'data': {
              'event': 'formCtaClicked',
              'formId': 'abc123',
              'formName': 'Welcome Form',
              'buttonLabel': null,
              'deepLinkUrl': 'myapp://products',
            },
          }),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('buttonLabel'),
            ),
          ),
        );
      });

      test('throws on empty buttonLabel in formCtaClicked', () {
        expect(
          () => FormLifecycleEvent.fromMap({
            'type': 'form_lifecycle_event',
            'data': {
              'event': 'formCtaClicked',
              'formId': 'abc123',
              'formName': 'Welcome Form',
              'buttonLabel': '',
              'deepLinkUrl': 'myapp://products',
            },
          }),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('buttonLabel'),
            ),
          ),
        );
      });

      test('throws on null event type', () {
        expect(
          () => FormLifecycleEvent.fromMap({
            'type': 'form_lifecycle_event',
            'data': {
              'event': null,
              'formId': 'abc123',
              'formName': 'Welcome Form',
            },
          }),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('event'),
            ),
          ),
        );
      });

      test('throws on missing event type', () {
        expect(
          () => FormLifecycleEvent.fromMap({
            'type': 'form_lifecycle_event',
            'data': {
              'formId': 'abc123',
              'formName': 'Welcome Form',
            },
          }),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('event'),
            ),
          ),
        );
      });
    });

    test('throws on empty map', () {
      expect(
        () => FormLifecycleEvent.fromMap({}),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws on map with no data key', () {
      expect(
        () => FormLifecycleEvent.fromMap({'type': 'form_lifecycle_event'}),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws on empty data map', () {
      expect(
        () => FormLifecycleEvent.fromMap({
          'type': 'form_lifecycle_event',
          'data': <String, dynamic>{},
        }),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws on unknown event type', () {
      expect(
        () => FormLifecycleEvent.fromMap({
          'type': 'form_lifecycle_event',
          'data': {
            'event': 'form_exploded',
            'formId': 'abc123',
            'formName': 'Welcome Form',
          },
        }),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('FormLifecycleEvent equality', () {
    test('FormShown equals with same values', () {
      const a = FormShown(formId: 'x', formName: 'y');
      const b = FormShown(formId: 'x', formName: 'y');
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('FormShown not equal to FormDismissed with same values', () {
      const shown = FormShown(formId: 'x', formName: 'y');
      const dismissed = FormDismissed(formId: 'x', formName: 'y');
      expect(shown, isNot(equals(dismissed)));
    });

    test('FormCtaClicked equals with same values', () {
      const a = FormCtaClicked(
        formId: 'x',
        formName: 'y',
        buttonLabel: 'Go',
        deepLinkUrl: 'app://go',
      );
      const b = FormCtaClicked(
        formId: 'x',
        formName: 'y',
        buttonLabel: 'Go',
        deepLinkUrl: 'app://go',
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('FormCtaClicked not equal with different buttonLabel', () {
      const a = FormCtaClicked(
        formId: 'x',
        formName: 'y',
        buttonLabel: 'Go',
        deepLinkUrl: 'app://x',
      );
      const b = FormCtaClicked(
        formId: 'x',
        formName: 'y',
        buttonLabel: 'Stop',
        deepLinkUrl: 'app://x',
      );
      expect(a, isNot(equals(b)));
    });

    test('FormCtaClicked not equal with different deepLinkUrl', () {
      const a = FormCtaClicked(
        formId: 'x',
        formName: 'y',
        buttonLabel: 'Go',
        deepLinkUrl: 'app://a',
      );
      const b = FormCtaClicked(
        formId: 'x',
        formName: 'y',
        buttonLabel: 'Go',
        deepLinkUrl: 'app://b',
      );
      expect(a, isNot(equals(b)));
    });
  });

  group('FormLifecycleEvent toString', () {
    test('FormShown toString', () {
      const event = FormShown(formId: 'abc', formName: 'Test');
      expect(event.toString(), 'FormShown(formId: abc, formName: Test)');
    });

    test('FormDismissed toString', () {
      const event = FormDismissed(formId: 'abc', formName: 'Test');
      expect(event.toString(), 'FormDismissed(formId: abc, formName: Test)');
    });

    test('FormCtaClicked toString', () {
      const event = FormCtaClicked(
        formId: 'abc',
        formName: 'Test',
        buttonLabel: 'Click',
        deepLinkUrl: 'app://x',
      );
      expect(
        event.toString(),
        'FormCtaClicked(formId: abc, formName: Test, '
        'buttonLabel: Click, deepLinkUrl: app://x)',
      );
    });

    test('FormCtaClicked toString with deepLinkUrl', () {
      const event = FormCtaClicked(
        formId: 'abc',
        formName: 'Test',
        buttonLabel: 'Click',
        deepLinkUrl: 'app://home',
      );
      expect(
        event.toString(),
        'FormCtaClicked(formId: abc, formName: Test, '
        'buttonLabel: Click, deepLinkUrl: app://home)',
      );
    });
  });

  group('FormLifecycleEvent exhaustive pattern matching', () {
    test('switch covers all subtypes', () {
      final events = <FormLifecycleEvent>[
        const FormShown(formId: '1', formName: 'Test'),
        const FormDismissed(formId: '2', formName: 'Test'),
        const FormCtaClicked(
          formId: '3',
          formName: 'Test',
          buttonLabel: 'Go',
          deepLinkUrl: 'app://go',
        ),
      ];

      final names = events.map((event) {
        // This switch is exhaustive thanks to the sealed class
        return switch (event) {
          FormShown() => 'shown',
          FormDismissed() => 'dismissed',
          FormCtaClicked() => 'cta',
        };
      }).toList();

      expect(names, ['shown', 'dismissed', 'cta']);
    });
  });
}
