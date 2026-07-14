import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for handling Hindi and Gujarati localization
/// Supports text rendering for Devanagari and Gujarati scripts
class LocalizationService {
  static const String _defaultLanguage = 'en';
  static const String _languageKey = 'selected_language';

  // Supported languages
  static const Map<String, String> supportedLanguages = {
    'en': 'English',
    'hi': 'हिन्दी',
    'gu': 'ગુજરાતી',
  };

  // Language resources cache
  static final Map<String, Map<String, String>> _languageResources = {};
  static String _currentLanguage = _defaultLanguage;
  static SharedPreferences? _prefs;

  /// Initialize the localization service
  static Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    _currentLanguage = _prefs?.getString(_languageKey) ?? _defaultLanguage;

    // Load default language resources
    await loadLanguageResources(_currentLanguage);
  }

  /// Get current language
  static String get currentLanguage => _currentLanguage;

  /// Get current locale
  static ui.Locale get currentLocale {
    switch (_currentLanguage) {
      case 'hi':
        return const ui.Locale('hi', 'IN');
      case 'gu':
        return const ui.Locale('gu', 'IN');
      default:
        return const ui.Locale('en', 'US');
    }
  }

  /// Check if current language uses Devanagari script (Hindi)
  static bool get isDevanagariScript => _currentLanguage == 'hi';

  /// Check if current language uses Gujarati script
  static bool get isGujaratiScript => _currentLanguage == 'gu';

  /// Check if current language is right-to-left
  static bool get isRTL => false; // Hindi and Gujarati are LTR

  /// Set language and persist preference
  static Future<void> setLanguage(String languageCode) async {
    if (!supportedLanguages.containsKey(languageCode)) {
      throw ArgumentError('Unsupported language: $languageCode');
    }

    _currentLanguage = languageCode;
    await _prefs?.setString(_languageKey, languageCode);
    await loadLanguageResources(languageCode);
  }

  /// Load language resources from assets
  static Future<void> loadLanguageResources(String languageCode) async {
    if (_languageResources.containsKey(languageCode)) {
      return; // Already loaded
    }

    try {
      final String jsonString = await rootBundle.loadString(
        'assets/localization/$languageCode.json',
      );
      final Map<String, dynamic> jsonMap = json.decode(jsonString);
      _languageResources[languageCode] = jsonMap.map(
        (key, value) => MapEntry(key, value.toString()),
      );
    } catch (e) {
      // If resource file doesn't exist, create empty map
      _languageResources[languageCode] = {};
    }
  }

  /// Get localized text with fallback mechanism
  static String getLocalizedText(String key, {String? language}) {
    final targetLanguage = language ?? _currentLanguage;

    // Try to get text in target language
    final languageMap = _languageResources[targetLanguage];
    if (languageMap != null && languageMap.containsKey(key)) {
      return languageMap[key]!;
    }

    // Fallback to English
    if (targetLanguage != 'en') {
      final englishMap = _languageResources['en'];
      if (englishMap != null && englishMap.containsKey(key)) {
        return englishMap[key]!;
      }
    }

    // Fallback to key itself
    return key;
  }

  /// Get localized text with parameters
  static String getLocalizedTextWithParams(
    String key,
    Map<String, String> params,
  ) {
    String text = getLocalizedText(key);

    params.forEach((paramKey, paramValue) {
      text = text.replaceAll('{$paramKey}', paramValue);
    });

    return text;
  }

  /// Format date according to Gujarati locale preferences
  static String formatGujaratiDate(DateTime date) {
    switch (_currentLanguage) {
      case 'hi':
        return DateFormat('dd MMMM yyyy', 'hi_IN').format(date);
      case 'gu':
        return DateFormat('dd MMMM yyyy', 'gu_IN').format(date);
      default:
        return DateFormat('dd MMMM yyyy', 'en_US').format(date);
    }
  }

  /// Format time according to current locale
  static String formatTime(DateTime time) {
    switch (_currentLanguage) {
      case 'hi':
        return DateFormat('hh:mm a', 'hi_IN').format(time);
      case 'gu':
        return DateFormat('hh:mm a', 'gu_IN').format(time);
      default:
        return DateFormat('hh:mm a', 'en_US').format(time);
    }
  }

  /// Format number according to current locale
  static String formatNumber(num number) {
    switch (_currentLanguage) {
      case 'hi':
        return NumberFormat('#,##,###', 'hi_IN').format(number);
      case 'gu':
        return NumberFormat('#,##,###', 'gu_IN').format(number);
      default:
        return NumberFormat('#,###', 'en_US').format(number);
    }
  }

  /// Format currency for Indian Rupees
  static String formatCurrency(num amount) {
    switch (_currentLanguage) {
      case 'hi':
        return NumberFormat.currency(
          locale: 'hi_IN',
          symbol: '₹',
        ).format(amount);
      case 'gu':
        return NumberFormat.currency(
          locale: 'gu_IN',
          symbol: '₹',
        ).format(amount);
      default:
        return NumberFormat.currency(
          locale: 'en_IN',
          symbol: '₹',
        ).format(amount);
    }
  }

  /// Get text direction for current language
  static ui.TextDirection get textDirection => ui.TextDirection.ltr;

  /// Get appropriate font family for current script
  static String? getFontFamily() {
    switch (_currentLanguage) {
      case 'hi':
        return 'NotoSansDevanagari'; // For Devanagari script
      case 'gu':
        return 'NotoSansGujarati'; // For Gujarati script
      default:
        return null; // Use default font
    }
  }

  /// Check if a string contains Devanagari characters
  static bool containsDevanagari(String text) {
    return RegExp(r'[\u0900-\u097F]').hasMatch(text);
  }

  /// Check if a string contains Gujarati characters
  static bool containsGujarati(String text) {
    return RegExp(r'[\u0A80-\u0AFF]').hasMatch(text);
  }

  /// Get all available translations for a key
  static Map<String, String> getAllTranslations(String key) {
    final Map<String, String> translations = {};

    for (final languageCode in supportedLanguages.keys) {
      final languageMap = _languageResources[languageCode];
      if (languageMap != null && languageMap.containsKey(key)) {
        translations[languageCode] = languageMap[key]!;
      }
    }

    return translations;
  }

  /// Clear language resources cache
  static void clearCache() {
    _languageResources.clear();
  }

  /// Preload all language resources
  static Future<void> preloadAllLanguages() async {
    for (final languageCode in supportedLanguages.keys) {
      await loadLanguageResources(languageCode);
    }
  }

  /// Get language name in its native script
  static String getLanguageName(String languageCode) {
    return supportedLanguages[languageCode] ?? languageCode;
  }

  /// Check if language resources are loaded
  static bool isLanguageLoaded(String languageCode) {
    return _languageResources.containsKey(languageCode);
  }
}
