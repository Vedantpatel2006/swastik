import 'package:flutter/material.dart';
import '../services/accessibility_service.dart';

/// Theme provider that adapts to accessibility settings and cultural preferences
class AccessibilityTheme {
  static final AccessibilityService _accessibilityService =
      AccessibilityService();

  /// Get theme data based on accessibility settings
  static ThemeData getTheme(BuildContext context) {
    final colorScheme = _getAccessibilityColorScheme();
    final textScaleFactor = _accessibilityService.textScaler.scale(1.0);
    final fontFamily = _accessibilityService.fontFamily;

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      fontFamily: fontFamily,

      // Text theme with proper scaling for complex scripts
      textTheme: _getTextTheme(textScaleFactor, fontFamily),

      // Enhanced button themes for accessibility
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(48, 48), // Minimum touch target
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: TextStyle(
            fontSize: 16 * textScaleFactor,
            fontWeight: FontWeight.w600,
            fontFamily: fontFamily,
          ),
        ),
      ),

      // Enhanced input decoration for accessibility
      inputDecorationTheme: InputDecorationTheme(
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        labelStyle: TextStyle(
          fontSize: 16 * textScaleFactor,
          fontFamily: fontFamily,
        ),
        hintStyle: TextStyle(
          fontSize: 14 * textScaleFactor,
          fontFamily: fontFamily,
        ),
      ),

      // Enhanced card theme
      cardTheme: CardThemeData(
        elevation: _accessibilityService.isHighContrastEnabled ? 8 : 2,
        margin: const EdgeInsets.all(8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: _accessibilityService.isHighContrastEnabled
              ? BorderSide(color: colorScheme.outline, width: 2)
              : BorderSide.none,
        ),
      ),

      // Enhanced app bar theme
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        titleTextStyle: TextStyle(
          fontSize: 20 * textScaleFactor,
          fontWeight: FontWeight.w600,
          fontFamily: fontFamily,
          color: colorScheme.onPrimary,
        ),
      ),

      // Enhanced navigation bar theme
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.primary,
        labelTextStyle: WidgetStateProperty.all(
          TextStyle(fontSize: 12 * textScaleFactor, fontFamily: fontFamily),
        ),
      ),

      // Enhanced list tile theme
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        titleTextStyle: TextStyle(
          fontSize: 16 * textScaleFactor,
          fontWeight: FontWeight.w500,
          fontFamily: fontFamily,
          color: colorScheme.onSurface,
        ),
        subtitleTextStyle: TextStyle(
          fontSize: 14 * textScaleFactor,
          fontFamily: fontFamily,
          color: colorScheme.onSurface.withValues(alpha: 0.7),
        ),
      ),

      // Enhanced focus theme for keyboard navigation (removed - not supported in ThemeData)
    );
  }

  /// Get text theme with proper support for Hindi/Gujarati scripts
  static TextTheme _getTextTheme(double textScaleFactor, String fontFamily) {
    return TextTheme(
      displayLarge: TextStyle(
        fontSize: 57 * textScaleFactor,
        fontWeight: FontWeight.w400,
        fontFamily: fontFamily,
        height: _getLineHeight(fontFamily),
      ),
      displayMedium: TextStyle(
        fontSize: 45 * textScaleFactor,
        fontWeight: FontWeight.w400,
        fontFamily: fontFamily,
        height: _getLineHeight(fontFamily),
      ),
      displaySmall: TextStyle(
        fontSize: 36 * textScaleFactor,
        fontWeight: FontWeight.w400,
        fontFamily: fontFamily,
        height: _getLineHeight(fontFamily),
      ),
      headlineLarge: TextStyle(
        fontSize: 32 * textScaleFactor,
        fontWeight: FontWeight.w400,
        fontFamily: fontFamily,
        height: _getLineHeight(fontFamily),
      ),
      headlineMedium: TextStyle(
        fontSize: 28 * textScaleFactor,
        fontWeight: FontWeight.w400,
        fontFamily: fontFamily,
        height: _getLineHeight(fontFamily),
      ),
      headlineSmall: TextStyle(
        fontSize: 24 * textScaleFactor,
        fontWeight: FontWeight.w400,
        fontFamily: fontFamily,
        height: _getLineHeight(fontFamily),
      ),
      titleLarge: TextStyle(
        fontSize: 22 * textScaleFactor,
        fontWeight: FontWeight.w400,
        fontFamily: fontFamily,
        height: _getLineHeight(fontFamily),
      ),
      titleMedium: TextStyle(
        fontSize: 16 * textScaleFactor,
        fontWeight: FontWeight.w500,
        fontFamily: fontFamily,
        height: _getLineHeight(fontFamily),
      ),
      titleSmall: TextStyle(
        fontSize: 14 * textScaleFactor,
        fontWeight: FontWeight.w500,
        fontFamily: fontFamily,
        height: _getLineHeight(fontFamily),
      ),
      bodyLarge: TextStyle(
        fontSize: 16 * textScaleFactor,
        fontWeight: FontWeight.w400,
        fontFamily: fontFamily,
        height: _getLineHeight(fontFamily),
      ),
      bodyMedium: TextStyle(
        fontSize: 14 * textScaleFactor,
        fontWeight: FontWeight.w400,
        fontFamily: fontFamily,
        height: _getLineHeight(fontFamily),
      ),
      bodySmall: TextStyle(
        fontSize: 12 * textScaleFactor,
        fontWeight: FontWeight.w400,
        fontFamily: fontFamily,
        height: _getLineHeight(fontFamily),
      ),
      labelLarge: TextStyle(
        fontSize: 14 * textScaleFactor,
        fontWeight: FontWeight.w500,
        fontFamily: fontFamily,
        height: _getLineHeight(fontFamily),
      ),
      labelMedium: TextStyle(
        fontSize: 12 * textScaleFactor,
        fontWeight: FontWeight.w500,
        fontFamily: fontFamily,
        height: _getLineHeight(fontFamily),
      ),
      labelSmall: TextStyle(
        fontSize: 11 * textScaleFactor,
        fontWeight: FontWeight.w500,
        fontFamily: fontFamily,
        height: _getLineHeight(fontFamily),
      ),
    );
  }

  /// Get appropriate line height for different scripts
  static double _getLineHeight(String fontFamily) {
    // Devanagari and Gujarati scripts need more line height
    if (fontFamily == 'NotoSansDevanagari' ||
        fontFamily == 'NotoSansGujarati') {
      return 1.4; // Increased line height for complex scripts
    }
    return 1.2; // Standard line height for Latin scripts
  }

  /// Get accessibility-enhanced color scheme
  static ColorScheme _getAccessibilityColorScheme() {
    final language = _accessibilityService.currentLanguage;
    final isHighContrast = _accessibilityService.isHighContrastEnabled;

    if (isHighContrast) {
      return _getHighContrastColorScheme(language);
    } else {
      return _accessibilityService.getCulturalColorScheme();
    }
  }

  /// Get high contrast color scheme for better visibility
  static ColorScheme _getHighContrastColorScheme(String language) {
    final colors = getHighContrastColors(language);

    return ColorScheme.light(
      primary: colors['primary']!,
      onPrimary: colors['onPrimary']!,
      secondary: colors['secondary']!,
      onSecondary: colors['onSecondary']!,
      surface: colors['surface']!,
      onSurface: colors['onSurface']!,
      error: colors['error']!,
      onError: colors['onError']!,
      outline: colors['outline']!,
    );
  }

  /// Get enhanced theme with larger touch targets and better accessibility
  static ThemeData getEnhancedAccessibilityTheme(BuildContext context) {
    final baseTheme = getTheme(context);
    final textScaleFactor = _accessibilityService.textScaler.scale(1.0);
    final isHighContrast = _accessibilityService.isHighContrastEnabled;

    return baseTheme.copyWith(
      // Enhanced button themes with larger touch targets
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(88, 56), // Larger minimum touch target
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: TextStyle(
            fontSize: 18 * textScaleFactor, // Larger text
            fontWeight: FontWeight.w600,
            fontFamily: _accessibilityService.fontFamily,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: isHighContrast
                ? BorderSide(color: baseTheme.colorScheme.outline, width: 2)
                : BorderSide.none,
          ),
        ),
      ),

      // Enhanced text button theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(88, 56),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: TextStyle(
            fontSize: 16 * textScaleFactor,
            fontWeight: FontWeight.w600,
            fontFamily: _accessibilityService.fontFamily,
          ),
        ),
      ),

      // Enhanced icon button theme
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(56, 56), // Larger touch target
          iconSize: 28, // Larger icons
          padding: const EdgeInsets.all(16),
        ),
      ),

      // Enhanced floating action button theme
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        sizeConstraints: const BoxConstraints(minWidth: 64, minHeight: 64),
        iconSize: 32,
      ),

      // Enhanced chip theme
      chipTheme: ChipThemeData(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        labelPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        labelStyle: TextStyle(
          fontSize: 14 * textScaleFactor,
          fontFamily: _accessibilityService.fontFamily,
        ),
      ),

      // Enhanced slider theme
      sliderTheme: SliderThemeData(
        trackHeight: 6,
        valueIndicatorTextStyle: TextStyle(
          fontSize: 16 * textScaleFactor,
          fontFamily: _accessibilityService.fontFamily,
        ),
      ),

      // Enhanced switch theme
      switchTheme: SwitchThemeData(
        materialTapTargetSize: MaterialTapTargetSize.padded,
        thumbIcon: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const Icon(Icons.check, size: 20);
          }
          return const Icon(Icons.close, size: 20);
        }),
      ),

      // Enhanced checkbox theme
      checkboxTheme: CheckboxThemeData(
        materialTapTargetSize: MaterialTapTargetSize.padded,
        visualDensity: VisualDensity.comfortable,
        side: isHighContrast
            ? BorderSide(color: baseTheme.colorScheme.outline, width: 2)
            : null,
      ),

      // Enhanced radio theme
      radioTheme: RadioThemeData(
        materialTapTargetSize: MaterialTapTargetSize.padded,
        visualDensity: VisualDensity.comfortable,
      ),

      // Enhanced tooltip theme
      tooltipTheme: TooltipThemeData(
        textStyle: TextStyle(
          fontSize: 14 * textScaleFactor,
          fontFamily: _accessibilityService.fontFamily,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        margin: const EdgeInsets.all(8),
      ),

      // Enhanced snack bar theme
      snackBarTheme: SnackBarThemeData(
        contentTextStyle: TextStyle(
          fontSize: 16 * textScaleFactor,
          fontFamily: _accessibilityService.fontFamily,
        ),
        actionTextColor: baseTheme.colorScheme.primary,
      ),
    );
  }

  /// Get high contrast colors for better visibility
  static Map<String, Color> getHighContrastColors(String language) {
    switch (language) {
      case 'hi':
      case 'gu':
        return {
          'primary': const Color(0xFFFF6B35), // High contrast saffron
          'onPrimary': const Color(0xFFFFFFFF),
          'secondary': const Color(0xFF138808), // High contrast green
          'onSecondary': const Color(0xFFFFFFFF),
          'background': const Color(0xFFFFFBF0), // Cream background
          'onBackground': const Color(0xFF000000),
          'surface': const Color(0xFFFFFFFF),
          'onSurface': const Color(0xFF000000),
          'error': const Color(0xFFD32F2F),
          'onError': const Color(0xFFFFFFFF),
          'outline': const Color(0xFF000000),
        };
      default:
        return {
          'primary': const Color(0xFFFF6B35),
          'onPrimary': const Color(0xFFFFFFFF),
          'secondary': const Color(0xFF388E3C),
          'onSecondary': const Color(0xFFFFFFFF),
          'background': const Color(0xFFFFFFFF),
          'onBackground': const Color(0xFF000000),
          'surface': const Color(0xFFFFFFFF),
          'onSurface': const Color(0xFF000000),
          'error': const Color(0xFFD32F2F),
          'onError': const Color(0xFFFFFFFF),
          'outline': const Color(0xFF000000),
        };
    }
  }
}
