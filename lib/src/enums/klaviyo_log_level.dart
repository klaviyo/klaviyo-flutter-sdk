import 'package:logging/logging.dart';

@Deprecated('Use KlaviyoSDK.setLoggingEnabled instead. Will be removed in 1.0.')

/// Log levels for the plugin's Dart-side logging.
enum KlaviyoLogLevel {
  /// No logging.
  none,

  /// Errors only.
  error,

  /// Warnings and errors.
  warning,

  /// Informational messages, warnings and errors.
  info,

  /// Debug messages and everything above.
  debug,

  /// Every message.
  verbose;

  /// The matching `package:logging` [Level].
  Level toLevel() {
    switch (this) {
      case KlaviyoLogLevel.none:
        return Level.OFF;
      case KlaviyoLogLevel.error:
        return Level.SEVERE;
      case KlaviyoLogLevel.warning:
        return Level.WARNING;
      case KlaviyoLogLevel.info:
        return Level.INFO;
      case KlaviyoLogLevel.debug:
        return Level.FINE;
      case KlaviyoLogLevel.verbose:
        return Level.FINER;
    }
  }

  /// Parses [value] case-insensitively, falling back to [info].
  static KlaviyoLogLevel fromString(String value) {
    switch (value.toLowerCase()) {
      case 'none':
        return KlaviyoLogLevel.none;
      case 'error':
        return KlaviyoLogLevel.error;
      case 'warning':
        return KlaviyoLogLevel.warning;
      case 'info':
        return KlaviyoLogLevel.info;
      case 'debug':
        return KlaviyoLogLevel.debug;
      case 'verbose':
        return KlaviyoLogLevel.verbose;
      default:
        return KlaviyoLogLevel.info;
    }
  }

  @override
  String toString() {
    switch (this) {
      case KlaviyoLogLevel.none:
        return 'none';
      case KlaviyoLogLevel.error:
        return 'error';
      case KlaviyoLogLevel.warning:
        return 'warning';
      case KlaviyoLogLevel.info:
        return 'info';
      case KlaviyoLogLevel.debug:
        return 'debug';
      case KlaviyoLogLevel.verbose:
        return 'verbose';
    }
  }
}
