const int _infiniteTimeoutSentinel = -1;

/// Configuration for in-app forms, passed to
/// [KlaviyoSDK.registerForInAppForms].
class InAppFormConfig {
  /// How long the forms session survives while the app is in the background.
  ///
  /// - null → platform default (1 hour)
  /// - 0 → timeout immediately when app backgrounds
  /// - >0 → timeout after inactivity
  /// - infinite() → no timeout
  final Duration? sessionTimeoutDuration;

  /// Whether the session never times out. True only for
  /// [InAppFormConfig.infinite].
  final bool isInfinite;

  const InAppFormConfig._({
    this.sessionTimeoutDuration,
    required this.isInfinite,
  });

  /// Platform default (1hr) or custom timeout
  const InAppFormConfig({Duration? sessionTimeoutDuration})
      : this._(
          sessionTimeoutDuration: sessionTimeoutDuration,
          isInfinite: false,
        );

  /// No timeout (infinite)
  const InAppFormConfig.infinite()
      : this._(sessionTimeoutDuration: null, isInfinite: true);

  /// Creates a configuration from the map produced by [toJson].
  factory InAppFormConfig.fromJson(Map<String, dynamic> json) {
    final raw = json['sessionTimeoutDuration'];

    if (raw == _infiniteTimeoutSentinel) {
      return const InAppFormConfig.infinite();
    }

    if (raw is int) {
      return InAppFormConfig(sessionTimeoutDuration: Duration(seconds: raw));
    }

    return const InAppFormConfig();
  }

  /// Converts this configuration to the map sent over the platform channel.
  Map<String, dynamic> toJson() {
    return {
      'sessionTimeoutDuration': isInfinite
          ? _infiniteTimeoutSentinel
          : sessionTimeoutDuration?.inSeconds,
    };
  }

  /// Returns a copy with the given fields replaced. Passing
  /// `isInfinite: true` returns [InAppFormConfig.infinite].
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

  // Returns IAF config in H:MM:SS.uuuuuu format
  @override
  String toString() {
    return isInfinite
        ? 'InAppFormConfig(sessionTimeoutDuration: infinite)'
        : 'InAppFormConfig(sessionTimeoutDuration: $sessionTimeoutDuration)';
  }
}
