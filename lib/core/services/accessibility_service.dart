import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing accessibility features with Hindi/Gujarati support
class AccessibilityService extends ChangeNotifier {
  static final AccessibilityService _instance =
      AccessibilityService._internal();
  factory AccessibilityService() => _instance;
  static AccessibilityService get instance => _instance;
  AccessibilityService._internal();

  // Accessibility settings
  bool _isHighContrastEnabled = false;
  bool _isScreenReaderEnabled = false;
  bool _isVoiceNavigationEnabled = false;
  double _textScaleFactor = 1.0;
  String _currentLanguage = 'en';
  bool _isKeyboardNavigationEnabled = false;

  // Getters
  bool get isHighContrastEnabled => _isHighContrastEnabled;
  bool get isScreenReaderEnabled => _isScreenReaderEnabled;
  bool get isVoiceNavigationEnabled => _isVoiceNavigationEnabled;
  double get textScaleFactor => _textScaleFactor;
  String get currentLanguage => _currentLanguage;
  bool get isKeyboardNavigationEnabled => _isKeyboardNavigationEnabled;

  /// Initialize accessibility service
  Future<void> initialize() async {
    await _loadSettings();
    await _detectSystemAccessibilitySettings();
  }

  /// Load accessibility settings from SharedPreferences
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _isHighContrastEnabled =
        prefs.getBool('accessibility_high_contrast') ?? false;
    _isScreenReaderEnabled =
        prefs.getBool('accessibility_screen_reader') ?? false;
    _isVoiceNavigationEnabled =
        prefs.getBool('accessibility_voice_navigation') ?? false;
    _textScaleFactor = prefs.getDouble('accessibility_text_scale') ?? 1.0;
    _currentLanguage = prefs.getString('accessibility_language') ?? 'en';
    _isKeyboardNavigationEnabled =
        prefs.getBool('accessibility_keyboard_navigation') ?? false;
  }

  /// Detect system accessibility settings
  Future<void> _detectSystemAccessibilitySettings() async {
    try {
      // Set default values - will be updated when context is available
      _isScreenReaderEnabled = false;
      _textScaleFactor = 1.0;
    } catch (e) {
      debugPrint('Error detecting accessibility settings: $e');
    }
  }

  /// Update accessibility settings with context
  void updateWithContext(BuildContext context) {
    try {
      final mediaQuery = MediaQuery.of(context);
      _isScreenReaderEnabled = mediaQuery.accessibleNavigation;
      _textScaleFactor = mediaQuery.textScaler.scale(1.0);
    } catch (e) {
      debugPrint('Error updating accessibility settings: $e');
    }
  }

  /// Get text scaler for accessibility
  TextScaler get textScaler => TextScaler.linear(_textScaleFactor);

  /// Enable/disable high contrast mode
  Future<void> setHighContrastMode(bool enabled) async {
    _isHighContrastEnabled = enabled;
    await _saveSettings();
    notifyListeners();
  }

  /// Enable/disable screen reader support
  Future<void> setScreenReaderEnabled(bool enabled) async {
    _isScreenReaderEnabled = enabled;
    await _saveSettings();
    notifyListeners();
  }

  /// Enable/disable voice navigation
  Future<void> setVoiceNavigationEnabled(bool enabled) async {
    _isVoiceNavigationEnabled = enabled;
    await _saveSettings();
    notifyListeners();
  }

  /// Set text scale factor
  Future<void> setTextScaleFactor(double factor) async {
    _textScaleFactor = factor.clamp(0.8, 3.0);
    await _saveSettings();
    notifyListeners();
  }

  /// Set language
  Future<void> setLanguage(String language) async {
    _currentLanguage = language;
    await _saveSettings();
    notifyListeners();
  }

  /// Enable/disable keyboard navigation
  Future<void> setKeyboardNavigationEnabled(bool enabled) async {
    _isKeyboardNavigationEnabled = enabled;
    await _saveSettings();
    notifyListeners();
  }

  /// Save settings to SharedPreferences
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('accessibility_high_contrast', _isHighContrastEnabled);
    await prefs.setBool('accessibility_screen_reader', _isScreenReaderEnabled);
    await prefs.setBool(
      'accessibility_voice_navigation',
      _isVoiceNavigationEnabled,
    );
    await prefs.setDouble('accessibility_text_scale', _textScaleFactor);
    await prefs.setString('accessibility_language', _currentLanguage);
    await prefs.setBool(
      'accessibility_keyboard_navigation',
      _isKeyboardNavigationEnabled,
    );
  }

  /// Get cultural color scheme for current language
  ColorScheme getCulturalColorScheme() {
    return const ColorScheme.light(
      primary: Color(0xFFFF7A00), // Light orange — brand primary
      secondary: Color(0xFFFF6B35), // Coral orange — brand secondary
      surface: Color(0xFFFFFFFF),
      onPrimary: Color(0xFFFFFFFF),
      onSecondary: Color(0xFFFFFFFF),
      onSurface: Color(0xFF1A1A1A),
      surfaceContainerHighest: Color(0xFFFFF8F0), // Warm cream tint
    );
  }

  /// Announce text for screen readers
  Future<void> announceForScreenReader(String text) async {
    if (_isScreenReaderEnabled) {
      try {
        // Use SemanticsService for screen reader announcements
        await SemanticsService.announce(text, TextDirection.ltr);
      } catch (e) {
        debugPrint('Error announcing to screen reader: $e');
      }
    }
  }

  /// Announce text to screen reader (alias)
  Future<void> announceToScreenReader(String text) async {
    await announceForScreenReader(text);
  }

  /// Get semantic label for widget based on current language
  String getSemanticLabel(String key, {Map<String, String>? params}) {
    // Basic implementation - in a real app this would use localization
    return key;
  }

  /// Create temple semantic label
  String createTempleSemanticLabel(
    String templeName, {
    String? location,
    String? distance,
    bool? isLive,
    bool? isFavorite,
  }) {
    final parts = <String>[templeName];

    if (location != null) parts.add('located at $location');
    if (distance != null) parts.add('$distance away');
    if (isLive == true) parts.add('live darshan available');
    if (isFavorite == true) parts.add('in favorites');

    return parts.join(', ');
  }

  /// Provide accessible haptic feedback
  Future<void> provideAccessibleHapticFeedback(
    BuildContext context, {
    required String type,
  }) async {
    switch (type) {
      case 'lightImpact':
        await HapticFeedback.lightImpact();
        break;
      case 'mediumImpact':
        await HapticFeedback.mediumImpact();
        break;
      case 'heavyImpact':
        await HapticFeedback.heavyImpact();
        break;
      case 'selectionClick':
        await HapticFeedback.selectionClick();
        break;
      case 'vibrate':
        await HapticFeedback.vibrate();
        break;
      default:
        await HapticFeedback.lightImpact();
        break;
    }
  }

  /// Get appropriate font family for current language
  String get fontFamily {
    switch (_currentLanguage) {
      case 'hi':
        return 'NotoSansHindi';
      case 'gu':
        return 'NotoSansGujarati';
      default:
        return 'Inter';
    }
  }

  /// Provide Android-specific haptic feedback
  Future<void> provideAndroidHapticFeedback(String type) async {
    final context = NavigationService.navigatorKey.currentContext;
    if (context != null) {
      await provideAccessibleHapticFeedback(context, type: type);
    } else {
      // Fallback to basic haptic feedback if no context available
      switch (type) {
        case 'lightImpact':
          await HapticFeedback.lightImpact();
          break;
        case 'mediumImpact':
          await HapticFeedback.mediumImpact();
          break;
        case 'heavyImpact':
          await HapticFeedback.heavyImpact();
          break;
        default:
          await HapticFeedback.lightImpact();
          break;
      }
    }
  }

  /// Announce to TalkBack (Android screen reader)
  Future<void> announceToTalkBack(String text) async {
    await announceForScreenReader(text);
  }

  /// Get Android touch configuration
  Map<String, dynamic> getAndroidTouchConfig() {
    return {
      'minimumTouchTargetSize': 48.0,
      'touchSlop': 8.0,
      'doubleTapTimeout': 300,
      'longPressTimeout': 500,
    };
  }

  /// Create Android content description
  String createAndroidContentDescription(String text, {String? hint}) {
    if (hint != null) {
      return '$text. $hint';
    }
    return text;
  }
}

// Navigation service for context access
class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
}
