import 'package:flutter/material.dart';
import 'dart:async';
import '../../services/connectivity_service.dart';
import '../../services/service_container.dart';
import '../../services/interfaces/location_service_interface.dart';
import 'animated_error_display.dart' as widgets;
import 'animated_retry_button.dart';

/// Error categories for different types of errors
enum ErrorCategory {
  network,
  authentication,
  permission,
  validation,
  server,
  unknown,
  timeout,
  notFound,
  location,
  data,
  firebase,
  platform,
}

/// Error display types for different UI presentations
enum ErrorDisplayType {
  fullScreen,
  dialog,
  snackbar,
  inline,
  banner,
  network,
  warning,
  error,
  info,
}

/// Enhanced error recovery widget with comprehensive error handling
class EnhancedErrorRecovery extends StatefulWidget {
  final dynamic error;
  final String? operationName;
  final VoidCallback? onRetry;
  final VoidCallback? onOfflineMode;
  final VoidCallback? onManualLocation;
  final Widget? fallbackWidget;
  final bool showOfflineOption;
  final bool showManualLocationOption;
  final bool isCompact;
  final int maxRetries;

  const EnhancedErrorRecovery({
    super.key,
    required this.error,
    this.operationName,
    this.onRetry,
    this.onOfflineMode,
    this.onManualLocation,
    this.fallbackWidget,
    this.showOfflineOption = true,
    this.showManualLocationOption = true,
    this.isCompact = false,
    this.maxRetries = 3,
  });

  @override
  State<EnhancedErrorRecovery> createState() => _EnhancedErrorRecoveryState();
}

