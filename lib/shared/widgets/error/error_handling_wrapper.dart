import 'package:flutter/material.dart';
import 'animated_error_display.dart';

/// A widget that wraps content and provides error handling capabilities
class ErrorHandlingWrapper extends StatelessWidget {
  final Widget child;
  final VoidCallback? onRetry;
  final bool handleNetworkErrors;
  final bool handleLocationErrors;
  final bool handleAuthErrors;
  final bool handleDataErrors;
  final bool showFullScreenError;
  final ErrorHandlingStrategy strategy;

  const ErrorHandlingWrapper({
    super.key,
    required this.child,
    this.onRetry,
    this.handleNetworkErrors = true,
    this.handleLocationErrors = true,
    this.handleAuthErrors = true,
    this.handleDataErrors = true,
    this.showFullScreenError = false,
    this.strategy = ErrorHandlingStrategy.overlay,
  });

  @override
  Widget build(BuildContext context) {
    // For now, just return the child widget
    // This wrapper can be enhanced later when error tracking service is implemented
    return child;
  }

  /// Static method to wrap a widget with error handling
  static Widget wrap({
    required Widget child,
    VoidCallback? onRetry,
    ErrorHandlingStrategy strategy = ErrorHandlingStrategy.overlay,
  }) {
    return ErrorHandlingWrapper(
      onRetry: onRetry,
      strategy: strategy,
      child: child,
    );
  }
}

/// Optimized error display widget
class ErrorDisplayWidget extends StatelessWidget {
  final String message;
  final String? title;
  final ErrorDisplayType type;
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;

  const ErrorDisplayWidget({
    super.key,
    required this.message,
    this.title,
    this.type = ErrorDisplayType.error,
    this.onRetry,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedErrorDisplay(
      title: title,
      message: message,
      type: type,
      onRetry: onRetry,
      onDismiss: onDismiss,
      showDismissButton: onDismiss != null,
    );
  }
}

/// Optimized full screen error widget
class FullScreenErrorWidget extends StatelessWidget {
  final String message;
  final String? title;
  final ErrorDisplayType type;
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;

  const FullScreenErrorWidget({
    super.key,
    required this.message,
    this.title,
    this.type = ErrorDisplayType.error,
    this.onRetry,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: ErrorDisplayWidget(
          message: message,
          title: title,
          type: type,
          onRetry: onRetry,
          onDismiss: onDismiss,
        ),
      ),
    );
  }
}

/// Optimized banner error widget
class BannerErrorWidget extends StatelessWidget {
  final String message;
  final Color? backgroundColor;
  final VoidCallback? onDismiss;

  const BannerErrorWidget({
    super.key,
    required this.message,
    this.backgroundColor,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: backgroundColor ?? const Color(0xFFEF4444),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
          if (onDismiss != null)
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 18),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: onDismiss,
            ),
        ],
      ),
    );
  }
}

/// Strategy for how to display errors
enum ErrorHandlingStrategy {
  /// Replace the content with the error
  replace,

  /// Show error as an overlay on top of content
  overlay,

  /// Show error as a banner at the top
  banner,
}
