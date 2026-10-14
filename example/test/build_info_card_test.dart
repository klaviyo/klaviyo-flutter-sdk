import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:klaviyo_flutter_sdk_example/build_info.dart';
import 'package:klaviyo_flutter_sdk_example/widgets/build_info_card.dart';

BuildInfo _testInfo() {
  // Bypasses BuildInfo.load() so the test needs no PackageInfo plugin mock.
  return const BuildInfo.forTesting(
    flutterSdkRef: 'feat/thing@0123456',
    iosSdkRef: '5.4.1',
    androidSdkRef: 'rel/4.6.0@0123456',
    commit: '0123456789abcdef',
    commitShort: '0123456',
    branch: 'feat/thing',
    appVersion: '1.2.3',
    buildNumber: '42',
    buildDate: '2026-10-13 12:00 UTC',
  );
}

void main() {
  testWidgets('BuildInfoCard shows refs, app version and commit', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: BuildInfoCard(info: _testInfo()))),
    );

    expect(find.text('Build info'), findsOneWidget);
    expect(find.text('feat/thing@0123456'), findsOneWidget);
    expect(find.text('5.4.1'), findsOneWidget);
    expect(find.text('rel/4.6.0@0123456'), findsOneWidget);
    expect(find.text('1.2.3 (42)'), findsOneWidget);
    expect(find.text('0123456 (feat/thing)'), findsOneWidget);
    expect(find.text('2026-10-13 12:00 UTC'), findsOneWidget);
  });

  testWidgets('BuildInfoCard copies the summary to the clipboard', (
    tester,
  ) async {
    String? clipboard;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clipboard = (call.arguments as Map)['text'] as String?;
      }
      return null;
    });

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: BuildInfoCard(info: _testInfo()))),
    );
    await tester.tap(find.byIcon(Icons.copy));
    await tester.pump();

    expect(clipboard, contains('Flutter SDK: feat/thing@0123456'));
    expect(clipboard, contains('iOS SDK: 5.4.1'));
    expect(clipboard, contains('Android SDK: rel/4.6.0@0123456'));
    expect(clipboard, contains('App: 1.2.3 (42)'));
    expect(clipboard, contains('Built: 2026-10-13 12:00 UTC'));
  });
}
