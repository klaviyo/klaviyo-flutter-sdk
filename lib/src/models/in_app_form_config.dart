const int _infiniteTimeoutSentinel = -1;
void _unchangedCallback() {}

class InAppFormConfig {
  /// - null → platform default (1 hour)
  /// - 0 → timeout immediately when app backgrounds
  /// - >0 → timeout after inactivity
  /// - infinite() → no timeout
  final Duration? sessionTimeoutDuration;
  final bool isInfinite;

  /// Positive loading budget through forms readiness. Null uses the native
  /// network timeout. Native SDKs normalize invalid or unsafe values.
  final Duration? loadTimeout;

  /// Recent analytics history replayed after loading (default 10 seconds,
  /// capped at 30 seconds). Zero disables history while retaining live events.
  /// History holds at most 10 events and can cause forms to appear after the
  /// original trigger. Replay does not guarantee trigger recovery.
  final Duration? eventReplayWindow;

  /// Called on terminal loading failure, independently of form lifecycle events.
  /// Retry is host-controlled. This callback is never serialized.
  final void Function()? onFailure;

  const InAppFormConfig._({
    this.sessionTimeoutDuration,
    required this.isInfinite,
    this.loadTimeout,
    this.eventReplayWindow,
    this.onFailure,
  });

  /// Platform default (1hr) or custom timeout
  const InAppFormConfig({
    Duration? sessionTimeoutDuration,
    Duration? loadTimeout,
    Duration? eventReplayWindow,
    void Function()? onFailure,
  }) : this._(
          sessionTimeoutDuration: sessionTimeoutDuration,
          isInfinite: false,
          loadTimeout: loadTimeout,
          eventReplayWindow: eventReplayWindow,
          onFailure: onFailure,
        );

  /// No timeout (infinite)
  const InAppFormConfig.infinite({
    Duration? loadTimeout,
    Duration? eventReplayWindow,
    void Function()? onFailure,
  }) : this._(
          isInfinite: true,
          loadTimeout: loadTimeout,
          eventReplayWindow: eventReplayWindow,
          onFailure: onFailure,
        );

  factory InAppFormConfig.fromJson(Map<String, dynamic> json) {
    final raw = json['sessionTimeoutDuration'];

    return InAppFormConfig._(
      isInfinite: raw == _infiniteTimeoutSentinel,
      sessionTimeoutDuration: raw is int && raw != _infiniteTimeoutSentinel
          ? Duration(seconds: raw)
          : null,
      loadTimeout: _durationFromSeconds(json['loadTimeout']),
      eventReplayWindow:
          _durationFromSeconds(json['eventReplayWindow'], maxSeconds: 30),
    );
  }

  static Duration? _durationFromSeconds(dynamic value, {int? maxSeconds}) {
    if (value is! num || !value.isFinite) return null;
    final seconds = maxSeconds == null ? value : value.clamp(0, maxSeconds);
    final maxDurationSeconds =
        0x7fffffffffffffff / Duration.microsecondsPerSecond;
    if (seconds >= maxDurationSeconds || seconds <= -maxDurationSeconds) {
      return null;
    }
    final microseconds = seconds * Duration.microsecondsPerSecond;
    if (!microseconds.isFinite || microseconds.abs() >= 0x7fffffffffffffff) {
      return null;
    }
    return Duration(microseconds: microseconds.round());
  }

  Map<String, dynamic> toJson() {
    return {
      'sessionTimeoutDuration': isInfinite
          ? _infiniteTimeoutSentinel
          : sessionTimeoutDuration?.inSeconds,
      'loadTimeout': loadTimeout == null
          ? null
          : loadTimeout!.inMicroseconds / Duration.microsecondsPerSecond,
      'eventReplayWindow': eventReplayWindow == null
          ? null
          : eventReplayWindow!.inMicroseconds / Duration.microsecondsPerSecond,
    };
  }

  InAppFormConfig copyWith({
    Duration? sessionTimeoutDuration,
    bool? isInfinite,
    Duration? loadTimeout,
    Duration? eventReplayWindow,
    void Function()? onFailure = _unchangedCallback,
  }) {
    return InAppFormConfig._(
      isInfinite: isInfinite ?? this.isInfinite,
      sessionTimeoutDuration:
          sessionTimeoutDuration ?? this.sessionTimeoutDuration,
      loadTimeout: loadTimeout ?? this.loadTimeout,
      eventReplayWindow: eventReplayWindow ?? this.eventReplayWindow,
      onFailure:
          identical(onFailure, _unchangedCallback) ? this.onFailure : onFailure,
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
