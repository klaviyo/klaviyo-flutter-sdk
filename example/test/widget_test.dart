import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:klaviyo_flutter_sdk_example/main.dart';

void main() {
  testWidgets('App shows the tab shell', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.byType(BottomNavigationBar), findsOneWidget);
    expect(find.text('Profile'), findsWidgets);
  });
}
