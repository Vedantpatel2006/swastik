import 'package:flutter/material.dart';
import 'haptic_feedback_helper.dart';

/// Extension on GestureDetector to add haptic feedback support
extension GestureDetectorHaptic on GestureDetector {
  /// Create a gesture detector with haptic feedback on tap
  static GestureDetector withHaptic({
    required Widget child,
    required VoidCallback onTap,
    String hapticType = 'light',
    VoidCallback? onLongPress,
    HitTestBehavior? behavior,
    Duration debounce = const Duration(milliseconds: 300),
  }) {
    bool _canTap = true;

    return GestureDetector(
      onTap: () async {
        if (!_canTap) return;
        _canTap = false;
        await _provideHaptic(hapticType);
        onTap();
        Future.delayed(debounce, () {
          _canTap = true;
        });
      },
      onLongPress: onLongPress != null
          ? () async {
              await HapticFeedbackHelper.heavyTap();
              onLongPress();
            }
          : null,
      behavior: behavior,
      child: child,
    );
  }

  static Future<void> _provideHaptic(String type) async {
    switch (type) {
      case 'light':
        await HapticFeedbackHelper.lightTap();
        break;
      case 'medium':
        await HapticFeedbackHelper.mediumTap();
        break;
      case 'heavy':
        await HapticFeedbackHelper.heavyTap();
        break;
      case 'success':
        await HapticFeedbackHelper.success();
        break;
      case 'error':
        await HapticFeedbackHelper.error();
        break;
      case 'warning':
        await HapticFeedbackHelper.warning();
        break;
      default:
        await HapticFeedbackHelper.lightTap();
    }
  }
}

/// Extension on IconButton to add haptic feedback
extension IconButtonHaptic on IconButton {
  /// Create an icon button with haptic feedback
  static IconButton withHaptic({
    required IconData icon,
    required VoidCallback onPressed,
    String hapticType = 'light',
    Color? color,
    double iconSize = 24.0,
    EdgeInsetsGeometry padding = const EdgeInsets.all(8.0),
    AlignmentGeometry alignment = Alignment.center,
    double splashRadius = 48.0,
    bool selected = false,
  }) {
    return IconButton(
      icon: Icon(icon),
      onPressed: () async {
        await _provideHaptic(hapticType);
        onPressed();
      },
      color: color,
      iconSize: iconSize,
      padding: padding,
      alignment: alignment,
      splashRadius: splashRadius,
      isSelected: selected,
    );
  }

  static Future<void> _provideHaptic(String type) async {
    switch (type) {
      case 'light':
        await HapticFeedbackHelper.lightTap();
        break;
      case 'medium':
        await HapticFeedbackHelper.mediumTap();
        break;
      case 'heavy':
        await HapticFeedbackHelper.heavyTap();
        break;
      case 'success':
        await HapticFeedbackHelper.success();
        break;
      case 'error':
        await HapticFeedbackHelper.error();
        break;
      case 'warning':
        await HapticFeedbackHelper.warning();
        break;
      default:
        await HapticFeedbackHelper.lightTap();
    }
  }
}

/// Extension on ElevatedButton to add haptic feedback
extension ElevatedButtonHaptic on ElevatedButton {
  /// Create an elevated button with haptic feedback
  static ElevatedButton withHaptic({
    required VoidCallback? onPressed,
    required Widget child,
    String hapticType = 'medium',
    ButtonStyle? style,
  }) {
    return ElevatedButton(
      onPressed: onPressed != null
          ? () async {
              await _provideHaptic(hapticType);
              onPressed();
            }
          : null,
      style: style,
      child: child,
    );
  }

  static Future<void> _provideHaptic(String type) async {
    switch (type) {
      case 'light':
        await HapticFeedbackHelper.lightTap();
        break;
      case 'medium':
        await HapticFeedbackHelper.mediumTap();
        break;
      case 'heavy':
        await HapticFeedbackHelper.heavyTap();
        break;
      case 'success':
        await HapticFeedbackHelper.success();
        break;
      case 'error':
        await HapticFeedbackHelper.error();
        break;
      case 'warning':
        await HapticFeedbackHelper.warning();
        break;
      default:
        await HapticFeedbackHelper.mediumTap();
    }
  }
}
