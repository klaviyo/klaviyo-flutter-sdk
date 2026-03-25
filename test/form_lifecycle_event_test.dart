import 'package:flutter_test/flutter_test.dart';
import 'package:klaviyo_flutter_sdk/klaviyo_flutter_sdk.dart';

void main() {
  group('FormLifecycleEvent.fromMap', () {
    test('parses form_shown event', () {
      final event = FormLifecycleEvent.fromMap({
        'type': 'form_lifecycle_event',
        'data': {
          'event': 'form_shown',
          'formId': 'abc123',
          'formName': 'Welcome Form',
        },
      });

      expect(event, isA<FormShown>());
      expect(event.formId, 'abc123');
      expect(event.formName, 'Welcome Form');
      expect(event.eventName, 'formShown');
    });

    test('parses form_dismissed event', () {
      final event = FormLifecycleEvent.fromMap({
        'type': 'form_lifecycle_event',
        'data': {
          'event': 'form_dismissed',
          'formId': 'abc123',
          'formName': 'Welcome Form',
        },
      });

      expect(event, isA<FormDismissed>());
      expect(event.formId, 'abc123');
      expect(event.formName, 'Welcome Form');
      expect(event.eventName, 'formDismissed');
    });

    test('parses form_cta_clicked event with all fields', () {
      final event = FormLifecycleEvent.fromMap({
        'type': 'form_lifecycle_event',
        'data': {
          'event': 'form_cta_clicked',
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

    test('parses form_cta_clicked with null optional fields', () {
      final event = FormLifecycleEvent.fromMap({
        'type': 'form_lifecycle_event',
        'data': {
          'event': 'form_cta_clicked',
          'formId': null,
          'formName': null,
          'buttonLabel': null,
          'deepLinkUrl': null,
        },
      });

      expect(event, isA<FormCtaClicked>());
      final cta = event as FormCtaClicked;
      expect(cta.formId, isNull);
      expect(cta.formName, isNull);
      expect(cta.buttonLabel, isNull);
      expect(cta.deepLinkUrl, isNull);
    });

    test('parses event with null formId and formName', () {
      final event = FormLifecycleEvent.fromMap({
        'type': 'form_lifecycle_event',
        'data': {
          'event': 'form_shown',
          'formId': null,
          'formName': null,
        },
      });

      expect(event, isA<FormShown>());
      expect(event.formId, isNull);
      expect(event.formName, isNull);
    });

    test('parses event with missing data key defaults to empty map', () {
      // data key missing entirely — should throw because 'event' is absent
      expect(
        () => FormLifecycleEvent.fromMap({'type': 'form_lifecycle_event'}),
        throwsA(isA<TypeError>()),
      );
    });

    test('throws on unknown event type', () {
      expect(
        () => FormLifecycleEvent.fromMap({
          'type': 'form_lifecycle_event',
          'data': {'event': 'form_exploded'},
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
      const a = FormCtaClicked(formId: 'x', buttonLabel: 'Go');
      const b = FormCtaClicked(formId: 'x', buttonLabel: 'Stop');
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
  });

  group('FormLifecycleEvent exhaustive pattern matching', () {
    test('switch covers all subtypes', () {
      final events = <FormLifecycleEvent>[
        const FormShown(formId: '1'),
        const FormDismissed(formId: '2'),
        const FormCtaClicked(formId: '3', buttonLabel: 'Go'),
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
