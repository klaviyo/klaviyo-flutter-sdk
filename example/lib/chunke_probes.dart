// LOCAL TEST HARNESS ONLY (chunk E). Never commit or push.
// ignore_for_file: deprecated_member_use, experimental_member_use
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:klaviyo_flutter_sdk/klaviyo_flutter_sdk.dart';

final List<StreamSubscription<dynamic>> _probeSubs = [];

String _opened(KlaviyoPushOpened o) =>
    'tap=${o.tap} button=${o.button?.id}/${o.button?.action} webUrl=${o.webUrl} '
    'replayed=${o.payload['replayed']} keys=${o.payload.keys.toList()..sort()}';

void installChunkEProbes() {
  for (final s in _probeSubs) {
    s.cancel();
  }
  _probeSubs.clear();
  final k = KlaviyoSDK();
  debugPrint('CHUNKE probes installing');
  // Subscriber A (primary) and B (second, same moment).
  _probeSubs.add(k.onPushOpened.listen((o) => debugPrint('CHUNKE opened[A] ${_opened(o)}')));
  _probeSubs.add(k.onPushOpened.listen((o) => debugPrint('CHUNKE opened[B] ${_opened(o)}')));
  // Subscriber L: late, 10s after install.
  Future.delayed(const Duration(seconds: 10), () {
    debugPrint('CHUNKE late subscriber [L] attaching');
    _probeSubs.add(k.onPushOpened.listen((o) => debugPrint('CHUNKE opened[L] ${_opened(o)}')));
  });
  _probeSubs.add(k.onPushToken.listen(
    (t) => debugPrint('CHUNKE token len=${t.length} hash=${t.hashCode}'),
    onError: (Object e) => debugPrint('CHUNKE token error ${e.runtimeType}'),
  ));
  _probeSubs.add(k.onPushData.listen(
      (d) => debugPrint('CHUNKE data keys=${d.payload.keys.toList()..sort()}')));
  // Deprecated streams.
  _probeSubs.add(k.onPushNotification.listen((m) => debugPrint(
      'CHUNKE deprecated onPushNotification type=${m['type']} replayed=${m['replayed']}')));
  _probeSubs.add(k.onPushAction.listen((a) =>
      debugPrint('CHUNKE deprecated onPushAction ${a.runtimeType}')));
}

@pragma('vm:entry-point')
void chunkeSecondaryMain() {
  debugPrint('CHUNKE secondary entrypoint running (no subscribers)');
}
