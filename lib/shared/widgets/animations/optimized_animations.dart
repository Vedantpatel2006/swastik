import 'package:flutter/material.dart';

import 'app_animations.dart';

/// Simple animation utilities
class AppAnimationUtils {
  /// Creates a basic animation controller
  static AnimationController createController({
    required TickerProvider vsync,
    Duration duration = AppAnimations.normalDuration,
  }) {
    return AnimationController(
      duration: duration,
      vsync: vsync,
    );
  }

  /// Creates a fade transition
  static Widget fadeTransition({
    required Animation<double> animation,
    required Widget child,
  }) {
    return FadeTransition(
      opacity: animation,
      child: child,
    );
  }

  /// Creates a scale transition
  static Widget scaleTransition({
    required Animation<double> animation,
    required Widget child,
    Alignment alignment = Alignment.center,
  }) {
    return ScaleTransition(
      scale: animation,
      alignment: alignment,
      child: child,
    );
  }

  /// Creates a slide transition
  static Widget slideTransition({
    required Animation<Offset> animation,
    required Widget child,
  }) {
    return SlideTransition(
      position: animation,
      child: child,
    );
  }
}
