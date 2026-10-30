import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:klaviyo_flutter_sdk_example/main.dart';
import 'package:klaviyo_flutter_sdk_example/tabs/auth_tab.dart';
import 'package:klaviyo_flutter_sdk_example/tabs/events_tab.dart';

/// Each ID must surface exactly once as a semantics identifier (what native
/// drivers like Maestro and Appium see) and as a widget key.
void _expectTestIds(List<String> ids) {
  for (final id in ids) {
    expect(find.bySemanticsIdentifier(id), findsOneWidget, reason: id);
    expect(find.byKey(ValueKey(id)), findsOneWidget, reason: id);
  }
}

void main() {
  testWidgets('tab bar and profile expose test IDs', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    _expectTestIds([
      'nav_profile_tab',
      'nav_events_tab',
      'nav_forms_tab',
      'nav_push_tab',
      'nav_geofencing_tab',
      'nav_auth_tab',
      'profile_build_info_button',
      'profile_status_text',
      'profile_api_key_field',
      'profile_initialize_button',
    ]);
    semantics.dispose();
  });

  testWidgets('events tab exposes test IDs', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(const MaterialApp(home: EventsTab()));

    _expectTestIds([
      'events_status_text',
      'events_name_field',
      'events_property_key_field',
      'events_property_value_field',
      'events_track_button',
      'events_opened_app_button',
      'events_viewed_product_button',
      'events_added_to_cart_button',
      'events_started_checkout_button',
      'events_test_event_button',
    ]);
    semantics.dispose();
  });

  testWidgets('auth tab exposes test IDs', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(const MaterialApp(home: AuthTab()));

    _expectTestIds([
      'auth_provider_switch',
      'auth_add_response_button',
      'auth_response_row_1',
      'auth_response_menu_button_1',
      'auth_response_drag_handle_1',
      'auth_clear_logs_button',
    ]);
    semantics.dispose();
    await tester.pumpWidget(const SizedBox());
  });
}