class _EnhancedErrorRecoveryState extends State<EnhancedErrorRecovery> {
  bool _isRetrying = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isCompact) {
      return _buildCompactErrorRecovery();
    }

    return _buildFullErrorRecovery();
  }

  Widget _buildCompactErrorRecovery() {
    final errorCategory = _categorizeError(widget.error);
    final errorMessage = _getUserFriendlyMessage(widget.error);

    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: _getErrorColor(errorCategory).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _getErrorColor(errorCategory).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _getErrorIcon(errorCategory),
            color: _getErrorColor(errorCategory),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getErrorTitle(errorCategory),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _getErrorColor(errorCategory),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  errorMessage,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _buildCompactActions(errorCategory),
        ],
      ),
    );
  }

  Widget _buildFullErrorRecovery() {
    final errorCategory = _categorizeError(widget.error);
    final errorMessage = _getUserFriendlyMessage(widget.error);

    return widgets.AnimatedErrorDisplay(
      title: _getErrorTitle(errorCategory),
      message: errorMessage,
      icon: _getErrorIcon(errorCategory),
      type: _convertErrorDisplayType(_getErrorDisplayType(widget.error)),
      showRetryButton: false,
      showDismissButton: false,
      padding: const EdgeInsets.all(24),
    );
  }

  Widget _buildCompactActions(ErrorCategory errorCategory) {
    final actions = <Widget>[];

    // Add specific actions based on error category
    switch (errorCategory) {
      case ErrorCategory.network:
        if (widget.showOfflineOption && widget.onOfflineMode != null) {
          actions.add(
            _buildCompactActionButton(
              'Offline',
              Icons.offline_bolt_outlined,
              widget.onOfflineMode!,
              isSecondary: true,
            ),
          );
        }
        break;
      case ErrorCategory.location:
        if (widget.showManualLocationOption &&
            widget.onManualLocation != null) {
          actions.add(
            _buildCompactActionButton(
              'Manual',
              Icons.edit_location_outlined,
              widget.onManualLocation!,
              isSecondary: true,
            ),
          );
        }
        break;
      default:
        break;
    }

    // Add retry button if available
    if (widget.onRetry != null) {
      if (actions.isNotEmpty) {
        actions.add(const SizedBox(width: 8));
      }
      actions.add(
        _buildCompactActionButton(
          'Retry',
          Icons.refresh_outlined,
          _handleRetry,
          isLoading: _isRetrying,
        ),
      );
    }

    return Row(children: actions);
  }

  Widget _buildCompactActionButton(
    String text,
    IconData icon,
    VoidCallback onPressed, {
    bool isSecondary = false,
    bool isLoading = false,
  }) {
    return AnimatedRetryButton(
      onPressed: isLoading ? null : onPressed,
      text: text,
      icon: icon,
      isLoading: isLoading,
      style: isSecondary ? RetryButtonStyle.outlined : RetryButtonStyle.filled,
      height: 32,
      backgroundColor: isSecondary ? Colors.transparent : null,
      foregroundColor: isSecondary ? const Color(0xFF6B7280) : null,
    );
  }

  Future<void> _handleRetry() async {
    if (_isRetrying || widget.onRetry == null) return;

    setState(() {
      _isRetrying = true;
    });

    try {
      // Add delay for better UX
      await Future.delayed(const Duration(milliseconds: 500));

      widget.onRetry!();
    } finally {
      if (mounted) {
        setState(() {
          _isRetrying = false;
        });
      }
    }
  }

  String _getErrorTitle(ErrorCategory category) {
    switch (category) {
      case ErrorCategory.network:
        return 'Connection Problem';
      case ErrorCategory.location:
        return 'Location Access Required';
      case ErrorCategory.permission:
        return 'Permission Required';
      case ErrorCategory.firebase:
        return 'Server Error';
      case ErrorCategory.data:
        return 'Data Error';
      case ErrorCategory.platform:
        return 'System Error';
      case ErrorCategory.unknown:
        return 'Unexpected Error';
      case ErrorCategory.authentication:
        return 'Authentication Required';
      case ErrorCategory.validation:
        return 'Validation Error';
      case ErrorCategory.server:
        return 'Server Error';
      case ErrorCategory.timeout:
        return 'Request Timeout';
      case ErrorCategory.notFound:
        return 'Not Found';
    }
  }

  IconData _getErrorIcon(ErrorCategory category) {
    switch (category) {
      case ErrorCategory.network:
        return Icons.cloud_off_outlined;
      case ErrorCategory.location:
        return Icons.location_off_outlined;
      case ErrorCategory.permission:
        return Icons.security_outlined;
      case ErrorCategory.firebase:
        return Icons.error_outlined;
      case ErrorCategory.data:
        return Icons.data_usage_outlined;
      case ErrorCategory.platform:
        return Icons.error_outline;
      case ErrorCategory.unknown:
        return Icons.help_outline;
      case ErrorCategory.authentication:
        return Icons.lock_outline;
      case ErrorCategory.validation:
        return Icons.warning_outlined;
      case ErrorCategory.server:
        return Icons.dns_outlined;
      case ErrorCategory.timeout:
        return Icons.timer_outlined;
      case ErrorCategory.notFound:
        return Icons.search_off_outlined;
    }
  }

  /// Categorize error based on its type
  ErrorCategory _categorizeError(dynamic error) {
    if (error.toString().toLowerCase().contains('network') ||
        error.toString().toLowerCase().contains('connection')) {
      return ErrorCategory.network;
    } else if (error.toString().toLowerCase().contains('auth') ||
        error.toString().toLowerCase().contains('permission')) {
      return ErrorCategory.authentication;
    } else if (error.toString().toLowerCase().contains('timeout')) {
      return ErrorCategory.timeout;
    } else if (error.toString().toLowerCase().contains('not found') ||
        error.toString().toLowerCase().contains('404')) {
      return ErrorCategory.notFound;
    } else if (error.toString().toLowerCase().contains('server') ||
        error.toString().toLowerCase().contains('500')) {
      return ErrorCategory.server;
    } else if (error.toString().toLowerCase().contains('validation')) {
      return ErrorCategory.validation;
    }
    return ErrorCategory.unknown;
  }

  /// Get user-friendly error message
  String _getUserFriendlyMessage(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    if (errorStr.contains('network') || errorStr.contains('connection')) {
      return 'Please check your internet connection and try again.';
    } else if (errorStr.contains('timeout')) {
      return 'The request timed out. Please try again.';
    } else if (errorStr.contains('not found') || errorStr.contains('404')) {
      return 'The requested resource was not found.';
    } else if (errorStr.contains('server') || errorStr.contains('500')) {
      return 'Server error occurred. Please try again later.';
    } else if (errorStr.contains('auth') || errorStr.contains('permission')) {
      return 'Authentication failed. Please log in again.';
    } else if (errorStr.contains('validation')) {
      return 'Please check your input and try again.';
    }
    return 'An unexpected error occurred. Please try again.';
  }

  /// Get error display type
  ErrorDisplayType _getErrorDisplayType(dynamic error) {
    final category = _categorizeError(error);
    switch (category) {
      case ErrorCategory.network:
        return ErrorDisplayType.network;
      case ErrorCategory.authentication:
      case ErrorCategory.permission:
        return ErrorDisplayType.warning;
      case ErrorCategory.server:
      case ErrorCategory.unknown:
        return ErrorDisplayType.error;
      default:
        return ErrorDisplayType.error;
    }
  }

  /// Convert ErrorHandlingUtils ErrorDisplayType to widgets ErrorDisplayType
  widgets.ErrorDisplayType _convertErrorDisplayType(ErrorDisplayType type) {
    switch (type) {
      case ErrorDisplayType.error:
        return widgets.ErrorDisplayType.error;
      case ErrorDisplayType.warning:
        return widgets.ErrorDisplayType.warning;
      case ErrorDisplayType.info:
        return widgets.ErrorDisplayType.info;
      case ErrorDisplayType.network:
        return widgets.ErrorDisplayType.network;
      case ErrorDisplayType.fullScreen:
      case ErrorDisplayType.dialog:
      case ErrorDisplayType.snackbar:
      case ErrorDisplayType.inline:
      case ErrorDisplayType.banner:
        return widgets.ErrorDisplayType.error;
    }
  }

  Color _getErrorColor(ErrorCategory category) {
    switch (category) {
      case ErrorCategory.network:
        return const Color(0xFF8B5CF6);
      case ErrorCategory.location:
        return const Color(0xFFF59E0B);
      case ErrorCategory.permission:
        return const Color(0xFFF59E0B);
      case ErrorCategory.firebase:
        return const Color(0xFFEF4444);
      case ErrorCategory.data:
        return const Color(0xFFEF4444);
      case ErrorCategory.platform:
        return const Color(0xFFEF4444);
      case ErrorCategory.unknown:
        return const Color(0xFF6B7280);
      case ErrorCategory.authentication:
        return const Color(0xFFF59E0B);
      case ErrorCategory.validation:
        return const Color(0xFFF59E0B);
      case ErrorCategory.server:
        return const Color(0xFFEF4444);
      case ErrorCategory.timeout:
        return const Color(0xFFF59E0B);
      case ErrorCategory.notFound:
        return const Color(0xFF6B7280);
    }
  }
}

