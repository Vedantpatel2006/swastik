import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Widget that ensures proper touch target sizes and interaction feedback
class EnhancedTouchTarget extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final double minWidth;
  final double minHeight;
  final bool enableHapticFeedback;
  final EdgeInsets? padding;

  const EnhancedTouchTarget({
    super.key,
    required this.child,
    this.onTap,
    this.semanticLabel,
    this.minWidth = 44.0,
    this.minHeight = 44.0,
    this.enableHapticFeedback = true,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      button: onTap != null,
      enabled: onTap != null,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap != null ? () {
            if (enableHapticFeedback) {
              HapticFeedback.lightImpact();
            }
            onTap!();
          } : null,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            constraints: BoxConstraints(
              minWidth: minWidth,
              minHeight: minHeight,
            ),
            padding: padding ?? const EdgeInsets.all(8),
            child: child,
          ),
        ),
      ),
    );
  }
}
