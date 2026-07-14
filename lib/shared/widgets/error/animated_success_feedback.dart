import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Haptic feedback types
enum HapticFeedbackType { light, medium, heavy, selection }

/// Animated success feedback widget for completed operations
class AnimatedSuccessFeedback extends StatefulWidget {
  final String? title;
  final String message;
  final IconData? icon;
  final Color? iconColor;
  final Color? backgroundColor;
  final VoidCallback? onDismiss;
  final Duration? autoHideDuration;
  final bool showCheckmark;
  final String type;

  const AnimatedSuccessFeedback({
    super.key,
    this.title,
    required this.message,
    this.icon,
    this.iconColor,
    this.backgroundColor,
    this.onDismiss,
    this.autoHideDuration,
    this.showCheckmark = true,
    this.type = 'success',
  });

  @override
  State<AnimatedSuccessFeedback> createState() =>
      _AnimatedSuccessFeedbackState();
}

class _AnimatedSuccessFeedbackState extends State<AnimatedSuccessFeedback>
    with TickerProviderStateMixin {
  late AnimationController _entryController;
  late AnimationController _checkmarkController;
  late AnimationController _pulseController;
  late AnimationController _exitController;

  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _checkmarkAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startEntryAnimation();
    _setupAutoHide();
  }

  void _initializeAnimations() {
    // Entry animation controller
    _entryController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Checkmark animation controller
    _checkmarkController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // Pulse animation controller
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Exit animation controller
    _exitController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // Entry animations
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.elasticOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeInOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, -0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _entryController, curve: Curves.easeInOut),
        );

    // Checkmark animation
    _checkmarkAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _checkmarkController, curve: Curves.elasticOut),
    );

    // Pulse animation
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> _startEntryAnimation() async {
    // Trigger haptic feedback
    await HapticFeedback.mediumImpact();

    // Start entry animation
    _entryController.forward();

    // Delay checkmark animation
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted && widget.showCheckmark) {
      _checkmarkController.forward();
    }

    // Start subtle pulse
    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) {
      _pulseController.repeat(reverse: true);
    }
  }

  void _setupAutoHide() {
    if (widget.autoHideDuration != null) {
      Future.delayed(widget.autoHideDuration!, () {
        if (mounted) {
          _handleDismiss();
        }
      });
    }
  }

  Future<void> _handleDismiss() async {
    _pulseController.stop();
    await _exitController.forward();

    if (mounted && widget.onDismiss != null) {
      widget.onDismiss!();
    }
  }

  @override
  void dispose() {
    _entryController.dispose();
    _checkmarkController.dispose();
    _pulseController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  Color get _iconColor {
    if (widget.iconColor != null) return widget.iconColor!;

    switch (widget.type) {
      case 'success':
        return const Color(0xFF10B981);
      case 'info':
        return const Color(0xFFFF7A00);
      case 'warning':
        return const Color(0xFFF59E0B);
      case 'error':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF10B981);
    }
  }

  IconData get _defaultIcon {
    if (widget.icon != null) return widget.icon!;

    switch (widget.type) {
      case 'success':
        return Icons.check_circle;
      case 'info':
        return Icons.info;
      case 'warning':
        return Icons.warning_amber;
      case 'error':
        return Icons.error;
      default:
        return Icons.check_circle;
    }
  }

  Color get _backgroundColor {
    return Theme.of(context).colorScheme.surface;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _entryController,
        _pulseController,
        _exitController,
      ]),
      builder: (context, child) {
        return FadeTransition(
          opacity: _exitController.status == AnimationStatus.forward
              ? Tween<double>(begin: 1.0, end: 0.0).animate(_exitController)
              : _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Transform.scale(
              scale: _scaleAnimation.value * _pulseAnimation.value,
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: _iconColor.withValues(alpha: 0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Animated Icon with Checkmark
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // Background circle
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _backgroundColor,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _defaultIcon,
                            color: _iconColor,
                            size: 32,
                          ),
                        ),

                        // Animated checkmark overlay
                        if (widget.showCheckmark)
                          AnimatedBuilder(
                            animation: _checkmarkAnimation,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: _checkmarkAnimation.value,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: _iconColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
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

                    // Success Message
                    Text(
                      widget.message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF6B7280),
                        height: 1.5,
                      ),
                    ),

                    // Dismiss button (if no auto-hide)
                    if (widget.autoHideDuration == null &&
                        widget.onDismiss != null) ...[
                      const SizedBox(height: 20),
                      _bounceOnTap(
                        onTap: _handleDismiss,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: _iconColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'OK',
                            style: TextStyle(
                              color: _iconColor,
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _bounceOnTap({required VoidCallback onTap, required Widget child}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        await HapticFeedback.lightImpact();
        onTap();
      },
      child: child,
    );
  }
}

/// Compact success toast for quick feedback
class AnimatedSuccessToast extends StatefulWidget {
  final String message;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? textColor;
  final Duration duration;
  final VoidCallback? onDismiss;

  const AnimatedSuccessToast({
    super.key,
    required this.message,
    this.icon,
    this.backgroundColor,
    this.textColor,
    this.duration = const Duration(seconds: 3),
    this.onDismiss,
  });

  @override
  State<AnimatedSuccessToast> createState() => _AnimatedSuccessToastState();
}

class _AnimatedSuccessToastState extends State<AnimatedSuccessToast>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimation();
  }

  void _initializeAnimations() {
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  Future<void> _startAnimation() async {
    await HapticFeedback.lightImpact();
    _controller.forward();

    // Auto-hide after duration
    Future.delayed(widget.duration, () {
      if (mounted) {
        _handleDismiss();
      }
    });
  }

  Future<void> _handleDismiss() async {
    await _controller.reverse();
    if (mounted && widget.onDismiss != null) {
      widget.onDismiss!();
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
      animation: _controller,
      builder: (context, child) {
        return SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.icon ?? Icons.check_circle,
                    color: widget.textColor ?? Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      widget.message,
                      style: TextStyle(
                        color: widget.textColor ?? Colors.white,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Types of success feedback
enum SuccessFeedbackType { success, info, warning }
