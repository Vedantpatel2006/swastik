import 'package:flutter/material.dart';

/// Error handling utilities
class ErrorHandlingUtils {
  static void logError(String message) {
    debugPrint('Error: $message');
  }

  static void handleError(dynamic error) {
    debugPrint('Handled error: $error');
  }

  /// Get user-friendly error message
  static String getUserFriendlyMessage(dynamic error) {
    if (error == null) return 'An unknown error occurred';

    final errorString = error.toString().toLowerCase();

    if (errorString.contains('permission')) {
      return 'Permission denied. Please grant the required permissions.';
    } else if (errorString.contains('network') ||
        errorString.contains('connection')) {
      return 'Network connection error. Please check your internet connection.';
    } else if (errorString.contains('location')) {
      return 'Location service error. Please enable location services.';
    } else if (errorString.contains('timeout')) {
      return 'Request timed out. Please try again.';
    } else {
      return 'Something went wrong. Please try again.';
    }
  }

  /// Categorize error type
  static ErrorCategory categorizeError(dynamic error) {
    if (error == null) return ErrorCategory.unknown;

    final errorString = error.toString().toLowerCase();

    if (errorString.contains('location') || errorString.contains('gps')) {
      return ErrorCategory.location;
    } else if (errorString.contains('permission')) {
      return ErrorCategory.permission;
    } else if (errorString.contains('network') ||
        errorString.contains('connection')) {
      return ErrorCategory.network;
    } else if (errorString.contains('validation') ||
        errorString.contains('invalid')) {
      return ErrorCategory.validation;
    } else {
      return ErrorCategory.unknown;
    }
  }

  /// Execute with retry logic
  static Future<T> executeWithRetry<T>(
    Future<T> Function() operation, {
    int maxRetries = 3,
    Duration delay = const Duration(seconds: 1),
  }) async {
    int attempts = 0;

    while (attempts < maxRetries) {
      try {
        return await operation();
      } catch (error) {
        attempts++;
        if (attempts >= maxRetries) {
          rethrow;
        }
        await Future.delayed(delay);
      }
    }

    throw Exception('Max retries exceeded');
  }
}

/// Error categories
enum ErrorCategory { network, location, permission, validation, unknown }
