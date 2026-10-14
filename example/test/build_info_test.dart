import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:klaviyo_flutter_sdk_example/build_info.dart';
import 'package:klaviyo_flutter_sdk_example/widgets/build_info_button.dart';

// The shared fixture that release-notes.sh's tests also assert against, so
// the app's copied block and the store notes can never drift.
final _fixture = jsonDecode(
  File('../.github/scripts/tests/fixtures/build-info-cases.json')
      .readAsStringSync(),
) as Map<String, dynamic>;

BuildInfo _fromFixture(Map<String, dynamic> c) {
  final isAndroid = c['platform'] == 'android';
  return BuildInfo.forTesting(
    flutterVersion: c['flutterVersion'] as String,
    flutterSdkRef: c['flutterRef'] as String,
    iosSdkVersion: isAndroid ? '—' : c['nativeVersion'] as String,
    iosSdkRef: isAndroid ? '—' : c['nativeRef'] as String,
    androidSdkVersion: isAndroid ? c['nativeVersion'] as String : '—',
    androidSdkRef: isAndroid ? c['nativeRef'] as String : '—',
    commitShort: c['commitShort'] as String,
    sourceLabel: c['sourceLabel'] as String,
    event: c['event'] as String,
    appVersion: c['appVersion'] as String,
    buildNumber: c['buildNumber'] as String,
    buildDate: c['buildDate'] as String,
  );
}

/// The notes header the shell side renders for this case, minus the CI run
/// line (the app never emits one).
String _expectedCopiedBlock(Map<String, dynamic> c) {
  final lines = (c['notesHeader'] as String)
      .split('\n')
      .where((l) => !l.startsWith('CI run:'))
      .join('\n');
  return lines;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BuildInfo formatting matches the shared fixture', () {
    for (final c in (_fixture['cases'] as List).cast<Map<String, dynamic>>()) {
      test(c['name'] as String, () {
        final info = _fromFixture(c);
        final expectedRows = (c['cardRows'] as List)
            .map((r) => (r[0] as String, r[1] as String))
            .toList();
        // The card shows only the running platform's native SDK; the fixture
        // rows are written for the case's platform, so compare only when the
        // test host agrees, and skip the native row otherwise.
        final hostIsAndroid = Platform.isAndroid;
        final caseIsAndroid = c['platform'] == 'android';
        final rows = info.rows;
        expect(rows[0], expectedRows[0]);
        expect(rows[1], expectedRows[1]);
        if (hostIsAndroid == caseIsAndroid) {
          expect(rows[2], expectedRows[2]);
        }
        expect(rows[3], expectedRows[3]);
        expect(rows[4], expectedRows[4]);
      });
    }
  });

  group('Copied block equals the notes header without the CI run line', () {
    for (final name in [
      'branch build',
      'prerelease build shows the full version',
      'local build',
      'missing values render as em dash',
    ]) {
      test(name, () {
        final c = (_fixture['cases'] as List)
            .cast<Map<String, dynamic>>()
            .firstWhere((c) => c['name'] == name);
        final info = _fromFixture(c);
        if ((Platform.isAndroid) != (c['platform'] == 'android')) {
          // The header's native line follows the host platform; skip the
          // cross-platform byte-compare (the shell side covers both).
          return;
        }
        expect(info.toHeaderBlock(), _expectedCopiedBlock(c));
      });
    }
  });

  testWidgets('Build info sheet shows rows and copies the header block', (
    tester,
  ) async {
    final c =
        (_fixture['cases'] as List).cast<Map<String, dynamic>>().firstWhere(
              (c) => c['name'] == 'missing values render as em dash',
            );
    final info = _fromFixture(c);

    String? clipboard;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clipboard = (call.arguments as Map)['text'] as String?;
      }
      return null;
    });
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/package_info'),
      (call) async => {
        'appName': 'Flutter Example',
        'packageName': 'com.klaviyo.flutterexample',
        'version': info.appVersion,
        'buildNumber': info.buildNumber,
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(actions: const [BuildInfoButton()]),
        ),
      ),
    );

    expect(find.byKey(BuildInfoButton.buttonKey), findsOneWidget);

    await tester.tap(find.byKey(BuildInfoButton.buttonKey));
    await tester.pumpAndSettle();

    expect(find.text('Build info'), findsOneWidget);
    expect(find.text('0.3.1 (1)'), findsOneWidget);
    // Missing values render as the em dash.
    expect(find.text('—'), findsWidgets);

    await tester.tap(find.byKey(const Key('copy-build-info')));
    await tester.pump();
    expect(
      clipboard,
      [
        'Flutter Example 0.3.1 (1)',
        'Klaviyo Flutter SDK —',
        'Klaviyo ${Platform.isAndroid ? 'Android' : 'iOS'} SDK —',
        'Commit: — on — (—)',
        'Built: —',
      ].join('\n'),
    );
    expect(clipboard, isNot(contains('CI run:')));
  });
}
