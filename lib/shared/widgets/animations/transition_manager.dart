import 'package:flutter/material.dart';
import 'app_animations.dart';

/// Manages page transitions and screen animations
class TransitionManager {
  /// Creates a slide transition from right to left
  static Widget slideTransition(
    Widget child,
    Animation<double> animation, {
    Offset begin = const Offset(1.0, 0.0),
    Offset end = Offset.zero,
    Curve curve = AppAnimations.pageTransitionCurve,
  }) {
    final slideAnimation = Tween<Offset>(
      begin: begin,
      end: end,
    ).animate(CurvedAnimation(parent: animation, curve: curve));

    return SlideTransition(position: slideAnimation, child: child);
  }

  /// Creates a fade transition
  static Widget fadeTransition(
    Widget child,
    Animation<double> animation, {
    double begin = 0.0,
    double end = 1.0,
    Curve curve = AppAnimations.defaultCurve,
  }) {
    final fadeAnimation = Tween<double>(
      begin: begin,
      end: end,
    ).animate(CurvedAnimation(parent: animation, curve: curve));

    return FadeTransition(opacity: fadeAnimation, child: child);
  }

  /// Creates a scale transition
  static Widget scaleTransition(
    Widget child,
    Animation<double> animation, {
    double begin = 0.0,
    double end = 1.0,
    Curve curve = AppAnimations.interactionCurve,
  }) {
    final scaleAnimation = Tween<double>(
      begin: begin,
      end: end,
    ).animate(CurvedAnimation(parent: animation, curve: curve));

    return ScaleTransition(scale: scaleAnimation, child: child);
  }

  /// Creates a combined fade and slide transition
  static Widget fadeSlideTransition(
    Widget child,
    Animation<double> animation, {
    Offset slideBegin = const Offset(0.0, 0.3),
    Offset slideEnd = Offset.zero,
    double fadeBegin = 0.0,
    double fadeEnd = 1.0,
    Curve curve = AppAnimations.pageTransitionCurve,
  }) {
    final slideAnimation = Tween<Offset>(
      begin: slideBegin,
      end: slideEnd,
    ).animate(CurvedAnimation(parent: animation, curve: curve));

    final fadeAnimation = Tween<double>(
      begin: fadeBegin,
      end: fadeEnd,
    ).animate(CurvedAnimation(parent: animation, curve: curve));

    return SlideTransition(
      position: slideAnimation,
      child: FadeTransition(opacity: fadeAnimation, child: child),
    );
  }

  /// Creates a scale and fade transition
  static Widget scaleFadeTransition(
    Widget child,
    Animation<double> animation, {
    double scaleBegin = 0.8,
    double scaleEnd = 1.0,
    double fadeBegin = 0.0,
    double fadeEnd = 1.0,
    Curve curve = AppAnimations.interactionCurve,
  }) {
    final scaleAnimation = Tween<double>(
      begin: scaleBegin,
      end: scaleEnd,
    ).animate(CurvedAnimation(parent: animation, curve: curve));

    final fadeAnimation = Tween<double>(
      begin: fadeBegin,
      end: fadeEnd,
    ).animate(CurvedAnimation(parent: animation, curve: curve));

    return ScaleTransition(
      scale: scaleAnimation,
      child: FadeTransition(opacity: fadeAnimation, child: child),
    );
  }

  /// Creates a rotation transition
  static Widget rotationTransition(
    Widget child,
    Animation<double> animation, {
    double begin = 0.0,
    double end = 1.0,
    Curve curve = AppAnimations.defaultCurve,
  }) {
    final rotationAnimation = Tween<double>(
      begin: begin,
      end: end,
    ).animate(CurvedAnimation(parent: animation, curve: curve));

    return RotationTransition(turns: rotationAnimation, child: child);
  }

  /// Creates a shared element transition with scale and fade
  static Widget sharedElementTransition(
    Widget child,
    Animation<double> animation, {
    double scaleBegin = 0.8,
    double scaleEnd = 1.0,
    double fadeBegin = 0.0,
    double fadeEnd = 1.0,
    Curve curve = AppAnimations.pageTransitionCurve,
  }) {
    final scaleAnimation = Tween<double>(begin: scaleBegin, end: scaleEnd)
        .animate(
          CurvedAnimation(
            parent: animation,
            curve: Interval(0.0, 0.6, curve: curve),
          ),
        );

    final fadeAnimation = Tween<double>(begin: fadeBegin, end: fadeEnd).animate(
      CurvedAnimation(
        parent: animation,
        curve: Interval(0.0, 0.4, curve: curve),
      ),
    );

    return ScaleTransition(
      scale: scaleAnimation,
      child: FadeTransition(opacity: fadeAnimation, child: child),
    );
  }
}

/// Custom page route that uses TransitionManager for animations
class CustomPageRoute<T> extends PageRouteBuilder<T> {
  final Widget child;
  final TransitionType transitionType;
  final Duration duration;
  final Curve curve;
  final bool enableHeroAnimations;
  final String? heroTag;

