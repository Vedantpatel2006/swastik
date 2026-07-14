import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';
import 'animations/app_animations.dart';

/// An animated button widget that provides scale animation and haptic feedback
class AnimatedButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final Duration animationDuration;
  final double scaleValue;
  final bool enableHapticFeedback;
  final Color? backgroundColor;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final BoxBorder? border;
  final List<BoxShadow>? boxShadow;

  const AnimatedButton({
    super.key,
    required this.child,
    this.onPressed,
    this.animationDuration = AppAnimations.fastDuration,
    this.scaleValue = AppAnimations.scaleAnimationValue,
    this.enableHapticFeedback = true,
    this.backgroundColor,
    this.padding,
    this.borderRadius,
    this.border,
    this.boxShadow,
  });

  @override
  State<AnimatedButton> createState() => _AnimatedButtonState();
}

class _AnimatedButtonState extends State<AnimatedButton>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: widget.scaleValue).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: AppAnimations.interactionCurve,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleTapDown(TapDownDetails details) async {
    if (widget.onPressed != null) {
      await _animationController.forward();
      if (widget.enableHapticFeedback) {
        _triggerHapticFeedback();
      }
    }
  }

  Future<void> _handleTapUp(TapUpDetails details) async {
    if (widget.onPressed != null) {
      await _animationController.reverse();
    }
  }

  Future<void> _handleTapCancel() async {
    if (widget.onPressed != null) {
      await _animationController.reverse();
    }
  }

  Future<void> _triggerHapticFeedback() async {
    final hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator == true) {
      Vibration.vibrate(duration: 30);
    } else {
      HapticFeedback.lightImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: widget.onPressed,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(scale: _scaleAnimation.value, child: child);
        },
        child: Container(
          padding: widget.padding,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: widget.borderRadius,
            border: widget.border,
            boxShadow: widget.boxShadow,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

/// An animated card widget that provides scale animation and haptic feedback
class AnimatedCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Duration animationDuration;
  final double scaleValue;
  final bool enableHapticFeedback;
  final Color? color;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final List<BoxShadow>? boxShadow;
  final double? elevation;

  const AnimatedCard({
    super.key,
    required this.child,
    this.onTap,
    this.animationDuration = AppAnimations.fastDuration,
    this.scaleValue = 0.98,
    this.enableHapticFeedback = true,
    this.color,
    this.margin,
    this.padding,
    this.borderRadius,
    this.boxShadow,
    this.elevation,
  });

  @override
  State<AnimatedCard> createState() => _AnimatedCardState();
}

class _AnimatedCardState extends State<AnimatedCard>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: widget.scaleValue).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: AppAnimations.interactionCurve,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleTapDown(TapDownDetails details) async {
    if (widget.onTap != null) {
      await _animationController.forward();
      if (widget.enableHapticFeedback) {
        _triggerHapticFeedback();
      }
    }
  }

  Future<void> _handleTapUp(TapUpDetails details) async {
    if (widget.onTap != null) {
      await _animationController.reverse();
    }
  }

  Future<void> _handleTapCancel() async {
    if (widget.onTap != null) {
      await _animationController.reverse();
    }
  }

  Future<void> _triggerHapticFeedback() async {
    final hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator == true) {
      Vibration.vibrate(duration: 50);
    } else {
      HapticFeedback.selectionClick();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(scale: _scaleAnimation.value, child: child);
        },
        child: Container(
          margin: widget.margin,
          child: Card(
            color: widget.color,
            elevation: widget.elevation,
            shape: widget.borderRadius != null
                ? RoundedRectangleBorder(borderRadius: widget.borderRadius!)
                : null,
            child: Container(
              padding: widget.padding,
              decoration: widget.boxShadow != null
                  ? BoxDecoration(
                      borderRadius: widget.borderRadius,
                      boxShadow: widget.boxShadow,
                    )
                  : null,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
