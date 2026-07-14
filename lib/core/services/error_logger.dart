import 'package:flutter/foundation.dart';

/// Service for logging errors throughout the application
class ErrorLogger {
  /// Log an error with context and optional metadata
  static void log(
    String context,
    dynamic error, {
    StackTrace? stackTrace,
    Map<String, dynamic>? metadata,
  }) {
    // Log to console in debug mode
    if (kDebugMode) {
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('🔴 ERROR in [$context]');
      debugPrint('Error: $error');

      if (metadata != null && metadata.isNotEmpty) {
        debugPrint('Metadata:');
        metadata.forEach((key, value) {
          debugPrint('  $key: $value');
        });
      }

      if (stackTrace != null) {
        debugPrint('StackTrace:');
        debugPrint(stackTrace.toString());
      }

      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    }

    // In production, you could send to a logging service
    // Example: Firebase Crashlytics, Sentry, etc.
    // if (!kDebugMode) {
    //   FirebaseCrashlytics.instance.recordError(error, stackTrace);
    // }
  }

  /// Log a warning
  static void warn(
    String context,
    String message, {
    Map<String, dynamic>? metadata,
  }) {
    if (kDebugMode) {
      debugPrint('⚠️  WARNING in [$context]: $message');
      if (metadata != null && metadata.isNotEmpty) {
        debugPrint('Metadata: $metadata');
      }
    }
  }

  /// Log info message
  static void info(
    String context,
    String message, {
    Map<String, dynamic>? metadata,
  }) {
    if (kDebugMode) {
      debugPrint('ℹ️  INFO in [$context]: $message');
      if (metadata != null && metadata.isNotEmpty) {
        debugPrint('Metadata: $metadata');
      }
    }
  }
}
