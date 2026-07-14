import 'package:flutter/material.dart';
import '../animations/app_animations.dart';
import 'animated_error_display.dart';
import 'animated_retry_button.dart';

/// Fallback UI component for graceful error handling
class FallbackUI extends StatefulWidget {
  final String? title;
  final String message;
  final IconData? icon;
  final VoidCallback? onRetry;
  final Widget? fallbackWidget;
  final bool showRetryButton;
  final FallbackUIType type;

  const FallbackUI({
    super.key,
    this.title,
    required this.message,
    this.icon,
    this.onRetry,
    this.fallbackWidget,
    this.showRetryButton = true,
    this.type = FallbackUIType.error,
  });

  @override
  State<FallbackUI> createState() => _FallbackUIState();
}

class _FallbackUIState extends State<FallbackUI>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _controller.forward();
  }

  void _initializeAnimations() {
    _controller = AnimationController(
      duration: AppAnimations.normalDuration,
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: AppAnimations.defaultCurve),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _controller,
            curve: AppAnimations.defaultCurve,
          ),
        );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color get _iconColor {
    switch (widget.type) {
      case FallbackUIType.error:
        return const Color(0xFFEF4444);
      case FallbackUIType.network:
        return const Color(0xFF8B5CF6);
      case FallbackUIType.empty:
        return const Color(0xFF6B7280);
      case FallbackUIType.maintenance:
        return const Color(0xFFF59E0B);
    }
  }

  IconData get _defaultIcon {
    if (widget.icon != null) return widget.icon!;

    switch (widget.type) {
      case FallbackUIType.error:
        return Icons.error_outline;
      case FallbackUIType.network:
        return Icons.cloud_off_outlined;
      case FallbackUIType.empty:
        return Icons.inbox_outlined;
      case FallbackUIType.maintenance:
        return Icons.build_outlined;
    }
  }

  String get _defaultTitle {
    if (widget.title != null) return widget.title!;

    switch (widget.type) {
      case FallbackUIType.error:
        return 'Something went wrong';
      case FallbackUIType.network:
        return 'Connection problem';
      case FallbackUIType.empty:
        return 'Nothing here';
      case FallbackUIType.maintenance:
        return 'Under maintenance';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.fallbackWidget != null) {
      return AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: widget.fallbackWidget!,
            ),
          );
        },
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Icon
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: _iconColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(_defaultIcon, size: 48, color: _iconColor),
                    ),

                    const SizedBox(height: 24),

                    // Title
                    Text(
                      _defaultTitle,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1F2937),
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 12),

                    // Message
                    Text(
                      widget.message,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF6B7280),
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    // Retry Button
                    if (widget.showRetryButton && widget.onRetry != null) ...[
                      const SizedBox(height: 32),
                      AnimatedRetryButton(
                        onPressed: widget.onRetry,
                        text: 'Try Again',
                        backgroundColor: _iconColor,
                        foregroundColor: Colors.white,
                        style: RetryButtonStyle.filled,
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
}

/// Compact fallback UI for smaller spaces
class CompactFallbackUI extends StatelessWidget {
  final String message;
  final IconData? icon;
  final VoidCallback? onRetry;
  final FallbackUIType type;

  const CompactFallbackUI({
    super.key,
    required this.message,
    this.icon,
    this.onRetry,
    this.type = FallbackUIType.error,
  });

  Color get _iconColor {
    switch (type) {
      case FallbackUIType.error:
        return const Color(0xFFEF4444);
      case FallbackUIType.network:
        return const Color(0xFF8B5CF6);
      case FallbackUIType.empty:
        return const Color(0xFF6B7280);
      case FallbackUIType.maintenance:
        return const Color(0xFFF59E0B);
    }
  }

  IconData get _defaultIcon {
    if (icon != null) return icon!;

    switch (type) {
      case FallbackUIType.error:
        return Icons.error_outline;
      case FallbackUIType.network:
        return Icons.cloud_off_outlined;
      case FallbackUIType.empty:
        return Icons.inbox_outlined;
      case FallbackUIType.maintenance:
        return Icons.build_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(_defaultIcon, size: 32, color: _iconColor),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              fontSize: 14,
              color: _iconColor,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            AnimatedRetryButton(
              onPressed: onRetry,
              text: 'Retry',
              backgroundColor: _iconColor,
              foregroundColor: Colors.white,
              style: RetryButtonStyle.filled,
              height: 36,
            ),
          ],
        ],
      ),
    );
  }
}

/// Network error recovery widget with animated transitions
class NetworkErrorRecovery extends StatefulWidget {
  final String? message;
  final VoidCallback? onRetry;
  final VoidCallback? onOfflineMode;
  final bool showOfflineOption;

  const NetworkErrorRecovery({
    super.key,
    this.message,
    this.onRetry,
    this.onOfflineMode,
    this.showOfflineOption = true,
  });

  @override
  State<NetworkErrorRecovery> createState() => _NetworkErrorRecoveryState();
}

class _NetworkErrorRecoveryState extends State<NetworkErrorRecovery>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedErrorDisplay(
      title: 'Network Error',
      message:
          widget.message ??
          'Unable to connect to the server. Please check your internet connection.',
      type: ErrorDisplayType.network,
      onRetry: widget.onRetry,
      showRetryButton: widget.onRetry != null,
      showDismissButton: false,
    );
  }
}

/// Types of fallback UI
enum FallbackUIType { error, network, empty, maintenance }
