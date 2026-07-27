import 'package:flutter_test/flutter_test.dart';
import 'package:klaviyo_flutter_sdk/klaviyo_flutter_sdk.dart';

void main() {
  group('KlaviyoSubscription.toJson', () {
    test('serializes listId, channels and customSource', () {
      const subscription = KlaviyoSubscription(
        listId: 'ABC123',
        channels: KlaviyoSubscriptionChannels(
          email: {EmailConsent.marketing, EmailConsent.openTracking},
          sms: {MessagingConsent.marketing},
          whatsapp: {MessagingConsent.transactional},
        ),
        customSource: 'Checkout screen',
      );

      final json = subscription.toJson();

      expect(json['listId'], 'ABC123');
      expect(json['customSource'], 'Checkout screen');
      // Order is not guaranteed by Set iteration, so compare unordered.
      expect(
        json['channels']['email'],
        unorderedEquals(['marketing', 'open_tracking']),
      );
      expect(json['channels']['sms'], ['marketing']);
      expect(json['channels']['whatsapp'], ['transactional']);
    });

    test('omits customSource when null', () {
      const subscription = KlaviyoSubscription(
        listId: 'ABC123',
        channels: KlaviyoSubscriptionChannels(
          email: {EmailConsent.marketing},
        ),
      );

      expect(subscription.toJson().containsKey('customSource'), isFalse);
    });

    test('omits channels that were not requested', () {
      const subscription = KlaviyoSubscription(
        listId: 'ABC123',
        channels: KlaviyoSubscriptionChannels(
          sms: {MessagingConsent.marketing},
        ),
      );

      final channels = subscription.toJson()['channels'] as Map;

      expect(channels.containsKey('email'), isFalse);
      expect(channels.containsKey('whatsapp'), isFalse);
      expect(channels['sms'], ['marketing']);
    });

    test('preserves an explicitly empty consent set', () {
      // The native SDKs warn and drop the request in this case; collapsing it
      // to an omitted channel here would mask the developer error.
      const subscription = KlaviyoSubscription(
        listId: 'ABC123',
        channels: KlaviyoSubscriptionChannels(email: {}),
      );

      expect(subscription.toJson()['channels']['email'], isEmpty);
    });

    test('allAvailableMarketing omits the channels key entirely', () {
      const subscription = KlaviyoSubscription.allAvailableMarketing(
        listId: 'ABC123',
        customSource: 'Onboarding',
      );

      final json = subscription.toJson();

      expect(json['listId'], 'ABC123');
      expect(json['customSource'], 'Onboarding');
      expect(json.containsKey('channels'), isFalse);
      expect(subscription.channels, isNull);
    });
  });

  group('KlaviyoSubscriptionChannels equality', () {
    test('is insensitive to consent ordering', () {
      const a = KlaviyoSubscriptionChannels(
        email: {EmailConsent.marketing, EmailConsent.openTracking},
      );
      const b = KlaviyoSubscriptionChannels(
        email: {EmailConsent.openTracking, EmailConsent.marketing},
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('distinguishes an omitted channel from an empty one', () {
      const omitted = KlaviyoSubscriptionChannels();
      const empty = KlaviyoSubscriptionChannels(email: {});

      expect(omitted, isNot(empty));
    });
  });
}
