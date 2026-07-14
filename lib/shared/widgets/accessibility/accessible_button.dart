import 'package:flutter/material.dart';
import '../../../core/services/accessibility_service.dart';

/// Accessible button widget with proper semantic labels and haptic feedback
class AccessibleButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final String? semanticLabel;
  final String? tooltip;
  final bool autofocus;
  final FocusNode? focusNode;
  final ButtonStyle? style;
  final bool enableHapticFeedback;

  const AccessibleButton({
    super.key,
    required this.child,
    this.onPressed,
    this.semanticLabel,
    this.tooltip,
    this.autofocus = false,
    this.focusNode,
    this.style,
    this.enableHapticFeedback = true,
  });

  @override
  Widget build(BuildContext context) {
    final accessibilityService = AccessibilityService.instance;

    Widget button = ElevatedButton(
      onPressed: onPressed != null
          ? () {
              if (enableHapticFeedback) {
                accessibilityService.provideAccessibleHapticFeedback(
                  context,
                  type: 'lightImpact',
                );
              }
              onPressed!();
            }
          : null,
      style: style,
      focusNode: focusNode,
      autofocus: autofocus,
      child: child,
    );

    if (tooltip != null) {
      button = Tooltip(message: tooltip!, child: button);
    }

    if (semanticLabel != null) {
      button = Semantics(
        label: semanticLabel,
        button: true,
        enabled: onPressed != null,
        child: button,
      );
    }

    return button;
  }
}

/// Accessible icon button with proper semantic labels
class AccessibleIconButton extends StatelessWidget {
  final Widget icon;
  final VoidCallback? onPressed;
  final String? semanticLabel;
  final String? tooltip;
  final bool autofocus;
  final FocusNode? focusNode;
  final double? iconSize;
  final Color? color;
  final bool enableHapticFeedback;

  const AccessibleIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.semanticLabel,
    this.tooltip,
    this.autofocus = false,
    this.focusNode,
    this.iconSize,
    this.color,
    this.enableHapticFeedback = true,
  });

  @override
  Widget build(BuildContext context) {
    final accessibilityService = AccessibilityService.instance;

    Widget button = IconButton(
      onPressed: onPressed != null
          ? () {
              if (enableHapticFeedback) {
                accessibilityService.provideAccessibleHapticFeedback(
                  context,
                  type: 'lightImpact',
                );
              }
              onPressed!();
            }
          : null,
      icon: icon,
      focusNode: focusNode,
      autofocus: autofocus,
      iconSize: iconSize,
      color: color,
      tooltip: tooltip,
    );

    if (semanticLabel != null) {
      button = Semantics(
        label: semanticLabel,
        button: true,
        enabled: onPressed != null,
        child: button,
      );
    }

    return button;
  }
}

/// Accessible floating action button
class AccessibleFloatingActionButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final String? semanticLabel;
  final String? tooltip;
  final bool autofocus;
  final FocusNode? focusNode;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool enableHapticFeedback;

  const AccessibleFloatingActionButton({
    super.key,
    required this.child,
    this.onPressed,
    this.semanticLabel,
    this.tooltip,
    this.autofocus = false,
    this.focusNode,
    this.backgroundColor,
    this.foregroundColor,
    this.enableHapticFeedback = true,
  });

  @override
  Widget build(BuildContext context) {
    final accessibilityService = AccessibilityService.instance;

    Widget button = FloatingActionButton(
      onPressed: onPressed != null
          ? () {
              if (enableHapticFeedback) {
                accessibilityService.provideAccessibleHapticFeedback(
                  context,
                  type: 'mediumImpact',
                );
              }
              onPressed!();
            }
          : null,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      focusNode: focusNode,
      autofocus: autofocus,
      tooltip: tooltip,
      child: child,
    );

    if (semanticLabel != null) {
      button = Semantics(
        label: semanticLabel,
        button: true,
        enabled: onPressed != null,
        child: button,
      );
    }

    return button;
  }
}

/// Accessible text button
class AccessibleTextButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final String? semanticLabel;
  final bool autofocus;
  final FocusNode? focusNode;
  final ButtonStyle? style;
  final bool enableHapticFeedback;

  const AccessibleTextButton({
    super.key,
    required this.child,
    this.onPressed,
    this.semanticLabel,
    this.autofocus = false,
    this.focusNode,
    this.style,
    this.enableHapticFeedback = true,
  });

  @override
  Widget build(BuildContext context) {
    final accessibilityService = AccessibilityService.instance;

    Widget button = TextButton(
      onPressed: onPressed != null
          ? () {
              if (enableHapticFeedback) {
                accessibilityService.provideAccessibleHapticFeedback(
                  context,
                  type: 'lightImpact',
                );
              }
              onPressed!();
            }
          : null,
      style: style,
      focusNode: focusNode,
      autofocus: autofocus,
      child: child,
    );

    if (semanticLabel != null) {
      button = Semantics(
        label: semanticLabel,
        button: true,
        enabled: onPressed != null,
        child: button,
      );
    }

    return button;
  }
}
