import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klaviyo_flutter_sdk_example/auth/auth_models.dart';
import 'package:klaviyo_flutter_sdk_example/auth/scripted_provider.dart';
import 'package:klaviyo_flutter_sdk_example/tabs/auth_tab.dart';

void main() {
  testWidgets('renders an out-of-range custom token expiry as malformed',
      (tester) async {
    final payload = base64Url.encode(utf8.encode('{"exp":8640000000001}'));
    final response = authController.responses.single;
    response.outcome = AuthOutcome.customToken;
    response.customToken = 'header.$payload.signature';

    await tester.pumpWidget(const MaterialApp(home: AuthTab()));

    expect(tester.takeException(), isNull);
    expect(find.text('Malformed'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });
}
