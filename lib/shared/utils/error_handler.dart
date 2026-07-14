import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Comprehensive error handling utility for the application
class ErrorHandler {
  static const String _logTag = 'ErrorHandler';

  /// Handle and log errors with optional user notification
  static void handleError(
    dynamic error, {
    StackTrace? stackTrace,
    String? context,
    bool showToUser = false,
    BuildContext? buildContext,
    String? userMessage,
  }) {
    // Log the error
    _logError(error, stackTrace: stackTrace, context: context);

    // Show to user if requested
    if (showToUser && buildContext != null && buildContext.mounted) {
      _showErrorToUser(
        buildContext,
        userMessage ?? _getUserFriendlyMessage(error),
      );
    }
  }

  /// Log error with proper formatting
  static void _logError(
    dynamic error, {
    StackTrace? stackTrace,
    String? context,
  }) {
    final contextStr = context != null ? '[$context] ' : '';
    
    if (kDebugMode) {
      debugPrint('$_logTag: ${contextStr}Error: $error');
      if (stackTrace != null) {
        debugPrint('$_logTag: Stack trace: $stackTrace');
      }
    }
  }

  /// Show error message to user
  static void _showErrorToUser(BuildContext context, String message) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  /// Convert technical errors to user-friendly messages
  static String _getUserFriendlyMessage(dynamic error) {
    final errorStr = error.toString().toLowerCase();

    if (errorStr.contains('network') || errorStr.contains('connection')) {
      return 'Network connection error. Please check your internet connection.';
    }
    
    if (errorStr.contains('timeout')) {
      return 'Request timed out. Please try again.';
    }
    
    if (errorStr.contains('permission')) {
      return 'Permission denied. Please check app permissions.';
    }
    
    if (errorStr.contains('not found') || errorStr.contains('404')) {
      return 'Requested resource not found.';
    }
    
    if (errorStr.contains('unauthorized') || errorStr.contains('401')) {
      return 'Authentication required. Please sign in again.';
    }
    
    if (errorStr.contains('forbidden') || errorStr.contains('403')) {
      return 'Access denied. You don\'t have permission for this action.';
    }

    return 'An unexpected error occurred. Please try again.';
  }

  /// Safe execution wrapper that handles errors gracefully
  static Future<T?> safeExecute<T>(
    Future<T> Function() operation, {
    String? context,
    T? fallbackValue,
    bool showErrorToUser = false,
    BuildContext? buildContext,
    String? userErrorMessage,
  }) async {
    try {
      return await operation();
    } catch (error, stackTrace) {
      handleError(
        error,
        stackTrace: stackTrace,
        context: context,
        showToUser: showErrorToUser,
        buildContext: buildContext,
        userMessage: userErrorMessage,
      );
      return fallbackValue;
    }
  }

  /// Safe synchronous execution wrapper
  static T? safeExecuteSync<T>(
    T Function() operation, {
    String? context,
    T? fallbackValue,
    bool showErrorToUser = false,
    BuildContext? buildContext,
    String? userErrorMessage,
  }) {
    try {
      return operation();
    } catch (error, stackTrace) {
      handleError(
        error,
        stackTrace: stackTrace,
        context: context,
        showToUser: showErrorToUser,
        buildContext: buildContext,
        userMessage: userErrorMessage,
      );
      return fallbackValue;
    }
  }

  /// Validate and handle null safety issues
  static T validateNotNull<T>(
    T? value,
    String fieldName, {
    String? context,
    T? fallbackValue,
  }) {
    if (value == null) {
      final error = 'Null value encountered for required field: $fieldName';
      handleError(error, context: context);
      
      if (fallbackValue != null) {
        return fallbackValue;
      }
      
      throw ArgumentError(error);
    }
    return value;
  }

  /// Handle form validation errors
  static String? validateFormField(
    String? value, {
    required String fieldName,
    bool required = true,
    int? minLength,
    int? maxLength,
    String? pattern,
  }) {
    if (required && (value == null || value.trim().isEmpty)) {
      return '$fieldName is required';
    }

    if (value != null && value.isNotEmpty) {
      if (minLength != null && value.length < minLength) {
        return '$fieldName must be at least $minLength characters';
      }

      if (maxLength != null && value.length > maxLength) {
        return '$fieldName must not exceed $maxLength characters';
      }

      if (pattern != null && !RegExp(pattern).hasMatch(value)) {
        return '$fieldName format is invalid';
      }
    }

    return null;
  }

  /// Show confirmation dialog with error handling
  static Future<bool> showConfirmationDialog(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
  }) async {
    if (!context.mounted) return false;

    try {
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(cancelText),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(confirmText),
            ),
          ],
        ),
      );
      return result ?? false;
    } catch (error) {
      handleError(error, context: 'showConfirmationDialog');
      return false;
    }
  }
}

/// Extension methods for safer operations
extension SafeOperations on String? {
  /// Safe string operations
  String get safeValue => this ?? '';
  bool get isNullOrEmpty => this == null || this!.isEmpty;
  bool get isNotNullOrEmpty => !isNullOrEmpty;
}

extension SafeListOperations<T> on List<T>? {
  /// Safe list operations
  List<T> get safeValue => this ?? [];
  bool get isNullOrEmpty => this == null || this!.isEmpty;
  bool get isNotNullOrEmpty => !isNullOrEmpty;
  int get safeLength => this?.length ?? 0;
}

extension SafeMapOperations<K, V> on Map<K, V>? {
  /// Safe map operations
  Map<K, V> get safeValue => this ?? {};
  bool get isNullOrEmpty => this == null || this!.isEmpty;
  bool get isNotNullOrEmpty => !isNullOrEmpty;
}