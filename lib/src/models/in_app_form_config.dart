const int _infiniteTimeoutSentinel = -1;

class InAppFormConfig {

  /// - null → platform default (1 hour)
  /// - 0 → timeout immediately when app backgrounds
  /// - >0 → timeout after inactivity
  /// - infinite() → no timeout
  final Duration? sessionTimeoutDuration;
  final bool isInfinite;

  const InAppFormConfig._({
    this.sessionTimeoutDuration,
    required this.isInfinite,
  });

  /// Platform default (1hr) or custom timeout
  const InAppFormConfig({Duration? sessionTimeoutDuration})
    : this._(sessionTimeoutDuration: sessionTimeoutDuration, isInfinite: false);

  /// No timeout (infinite)
  const InAppFormConfig.infinite()
    : this._(sessionTimeoutDuration: null, isInfinite: true);

  factory InAppFormConfig.fromJson(Map<String, dynamic> json) {
    final raw = json['sessionTimeoutDuration'];

    if (raw == _infiniteTimeoutSentinel) {
      return const InAppFormConfig.infinite();
    }

    if (raw is int) {
      return InAppFormConfig(
        sessionTimeoutDuration: Duration(seconds: raw),
      );
    }

    return const InAppFormConfig();
  }

  Map<String, dynamic> toJson() {
    return {
      'sessionTimeoutDuration': isInfinite
          ? _infiniteTimeoutSentinel
          : sessionTimeoutDuration?.inSeconds,
    };
  }

  InAppFormConfig copyWith({
    Duration? sessionTimeoutDuration,
    bool? isInfinite,
  }) {
    if (isInfinite == true) {
      return const InAppFormConfig.infinite();
    }

    return InAppFormConfig(
      sessionTimeoutDuration:
      sessionTimeoutDuration ?? this.sessionTimeoutDuration,
    );
  }

  @override
  String toString() {
    return isInfinite
        ? 'InAppFormConfig(sessionTimeoutDuration: infinite)'
        : 'InAppFormConfig(sessionTimeoutDuration: $sessionTimeoutDuration)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is InAppFormConfig &&
        other.isInfinite == isInfinite &&
        other.sessionTimeoutDuration == sessionTimeoutDuration;
  }

  @override
  int get hashCode =>
      Object.hash(isInfinite, sessionTimeoutDuration);
}
