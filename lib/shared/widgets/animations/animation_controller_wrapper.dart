import 'package:flutter/material.dart';
import 'app_animations.dart';

/// A wrapper around AnimationController that provides common animation patterns
class AnimationControllerWrapper {
  final AnimationController _controller;
  final TickerProvider vsync;

  AnimationControllerWrapper({
    required this.vsync,
    Duration duration = AppAnimations.normalDuration,
  }) : _controller = AnimationController(duration: duration, vsync: vsync);

  AnimationController get controller => _controller;

  // Common animation patterns
  late final Animation<double> fadeIn = AppAnimations.createFadeAnimation(
    _controller,
  );
  late final Animation<double> fadeOut = AppAnimations.createFadeAnimation(
    _controller,
    begin: 1.0,
    end: 0.0,
  );
  late final Animation<double> scaleUp = AppAnimations.createScaleAnimation(
    _controller,
  );
  late final Animation<double> scaleDown = AppAnimations.createScaleAnimation(
    _controller,
    begin: 1.0,
    end: AppAnimations.scaleAnimationValue,
  );
  late final Animation<Offset> slideFromRight =
      AppAnimations.createSlideAnimation(_controller);
  late final Animation<Offset> slideFromLeft =
      AppAnimations.createSlideAnimation(
        _controller,
        begin: const Offset(-1.0, 0.0),
      );
  late final Animation<Offset> slideFromTop =
      AppAnimations.createSlideAnimation(
        _controller,
        begin: const Offset(0.0, -1.0),
      );
  late final Animation<Offset> slideFromBottom =
      AppAnimations.createSlideAnimation(
        _controller,
        begin: const Offset(0.0, 1.0),
      );

  // Animation control methods
  Future<void> forward() => _controller.forward();
  Future<void> reverse() => _controller.reverse();
  Future<void> reset() async => _controller.reset();
  Future<void> animateTo(double value) => _controller.animateTo(value);
  Future<void> animateBack(double value) => _controller.animateBack(value);

  // Repeat animations
  void repeat({double? min, double? max, bool reverse = false}) {
    _controller.repeat(min: min, max: max, reverse: reverse);
  }

  void stop() => _controller.stop();

  // Status and value getters
  AnimationStatus get status => _controller.status;
  double get value => _controller.value;
  bool get isAnimating => _controller.isAnimating;
  bool get isCompleted => _controller.isCompleted;
  bool get isDismissed => _controller.isDismissed;

  // Listeners
  void addListener(VoidCallback listener) => _controller.addListener(listener);
  void removeListener(VoidCallback listener) =>
      _controller.removeListener(listener);
  void addStatusListener(AnimationStatusListener listener) =>
      _controller.addStatusListener(listener);
  void removeStatusListener(AnimationStatusListener listener) =>
      _controller.removeStatusListener(listener);

  // Dispose
  void dispose() => _controller.dispose();

  // Factory methods for common use cases
  static AnimationControllerWrapper createFadeController({
    required TickerProvider vsync,
    Duration duration = AppAnimations.normalDuration,
  }) {
    return AnimationControllerWrapper(vsync: vsync, duration: duration);
  }

  static AnimationControllerWrapper createScaleController({
    required TickerProvider vsync,
    Duration duration = AppAnimations.fastDuration,
  }) {
    return AnimationControllerWrapper(vsync: vsync, duration: duration);
  }

  static AnimationControllerWrapper createSlideController({
    required TickerProvider vsync,
    Duration duration = AppAnimations.normalDuration,
  }) {
    return AnimationControllerWrapper(vsync: vsync, duration: duration);
  }

  static AnimationControllerWrapper createLoadingController({
    required TickerProvider vsync,
    Duration duration = AppAnimations.slowDuration,
  }) {
    return AnimationControllerWrapper(vsync: vsync, duration: duration);
  }
}
