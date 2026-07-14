import 'dart:async';
import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Comprehensive error handling for temple operations with detailed logging
/// Implements requirements 4.1, 4.2, 4.3, 4.4 for detailed error logging

/// Temple parsing error with detailed information about parsing failures
class TempleParsingError implements Exception {
  final String templeId;
  final String field;
  final dynamic actualValue;
  final Type expectedType;
  final String? additionalContext;
  final DateTime timestamp;

  TempleParsingError(
    this.templeId,
    this.field,
    this.actualValue,
    this.expectedType, {
    this.additionalContext,
  }) : timestamp = DateTime.now();

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('TempleParsingError:');
    buffer.writeln('  Temple ID: $templeId');
    buffer.writeln('  Field: $field');
    buffer.writeln('  Expected Type: $expectedType');
    buffer.writeln('  Actual Type: ${actualValue.runtimeType}');
    buffer.writeln('  Actual Value: $actualValue');
    buffer.writeln('  Timestamp: ${timestamp.toIso8601String()}');

    if (additionalContext != null) {
      buffer.writeln('  Additional Context: $additionalContext');
    }

    return buffer.toString();
  }

  /// Get a user-friendly error message
  String get userFriendlyMessage {
    return 'Unable to load temple data for field "$field". The data format is unexpected.';
  }

  /// Get detailed error information for logging
  Map<String, dynamic> toLogMap() {
    return {
      'error_type': 'temple_parsing_error',
      'temple_id': templeId,
      'field': field,
      'expected_type': expectedType.toString(),
      'actual_type': actualValue.runtimeType.toString(),
      'actual_value': actualValue.toString(),
      'timestamp': timestamp.toIso8601String(),
      'additional_context': additionalContext,
    };
  }
}

/// Firestore error handler for permission and network error handling
class FirestoreErrorHandler {
  /// Handle Firestore operation with comprehensive error handling and retry logic
  /// Implements requirement 4.4 for Firestore operation failure logging
  static Future<T?> handleFirestoreOperation<T>(
    Future<T> Function() operation, {
    String? operationName,
    String? documentId,
    String? collectionPath,
    T? Function()? fallback,
    int maxRetries = 3,
    Duration retryDelay = const Duration(seconds: 2),
  }) async {
    int attempts = 0;
    DateTime startTime = DateTime.now();

    while (attempts < maxRetries) {
      attempts++;

      try {
        if (kDebugMode && operationName != null) {
          developer.log(
            'FirestoreErrorHandler: Executing $operationName (attempt $attempts/$maxRetries)',
            name: 'FirestoreErrorHandler',
          );
        }

        final result = await operation();

        // Log successful operation
        _logFirestoreSuccess(
          operationName,
          documentId,
          collectionPath,
          attempts,
          DateTime.now().difference(startTime),
        );

        return result;
      } on FirebaseException catch (e) {
        final isLastAttempt = attempts >= maxRetries;

        // Log Firestore error with specific error codes and retry information
        _logFirestoreError(
          e,
          operationName,
          documentId,
          collectionPath,
          attempts,
          maxRetries,
          isLastAttempt,
        );

        if (isLastAttempt) {
          // Try fallback if available
          if (fallback != null) {
            try {
              final fallbackResult = fallback();
              _logFirestoreFallbackUsed(operationName, documentId, e.code);
              return fallbackResult;
            } catch (fallbackError) {
              _logFirestoreFallbackFailed(
                operationName,
                documentId,
                fallbackError,
              );
            }
          }

          rethrow;
        }

        // Wait before retry (with exponential backoff)
        final delay = Duration(
          milliseconds: (retryDelay.inMilliseconds * (attempts * 1.5)).round(),
        );
        await Future.delayed(delay);
      } catch (e, stackTrace) {
        // Handle non-Firebase exceptions
        _logNonFirestoreError(
          e,
          stackTrace,
          operationName,
          documentId,
          collectionPath,
          attempts,
        );

        if (attempts >= maxRetries) {
          rethrow;
        }

        await Future.delayed(retryDelay);
      }
    }

    return null;
  }

  /// Log successful Firestore operation
  static void _logFirestoreSuccess(
    String? operationName,
    String? documentId,
    String? collectionPath,
    int attempts,
    Duration duration,
  ) {
    final logData = {
      'event_type': 'firestore_operation_success',
      'operation_name': operationName,
      'document_id': documentId,
      'collection_path': collectionPath,
      'attempts': attempts,
      'duration_ms': duration.inMilliseconds,
      'timestamp': DateTime.now().toIso8601String(),
    };

    if (kDebugMode) {
      developer.log(
        'Firestore Success: ${operationName ?? 'operation'} completed in ${duration.inMilliseconds}ms ($attempts attempts)',
        name: 'FirestoreErrorHandler',
      );
    }

    _sendToAnalytics('firestore_operation_success', logData);
  }

