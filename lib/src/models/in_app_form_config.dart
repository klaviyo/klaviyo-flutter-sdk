const int _infiniteTimeoutSentinel = -1;

class InAppFormConfig {
  /// - null → platform default (1 hour)
  /// - 0 → timeout immediately when app backgrounds
  /// - >0 → timeout after inactivity
  /// - infinite() → no timeout
  final Duration? sessionTimeoutDuration;
  final bool isInfinite;

  /// Optional short-lived credential, generated from the Klaviyo form editor,
  /// that loads draft forms for on-device testing instead of your published
  /// forms. Never ship a preview token in a production build. Null or empty
  /// leaves any token set with `KlaviyoSDK().setFormsPreviewToken` unchanged.
  final String? previewToken;

  const InAppFormConfig._({
    this.sessionTimeoutDuration,
    required this.isInfinite,
    this.previewToken,
  });

  /// Platform default (1hr) or custom timeout
  const InAppFormConfig({
    Duration? sessionTimeoutDuration,
    String? previewToken,
  }) : this._(
          sessionTimeoutDuration: sessionTimeoutDuration,
          isInfinite: false,
          previewToken: previewToken,
        );

  /// No timeout (infinite)
  const InAppFormConfig.infinite({String? previewToken})
      : this._(
          sessionTimeoutDuration: null,
          isInfinite: true,
          previewToken: previewToken,
        );

  factory InAppFormConfig.fromJson(Map<String, dynamic> json) {
    final raw = json['sessionTimeoutDuration'];
    final previewToken = json['previewToken'] as String?;

    if (raw == _infiniteTimeoutSentinel) {
      return InAppFormConfig.infinite(previewToken: previewToken);
    }

    if (raw is int) {
      return InAppFormConfig(
        sessionTimeoutDuration: Duration(seconds: raw),
        previewToken: previewToken,
      );
    }

    return InAppFormConfig(previewToken: previewToken);
  }

  Map<String, dynamic> toJson() {
    return {
      'sessionTimeoutDuration': isInfinite
          ? _infiniteTimeoutSentinel
          : sessionTimeoutDuration?.inSeconds,
      if (previewToken != null && previewToken!.isNotEmpty)
        'previewToken': previewToken,
    };
  }

  InAppFormConfig copyWith({
    Duration? sessionTimeoutDuration,
    bool? isInfinite,
    String? previewToken,
  }) {
    final token = previewToken ?? this.previewToken;
    if (isInfinite == true) {
      return InAppFormConfig.infinite(previewToken: token);
    }

    return InAppFormConfig(
      sessionTimeoutDuration:
          sessionTimeoutDuration ?? this.sessionTimeoutDuration,
      previewToken: token,
    );
  }

  // Returns IAF config in H:MM:SS.uuuuuu format. Redacts the preview token so
  // the credential never reaches logs.
  @override
  String toString() {
    final timeout = isInfinite ? 'infinite' : '$sessionTimeoutDuration';
    final token =
        (previewToken == null || previewToken!.isEmpty) ? 'null' : '<redacted>';
    return 'InAppFormConfig(sessionTimeoutDuration: $timeout, previewToken: $token)';
  }
}
