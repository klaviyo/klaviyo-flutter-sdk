import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

const _missing = '—';

/// Which SDK builds this app was compiled against, written by
/// scripts/sdk-ref.sh and passed to the build with
/// `--dart-define-from-file=example/build-info.json`. Plain `flutter run`
/// without the file leaves every ref at the "—" placeholder.
class BuildInfo {
  const BuildInfo._({
    required this.flutterVersion,
    required this.flutterSdkRef,
    required this.iosSdkVersion,
    required this.iosSdkRef,
    required this.androidSdkVersion,
    required this.androidSdkRef,
    required this.commitShort,
    required this.sourceLabel,
    required this.event,
    required this.appVersion,
    required this.buildNumber,
    required this.buildDate,
  });

  final String flutterVersion;
  final String flutterSdkRef;
  final String iosSdkVersion;
  final String iosSdkRef;
  final String androidSdkVersion;
  final String androidSdkRef;
  final String commitShort;
  final String sourceLabel;
  final String event;

  /// Marketing version from the store config (CFBundleShortVersionString /
  /// versionName), read at runtime so it always matches the installed build.
  final String appVersion;

  /// CFBundleVersion / versionCode, read at runtime.
  final String buildNumber;
  final String buildDate;

  @visibleForTesting
  const factory BuildInfo.forTesting({
    required String flutterVersion,
    required String flutterSdkRef,
    required String iosSdkVersion,
    required String iosSdkRef,
    required String androidSdkVersion,
    required String androidSdkRef,
    required String commitShort,
    required String sourceLabel,
    required String event,
    required String appVersion,
    required String buildNumber,
    required String buildDate,
  }) = BuildInfo._;

  static Future<BuildInfo>? _cached;

  static Future<BuildInfo> load() =>
      _cached ??= PackageInfo.fromPlatform().then(
        (packageInfo) => BuildInfo._(
          flutterVersion: const String.fromEnvironment(
            'sdkVersion',
            defaultValue: _missing,
          ),
          flutterSdkRef: const String.fromEnvironment(
            'flutterSdkRef',
            defaultValue: _missing,
          ),
          iosSdkVersion: const String.fromEnvironment(
            'iosSdkVersion',
            defaultValue: _missing,
          ),
          iosSdkRef: const String.fromEnvironment(
            'iosSdkRef',
            defaultValue: _missing,
          ),
          androidSdkVersion: const String.fromEnvironment(
            'androidSdkVersion',
            defaultValue: _missing,
          ),
          androidSdkRef: const String.fromEnvironment(
            'androidSdkRef',
            defaultValue: _missing,
          ),
          commitShort: const String.fromEnvironment(
            'commitShort',
            defaultValue: _missing,
          ),
          sourceLabel: const String.fromEnvironment(
            'sourceLabel',
            defaultValue: _missing,
          ),
          event: const String.fromEnvironment('event', defaultValue: _missing),
          appVersion: packageInfo.version,
          buildNumber: packageInfo.buildNumber,
          buildDate: const String.fromEnvironment(
            'buildDate',
            defaultValue: _missing,
          ),
        ),
      );

  String get nativeSdkName => Platform.isAndroid ? 'Android' : 'iOS';

  String get nativeSdkVersion =>
      Platform.isAndroid ? androidSdkVersion : iosSdkVersion;

  String get nativeSdkRef => Platform.isAndroid ? androidSdkRef : iosSdkRef;

  /// `version · ref`; the ref is omitted when it is missing or just restates
  /// the release version.
  static String sdkValue(String version, String ref) {
    if (ref.isEmpty || ref == _missing || ref == version) {
      return version.isEmpty ? _missing : version;
    }
    return '$version · $ref';
  }

  /// Rows shown in the sheet and copied to the clipboard, as (label, value).
  List<(String, String)> get rows => [
        ('App', '$appVersion ($buildNumber)'),
        ('Klaviyo Flutter SDK', sdkValue(flutterVersion, flutterSdkRef)),
        (
          'Klaviyo $nativeSdkName SDK',
          sdkValue(nativeSdkVersion, nativeSdkRef)
        ),
        ('App commit', '$commitShort on $sourceLabel'),
        ('Built', buildDate),
      ];

  /// The exact text "Copy build info" puts on the clipboard: the release
  /// notes header without the CI run line (the app cannot know which run
  /// built it).
  String toHeaderBlock() => [
        'Flutter Example $appVersion ($buildNumber)',
        'Klaviyo Flutter SDK ${sdkValue(flutterVersion, flutterSdkRef)}',
        'Klaviyo $nativeSdkName SDK ${sdkValue(nativeSdkVersion, nativeSdkRef)}',
        'Commit: $commitShort on $sourceLabel ($event)',
        'Built: $buildDate',
      ].join('\n');
}
