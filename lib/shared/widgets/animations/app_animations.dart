import 'package:flutter/material.dart';

/// Core animation utilities and constants for the temple app
class AppAnimations {
  // Animation durations
  static const Duration fastDuration = Duration(milliseconds: 200);
  static const Duration normalDuration = Duration(milliseconds: 300);
  static const Duration slowDuration = Duration(milliseconds: 500);
  static const Duration extraSlowDuration = Duration(milliseconds: 800);

  // Animation curves
  static const Curve defaultCurve = Curves.easeInOutCubic;
  static const Curve bounceCurve = Curves.elasticOut;
  static const Curve smoothCurve = Curves.easeInOut;
  static const Curve sharpCurve = Curves.easeInOutQuart;
  static const Curve gentleCurve = Curves.easeInOutSine;

  // Specific animation curves for different use cases
  static const Curve pageTransitionCurve = Curves.easeInOutCubic;
  static const Curve loadingCurve = Curves.easeInOut;
  static const Curve interactionCurve = Curves.easeOutBack;
  static const Curve errorCurve = Curves.elasticOut;

  // Animation values
  static const double scaleAnimationValue = 0.95;
  static const double fadeAnimationValue = 0.0;
  static const Offset slideAnimationOffset = Offset(1.0, 0.0);

  // Helper methods for common animation patterns
  static Animation<double> createFadeAnimation(
    AnimationController controller, {
    double begin = 0.0,
    double end = 1.0,
    Curve curve = defaultCurve,
  }) {
    return Tween<double>(
      begin: begin,
      end: end,
    ).animate(CurvedAnimation(parent: controller, curve: curve));
  }

  static Animation<double> createScaleAnimation(
    AnimationController controller, {
    double begin = 0.0,
    double end = 1.0,
    Curve curve = interactionCurve,
  }) {
    return Tween<double>(
      begin: begin,
      end: end,
    ).animate(CurvedAnimation(parent: controller, curve: curve));
  }

  static Animation<Offset> createSlideAnimation(
    AnimationController controller, {
    Offset begin = const Offset(1.0, 0.0),
    Offset end = Offset.zero,
    Curve curve = pageTransitionCurve,
  }) {
    return Tween<Offset>(
      begin: begin,
      end: end,
    ).animate(CurvedAnimation(parent: controller, curve: curve));
  }

  static Animation<Color?> createColorAnimation(
    AnimationController controller, {
    required Color begin,
    required Color end,
    Curve curve = defaultCurve,
  }) {
    return ColorTween(
      begin: begin,
      end: end,
    ).animate(CurvedAnimation(parent: controller, curve: curve));
  }
}
