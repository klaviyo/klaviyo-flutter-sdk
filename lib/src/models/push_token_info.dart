import '../enums/push_environment.dart';

/// Represents push token information
class PushTokenInfo {
  final String token;
  final PushEnvironment environment;
  final String platform;
  final DateTime createdAt;
  final bool isActive;

  const PushTokenInfo({
    required this.token,
    required this.environment,
    required this.platform,
    required this.createdAt,
    this.isActive = true,
  });

  /// Create a copy with updated values
  PushTokenInfo copyWith({
    String? token,
    PushEnvironment? environment,
    String? platform,
    DateTime? createdAt,
    bool? isActive,
  }) {
    return PushTokenInfo(
      token: token ?? this.token,
      environment: environment ?? this.environment,
      platform: platform ?? this.platform,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
    );
  }

  /// Convert to JSON for API requests
  Map<String, dynamic> toJson() {
    return {
      'token': token,
      'platform': platform,
      'environment': environment.name,
      'enabled_datetime': createdAt.toIso8601String(),
    };
  }

  /// Create from JSON
  factory PushTokenInfo.fromJson(Map<String, dynamic> json) {
    return PushTokenInfo(
      token: json['token'] as String? ?? '',
      platform: json['platform'] as String? ?? '',
      environment: PushEnvironment.values.firstWhere(
        (e) => e.name == (json['environment'] as String? ?? ''),
        orElse: () => PushEnvironment.production,
      ),
      createdAt: DateTime.tryParse(json['enabled_datetime'] as String? ?? '') ??
          DateTime.now(),
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  @override
  String toString() {
    return 'PushTokenInfo(platform: $platform, environment: $environment, active: $isActive)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is PushTokenInfo &&
        other.token == token &&
        other.environment == environment &&
        other.platform == platform &&
        other.createdAt == createdAt &&
        other.isActive == isActive;
  }

  @override
  int get hashCode {
    return Object.hash(token, environment, platform, createdAt, isActive);
  }
}
