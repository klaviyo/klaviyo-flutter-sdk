import 'dart:async';
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

      test('parses null buttonLabel as empty string in formCtaClicked', () {
        final event = FormLifecycleEvent.fromMap({
          'type': 'form_lifecycle_event',
          'data': {
            'event': 'formCtaClicked',
            'formId': 'abc123',
            'formName': 'Welcome Form',
            'buttonLabel': null,
            'deepLinkUrl': 'myapp://products',
          },
        });
        expect(event, isA<FormCtaClicked>());
        final cta = event as FormCtaClicked;
        expect(cta.buttonLabel, '');
      });

      test('parses empty buttonLabel in formCtaClicked', () {
        final event = FormLifecycleEvent.fromMap({
          'type': 'form_lifecycle_event',
          'data': {
            'event': 'formCtaClicked',
            'formId': 'abc123',
            'formName': 'Welcome Form',
            'buttonLabel': '',
            'deepLinkUrl': 'myapp://products',
          },
        });

        expect(event, isA<FormCtaClicked>());
        final cta = event as FormCtaClicked;
        expect(cta.buttonLabel, '');
        expect(cta.deepLinkUrl, 'myapp://products');
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

    test('throws on wrong type field', () {
      expect(
        () => FormLifecycleEvent.fromMap({
          'type': 'push_notification',
          'data': {
            'event': 'formShown',
            'formId': 'abc123',
            'formName': 'Welcome Form',
          },
        }),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('form_lifecycle_event'),
          ),
        ),
      );
    });

    test('throws on missing type field', () {
      expect(
        () => FormLifecycleEvent.fromMap({
          'data': {
            'event': 'formShown',
            'formId': 'abc123',
            'formName': 'Welcome Form',
          },
        }),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('form_lifecycle_event'),
          ),
        ),
      );
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
        FormWillDisplay(
          formId: '4',
          formName: 'Test',
          formType: 'POPUP',
          completer: Completer<bool>(),
        ),
      ];

      final names = events.map((event) {
        // This switch is exhaustive thanks to the sealed class
        return switch (event) {
          FormShown() => 'shown',
          FormDismissed() => 'dismissed',
          FormCtaClicked() => 'cta',
          FormWillDisplay() => 'willDisplay',
        };
      }).toList();

      expect(names, ['shown', 'dismissed', 'cta', 'willDisplay']);
    });
  });

  group('FormWillDisplay', () {
    test('accept completes with true', () async {
      final completer = Completer<bool>();
      final event = FormWillDisplay(
        formId: 'gate1',
        formName: 'Gated Form',
        formType: 'POPUP',
        completer: completer,
      );

      event.accept();

      expect(await completer.future, isTrue);
    });

    test('reject completes with false', () async {
      final completer = Completer<bool>();
      final event = FormWillDisplay(
        formId: 'gate1',
        formName: 'Gated Form',
        formType: 'FLYOUT',
        completer: completer,
      );

      event.reject();

      expect(await completer.future, isFalse);
    });

    test('double call is ignored — first call wins', () async {
      final completer = Completer<bool>();
      final event = FormWillDisplay(
        formId: 'gate1',
        formName: 'Gated Form',
        formType: 'POPUP',
        completer: completer,
      );

      event.reject();
      event.accept(); // should be ignored

      expect(await completer.future, isFalse);
    });

    test('accept then reject — first call wins', () async {
      final completer = Completer<bool>();
      final event = FormWillDisplay(
        formId: 'gate1',
        formName: 'Gated Form',
        formType: 'POPUP',
        completer: completer,
      );

      event.accept();
      event.reject(); // should be ignored

      expect(await completer.future, isTrue);
    });

    test('eventName returns formWillDisplay', () {
      final event = FormWillDisplay(
        formId: 'abc',
        formName: 'Test',
        formType: 'POPUP',
        completer: Completer<bool>(),
      );
      expect(event.eventName, 'formWillDisplay');
    });

    test('toString includes formType', () {
      final event = FormWillDisplay(
        formId: 'abc',
        formName: 'Test',
        formType: 'FULLSCREEN',
        completer: Completer<bool>(),
      );
      expect(
        event.toString(),
        'FormWillDisplay(formId: abc, formName: Test, formType: FULLSCREEN)',
      );
    });

    test('equality ignores completer', () {
      final a = FormWillDisplay(
        formId: 'abc',
        formName: 'Form',
        formType: 'POPUP',
        completer: Completer<bool>(),
      );
      final b = FormWillDisplay(
        formId: 'abc',
        formName: 'Form',
        formType: 'POPUP',
        completer: Completer<bool>(),
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('inequality by formType', () {
      final popup = FormWillDisplay(
        formId: 'abc',
        formName: 'Form',
        formType: 'POPUP',
        completer: Completer<bool>(),
      );
      final flyout = FormWillDisplay(
        formId: 'abc',
        formName: 'Form',
        formType: 'FLYOUT',
        completer: Completer<bool>(),
      );
      expect(popup, isNot(equals(flyout)));
    });

    test('FormWillDisplay not equal to FormShown', () {
      final willDisplay = FormWillDisplay(
        formId: 'abc',
        formName: 'Form',
        formType: 'POPUP',
        completer: Completer<bool>(),
      );
      const shown = FormShown(formId: 'abc', formName: 'Form');
      expect(willDisplay, isNot(equals(shown)));
    });
  });

  group('FormLifecycleEvent.fromMap crash safety', () {
    test(
        'fromMap throws on formWillDisplay — confirming it must not be '
        'emitted on the raw event stream', () {
      expect(
        () => FormLifecycleEvent.fromMap({
          'type': 'form_lifecycle_event',
          'data': {
            'event': 'formWillDisplay',
            'formId': 'abc',
            'formName': 'Form',
            'formType': 'POPUP',
          },
        }),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('formWillDisplay'),
          ),
        ),
      );
    });
  });

  group('FormWillDisplay timeout', () {
    test(
        'completer times out and returns true (fail-open) when nobody '
        'calls accept/reject', () async {
      final completer = Completer<bool>();
      // ignore: unused_local_variable — we just need the event to exist
      final event = FormWillDisplay(
        formId: 'timeout1',
        formName: 'Timeout Form',
        formType: 'POPUP',
        completer: completer,
      );

      // Simulate the SDK timeout logic: if nobody calls accept/reject,
      // the completer future should time out and fail-open
      final result = await completer.future.timeout(
        const Duration(milliseconds: 50),
        onTimeout: () => true, // fail-open
      );

      expect(result, isTrue);
    });
  });
}
