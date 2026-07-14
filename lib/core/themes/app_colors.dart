import 'package:flutter/material.dart';

/// Centralized color palette for the Swastik app
/// Based on Hindu/Indian spiritual themes with saffron as primary color
class AppColors {
  // Private constructor to prevent instantiation
  AppColors._();

  // ============================================================================
  // PRIMARY COLORS - Saffron/Orange (Brand Identity)
  // ============================================================================

  /// Main brand color - International Orange
  static const Color lightOrange = Color(0xFFFF4F00);

  /// Light orange for gradients and hover states
  static const Color primaryOrange = Color(0xFFFF7A00);

  /// Coral orange for accents and highlights
  static const Color coralOrange = Color(0xFFFF6B35);

  // ============================================================================
  // SECONDARY COLORS - Blue (Trust & Navigation)
  // ============================================================================

  /// Primary blue for navigation and information
  static const Color primaryBlue = Color(0xFF3B82F6);

  /// Dark blue for gradients and hover states
  static const Color darkBlue = Color(0xFF2563EB);

  /// Light blue for high contrast mode
  static const Color lightBlue = Color(0xFF1976D2);

  // ============================================================================
  // STATUS COLORS
  // ============================================================================

  // Success (Green)
  static const Color successGreen = Color(0xFF10B981);
  static const Color darkGreen = Color(0xFF138808);
  static const Color forestGreen = Color(0xFF388E3C);

  // Error (Red)
  static const Color errorRed = Color(0xFFEF4444);
  static const Color darkRed = Color(0xFFD32F2F);
  static const Color liveRed = Color(0xFFFF0844);
  static const Color lightRed = Color(0xFFFF6B6B);

  // Warning (Amber)
  static const Color warningAmber = Color(0xFFF59E0B);
  static const Color walletOrange = Color(0xFFFF9800);

  // Info (Purple)
  static const Color infoPurple = Color(0xFF8B5CF6);
  static const Color darkPurple = Color(0xFF9C27B0);

  // ============================================================================
  // NEUTRAL COLORS - Backgrounds & Surfaces
  // ============================================================================

  /// Main background - warm cream tone
  static const Color creamBackground = Color(0xFFFFF8F0);

  /// Light cream for high contrast
  static const Color lightCream = Color(0xFFFFFBF0);

  /// White for cards and surfaces
  static const Color white = Color(0xFFFFFFFF);

  /// Light gray for drawer and secondary surfaces
  static const Color lightGray = Color(0xFFF8F9FA);

  /// Very light gray for input fields
  static const Color veryLightGray = Color(0xFFF9FAFB);

  /// Subtle gray for borders and dividers
  static const Color subtleGray = Color(0xFFF5F5F5);

  /// Medium gray
  static const Color mediumGray = Color(0xFFF3F4F6);

  // ============================================================================
  // TEXT COLORS
  // ============================================================================

  /// Primary text color
  static const Color primaryText = Color(0xFF1F2937);
  
  /// Alias for primaryText for consistency
  static const Color textPrimary = primaryText;

  /// Secondary text color
  static const Color secondaryText = Color(0xFF6B7280);
  
  /// Alias for secondaryText for consistency
  static const Color textSecondary = secondaryText;

  /// Disabled text color
  static const Color disabledText = Color(0xFF9CA3AF);

  /// Black for high contrast
  static const Color black = Color(0xFF000000);

  // ============================================================================
  // BORDER COLORS
  // ============================================================================

  /// Standard border color
  static const Color borderGray = Color(0xFFE5E7EB);

  /// Light border color
  static const Color lightBorder = Color(0xFFF3F4F6);

  /// Blue gray for special cases
  static const Color blueGray = Color(0xFF607D8B);

  // ============================================================================
  // ERROR STATE COLORS
  // ============================================================================

  /// Error message background
  static const Color errorBackground = Color(0xFFFEF2F2);

  /// Error message border
  static const Color errorBorder = Color(0xFFFECACA);

  // ============================================================================
  // GRADIENTS
  // ============================================================================

  /// Primary orange gradient for brand elements
  static const LinearGradient orangeGradient = LinearGradient(
    colors: [primaryOrange, lightOrange],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  /// Blue gradient for navigation
  static const LinearGradient blueGradient = LinearGradient(
    colors: [primaryBlue, darkBlue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Live streaming gradient
  static const LinearGradient liveGradient = LinearGradient(
    colors: [liveRed, lightRed],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Success gradient
  static const LinearGradient successGradient = LinearGradient(
    colors: [successGreen, darkGreen],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  /// Get color with opacity
  static Color withOpacity(Color color, double opacity) {
    return color.withValues(alpha: opacity);
  }

  /// Get status color based on status string
  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'success':
      case 'active':
      case 'online':
      case 'synced':
        return successGreen;
      case 'error':
      case 'failed':
      case 'offline':
        return errorRed;
      case 'warning':
      case 'conflict':
        return warningAmber;
      case 'pending':
      case 'syncing':
        return infoPurple;
      case 'live':
        return liveRed;
      default:
        return secondaryText;
    }
  }

  /// Get gradient based on type
  static LinearGradient getGradient(String type) {
    switch (type.toLowerCase()) {
      case 'primary':
      case 'orange':
        return orangeGradient;
      case 'blue':
      case 'navigation':
        return blueGradient;
      case 'live':
      case 'streaming':
        return liveGradient;
      case 'success':
        return successGradient;
      default:
        return orangeGradient;
    }
  }

  // ============================================================================
  // SEMANTIC COLORS (Context-based)
  // ============================================================================

  /// Colors for specific UI elements
  static const Color appBarBackground = primaryOrange;
  static const Color appBarForeground = white;
  static const Color scaffoldBackground = creamBackground;
  static const Color cardBackground = white;
  static const Color drawerBackground = lightGray;
  static const Color inputBackground = veryLightGray;
  static const Color dividerColor = borderGray;

  /// Button colors
  static const Color primaryButtonBackground = primaryOrange;
  static const Color primaryButtonForeground = white;
  static const Color secondaryButtonBackground = coralOrange;
  static const Color secondaryButtonForeground = white;

  /// Icon colors
  static const Color primaryIconColor = primaryOrange;
  static const Color secondaryIconColor = secondaryText;
  static const Color activeIconColor = primaryOrange;
  static const Color inactiveIconColor = secondaryText;

  // ============================================================================
  // ACCESSIBILITY COLORS (High Contrast)
  // ============================================================================

  /// High contrast primary
  static const Color highContrastPrimary = coralOrange;

  /// High contrast secondary
  static const Color highContrastSecondary = darkGreen;

  /// High contrast background
  static const Color highContrastBackground = lightCream;

  /// High contrast text
  static const Color highContrastText = black;

  /// High contrast border
  static const Color highContrastBorder = black;
}
