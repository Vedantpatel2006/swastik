import 'package:flutter/material.dart';
import '../../services/connectivity_service.dart';
import '../../utils/error_handling_utils.dart';
import 'animated_error_display.dart' as widgets;
import 'fallback_ui.dart';

/// Specialized error handler for network-related errors
class NetworkErrorHandler {
  static final ConnectivityService _connectivityService = ConnectivityService();

  /// Handle network errors with appropriate UI and retry logic
  static Future<void> handleNetworkError({
    required BuildContext context,
    required dynamic error,
    VoidCallback? onRetry,
    VoidCallback? onOfflineMode,
    bool showOfflineOption = true,
    String? operationName,
  }) async {
    final errorMessage = ErrorHandlingUtils.getUserFriendlyMessage(error);
    final connectivityStatus = await _connectivityService
        .getConnectivityStatus();

    await _showNetworkErrorDialog(
      context: context,
      error: error,
      message: errorMessage,
      connectivityStatus: connectivityStatus,
      onRetry: onRetry,
      onOfflineMode: onOfflineMode,
      showOfflineOption: showOfflineOption,
      operationName: operationName,
    );
  }

  /// Show network error dialog with connectivity-specific actions
  static Future<void> _showNetworkErrorDialog({
    required BuildContext context,
    required dynamic error,
    required String message,
    required ConnectivityStatus connectivityStatus,
    VoidCallback? onRetry,
    VoidCallback? onOfflineMode,
    bool showOfflineOption = true,
    String? operationName,
  }) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: NetworkErrorDialog(
          message: message,
          connectivityStatus: connectivityStatus,
          onRetry: onRetry,
          onOfflineMode: onOfflineMode,
          onDismiss: () => Navigator.of(context).pop(),
          showOfflineOption: showOfflineOption,
          operationName: operationName,
        ),
      ),
    );
  }

  /// Create inline network error widget
  static Widget buildInlineNetworkError({
    required String message,
    VoidCallback? onRetry,
    VoidCallback? onOfflineMode,
    bool showOfflineOption = true,
    bool isCompact = false,
  }) {
    if (isCompact) {
      return CompactFallbackUI(
        message: message,
        icon: Icons.cloud_off_outlined,
        type: FallbackUIType.network,
        onRetry: onRetry,
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.cloud_off_outlined,
                color: const Color(0xFF8B5CF6),
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Connection Problem',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF6B7280),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          _buildNetworkErrorActions(
            onRetry: onRetry,
            onOfflineMode: onOfflineMode,
            showOfflineOption: showOfflineOption,
          ),
        ],
      ),
    );
  }

  /// Build action buttons for network errors
  static Widget _buildNetworkErrorActions({
    VoidCallback? onRetry,
    VoidCallback? onOfflineMode,
    bool showOfflineOption = true,
  }) {
    final actions = <Widget>[];

    // Offline mode button
    if (showOfflineOption && onOfflineMode != null) {
      actions.add(
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onOfflineMode,
            icon: const Icon(Icons.offline_bolt_outlined, size: 16),
            label: const Text('Use Offline'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF6B7280),
              side: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
          ),
        ),
      );
    }

    // Add spacing
    if (actions.isNotEmpty && onRetry != null) {
      actions.add(const SizedBox(width: 8));
    }

    // Retry button
    if (onRetry != null) {
      actions.add(
        Expanded(
          child: ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_outlined, size: 16),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B5CF6),
              foregroundColor: Colors.white,
            ),
          ),
        ),
      );
    }

    if (actions.isEmpty) return const SizedBox.shrink();

    return Row(children: actions);
  }

  /// Execute network operation with comprehensive error handling
  static Future<T?> executeNetworkOperation<T>(
    Future<T> Function() operation, {
    required BuildContext context,
    String? operationName,
    bool showOfflineFallback = true,
    VoidCallback? onOfflineFallback,
    int maxRetries = 3,
  }) async {
    try {
      return await _connectivityService.retryWithConnectivity(
        operation,
        maxRetries: maxRetries,
      );
    } catch (e) {
      if (mounted(context)) {
        await handleNetworkError(
          context: context,
          error: e,
          operationName: operationName,
          onRetry: () {
            Navigator.of(context).pop();
            // Retry will be handled by the calling code
          },
          onOfflineMode: showOfflineFallback
              ? () {
                  Navigator.of(context).pop();
                  onOfflineFallback?.call();
                }
              : null,
          showOfflineOption: showOfflineFallback,
        );
      }
      return null;
    }
  }

  /// Check if context is still mounted
  static bool mounted(BuildContext context) {
    try {
      return context.mounted;
    } catch (e) {
      return false;
    }
  }

  /// Create network status indicator widget
  static Widget buildNetworkStatusIndicator({
    required ConnectivityStatus status,
    VoidCallback? onTap,
  }) {
    Color color;
    IconData icon;
    String message;

    switch (status) {
      case ConnectivityStatus.connected:
        color = const Color(0xFF10B981);
        icon = Icons.cloud_done_outlined;
        message = 'Connected';
        break;
      case ConnectivityStatus.disconnected:
        color = const Color(0xFFEF4444);
        icon = Icons.cloud_off_outlined;
        message = 'No connection';
        break;
      case ConnectivityStatus.unknown:
        color = const Color(0xFFF59E0B);
        icon = Icons.cloud_queue_outlined;
        message = 'Checking...';
        break;
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(
              message,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom dialog for network errors
class NetworkErrorDialog extends StatefulWidget {
  final String message;
  final ConnectivityStatus connectivityStatus;
  final VoidCallback? onRetry;
  final VoidCallback? onOfflineMode;
  final VoidCallback onDismiss;
  final bool showOfflineOption;
  final String? operationName;

  const NetworkErrorDialog({
    super.key,
    required this.message,
    required this.connectivityStatus,
    this.onRetry,
    this.onOfflineMode,
    required this.onDismiss,
    this.showOfflineOption = true,
    this.operationName,
  });

  @override
  State<NetworkErrorDialog> createState() => _NetworkErrorDialogState();
}

class _NetworkErrorDialogState extends State<NetworkErrorDialog> {
  @override
  Widget build(BuildContext context) {
    return widgets.AnimatedErrorDisplay(
      title: 'Connection Problem',
      message: widget.message,
      icon: Icons.cloud_off_outlined,
      type: widgets.ErrorDisplayType.network,
      showRetryButton: false,
      showDismissButton: false,
      onDismiss: widget.onDismiss,
      padding: const EdgeInsets.all(24),
    );
  }
}