  /// Log Firestore error with detailed information
  static void _logFirestoreError(
    FirebaseException error,
    String? operationName,
    String? documentId,
    String? collectionPath,
    int currentAttempt,
    int maxRetries,
    bool isLastAttempt,
  ) {
    final logData = {
      'event_type': 'firestore_operation_error',
      'operation_name': operationName,
      'document_id': documentId,
      'collection_path': collectionPath,
      'error_code': error.code,
      'error_message': error.message,
      'current_attempt': currentAttempt,
      'max_retries': maxRetries,
      'is_last_attempt': isLastAttempt,
      'timestamp': DateTime.now().toIso8601String(),
    };

    if (kDebugMode) {
      developer.log(
        'Firestore Error: ${error.code} - ${error.message} '
        '(${operationName ?? 'operation'}, attempt $currentAttempt/$maxRetries)',
        name: 'FirestoreErrorHandler',
        error: error,
      );
    }

    _sendToAnalytics('firestore_operation_error', logData);
  }

  /// Log non-Firestore error
  static void _logNonFirestoreError(
    dynamic error,
    StackTrace stackTrace,
    String? operationName,
    String? documentId,
    String? collectionPath,
    int currentAttempt,
  ) {
    final logData = {
      'event_type': 'non_firestore_error',
      'operation_name': operationName,
      'document_id': documentId,
      'collection_path': collectionPath,
      'error_type': error.runtimeType.toString(),
      'error_message': error.toString(),
      'current_attempt': currentAttempt,
      'timestamp': DateTime.now().toIso8601String(),
    };

    if (kDebugMode) {
      developer.log(
        'Non-Firestore Error: ${error.runtimeType} - $error (${operationName ?? 'operation'})',
        name: 'FirestoreErrorHandler',
        error: error,
        stackTrace: stackTrace,
      );
    }

    _sendToAnalytics('non_firestore_error', logData);
  }

  /// Log fallback usage
  static void _logFirestoreFallbackUsed(
    String? operationName,
    String? documentId,
    String errorCode,
  ) {
    final logData = {
      'event_type': 'firestore_fallback_used',
      'operation_name': operationName,
      'document_id': documentId,
      'original_error_code': errorCode,
      'timestamp': DateTime.now().toIso8601String(),
    };

    if (kDebugMode) {
      developer.log(
        'Firestore Fallback Used: ${operationName ?? 'operation'} after error $errorCode',
        name: 'FirestoreErrorHandler',
      );
    }

    _sendToAnalytics('firestore_fallback_used', logData);
  }

  /// Log fallback failure
  static void _logFirestoreFallbackFailed(
    String? operationName,
    String? documentId,
    dynamic fallbackError,
  ) {
    final logData = {
      'event_type': 'firestore_fallback_failed',
      'operation_name': operationName,
      'document_id': documentId,
      'fallback_error': fallbackError.toString(),
      'timestamp': DateTime.now().toIso8601String(),
    };

    if (kDebugMode) {
      developer.log(
        'Firestore Fallback Failed: ${operationName ?? 'operation'} - $fallbackError',
        name: 'FirestoreErrorHandler',
        error: fallbackError,
      );
    }

    _sendToAnalytics('firestore_fallback_failed', logData);
  }

  /// Get user-friendly error message for Firestore errors
  static String getUserFriendlyMessage(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
        return 'Access denied. Please check your permissions or sign in again.';
      case 'not-found':
        return 'The requested data was not found.';
      case 'already-exists':
        return 'This item already exists.';
      case 'invalid-argument':
        return 'Invalid data provided.';
      case 'unauthenticated':
        return 'Authentication required. Please sign in.';
      case 'unavailable':
        return 'Service temporarily unavailable. Please try again later.';
      case 'deadline-exceeded':
        return 'Request timed out. Please try again.';
      case 'resource-exhausted':
        return 'Service temporarily overloaded. Please try again later.';
      case 'failed-precondition':
        return 'Operation cannot be completed due to current state.';
      case 'aborted':
        return 'Operation was aborted. Please try again.';
      case 'out-of-range':
        return 'Invalid data range provided.';
      case 'unimplemented':
        return 'This feature is not yet available.';
      case 'internal':
        return 'Internal server error. Please try again later.';
      case 'data-loss':
        return 'Data corruption detected. Please contact support.';
      default:
        return 'An unexpected error occurred. Please try again.';
    }
  }

  /// Send analytics data (placeholder for actual implementation)
  static void _sendToAnalytics(String eventName, Map<String, dynamic> data) {
    // In a real implementation, this would send data to Firebase Analytics,
    // Crashlytics, or another analytics service
    if (kDebugMode) {
      developer.log('Analytics Event: $eventName - $data', name: 'Analytics');
    }
  }
}
