import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klaviyo_flutter_sdk_example/tabs/profile_tab.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const sdkChannel = MethodChannel('klaviyo_sdk');
  const eventsChannel = MethodChannel('klaviyo_events');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  Map<String, String?> profile = {};

  setUp(() {
    SharedPreferences.setMockInitialValues({'klaviyo_api_key': 'ABC123'});
    profile = {
      'getEmail': 'saved@example.com',
      'getPhoneNumber': '+15555550100',
      'getExternalId': 'user-1',
    };
    messenger.setMockMethodCallHandler(sdkChannel, (call) async {
      if (call.method == 'resetProfile') profile.updateAll((_, __) => null);
      return profile[call.method];
    });
    messenger.setMockMethodCallHandler(eventsChannel, (call) async => null);
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(sdkChannel, null);
    messenger.setMockMethodCallHandler(eventsChannel, null);
  });

  testWidgets('shows SDK values on launch, tab revisit and reset',
      (tester) async {
    Future<void> pumpProfileTab() async {
      await tester.pumpWidget(const MaterialApp(home: ProfileTab()));
      await tester.pumpAndSettle();
    }

    String valueOf(String testId) => tester
        .widgetList<Text>(
          find.descendant(
            of: find.byKey(ValueKey(testId)),
            matching: find.byType(Text),
          ),
        )
        .last
        .data!;

    await pumpProfileTab();
    expect(valueOf('profile_current_company_id_text'), 'ABC123');
    expect(valueOf('profile_current_email_text'), 'saved@example.com');
    expect(valueOf('profile_current_phone_text'), '+15555550100');
    expect(valueOf('profile_current_external_id_text'), 'user-1');

    profile['getEmail'] = 'changed@example.com';
    await tester.pumpWidget(const SizedBox());
    await pumpProfileTab();
    expect(valueOf('profile_current_email_text'), 'changed@example.com');

    await tester.ensureVisible(
      find.byKey(const ValueKey('profile_reset_profile_button')),
    );
    await tester
        .tap(find.byKey(const ValueKey('profile_reset_profile_button')));
    await tester.pumpAndSettle();
    expect(valueOf('profile_current_company_id_text'), 'ABC123');
    expect(valueOf('profile_current_email_text'), '(not set)');
    expect(valueOf('profile_current_phone_text'), '(not set)');
    expect(valueOf('profile_current_external_id_text'), '(not set)');
  });
}
