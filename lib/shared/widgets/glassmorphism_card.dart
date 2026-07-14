import 'dart:ui';
import 'package:flutter/material.dart';

/// A reusable card widget that implements the Glassmorphism design style
/// Features:
/// - Backdrop blur filter
/// - Semi-transparent gradient background
/// - Semi-transparent border
/// - Optional shadow
class GlassmorphismCard extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final Gradient? gradient;
  final BorderRadius? borderRadius;
  final Border? border;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  const GlassmorphismCard({
    super.key,
    required this.child,
    this.blur = 10.0,
    this.opacity = 0.2,
    this.gradient,
    this.borderRadius,
    this.border,
    this.padding = const EdgeInsets.all(16.0),
    this.margin,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBorderRadius = borderRadius ?? BorderRadius.circular(20);

    Widget content = ClipRRect(
      borderRadius: effectiveBorderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: effectiveBorderRadius,
            border: border ??
                Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1.5,
                ),
            gradient: gradient ??
                LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: opacity),
                    Colors.white.withValues(alpha: opacity * 0.5),
                  ],
                  stops: const [0.1, 1.0],
                ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: padding,
          child: child,
        ),
      ),
    );

    if (margin != null) {
      content = Padding(padding: margin!, child: content);
    }

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: content,
      );
    }

    return content;
  }
}