/// Inline error recovery widget for forms and lists
class InlineErrorRecovery extends StatelessWidget {
  final dynamic error;
  final String? operationName;
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;
  final bool showDismissButton;

  const InlineErrorRecovery({
    super.key,
    required this.error,
    this.operationName,
    this.onRetry,
    this.onDismiss,
    this.showDismissButton = false,
  });

  @override
  Widget build(BuildContext context) {
    return EnhancedErrorRecovery(
      error: error,
      operationName: operationName,
      onRetry: onRetry,
      isCompact: true,
      showOfflineOption: false,
      showManualLocationOption: false,
    );
  }
}

/// Error recovery widget with system status indicators
class ErrorRecoveryWithStatus extends StatefulWidget {
  final dynamic error;
  final String? operationName;
  final VoidCallback? onRetry;
  final VoidCallback? onOfflineMode;
  final VoidCallback? onManualLocation;

  const ErrorRecoveryWithStatus({
    super.key,
    required this.error,
    this.operationName,
    this.onRetry,
    this.onOfflineMode,
    this.onManualLocation,
  });

  @override
  State<ErrorRecoveryWithStatus> createState() =>
      _ErrorRecoveryWithStatusState();
}

class _ErrorRecoveryWithStatusState extends State<ErrorRecoveryWithStatus> {
  ConnectivityStatus _connectivityStatus = ConnectivityStatus.unknown;
  LocationPermissionStatus _locationPermissionStatus =
      LocationPermissionStatus.notDetermined;
  StreamSubscription<ConnectivityStatus>? _statusSubscription;

