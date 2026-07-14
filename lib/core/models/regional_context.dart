/// Model representing regional context information for crash reporting and analytics
class RegionalContext {
  final String region;
  final String state;
  final String language;
  final String? district;
  final String appVersion;
  final List<String> enabledFeatures;
  final DateTime timestamp;

  const RegionalContext({
    required this.region,
    required this.state,
    required this.language,
    this.district,
    required this.appVersion,
    required this.enabledFeatures,
    required this.timestamp,
  });

  /// Create Gujarat-specific regional context
  factory RegionalContext.gujarat({
    required String language,
    String? district,
    required String appVersion,
    required List<String> enabledFeatures,
  }) {
    return RegionalContext(
      region: 'Gujarat',
      state: 'Gujarat',
      language: language,
      district: district,
      appVersion: appVersion,
      enabledFeatures: enabledFeatures,
      timestamp: DateTime.now(),
    );
  }

  /// Create context for future state expansion
  factory RegionalContext.forState({
    required String state,
    required String language,
    String? district,
    required String appVersion,
    required List<String> enabledFeatures,
  }) {
    return RegionalContext(
      region: state,
      state: state,
      language: language,
      district: district,
      appVersion: appVersion,
      enabledFeatures: enabledFeatures,
      timestamp: DateTime.now(),
    );
  }

  /// Convert to map for serialization
  Map<String, dynamic> toMap() {
    return {
      'region': region,
      'state': state,
      'language': language,
      'district': district,
      'appVersion': appVersion,
      'enabledFeatures': enabledFeatures,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  /// Create from map
  factory RegionalContext.fromMap(Map<String, dynamic> map) {
    return RegionalContext(
      region: map['region'] ?? '',
      state: map['state'] ?? '',
      language: map['language'] ?? '',
      district: map['district'],
      appVersion: map['appVersion'] ?? '',
      enabledFeatures: List<String>.from(map['enabledFeatures'] ?? []),
      timestamp: DateTime.parse(
        map['timestamp'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  @override
  String toString() {
    return 'RegionalContext(region: $region, state: $state, language: $language, district: $district)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RegionalContext &&
        other.region == region &&
        other.state == state &&
        other.language == language &&
        other.district == district &&
        other.appVersion == appVersion;
  }

  @override
  int get hashCode {
    return region.hashCode ^
        state.hashCode ^
        language.hashCode ^
        district.hashCode ^
        appVersion.hashCode;
  }
}