  CustomPageRoute({
    required this.child,
    this.transitionType = TransitionType.slideFromRight,
    this.duration = AppAnimations.normalDuration,
    this.curve = AppAnimations.pageTransitionCurve,
    this.enableHeroAnimations = true,
    this.heroTag,
    super.settings,
  }) : super(
         pageBuilder: (context, animation, secondaryAnimation) => child,
         transitionDuration: duration,
         reverseTransitionDuration: duration,
       );

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Apply secondary animation for the previous page
    Widget transitionChild = child;

    // Add shared element transition support
    if (enableHeroAnimations) {
      transitionChild = _wrapWithSharedElementTransition(
        transitionChild,
        animation,
        secondaryAnimation,
      );
    }

    switch (transitionType) {
      case TransitionType.slideFromRight:
        return TransitionManager.slideTransition(
          transitionChild,
          animation,
          begin: const Offset(1.0, 0.0),
          curve: curve,
        );
      case TransitionType.slideFromLeft:
        return TransitionManager.slideTransition(
          transitionChild,
          animation,
          begin: const Offset(-1.0, 0.0),
          curve: curve,
        );
      case TransitionType.slideFromTop:
        return TransitionManager.slideTransition(
          transitionChild,
          animation,
          begin: const Offset(0.0, -1.0),
          curve: curve,
        );
      case TransitionType.slideFromBottom:
        return TransitionManager.slideTransition(
          transitionChild,
          animation,
          begin: const Offset(0.0, 1.0),
          curve: curve,
        );
      case TransitionType.fade:
        return TransitionManager.fadeTransition(
          transitionChild,
          animation,
          curve: curve,
        );
      case TransitionType.scale:
        return TransitionManager.scaleTransition(
          transitionChild,
          animation,
          curve: curve,
        );
      case TransitionType.fadeSlide:
        return TransitionManager.fadeSlideTransition(
          transitionChild,
          animation,
          curve: curve,
        );
      case TransitionType.scaleFade:
        return TransitionManager.scaleFadeTransition(
          transitionChild,
          animation,
          curve: curve,
        );
      case TransitionType.rotation:
        return TransitionManager.rotationTransition(
          transitionChild,
          animation,
          curve: curve,
        );
      case TransitionType.sharedElement:
        return TransitionManager.sharedElementTransition(
          transitionChild,
          animation,
          curve: curve,
        );
    }
  }

  /// Wraps the child with shared element transition support
  Widget _wrapWithSharedElementTransition(
    Widget child,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    // Add subtle scale animation to the previous page
    final secondaryScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: secondaryAnimation, curve: curve));

    return AnimatedBuilder(
      animation: secondaryAnimation,
      builder: (context, _) {
        return Transform.scale(
          scale: secondaryScaleAnimation.value,
          child: child,
        );
      },
    );
  }
}

/// Types of page transitions available
enum TransitionType {
  slideFromRight,
  slideFromLeft,
  slideFromTop,
  slideFromBottom,
  fade,
  scale,
  fadeSlide,
  scaleFade,
  rotation,
  sharedElement,
}

/// Extension on Navigator to easily use custom transitions
extension NavigatorExtension on NavigatorState {
  Future<T?> pushWithTransition<T extends Object?>(
    Widget page, {
    TransitionType transitionType = TransitionType.slideFromRight,
    Duration duration = AppAnimations.normalDuration,
    Curve curve = AppAnimations.pageTransitionCurve,
    bool enableHeroAnimations = true,
    String? heroTag,
    RouteSettings? settings,
  }) {
    return push<T>(
      CustomPageRoute<T>(
        child: page,
        transitionType: transitionType,
        duration: duration,
        curve: curve,
        enableHeroAnimations: enableHeroAnimations,
        heroTag: heroTag,
        settings: settings,
      ),
    );
  }

  Future<T?>
  pushReplacementWithTransition<T extends Object?, TO extends Object?>(
    Widget page, {
    TransitionType transitionType = TransitionType.slideFromRight,
    Duration duration = AppAnimations.normalDuration,
    Curve curve = AppAnimations.pageTransitionCurve,
    bool enableHeroAnimations = true,
    String? heroTag,
    TO? result,
    RouteSettings? settings,
  }) {
    return pushReplacement<T, TO>(
      CustomPageRoute<T>(
        child: page,
        transitionType: transitionType,
        duration: duration,
        curve: curve,
        enableHeroAnimations: enableHeroAnimations,
        heroTag: heroTag,
        settings: settings,
      ),
      result: result,
    );
  }

  /// Push with hero animation for temple images
  Future<T?> pushWithHeroTransition<T extends Object?>(
    Widget page, {
    required String heroTag,
    TransitionType transitionType = TransitionType.sharedElement,
    Duration duration = AppAnimations.normalDuration,
    Curve curve = AppAnimations.pageTransitionCurve,
    RouteSettings? settings,
  }) {
    return push<T>(
      CustomPageRoute<T>(
        child: page,
        transitionType: transitionType,
        duration: duration,
        curve: curve,
        enableHeroAnimations: true,
        heroTag: heroTag,
        settings: settings,
      ),
    );
  }
}
