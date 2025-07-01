enum KlaviyoLogLevel {
  none,
  error,
  warning,
  info,
  debug,
  verbose;

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