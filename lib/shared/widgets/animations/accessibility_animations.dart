import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_animations.dart';

/// Accessibility-aware animation configurations and utilities
class AccessibilityAnimations {
  /// Gets the appropriate animation duration based on accessibility settings
  static Duration getAccessibleDuration(
    BuildContext context,
    Duration defaultDuration,
  ) {
    final mediaQuery = MediaQuery.of(context);

    // Respect system animation scale
    final timeDilation = mediaQuery.accessibleNavigation ? 0.5 : 1.0;

    // Reduce animations if requested
    if (mediaQuery.disableAnimations) {
      return Duration.zero;
    }

    return Duration(
      milliseconds: (defaultDuration.inMilliseconds * timeDilation).round(),
    );
  }

  /// Creates an accessible fade transition
  static Widget accessibleFadeTransition({
    required BuildContext context,
    required Animation<double> animation,
    required Widget child,
    Duration? duration,
  }) {
    if (MediaQuery.of(context).disableAnimations) {
      return child;
    }

    return FadeTransition(
      opacity: animation,
      child: child,
    );
  }

  /// Creates an accessible scale transition with reduced motion support
  static Widget accessibleScaleTransition({
    required BuildContext context,
    required Animation<double> animation,
    required Widget child,
    Alignment alignment = Alignment.center,
  }) {
    if (MediaQuery.of(context).disableAnimations) {
      return child;
    }

    return ScaleTransition(
      scale: animation,
      alignment: alignment,
      child: child,
    );
  }

  /// Creates an accessible slide transition
  static Widget accessibleSlideTransition({
    required BuildContext context,
    required Animation<double> animation,
    required Widget child,
    Offset reducedOffset = const Offset(0.1, 0.0),
  }) {
    final mediaQuery = MediaQuery.of(context);

    if (mediaQuery.disableAnimations) {
      return child;
    }

    // Use smaller offset for reduced motion
    if (mediaQuery.accessibleNavigation) {
      final Animation<Offset> offsetAnimation = Tween<Offset>(
        begin: reducedOffset,
        end: Offset.zero,
      ).animate(animation);

      return SlideTransition(position: offsetAnimation, child: child);
    }

    final Animation<Offset> slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(animation);

    return SlideTransition(
      position: slideAnimation,
      child: child,
    );
  }

  /// Creates an accessible button with appropriate feedback
  static Widget accessibleAnimatedButton({
    required BuildContext context,
    required Widget child,
    required VoidCallback? onPressed,
    bool enableHapticFeedback = true,
    bool enableVisualFeedback = true,
    String? semanticLabel,
  }) {
    return Semantics(
      label: semanticLabel,
      button: true,
      enabled: onPressed != null,
      child: Builder(
        builder: (context) {
          if (!enableVisualFeedback ||
              MediaQuery.of(context).disableAnimations) {
            return GestureDetector(
      behavior: HitTestBehavior.opaque,
              onTap: () {
                if (enableHapticFeedback) {
                  _triggerAccessibleHapticFeedback(context);
                }
                onPressed?.call();
              },
              child: child,
            );
          }

          return _AccessibleAnimatedButton(
            onPressed: onPressed,
            enableHapticFeedback: enableHapticFeedback,
            child: child,
          );
        },
      ),
    );
  }

