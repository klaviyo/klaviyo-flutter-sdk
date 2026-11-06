import 'package:flutter_test/flutter_test.dart';
import 'package:klaviyo_flutter_sdk/klaviyo_flutter_sdk.dart';

void main() {
  group('KlaviyoEvent valueCurrency', () {
    test('toJson includes value_currency when set', () {
      final event = KlaviyoEvent.custom(
        metric: 'Purchase Completed',
        value: 10,
        valueCurrency: 'EUR',
      );

      expect(event.toJson(), {
        'name': 'Purchase Completed',
        'value': 10.0,
        'value_currency': 'EUR',
      });
    });

    test('toJson omits value_currency when not set', () {
      final event = KlaviyoEvent(
        name: const EventMetric.custom('Purchase Completed'),
        properties: {'product_id': 'prod_123'},
        value: 10,
        uniqueId: 'order_1',
      );

      expect(event.toJson(), {
        'name': 'Purchase Completed',
        'properties': {'product_id': 'prod_123'},
        'value': 10.0,
        'unique_id': 'order_1',
      });
    });

    test('fromJson reads value_currency', () {
      final event = KlaviyoEvent.fromJson({
        'name': 'Purchase Completed',
        'value': 10,
        'value_currency': 'EUR',
      });

      expect(event.valueCurrency, 'EUR');
      expect(event.value, 10.0);
    });

    test('fromJson leaves valueCurrency null when absent', () {
      final event = KlaviyoEvent.fromJson({'name': 'Purchase Completed'});

      expect(event.valueCurrency, isNull);
    });

    test('round-trips through toJson and fromJson', () {
      final event = KlaviyoEvent.custom(
        metric: 'Purchase Completed',
        value: 99.99,
        valueCurrency: 'USD',
        uniqueId: 'order_2',
      );

      expect(KlaviyoEvent.fromJson(event.toJson()), event);
    });

    test('copyWith sets and preserves valueCurrency', () {
      final event = KlaviyoEvent.custom(metric: 'Purchase Completed');

      final withCurrency = event.copyWith(valueCurrency: 'EUR');
      expect(withCurrency.valueCurrency, 'EUR');
      expect(withCurrency.copyWith(value: 5).valueCurrency, 'EUR');
    });

    test('equality and hashCode account for valueCurrency', () {
      final eur = KlaviyoEvent.custom(
        metric: 'Purchase Completed',
        value: 10,
        valueCurrency: 'EUR',
      );
      final eurAgain = KlaviyoEvent.custom(
        metric: 'Purchase Completed',
        value: 10,
        valueCurrency: 'EUR',
      );
      final usd = eur.copyWith(valueCurrency: 'USD');

      expect(eur, eurAgain);
      expect(eur.hashCode, eurAgain.hashCode);
      expect(eur == usd, isFalse);
    });
  });
}
