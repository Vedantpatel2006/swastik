import 'package:cloud_firestore/cloud_firestore.dart';

/// User preferences for temple discovery and personalization
class UserPreferences {
  final String userId;
  final double locationRadius; // in kilometers
  final List<String> preferredTraditions;
  final bool enableLocationServices;
  final bool enableNotifications;
  final String theme; // light, dark, auto
  final String language;
  final String? savedLocation; // User's selected location string
  final Map<String, dynamic> customSettings;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserPreferences({
    required this.userId,
    this.locationRadius = 50.0, // Default 50km radius
    this.preferredTraditions = const [],
    this.enableLocationServices = true,
    this.enableNotifications = true,
    this.theme = 'auto',
    this.language = 'en',
    this.savedLocation,
    this.customSettings = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create UserPreferences from Firestore document
  factory UserPreferences.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return UserPreferences.fromJson({...data, 'userId': doc.id});
  }

  /// Create UserPreferences from JSON
  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    return UserPreferences(
      userId: json['userId'] as String,
      locationRadius: (json['locationRadius'] as num?)?.toDouble() ?? 50.0,
      preferredTraditions: json['preferredTraditions'] != null
          ? List<String>.from(json['preferredTraditions'] as List)
          : [],
      enableLocationServices: json['enableLocationServices'] as bool? ?? true,
      enableNotifications: json['enableNotifications'] as bool? ?? true,
      theme: json['theme'] as String? ?? 'auto',
      language: json['language'] as String? ?? 'en',
      savedLocation: json['savedLocation'] as String?,
      customSettings: json['customSettings'] != null
          ? Map<String, dynamic>.from(json['customSettings'] as Map)
          : {},
      createdAt: json['createdAt'] != null
          ? (json['createdAt'] is Timestamp
                ? (json['createdAt'] as Timestamp).toDate()
                : DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int))
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? (json['updatedAt'] is Timestamp
                ? (json['updatedAt'] as Timestamp).toDate()
                : DateTime.fromMillisecondsSinceEpoch(json['updatedAt'] as int))
          : DateTime.now(),
    );
  }

  /// Convert UserPreferences to JSON
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'locationRadius': locationRadius,
      'preferredTraditions': preferredTraditions,
      'enableLocationServices': enableLocationServices,
      'enableNotifications': enableNotifications,
      'theme': theme,
      'language': language,
      'savedLocation': savedLocation,
      'customSettings': Map<String, dynamic>.from(customSettings),
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  /// Convert UserPreferences to Firestore JSON (with Timestamps)
  Map<String, dynamic> toFirestoreJson() {
    return {
      'userId': userId,
      'locationRadius': locationRadius,
      'preferredTraditions': preferredTraditions,
      'enableLocationServices': enableLocationServices,
      'enableNotifications': enableNotifications,
      'theme': theme,
      'language': language,
      'savedLocation': savedLocation,
      'customSettings': Map<String, dynamic>.from(customSettings),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Create default preferences for a new user
  factory UserPreferences.defaultForUser(String userId) {
    final now = DateTime.now();
    return UserPreferences(userId: userId, createdAt: now, updatedAt: now);
  }

  /// Validate user preferences
  bool isValid() {
    final validThemes = ['light', 'dark', 'auto'];
    final validLanguages = ['en', 'hi']; // Add more as needed

    return userId.isNotEmpty &&
        locationRadius > 0 &&
        locationRadius <= 1000 && // Max 1000km radius
        validThemes.contains(theme) &&
        validLanguages.contains(language);
  }

  /// Create a copy of UserPreferences with updated fields
  UserPreferences copyWith({
    String? userId,
    double? locationRadius,
    List<String>? preferredTraditions,
    bool? enableLocationServices,
    bool? enableNotifications,
    String? theme,
    String? language,
    String? savedLocation,
    Map<String, dynamic>? customSettings,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserPreferences(
      userId: userId ?? this.userId,
      locationRadius: locationRadius ?? this.locationRadius,
      preferredTraditions: preferredTraditions ?? this.preferredTraditions,
      enableLocationServices:
          enableLocationServices ?? this.enableLocationServices,
      enableNotifications: enableNotifications ?? this.enableNotifications,
      theme: theme ?? this.theme,
      language: language ?? this.language,
      savedLocation: savedLocation ?? this.savedLocation,
      customSettings: customSettings ?? this.customSettings,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  /// Update location radius with validation
  UserPreferences updateLocationRadius(double radius) {
    if (radius <= 0 || radius > 1000) {
      throw ArgumentError(
        'Location radius must be between 0 and 1000 kilometers',
      );
    }
    return copyWith(locationRadius: radius, updatedAt: DateTime.now());
  }

  /// Add a preferred tradition
  UserPreferences addPreferredTradition(String tradition) {
    if (tradition.isEmpty) {
      throw ArgumentError('Tradition cannot be empty');
    }
    if (preferredTraditions.contains(tradition)) {
      return this; // Already exists
    }
    final updatedTraditions = [...preferredTraditions, tradition];
    return copyWith(
      preferredTraditions: updatedTraditions,
      updatedAt: DateTime.now(),
    );
  }

  /// Remove a preferred tradition
  UserPreferences removePreferredTradition(String tradition) {
    final updatedTraditions = preferredTraditions
        .where((t) => t != tradition)
        .toList();
    return copyWith(
      preferredTraditions: updatedTraditions,
      updatedAt: DateTime.now(),
    );
  }

  /// Update theme with validation
  UserPreferences updateTheme(String newTheme) {
    final validThemes = ['light', 'dark', 'auto'];
    if (!validThemes.contains(newTheme)) {
      throw ArgumentError(
        'Invalid theme. Must be one of: ${validThemes.join(', ')}',
      );
    }
    return copyWith(theme: newTheme, updatedAt: DateTime.now());
  }

  /// Update language with validation
  UserPreferences updateLanguage(String newLanguage) {
    final validLanguages = ['en', 'hi']; // Add more as needed
    if (!validLanguages.contains(newLanguage)) {
      throw ArgumentError(
        'Invalid language. Must be one of: ${validLanguages.join(', ')}',
      );
    }
    return copyWith(language: newLanguage, updatedAt: DateTime.now());
  }

  /// Update custom setting
  UserPreferences updateCustomSetting(String key, dynamic value) {
    if (key.isEmpty) {
      throw ArgumentError('Setting key cannot be empty');
    }
    final updatedSettings = Map<String, dynamic>.from(customSettings);
    updatedSettings[key] = value;
    return copyWith(customSettings: updatedSettings, updatedAt: DateTime.now());
  }

  /// Remove custom setting
  UserPreferences removeCustomSetting(String key) {
    final updatedSettings = Map<String, dynamic>.from(customSettings);
    updatedSettings.remove(key);
    return copyWith(customSettings: updatedSettings, updatedAt: DateTime.now());
  }

  /// Get custom setting value
  T? getCustomSetting<T>(String key) {
    final value = customSettings[key];
    return value is T ? value : null;
  }

  /// Check if user has any preferred traditions
  bool get hasPreferredTraditions => preferredTraditions.isNotEmpty;

  /// Check if location services are enabled
  bool get isLocationEnabled => enableLocationServices;

  /// Check if notifications are enabled
  bool get areNotificationsEnabled => enableNotifications;

  /// Get display name for theme
  String get themeDisplayName {
    switch (theme) {
      case 'light':
        return 'Light';
      case 'dark':
        return 'Dark';
      case 'auto':
        return 'Auto';
      default:
        return 'Unknown';
    }
  }

  /// Get display name for language
  String get languageDisplayName {
    switch (language) {
      case 'en':
        return 'English';
      case 'hi':
        return 'हिंदी';
      default:
        return 'Unknown';
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserPreferences &&
        other.userId == userId &&
        other.locationRadius == locationRadius &&
        _listEquals(other.preferredTraditions, preferredTraditions) &&
        other.enableLocationServices == enableLocationServices &&
        other.enableNotifications == enableNotifications &&
        other.theme == theme &&
        other.language == language &&
        other.savedLocation == savedLocation &&
        _mapEquals(other.customSettings, customSettings) &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      userId,
      locationRadius,
      preferredTraditions,
      enableLocationServices,
      enableNotifications,
      theme,
      language,
      savedLocation,
      customSettings,
      createdAt,
      updatedAt,
    );
  }

  @override
  String toString() {
    return 'UserPreferences(userId: $userId, locationRadius: ${locationRadius}km, '
        'traditions: $preferredTraditions, theme: $theme, language: $language)';
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  bool _mapEquals(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (a[key] != b[key]) return false;
    }
    return true;
  }
}
