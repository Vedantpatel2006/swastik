import 'package:flutter/material.dart';

import '../../services/location_service.dart';
import '../../services/service_container.dart';
import '../../services/interfaces/location_service_interface.dart';
import '../../utils/error_handling_utils.dart';
import 'animated_error_display.dart' as widgets;
import 'error_handler.dart';

/// Specialized error handler for location-related errors
class LocationErrorHandler {
  static LocationService get _locationService => services.locationService;

  /// Handle location permission errors with appropriate UI
  static Future<void> handleLocationPermissionError({
    required BuildContext context,
    required dynamic error,
    VoidCallback? onRetry,
    VoidCallback? onManualLocation,
    bool showManualLocationOption = true,
  }) async {
    final errorMessage = ErrorHandlingUtils.getUserFriendlyMessage(error);
    final category = ErrorHandlingUtils.categorizeError(error);

    if (category == ErrorCategory.location) {
      await _showLocationPermissionDialog(
        context: context,
        error: error,
        message: errorMessage,
        onRetry: onRetry,
        onManualLocation: onManualLocation,
        showManualLocationOption: showManualLocationOption,
      );
    } else {
      await ErrorHandler.showErrorDialog(
        context: context,
        title: 'Location Error',
        message: errorMessage,
        onRetry: onRetry,
        type: widgets.ErrorDisplayType.warning,
      );
    }
  }

  /// Show location permission dialog with specific actions
  static Future<void> _showLocationPermissionDialog({
    required BuildContext context,
    required dynamic error,
    required String message,
    VoidCallback? onRetry,
    VoidCallback? onManualLocation,
    bool showManualLocationOption = true,
  }) async {
    final permissionStatus = await _locationService
        .getLocationPermissionStatus();

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: LocationPermissionDialog(
          message: message,
          permissionStatus: permissionStatus,
          onRetry: onRetry,
          onManualLocation: onManualLocation,
          onDismiss: () => Navigator.of(context).pop(),
          showManualLocationOption: showManualLocationOption,
        ),
      ),
    );
  }

  /// Create inline location error widget
  static Widget buildInlineLocationError({
    required String message,
    VoidCallback? onRetry,
    VoidCallback? onManualLocation,
    VoidCallback? onOpenSettings,
    bool showManualLocationOption = true,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.location_off_outlined,
                color: const Color(0xFFF59E0B),
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Location Access Required',
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
          _buildLocationErrorActions(
            onRetry: onRetry,
            onManualLocation: onManualLocation,
            onOpenSettings: onOpenSettings,
            showManualLocationOption: showManualLocationOption,
          ),
        ],
      ),
    );
  }

  /// Build action buttons for location errors
  static Widget _buildLocationErrorActions({
    VoidCallback? onRetry,
    VoidCallback? onManualLocation,
    VoidCallback? onOpenSettings,
    bool showManualLocationOption = true,
  }) {
    final actions = <Widget>[];

    // Manual location button
    if (showManualLocationOption && onManualLocation != null) {
      actions.add(
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onManualLocation,
            icon: const Icon(Icons.edit_location_outlined, size: 16),
            label: const Text('Enter Location'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF6B7280),
              side: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
          ),
        ),
      );
    }

    // Add spacing
    if (actions.isNotEmpty && (onRetry != null || onOpenSettings != null)) {
      actions.add(const SizedBox(width: 8));
    }

    // Settings button for permanently denied permissions
    if (onOpenSettings != null) {
      actions.add(
        Expanded(
          child: ElevatedButton.icon(
            onPressed: onOpenSettings,
            icon: const Icon(Icons.settings_outlined, size: 16),
            label: const Text('Open Settings'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: Colors.white,
            ),
          ),
        ),
      );
    } else if (onRetry != null) {
      // Retry button for other permission issues
      actions.add(
        Expanded(
          child: ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_outlined, size: 16),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: Colors.white,
            ),
          ),
        ),
      );
    }

    if (actions.isEmpty) return const SizedBox.shrink();

    return Row(children: actions);
  }

  /// Execute location operation with comprehensive error handling
  static Future<T?> executeLocationOperation<T>(
    Future<T> Function() operation, {
    required BuildContext context,
    String? operationName,
    bool showManualLocationFallback = true,
    VoidCallback? onManualLocationFallback,
  }) async {
    try {
      return await ErrorHandlingUtils.executeWithRetry(
        operation,
        maxRetries: 3,
        delay: const Duration(seconds: 1),
      );
    } catch (e) {
      // Handle error by showing location permission dialog
      await handleLocationPermissionError(
        context: context,
        error: e,
        onRetry: () {
          Navigator.of(context).pop();
        },
        onManualLocation: showManualLocationFallback
            ? () {
                Navigator.of(context).pop();
                onManualLocationFallback?.call();
              }
            : null,
        showManualLocationOption: showManualLocationFallback,
      );
      return null;
    }
  }
}

/// Custom dialog for location permission errors
class LocationPermissionDialog extends StatefulWidget {
  final String message;
  final LocationPermissionStatus permissionStatus;
  final VoidCallback? onRetry;
  final VoidCallback? onManualLocation;
  final VoidCallback onDismiss;
  final bool showManualLocationOption;

  const LocationPermissionDialog({
    super.key,
    required this.message,
    required this.permissionStatus,
    this.onRetry,
    this.onManualLocation,
    required this.onDismiss,
    this.showManualLocationOption = true,
  });

  @override
  State<LocationPermissionDialog> createState() =>
      _LocationPermissionDialogState();
}

class _LocationPermissionDialogState extends State<LocationPermissionDialog> {
  @override
  Widget build(BuildContext context) {
    return widgets.AnimatedErrorDisplay(
      title: 'Location Access Required',
      message: widget.message,
      icon: Icons.location_off_outlined,
      type: widgets.ErrorDisplayType.warning,
      showRetryButton: false,
      showDismissButton: false,
      onDismiss: widget.onDismiss,
      padding: const EdgeInsets.all(24),
    );
  }
}
