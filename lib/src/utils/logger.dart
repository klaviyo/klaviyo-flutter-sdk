import '../enums/klaviyo_log_level.dart';

class Logger {
  static final Logger _instance = Logger._internal();
  factory Logger() => _instance;
  Logger._internal();

  KlaviyoLogLevel _logLevel = KlaviyoLogLevel.info;
  bool _enabled = true;

  /// Set the log level
  void setLogLevel(KlaviyoLogLevel level) {
    _logLevel = level;
  }

  /// Enable or disable logging
  void setEnabled(bool enabled) {
    _enabled = enabled;
  }

  /// Log a verbose message
  void verbose(String message, [Object? error, StackTrace? stackTrace]) {
    _log(KlaviyoLogLevel.verbose, 'VERBOSE', message, error, stackTrace);
  }

  /// Log a debug message
  void debug(String message, [Object? error, StackTrace? stackTrace]) {
    _log(KlaviyoLogLevel.debug, 'DEBUG', message, error, stackTrace);
  }

  /// Log an info message
  void info(String message, [Object? error, StackTrace? stackTrace]) {
    _log(KlaviyoLogLevel.info, 'INFO', message, error, stackTrace);
  }

  /// Log a warning message
  void warning(String message, [Object? error, StackTrace? stackTrace]) {
    _log(KlaviyoLogLevel.warning, 'WARNING', message, error, stackTrace);
  }

  /// Log an error message
  void error(String message, [Object? error, StackTrace? stackTrace]) {
    _log(KlaviyoLogLevel.error, 'ERROR', message, error, stackTrace);
  }

  /// Internal logging method
  void _log(
    KlaviyoLogLevel level,
    String levelName,
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    if (!_enabled || level.index > _logLevel.index) {
      return;
    }

    final timestamp = DateTime.now().toIso8601String();
    final logMessage = '[$timestamp] [$levelName] KlaviyoSDK: $message';

    switch (level) {
      case KlaviyoLogLevel.error:
        print(logMessage);
        if (error != null) {
          print('Error: $error');
        }
        if (stackTrace != null) {
          print('StackTrace: $stackTrace');
        }
        break;
      case KlaviyoLogLevel.warning:
        print(logMessage);
        if (error != null) {
          print('Warning details: $error');
        }
        break;
      case KlaviyoLogLevel.info:
      case KlaviyoLogLevel.debug:
      case KlaviyoLogLevel.verbose:
        print(logMessage);
        if (error != null) {
          print('Details: $error');
        }
        break;
      case KlaviyoLogLevel.none:
        // Do nothing
        break;
    }
  }

  /// Get current log level
  KlaviyoLogLevel get logLevel => _logLevel;

  /// Check if logging is enabled
  bool get enabled => _enabled;
} 