import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Which SDK builds this app was compiled against, written by
/// scripts/sdk-ref.sh and passed to the build with
/// `--dart-define-from-file=example/build-info.json`. Plain `flutter run`
/// without the file leaves every ref at its default.
class BuildInfo {
  const BuildInfo._({
    required this.flutterSdkRef,
    required this.iosSdkRef,
    required this.androidSdkRef,
    required this.commit,
    required this.commitShort,
    required this.branch,
    required this.appVersion,
    required this.buildDate,
    required this.buildNumber,
  });

  final String flutterSdkRef;
  final String iosSdkRef;
  final String androidSdkRef;
  final String commit;
  final String commitShort;
  final String branch;

  /// Marketing version from the store config (CFBundleShortVersionString /
  /// versionName), read at runtime so it always matches the installed build.
  final String appVersion;

  /// CFBundleVersion / versionCode, read at runtime.
  final String buildNumber;
  final String buildDate;

  @visibleForTesting
  const factory BuildInfo.forTesting({
    required String flutterSdkRef,
    required String iosSdkRef,
    required String androidSdkRef,
    required String commit,
    required String commitShort,
    required String branch,
    required String appVersion,
    required String buildNumber,
    required String buildDate,
  }) = BuildInfo._;

  static Future<BuildInfo> load() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return BuildInfo._(
      flutterSdkRef: const String.fromEnvironment(
        'flutterSdkRef',
        defaultValue: 'local',
      ),
      iosSdkRef: const String.fromEnvironment(
        'iosSdkRef',
        defaultValue: 'local',
      ),
      androidSdkRef: const String.fromEnvironment(
        'androidSdkRef',
        defaultValue: 'local',
      ),
      commit: const String.fromEnvironment('commit', defaultValue: 'unknown'),
      commitShort: const String.fromEnvironment(
        'commitShort',
        defaultValue: 'unknown',
      ),
      branch: const String.fromEnvironment('branch', defaultValue: 'local'),
      appVersion: packageInfo.version,
      buildNumber: packageInfo.buildNumber,
      buildDate: const String.fromEnvironment(
        'buildDate',
        defaultValue: 'unknown',
      ),
    );
  }

  String toMultilineString() => [
        'Flutter SDK: $flutterSdkRef',
        'iOS SDK: $iosSdkRef',
        'Android SDK: $androidSdkRef',
        'App: $appVersion ($buildNumber)',
        'Commit: $commitShort ($branch)',
        'Built: $buildDate',
      ].join('\n');
}
