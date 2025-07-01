enum PushEnvironment {
  development,
  production;

  static PushEnvironment fromString(String value) {
    switch (value.toLowerCase()) {
      case 'development':
      case 'dev':
        return PushEnvironment.development;
      case 'production':
      case 'prod':
        return PushEnvironment.production;
      default:
        return PushEnvironment.development;
    }
  }

  @override
  String toString() {
    switch (this) {
      case PushEnvironment.development:
        return 'development';
      case PushEnvironment.production:
        return 'production';
    }
  }
} 