  /// Triggers haptic feedback appropriate for accessibility settings
  static void _triggerAccessibleHapticFeedback(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    // Provide stronger haptic feedback for accessibility users
    if (mediaQuery.accessibleNavigation) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.lightImpact();
    }
  }

  /// Creates an accessible loading animation
  static Widget accessibleLoadingAnimation({
    required BuildContext context,
    Widget? child,
    String? semanticLabel,
  }) {
    return Semantics(
      label: semanticLabel ?? 'Loading',
      liveRegion: true,
      child: MediaQuery.of(context).disableAnimations
          ? child ?? const CircularProgressIndicator()
          : _AccessibleLoadingWidget(child: child),
    );
  }

  /// Creates an accessible error animation
  static Widget accessibleErrorAnimation({
    required BuildContext context,
    required Widget child,
    required bool hasError,
    String? errorMessage,
  }) {
    return Semantics(
      label: hasError ? (errorMessage ?? 'Error occurred') : null,
      liveRegion: hasError,
      child: MediaQuery.of(context).disableAnimations
          ? child
          : _AccessibleErrorWidget(hasError: hasError, child: child),
    );
  }

  /// Gets animation curve appropriate for accessibility
  static Curve getAccessibleCurve(BuildContext context, Curve defaultCurve) {
    final mediaQuery = MediaQuery.of(context);

    // Use gentler curves for accessibility
    if (mediaQuery.accessibleNavigation) {
      return Curves.easeInOut;
    }

    return defaultCurve;
  }
}

/// Internal accessible animated button implementation
class _AccessibleAnimatedButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final bool enableHapticFeedback;

  const _AccessibleAnimatedButton({
    required this.child,
    required this.onPressed,
    required this.enableHapticFeedback,
  });

  @override
  State<_AccessibleAnimatedButton> createState() =>
      _AccessibleAnimatedButtonState();
}

class _AccessibleAnimatedButtonState extends State<_AccessibleAnimatedButton>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AccessibilityAnimations.getAccessibleDuration(
        context,
        AppAnimations.fastDuration,
      ),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(
        parent: _controller,
        curve: AccessibilityAnimations.getAccessibleCurve(
          context,
          AppAnimations.interactionCurve,
        ),
      ),
    );
  }

  Future<void> _handleTap() async {
    if (widget.onPressed != null) {
      await _controller.forward();
      await _controller.reverse();

      if (mounted && widget.enableHapticFeedback) {
        AccessibilityAnimations._triggerAccessibleHapticFeedback(context);
      }

      widget.onPressed!();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleTap,
      child: ScaleTransition(scale: _scaleAnimation, child: widget.child),
    );
  }
}

/// Internal accessible loading widget implementation
class _AccessibleLoadingWidget extends StatefulWidget {
  final Widget? child;

  const _AccessibleLoadingWidget({this.child});

  @override
  State<_AccessibleLoadingWidget> createState() =>
      _AccessibleLoadingWidgetState();
}

class _AccessibleLoadingWidgetState extends State<_AccessibleLoadingWidget>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.linear));

    _controller.repeat();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _rotationAnimation,
      builder: (context, child) {
        return Transform.rotate(
          angle: _rotationAnimation.value * 2 * 3.14159,
          child: widget.child ?? const CircularProgressIndicator(),
        );
      },
    );
  }
}

/// Internal accessible error widget implementation
class _AccessibleErrorWidget extends StatefulWidget {
  final Widget child;
  final bool hasError;

  const _AccessibleErrorWidget({required this.child, required this.hasError});

  @override
  State<_AccessibleErrorWidget> createState() => _AccessibleErrorWidgetState();
}

class _AccessibleErrorWidgetState extends State<_AccessibleErrorWidget>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppAnimations.normalDuration,
      vsync: this,
    );

    _shakeAnimation = Tween<double>(
      begin: -1.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticIn));
  }

  @override
  void didUpdateWidget(_AccessibleErrorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.hasError && !oldWidget.hasError) {
      _controller.forward().then((_) => _controller.reset());

      // Provide haptic feedback for errors
      HapticFeedback.heavyImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_shakeAnimation.value * 5.0, 0),
          child: widget.child,
        );
      },
    );
  }
}

/// Extension for adding accessibility support to existing animations
extension AccessibilityAnimationExtension on Widget {
  /// Wraps the widget with accessibility-aware animation support
  Widget withAccessibilitySupport(BuildContext context) {
    // Return the widget as-is since we've removed performance monitoring
    // and accessibility is now handled by the system
    return this;
  }
}
