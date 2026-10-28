import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klaviyo_flutter_sdk/klaviyo_flutter_sdk.dart';
import 'package:klaviyo_flutter_sdk_example/tabs/forms_tab.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Open forwards the form ID and logs a request, not presentation',
      (tester) async {
    const methods = MethodChannel('klaviyo_sdk');
    const events = EventChannel('klaviyo_events');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(methods, (call) async {
      calls.add(call);
      return null;
    });
    messenger.setMockStreamHandler(
      events,
      MockStreamHandler.inline(onListen: (_, sink) {}),
    );
    addTearDown(() {
      messenger.setMockMethodCallHandler(methods, null);
      messenger.setMockStreamHandler(events, null);
    });
    await KlaviyoSDK().initialize(apiKey: 'test');
    calls.clear();
    FormsTab.resetState();
    await tester.pumpWidget(const MaterialApp(home: FormsTab()));

    await tester.enterText(
      find.widgetWithText(TextField, 'Form ID'),
      ' AbC123 ',
    );
    await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Open'));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Open'));
    await tester.pumpAndSettle();

    expect(calls, hasLength(1));
    expect(calls.single.method, 'openForm');
    expect(calls.single.arguments, {'formId': ' AbC123 '});
    await tester.scrollUntilVisible(
      find.textContaining('Open requested:  AbC123 '),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Open requested:  AbC123 '), findsOneWidget);
    expect(find.textContaining('formShown'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
