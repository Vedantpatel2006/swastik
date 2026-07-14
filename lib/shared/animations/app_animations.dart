import 'package:flutter/material.dart';

/// Common animations used throughout the app
class AppAnimations {
  static const Duration defaultDuration = Duration(milliseconds: 300);
  static const Duration fastDuration = Duration(milliseconds: 150);
  static const Duration slowDuration = Duration(milliseconds: 500);

  static const Curve defaultCurve = Curves.easeInOut;
  static const Curve bounceCurve = Curves.bounceOut;
  static const Curve elasticCurve = Curves.elasticOut;

  /// Fade in animation
  static Widget fadeIn({
    required Widget child,
    Duration duration = defaultDuration,
    Curve curve = defaultCurve,
    double begin = 0.0,
    double end = 1.0,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: begin, end: end),
      duration: duration,
      curve: curve,
      builder: (context, value, child) {
        return Opacity(opacity: value, child: child);
      },
      child: child,
    );
  }

  /// Slide in animation
  static Widget slideIn({
    required Widget child,
    Duration duration = defaultDuration,
    Curve curve = defaultCurve,
    Offset begin = const Offset(0, 1),
    Offset end = Offset.zero,
  }) {
    return TweenAnimationBuilder<Offset>(
      tween: Tween(begin: begin, end: end),
      duration: duration,
      curve: curve,
      builder: (context, value, child) {
        return Transform.translate(offset: value, child: child);
      },
      child: child,
    );
  }

  /// Scale animation
  static Widget scale({
    required Widget child,
    Duration duration = defaultDuration,
    Curve curve = defaultCurve,
    double begin = 0.0,
    double end = 1.0,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: begin, end: end),
      duration: duration,
      curve: curve,
      builder: (context, value, child) {
        return Transform.scale(scale: value, child: child);
      },
      child: child,
    );
  }
}
