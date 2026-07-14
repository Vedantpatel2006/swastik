import 'package:flutter/material.dart';
import '../animations/app_animations.dart';
import '../animations/micro_animations.dart';

/// Animated error display widget with smooth transitions and retry functionality
class AnimatedErrorDisplay extends StatefulWidget {
  final String? title;
  final String message;
  final IconData? icon;
  final Color? iconColor;
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;
  final String? retryText;
  final String? dismissText;
  final bool showRetryButton;
  final bool showDismissButton;
  final EdgeInsets? padding;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;
  final ErrorDisplayType type;

  const AnimatedErrorDisplay({
    super.key,
    this.title,
    required this.message,
    this.icon,
    this.iconColor,
    this.onRetry,
    this.onDismiss,
    this.retryText,
    this.dismissText,
    this.showRetryButton = true,
    this.showDismissButton = false,
    this.padding,
    this.borderRadius,
    this.backgroundColor,
    this.type = ErrorDisplayType.error,
  });

  @override
  State<AnimatedErrorDisplay> createState() => _AnimatedErrorDisplayState();
}

class _AnimatedErrorDisplayState extends State<AnimatedErrorDisplay>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late AnimationController _iconController;

  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _iconScaleAnimation;
  late Animation<double> _iconRotationAnimation;

  bool _isRetrying = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startEntryAnimation();
  }

  void _initializeAnimations() {
    // Slide animation controller
    _slideController = AnimationController(
      duration: AppAnimations.normalDuration,
      vsync: this,
    );

    // Fade animation controller
    _fadeController = AnimationController(
      duration: AppAnimations.fastDuration,
      vsync: this,
    );

    // Icon animation controller
    _iconController = AnimationController(
      duration: AppAnimations.slowDuration,
      vsync: this,
    );

    // Create animations
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _slideController,
            curve: AppAnimations.errorCurve,
          ),
        );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: AppAnimations.defaultCurve,
      ),
    );

    _iconScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _iconController,
        curve: AppAnimations.bounceCurve,
      ),
    );

    _iconRotationAnimation = Tween<double>(begin: -0.1, end: 0.0).animate(
      CurvedAnimation(
        parent: _iconController,
        curve: AppAnimations.defaultCurve,
      ),
    );
  }

  Future<void> _startEntryAnimation() async {
    await Future.delayed(const Duration(milliseconds: 50));
    if (mounted) {
      _fadeController.forward();
      await Future.delayed(const Duration(milliseconds: 100));
      if (mounted) {
        _slideController.forward();
        await Future.delayed(const Duration(milliseconds: 200));
        if (mounted) {
          _iconController.forward();
        }
      }
    }
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    _iconController.dispose();
    super.dispose();
  }

  Future<void> _handleRetry() async {
    if (_isRetrying || widget.onRetry == null) return;

    setState(() {
      _isRetrying = true;
    });

    // Trigger haptic feedback
    await MicroAnimations.triggerHapticFeedback(HapticFeedbackType.light);

    try {
      // Add a small delay for better UX
      await Future.delayed(const Duration(milliseconds: 300));
      widget.onRetry!();
    } finally {
      if (mounted) {
        setState(() {
          _isRetrying = false;
        });
      }
    }
  }

  Future<void> _handleDismiss() async {
    if (widget.onDismiss == null) return;

    // Animate out
    await _fadeController.reverse();
    await _slideController.reverse();

    if (mounted) {
      widget.onDismiss!();
    }
  }

  Color get _iconColor {
    if (widget.iconColor != null) return widget.iconColor!;

    switch (widget.type) {
      case ErrorDisplayType.error:
        return const Color(0xFFEF4444);
      case ErrorDisplayType.warning:
        return const Color(0xFFF59E0B);
      case ErrorDisplayType.info:
        return const Color(0xFFFF7A00);
      case ErrorDisplayType.network:
        return const Color(0xFF8B5CF6);
    }
  }

  IconData get _defaultIcon {
    if (widget.icon != null) return widget.icon!;

    switch (widget.type) {
      case ErrorDisplayType.error:
        return Icons.error_outline;
      case ErrorDisplayType.warning:
        return Icons.warning_amber_outlined;
      case ErrorDisplayType.info:
        return Icons.info_outline;
      case ErrorDisplayType.network:
        return Icons.cloud_off_outlined;
    }
  }

  Color get _backgroundColor {
    return Theme.of(context).colorScheme.surface;
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: widget.padding ?? const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: widget.borderRadius ?? BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animated Icon
              AnimatedBuilder(
                animation: _iconController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _iconScaleAnimation.value,
                    child: Transform.rotate(
                      angle: _iconRotationAnimation.value,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _backgroundColor,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(_defaultIcon, color: _iconColor, size: 32),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),

              // Title (if provided)
              if (widget.title != null) ...[
                Text(
                  widget.title!,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
              ],

              // Error Message
              Text(
                widget.message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B7280),
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 24),

              // Action Buttons
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    final buttons = <Widget>[];

    // Dismiss Button
    if (widget.showDismissButton && widget.onDismiss != null) {
      buttons.add(
        Expanded(
          child: MicroAnimations.bounceOnTap(
            onTap: _handleDismiss,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE5E7EB)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.dismissText ?? 'Dismiss',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Add spacing between buttons
    if (buttons.isNotEmpty &&
        widget.showRetryButton &&
        widget.onRetry != null) {
      buttons.add(const SizedBox(width: 12));
    }

    // Retry Button
    if (widget.showRetryButton && widget.onRetry != null) {
      buttons.add(
        Expanded(
          child: MicroAnimations.bounceOnTap(
            onTap: _isRetrying ? null : _handleRetry,
            child: AnimatedContainer(
              duration: AppAnimations.fastDuration,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: _isRetrying
                    ? _iconColor.withValues(alpha: 0.7)
                    : _iconColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: _isRetrying
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      widget.retryText ?? 'Retry',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
            ),
          ),
        ),
      );
    }

    if (buttons.isEmpty) return const SizedBox.shrink();

    return Row(children: buttons);
  }
}

/// Types of error displays with different styling
enum ErrorDisplayType { error, warning, info, network }
