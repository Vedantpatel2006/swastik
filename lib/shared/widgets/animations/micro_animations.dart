import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';
import 'app_animations.dart';

/// Utility class for micro-animations and interaction feedback
class MicroAnimations {
  /// Creates a bounce animation for buttons and interactive elements
  static Widget bounceOnTap({
    required Widget child,
    required VoidCallback? onTap,
    Duration duration = AppAnimations.fastDuration,
    double scaleValue = AppAnimations.scaleAnimationValue,
    bool enableHapticFeedback = true,
  }) {
    return _BounceWidget(
      onTap: onTap,
      duration: duration,
      scaleValue: scaleValue,
      enableHapticFeedback: enableHapticFeedback,
      child: child,
    );
  }

  /// Creates a pulse animation for highlighting elements
  static Widget pulseAnimation({
    required Widget child,
    Duration duration = AppAnimations.slowDuration,
    double minScale = 0.95,
    double maxScale = 1.05,
    bool repeat = true,
  }) {
    return _PulseWidget(
      duration: duration,
      minScale: minScale,
      maxScale: maxScale,
      repeat: repeat,
      child: child,
    );
  }

  /// Creates a shake animation for error feedback
  static Widget shakeOnError({
    required Widget child,
    required bool hasError,
    Duration duration = AppAnimations.normalDuration,
    double shakeOffset = 10.0,
  }) {
    return _ShakeWidget(
      hasError: hasError,
      duration: duration,
      shakeOffset: shakeOffset,
      child: child,
    );
  }

  /// Creates a fade and slide animation for list items
  static Widget fadeSlideIn({
    required Widget child,
    Duration delay = Duration.zero,
    Duration duration = AppAnimations.normalDuration,
    Offset slideOffset = const Offset(0, 20),
  }) {
    return _FadeSlideWidget(
      delay: delay,
      duration: duration,
      slideOffset: slideOffset,
      child: child,
    );
  }

  /// Creates a scale and fade animation for appearing elements
  static Widget scaleIn({
    required Widget child,
    Duration delay = Duration.zero,
    Duration duration = AppAnimations.normalDuration,
    double initialScale = 0.0,
  }) {
    return _ScaleInWidget(
      delay: delay,
      duration: duration,
      initialScale: initialScale,
      child: child,
    );
  }

  /// Triggers haptic feedback based on interaction type
  static Future<void> triggerHapticFeedback(HapticFeedbackType type) async {
    final hasVibrator = await Vibration.hasVibrator();
    switch (type) {
      case HapticFeedbackType.light:
        if (hasVibrator == true) {
          Vibration.vibrate(duration: 30);
        } else {
          HapticFeedback.lightImpact();
        }
        break;
      case HapticFeedbackType.medium:
        if (hasVibrator == true) {
          Vibration.vibrate(duration: 100);
        } else {
          HapticFeedback.mediumImpact();
        }
        break;
      case HapticFeedbackType.heavy:
        if (hasVibrator == true) {
          Vibration.vibrate(duration: 200);
        } else {
          HapticFeedback.heavyImpact();
        }
        break;
      case HapticFeedbackType.selection:
        if (hasVibrator == true) {
          Vibration.vibrate(duration: 50);
        } else {
          HapticFeedback.selectionClick();
        }
        break;
      case HapticFeedbackType.error:
        if (hasVibrator == true) {
          Vibration.vibrate(duration: 200);
        } else {
          HapticFeedback.heavyImpact();
        }
        break;
    }
  }
}

enum HapticFeedbackType { light, medium, heavy, selection, error }

/// Internal bounce widget implementation
class _BounceWidget extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Duration duration;
  final double scaleValue;
  final bool enableHapticFeedback;

  const _BounceWidget({
    required this.child,
    required this.onTap,
    required this.duration,
    required this.scaleValue,
    required this.enableHapticFeedback,
  });

  @override
  State<_BounceWidget> createState() => _BounceWidgetState();
}

class _BounceWidgetState extends State<_BounceWidget> with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.scaleValue,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: AppAnimations.interactionCurve,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    if (widget.onTap != null) {
      await _controller.forward();
      widget.onTap!();
      await _controller.reverse();
      if (widget.enableHapticFeedback) {
        await SystemSound.play(SystemSoundType.click);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleTap,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

/// Internal pulse widget implementation
class _PulseWidget extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double minScale;
  final double maxScale;
  final bool repeat;

  const _PulseWidget({
    required this.child,
    required this.duration,
    required this.minScale,
    required this.maxScale,
    required this.repeat,
  });

  @override
  State<_PulseWidget> createState() => _PulseWidgetState();
}

class _PulseWidgetState extends State<_PulseWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    _scaleAnimation = Tween<double>(
      begin: widget.minScale,
      end: widget.maxScale,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    if (widget.repeat) {
      _controller.repeat(reverse: true);
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: widget.child,
        );
      },
    );
  }
}

/// Internal shake widget implementation
class _ShakeWidget extends StatefulWidget {
  final Widget child;
  final bool hasError;
  final Duration duration;
  final double shakeOffset;

  const _ShakeWidget({
    required this.child,
    required this.hasError,
    required this.duration,
    required this.shakeOffset,
  });

  @override
  State<_ShakeWidget> createState() => _ShakeWidgetState();
}

class _ShakeWidgetState extends State<_ShakeWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    _shakeAnimation = Tween<double>(
      begin: -1.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticIn));
  }

  @override
  void didUpdateWidget(_ShakeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.hasError && !oldWidget.hasError) {
      _controller.forward().then((_) => _controller.reset());
      MicroAnimations.triggerHapticFeedback(HapticFeedbackType.error);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_shakeAnimation.value * widget.shakeOffset, 0),
          child: widget.child,
        );
      },
    );
  }
}

/// Internal fade slide widget implementation
class _FadeSlideWidget extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  final Offset slideOffset;

  const _FadeSlideWidget({
    required this.child,
    required this.delay,
    required this.duration,
    required this.slideOffset,
  });

  @override
  State<_FadeSlideWidget> createState() => _FadeSlideWidgetState();
}

class _FadeSlideWidgetState extends State<_FadeSlideWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: AppAnimations.defaultCurve,
    );
    _slideAnimation = Tween<Offset>(begin: widget.slideOffset, end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: AppAnimations.interactionCurve,
          ),
        );

    Future.delayed(widget.delay, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: _slideAnimation.value,
          child: Opacity(opacity: _fadeAnimation.value, child: widget.child),
        );
      },
    );
  }
}

/// Internal scale in widget implementation
class _ScaleInWidget extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  final double initialScale;

  const _ScaleInWidget({
    required this.child,
    required this.delay,
    required this.duration,
    required this.initialScale,
  });

  @override
  State<_ScaleInWidget> createState() => _ScaleInWidgetState();
}

class _ScaleInWidgetState extends State<_ScaleInWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    _scaleAnimation = Tween<double>(begin: widget.initialScale, end: 1.0)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: AppAnimations.interactionCurve,
          ),
        );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: AppAnimations.defaultCurve,
    );

    Future.delayed(widget.delay, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(opacity: _fadeAnimation.value, child: widget.child),
        );
      },
    );
  }
}
