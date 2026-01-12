class InAppFormConfig {
  final int? sessionTimeoutDuration;

  const InAppFormConfig({
    this.sessionTimeoutDuration,
  });

  factory InAppFormConfig.fromJson(Map<String, dynamic> json) {
    return InAppFormConfig(
      sessionTimeoutDuration: json['sessionTimeoutDuration'] as int?
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sessionTimeoutDuration': sessionTimeoutDuration
    };
  }

  InAppFormConfig copyWith({
    int? sessionTimeoutDuration
  }) {
    return InAppFormConfig(
      sessionTimeoutDuration: sessionTimeoutDuration ?? this.sessionTimeoutDuration
    );
  }

  @override
  String toString() {
    return 'InAppFormConfig(sessionTimeoutDuration: $sessionTimeoutDuration)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is InAppFormConfig &&
        other.sessionTimeoutDuration == sessionTimeoutDuration;
  }

  @override
  int get hashCode {
    return sessionTimeoutDuration.hashCode;
  }
}
