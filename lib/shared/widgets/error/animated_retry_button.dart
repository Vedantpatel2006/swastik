import 'package:flutter/material.dart';
import '../../../shared/widgets/animations/app_animations.dart';
import '../../../shared/widgets/animations/micro_animations.dart';

/// Animated retry button with loading states and smooth transitions
class AnimatedRetryButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final String text;
  final bool isLoading;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final EdgeInsets? padding;
  final BorderRadius? borderRadius;
  final double? width;
  final double? height;
  final RetryButtonStyle style;

  const AnimatedRetryButton({
    super.key,
    required this.onPressed,
    this.text = 'Retry',
    this.isLoading = false,
    this.icon,
    this.backgroundColor,
    this.foregroundColor,
    this.padding,
    this.borderRadius,
    this.width,
    this.height,
    this.style = RetryButtonStyle.filled,
  });

  @override
  State<AnimatedRetryButton> createState() => _AnimatedRetryButtonState();
}

class _AnimatedRetryButtonState extends State<AnimatedRetryButton>
    with TickerProviderStateMixin {
  late AnimationController _loadingController;
  late AnimationController _pulseController;
  late AnimationController _iconController;

  late Animation<double> _rotationAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _iconScaleAnimation;

  bool _wasLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    // Loading rotation animation
    _loadingController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    // Pulse animation for emphasis
    _pulseController = AnimationController(
      duration: AppAnimations.slowDuration,
      vsync: this,
    );

    // Icon animation
    _iconController = AnimationController(
      duration: AppAnimations.normalDuration,
      vsync: this,
    );

    _rotationAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _loadingController, curve: Curves.linear),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _iconScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _iconController,
        curve: AppAnimations.bounceCurve,
      ),
    );

    // Start icon animation
    _iconController.forward();
  }

  @override
  void didUpdateWidget(AnimatedRetryButton oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isLoading != oldWidget.isLoading) {
      if (widget.isLoading) {
        _loadingController.repeat();
        _pulseController.stop();
      } else {
        _loadingController.stop();
        if (_wasLoading) {
          // Success pulse when loading completes
          _pulseController.forward().then((_) {
            _pulseController.reverse();
          });
        }
      }
      _wasLoading = widget.isLoading;
    }
  }

  @override
  void dispose() {
    _loadingController.dispose();
    _pulseController.dispose();
    _iconController.dispose();
    super.dispose();
  }

  Future<void> _handlePress() async {
    if (widget.isLoading || widget.onPressed == null) return;

    // Trigger haptic feedback
    await MicroAnimations.triggerHapticFeedback(HapticFeedbackType.medium);

    // Brief scale animation
    await _iconController.reverse();
    await _iconController.forward();

    widget.onPressed!();
  }

  Color get _backgroundColor {
    return Theme.of(context).colorScheme.surface;
  }

  Color get _foregroundColor {
    if (widget.foregroundColor != null) return widget.foregroundColor!;

    switch (widget.style) {
      case RetryButtonStyle.filled:
        return Colors.white;
      case RetryButtonStyle.outlined:
      case RetryButtonStyle.text:
        return const Color(0xFFFF7A00);
    }
  }

  BorderSide? get _borderSide {
    switch (widget.style) {
      case RetryButtonStyle.filled:
      case RetryButtonStyle.text:
        return null;
      case RetryButtonStyle.outlined:
        return BorderSide(
          color: widget.isLoading
              ? _foregroundColor.withValues(alpha: 0.5)
              : _foregroundColor,
          width: 1.5,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MicroAnimations.bounceOnTap(
      onTap: _handlePress,
      enableHapticFeedback: false, // We handle haptic feedback manually
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulseController, _iconController]),
        builder: (context, child) {
          return Transform.scale(
            scale: _pulseAnimation.value * _iconScaleAnimation.value,
            child: AnimatedContainer(
              duration: AppAnimations.fastDuration,
              width: widget.width,
              height: widget.height ?? 48,
              padding:
                  widget.padding ??
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: widget.isLoading
                    ? _backgroundColor.withValues(alpha: 0.7)
                    : _backgroundColor,
                borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
                border: _borderSide != null
                    ? Border.fromBorderSide(_borderSide!)
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Loading indicator or icon
                  if (widget.isLoading)
                    AnimatedBuilder(
                      animation: _rotationAnimation,
                      builder: (context, child) {
                        return Transform.rotate(
                          angle: _rotationAnimation.value * 2 * 3.14159,
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _foregroundColor,
                              ),
                            ),
                          ),
                        );
                      },
                    )
                  else if (widget.icon != null) ...[
                    Icon(widget.icon, color: _foregroundColor, size: 16),
                    const SizedBox(width: 8),
                  ],

                  // Button text
                  if (!widget.isLoading ||
                      widget.style != RetryButtonStyle.filled)
                    AnimatedDefaultTextStyle(
                      duration: AppAnimations.fastDuration,
                      style: TextStyle(
                        color: widget.isLoading
                            ? _foregroundColor.withValues(alpha: 0.7)
                            : _foregroundColor,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                      child: Text(widget.text),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Different styles for the retry button
enum RetryButtonStyle { filled, outlined, text }
