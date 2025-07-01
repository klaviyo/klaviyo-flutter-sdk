class InAppFormConfig {
  final bool? enabled;
  final bool? autoShow;
  final String? position;
  final Map<String, dynamic>? theme;

  const InAppFormConfig({
    this.enabled,
    this.autoShow,
    this.position,
    this.theme,
  });

  factory InAppFormConfig.fromJson(Map<String, dynamic> json) {
    return InAppFormConfig(
      enabled: json['enabled'] as bool?,
      autoShow: json['autoShow'] as bool?,
      position: json['position'] as String?,
      theme: json['theme'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'autoShow': autoShow,
      'position': position,
      'theme': theme,
    };
  }

  InAppFormConfig copyWith({
    bool? enabled,
    bool? autoShow,
    String? position,
    Map<String, dynamic>? theme,
  }) {
    return InAppFormConfig(
      enabled: enabled ?? this.enabled,
      autoShow: autoShow ?? this.autoShow,
      position: position ?? this.position,
      theme: theme ?? this.theme,
    );
  }

  @override
  String toString() {
    return 'InAppFormConfig(enabled: $enabled, autoShow: $autoShow, position: $position, theme: $theme)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is InAppFormConfig &&
        other.enabled == enabled &&
        other.autoShow == autoShow &&
        other.position == position &&
        other.theme == theme;
  }

  @override
  int get hashCode {
    return enabled.hashCode ^
        autoShow.hashCode ^
        position.hashCode ^
        theme.hashCode;
  }
} 