  @override
  void initState() {
    super.initState();
    _monitorSystemStatus();
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    super.dispose();
  }

  void _monitorSystemStatus() {
    // Monitor connectivity status
    _statusSubscription = ConnectivityService().statusStream.listen((status) {
      if (mounted) {
        setState(() {
          _connectivityStatus = status;
        });
      }
    });

    // Check initial status
    _updateSystemStatus();
  }

  Future<void> _updateSystemStatus() async {
    try {
      final connectivityService = ConnectivityService();
      final locationService = services.locationService;

      final connectivityStatus = await connectivityService
          .getConnectivityStatus();
      final locationPermissionStatus = await locationService
          .getLocationPermissionStatus();

      if (mounted) {
        setState(() {
          _connectivityStatus = connectivityStatus;
          _locationPermissionStatus = locationPermissionStatus;
        });
      }
    } catch (e) {
      // Ignore errors during status check
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // System status indicators
        _buildSystemStatusIndicators(),
        const SizedBox(height: 16),

        // Error recovery widget
        EnhancedErrorRecovery(
          error: widget.error,
          operationName: widget.operationName,
          onRetry: widget.onRetry,
          onOfflineMode: widget.onOfflineMode,
          onManualLocation: widget.onManualLocation,
        ),
      ],
    );
  }

  Widget _buildSystemStatusIndicators() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildStatusIndicator(
          'Network',
          _getConnectivityIcon(_connectivityStatus),
          _getConnectivityColor(_connectivityStatus),
        ),
        const SizedBox(width: 16),
        _buildStatusIndicator(
          'Location',
          _getLocationIcon(_locationPermissionStatus),
          _getLocationColor(_locationPermissionStatus),
        ),
      ],
    );
  }

  Widget _buildStatusIndicator(String label, IconData icon, Color color) {
    return Container(
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
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getConnectivityIcon(ConnectivityStatus status) {
    switch (status) {
      case ConnectivityStatus.connected:
        return Icons.cloud_done_outlined;
      case ConnectivityStatus.disconnected:
        return Icons.cloud_off_outlined;
      case ConnectivityStatus.unknown:
        return Icons.cloud_queue_outlined;
    }
  }

  Color _getConnectivityColor(ConnectivityStatus status) {
    switch (status) {
      case ConnectivityStatus.connected:
        return const Color(0xFF10B981);
      case ConnectivityStatus.disconnected:
        return const Color(0xFFEF4444);
      case ConnectivityStatus.unknown:
        return const Color(0xFFF59E0B);
    }
  }

  IconData _getLocationIcon(LocationPermissionStatus status) {
    switch (status) {
      case LocationPermissionStatus.granted:
        return Icons.location_on_outlined;
      case LocationPermissionStatus.denied:
      case LocationPermissionStatus.deniedForever:
        return Icons.location_off_outlined;
      case LocationPermissionStatus.notDetermined:
        return Icons.location_searching_outlined;
    }
  }

  Color _getLocationColor(LocationPermissionStatus status) {
    switch (status) {
      case LocationPermissionStatus.granted:
        return const Color(0xFF10B981);
      case LocationPermissionStatus.denied:
      case LocationPermissionStatus.deniedForever:
        return const Color(0xFFEF4444);
      case LocationPermissionStatus.notDetermined:
        return const Color(0xFFF59E0B);
    }
  }
}
