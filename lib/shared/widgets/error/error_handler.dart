import 'package:flutter/material.dart';
import 'animated_error_display.dart';
import 'animated_retry_button.dart';
import 'animated_success_feedback.dart';

/// Centralized error handling utility with animated components
class ErrorHandler {
  /// Shows an animated error dialog
  static Future<void> showErrorDialog({
    required BuildContext context,
    String? title,
    required String message,
    VoidCallback? onRetry,
    VoidCallback? onDismiss,
    ErrorDisplayType type = ErrorDisplayType.error,
    bool barrierDismissible = true,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: AnimatedErrorDisplay(
          title: title,
          message: message,
          type: type,
          onRetry: onRetry,
          onDismiss: onDismiss ?? () => Navigator.of(context).pop(),
          showDismissButton: true,
        ),
      ),
    );
  }

  /// Shows an animated error bottom sheet
  static Future<void> showErrorBottomSheet({
    required BuildContext context,
    String? title,
    required String message,
    VoidCallback? onRetry,
    ErrorDisplayType type = ErrorDisplayType.error,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: AnimatedErrorDisplay(
          title: title,
          message: message,
          type: type,
          onRetry: onRetry,
          onDismiss: () => Navigator.of(context).pop(),
          showDismissButton: true,
        ),
      ),
    );
  }

  /// Shows a success feedback dialog
  static Future<void> showSuccessDialog({
    required BuildContext context,
    String? title,
    required String message,
    Duration? autoHideDuration = const Duration(seconds: 2),
    SuccessFeedbackType type = SuccessFeedbackType.success,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: AnimatedSuccessFeedback(
          title: title,
          message: message,
          type: type.toString(),
          autoHideDuration: autoHideDuration,
          onDismiss: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  /// Shows a success toast notification
  static void showSuccessToast({
    required BuildContext context,
    required String message,
    Duration duration = const Duration(seconds: 3),
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: 16,
        left: 0,
        right: 0,
        child: AnimatedSuccessToast(
          message: message,
          duration: duration,
          onDismiss: () => overlayEntry.remove(),
        ),
      ),
    );

    overlay.insert(overlayEntry);
  }

  /// Shows an error snackbar with retry option
  static void showErrorSnackBar({
    required BuildContext context,
    required String message,
    VoidCallback? onRetry,
    Duration duration = const Duration(seconds: 4),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFEF4444),
        duration: duration,
        action: onRetry != null
            ? SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: onRetry,
              )
            : null,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  /// Shows a success snackbar
  static void showSuccessSnackBar({
    required BuildContext context,
    required String message,
    Duration duration = const Duration(seconds: 3),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        duration: duration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  /// Creates an inline error widget for forms and lists
  static Widget buildInlineError({
    required String message,
    VoidCallback? onRetry,
    ErrorDisplayType type = ErrorDisplayType.error,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: _getErrorColor(type).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _getErrorColor(type).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(_getErrorIcon(type), color: _getErrorColor(type), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: _getErrorColor(type), fontSize: 14),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: 12),
            AnimatedRetryButton(
              onPressed: onRetry,
              text: 'Retry',
              style: RetryButtonStyle.text,
              backgroundColor: Colors.transparent,
              foregroundColor: _getErrorColor(type),
            ),
          ],
        ],
      ),
    );
  }

  /// Creates a loading state widget with error fallback
  static Widget buildLoadingWithError({
    required bool isLoading,
    required bool hasError,
    String? errorMessage,
    VoidCallback? onRetry,
    required Widget child,
    Widget? loadingWidget,
  }) {
    if (isLoading) {
      return loadingWidget ?? const Center(child: CircularProgressIndicator());
    }

    if (hasError) {
      return Center(
        child: AnimatedErrorDisplay(
          message: errorMessage ?? 'Something went wrong',
          onRetry: onRetry,
          showDismissButton: false,
        ),
      );
    }

    return child;
  }

  /// Helper method to get error color based on type
  static Color _getErrorColor(ErrorDisplayType type) {
    switch (type) {
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

  /// Helper method to get error icon based on type
  static IconData _getErrorIcon(ErrorDisplayType type) {
    switch (type) {
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
}

/// Extension methods for easier error handling
extension ErrorHandlerExtension on BuildContext {
  /// Show error dialog
  Future<void> showError({
    String? title,
    required String message,
    VoidCallback? onRetry,
    ErrorDisplayType type = ErrorDisplayType.error,
  }) {
    return ErrorHandler.showErrorDialog(
      context: this,
      title: title,
      message: message,
      onRetry: onRetry,
      type: type,
    );
  }

  /// Show success dialog
  Future<void> showSuccess({
    String? title,
    required String message,
    Duration? autoHideDuration = const Duration(seconds: 2),
  }) {
    return ErrorHandler.showSuccessDialog(
      context: this,
      title: title,
      message: message,
      autoHideDuration: autoHideDuration,
    );
  }

  /// Show error snackbar
  void showErrorSnackBar({required String message, VoidCallback? onRetry}) {
    ErrorHandler.showErrorSnackBar(
      context: this,
      message: message,
      onRetry: onRetry,
    );
  }

  /// Show success snackbar
  void showSuccessSnackBar({required String message}) {
    ErrorHandler.showSuccessSnackBar(context: this, message: message);
  }

  /// Show success toast
  void showSuccessToast({required String message}) {
    ErrorHandler.showSuccessToast(context: this, message: message);
  }
}
