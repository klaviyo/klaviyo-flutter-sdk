// TEMPORARY local-only harness for chunk B device testing. Never commit.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:klaviyo_flutter_sdk/klaviyo_flutter_sdk.dart';

class ChunkBHarness extends StatefulWidget {
  const ChunkBHarness({super.key, required this.email});
  final String Function() email;

  @override
  State<ChunkBHarness> createState() => _ChunkBHarnessState();
}

class _ChunkBHarnessState extends State<ChunkBHarness> {
  final _k = KlaviyoSDK();
  String _out = 'harness idle';
  String _tc = 'tc000';
  final Map<String, Future<void> Function()> _reg = {};
  String _email() =>
      'evan.masseau+flutter-chunkb-$_tc-${defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android'}@klaviyo.com';

  Future<void> _run(String label, Future<void> Function() f) async {
    _tc = label.split(' ')[1].toLowerCase();
    // ignore: avoid_print
    print('CHUNKB_CASE $label');
    try {
      if (!label.contains('TC018') && !label.contains('TC020')) {
        await _k.resetProfile();
        await Future<void>.delayed(const Duration(milliseconds: 700));
        if (label.contains('TC014') ||
            label.contains('TC015') ||
            label.contains('TC017')) {
          await _k.setEmail(_email());
        }
      }
      await f();
      final n = int.tryParse(label.split(' ')[1].substring(2)) ?? 0;
      if (n >= 5 && n <= 13) {
        await Future<void>.delayed(const Duration(milliseconds: 400));
        await _k.createEvent(KlaviyoEvent.custom(metric: 'chunkb_flush'));
      }
      setState(() => _out = '$label OK');
    } catch (e) {
      setState(() => _out = '$label THREW: $e');
    }
  }

  Future<void> _attr(String k, dynamic v) => _k.setProfileAttribute(k, v);

  Widget _b(String t, Future<void> Function() f) {
    _reg[t] = f;
    return _bw(t, f);
  }

  Widget _bw(String t, Future<void> Function() f) => Padding(
        padding: EdgeInsets.zero,
        child: SizedBox(
          width: 175,
          height: 32,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(padding: EdgeInsets.zero),
            onPressed: () => _run(t, f),
            child: Text(t, style: const TextStyle(fontSize: 11)),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final e = _email;
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        SizedBox(
          width: 360,
          child: Text(_out, key: const Key('harness_out')),
        ),
        _bw('H RUN ALL', () async {
          final entries = _reg.entries.toList();
          for (final e in entries) {
            if (e.key.contains('TC018') || e.key.contains('TC020')) continue;
            await _run(e.key, e.value);
            await Future<void>.delayed(const Duration(seconds: 4));
          }
        }),
        _b(
          'H TC001 full profile',
          () => _k.setProfile(
            KlaviyoProfile(
              email: e(),
              firstName: 'Ada',
              lastName: 'Lovelace',
              properties: {'example_app_source': 'flutter_profile_tab'},
            ),
          ),
        ),
        _b(
          'H TC002 props',
          () => _k.setProfile(
            KlaviyoProfile(
              email: e(),
              properties: {'plan': 'pro', 'seats': 5, 'trial': true},
            ),
          ),
        ),
        _b(
          'H TC003 firstName custom',
          () => _k.setProfile(
            KlaviyoProfile(
              email: e(),
              firstName: 'Ada',
              properties: {'firstName': 'Grace'},
            ),
          ),
        ),
        _b(
          'H TC004 no props',
          () => _k.setProfile(
            KlaviyoProfile(email: e(), firstName: 'Ada', lastName: 'Lovelace'),
          ),
        ),
        _b('H TC005 camel names', () async {
          await _k.setEmail(e());
          await _attr('firstName', 'Ada');
          await _attr('lastName', 'Lovelace');
        }),
        _b('H TC006 snake/upper', () async {
          await _k.setEmail(e());
          await _attr('first_name', 'Ada');
          await _attr('LASTNAME', 'Lovelace');
        }),
        _b('H TC007 org/title/image', () async {
          await _k.setEmail(e());
          await _attr('organization', 'Acme');
          await _attr('title', 'Engineer');
          await _attr('image', 'https://example.com/ada.png');
        }),
        _b('H TC008 location', () async {
          await _k.setEmail(e());
          await _attr('address1', '1 Main St');
          await _attr('address_2', 'Suite 4');
          await _attr('city', 'Boston');
          await _attr('country', 'US');
          await _attr('region', 'MA');
          await _attr('zip', '02110');
          await _attr('latitude', 42.35);
          await _attr('longitude', -71.05);
        }),
        _b('H TC009 timezone', () async {
          await _k.setEmail(e());
          await _attr('timezone', 'America/New_York');
          await _attr('time_zone', 'America/Chicago');
        }),
        _b('H TC010 identifiers', () async {
          await _k.setEmail(e());
          await _attr('externalId', 'ext-123');
          await _attr('phoneNumber', '+15555550100');
        }),
        _b('H TC011 unknown', () async {
          await _k.setEmail(e());
          await _attr('favorite_color', 'green');
        }),
        _b('H TC012 null alias', () async {
          await _k.setEmail(e());
          await _k.setProfileProperties({'firstName': 'Ada', 'first_name': null});
        }),
        _b('H TC013 lone null', () async {
          await _k.setEmail(e());
          await _attr('nickname', null);
        }),
        _b(
          'H TC014 USD',
          () => _k.createEvent(
            KlaviyoEvent.custom(
              metric: 'Added to Cart',
              value: 59.98,
              valueCurrency: 'USD',
            ),
          ),
        ),
        _b(
          'H TC015 EUR',
          () => _k.createEvent(
            KlaviyoEvent.custom(
              metric: 'Added to Cart',
              value: 10.0,
              valueCurrency: 'EUR',
            ),
          ),
        ),
        _b(
          'H TC015 JPY',
          () => _k.createEvent(
            KlaviyoEvent.custom(
              metric: 'Added to Cart',
              value: 1000.0,
              valueCurrency: 'JPY',
            ),
          ),
        ),
        _b(
          'H TC017 USD+sku',
          () => _k.createEvent(
            KlaviyoEvent.custom(
              metric: 'Added to Cart',
              value: 20.0,
              valueCurrency: 'USD',
              properties: {'sku': 'SKU-1'},
            ),
          ),
        ),
        _b('H TC018 link preinit-safe', () async {
          final r = _k.handleUniversalTrackingLink(
            'https://email.example-track.com/u/abc123',
          );
          setState(() => _out = 'H TC018 returned $r');
        }),
        _b('H TC020 non-tracking url', () async {
          final r = _k.handleUniversalTrackingLink(
            'https://example.com/not-a-tracking-link',
          );
          setState(() => _out = 'H TC020 returned $r');
        }),
      ],
    );
  }
}
