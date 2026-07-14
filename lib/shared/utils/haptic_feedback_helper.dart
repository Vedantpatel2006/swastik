import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Utility class for consistent haptic feedback across the app
/// Provides different types of haptic feedback for different user interactions
class HapticFeedbackHelper {
  // Prevent instantiation
  HapticFeedbackHelper._();

  /// Light tap feedback - for minor interactions (like button presses)
  static Future<void> lightTap() async {
    try {
      await HapticFeedback.lightImpact();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Haptic feedback not available: $e');
      }
    }
  }

  /// Medium tap feedback - for moderate interactions (like favorites toggle)
  static Future<void> mediumTap() async {
    try {
      await HapticFeedback.mediumImpact();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Haptic feedback not available: $e');
      }
    }
  }

  /// Heavy tap feedback - for significant interactions (like bookings, donations)
  static Future<void> heavyTap() async {
    try {
      await HapticFeedback.heavyImpact();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Haptic feedback not available: $e');
      }
    }
  }

  /// Selection feedback - for selection changes
  static Future<void> selection() async {
    try {
      await HapticFeedback.selectionClick();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Haptic feedback not available: $e');
      }
    }
  }

  /// Success feedback - for successful operations
  static Future<void> success() async {
    try {
      // Use sequence of light impacts to simulate success
      await HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(milliseconds: 100));
      await HapticFeedback.lightImpact();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Haptic feedback not available: $e');
      }
    }
  }

  /// Error feedback - for error states
  static Future<void> error() async {
    try {
      // Use heavy impact to indicate error
      await HapticFeedback.heavyImpact();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Haptic feedback not available: $e');
      }
    }
  }

  /// Warning feedback - for warnings
  static Future<void> warning() async {
    try {
      // Use sequence to indicate warning
      await HapticFeedback.lightImpact();
      await Future.delayed(const Duration(milliseconds: 50));
      await HapticFeedback.lightImpact();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Haptic feedback not available: $e');
      }
    }
  }

  /// Toggle feedback - for toggle switches
  static Future<void> toggle() async {
    try {
      await HapticFeedback.selectionClick();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Haptic feedback not available: $e');
      }
    }
  }
}
