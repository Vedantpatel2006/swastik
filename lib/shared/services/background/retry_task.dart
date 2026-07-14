import 'dart:async';
import 'dart:math' as math;
import 'background_processor.dart';

/// A background task that implements retry logic with exponential backoff
abstract class RetryableBackgroundTask extends BackgroundTask {
  final int maxRetries;
  final Duration baseDelay;
  final double backoffMultiplier;
  final Duration maxDelay;
  int _currentAttempt = 0;

  RetryableBackgroundTask({
    required super.id,
    required super.name,
    this.maxRetries = 3,
    this.baseDelay = const Duration(seconds: 1),
    this.backoffMultiplier = 2.0,
    this.maxDelay = const Duration(minutes: 5),
  });

  /// The actual work to be performed (implemented by subclasses)
  Future<void> performWork();

  /// Check if the error is retryable (can be overridden by subclasses)
  bool isRetryableError(dynamic error) {
    // By default, retry most errors except for specific ones
    final errorString = error.toString().toLowerCase();

    // Don't retry authentication or permission errors
    if (errorString.contains('permission') ||
        errorString.contains('unauthorized') ||
        errorString.contains('forbidden') ||
        errorString.contains('invalid token')) {
      return false;
    }

    // Don't retry validation errors
    if (errorString.contains('validation') ||
        errorString.contains('invalid format') ||
        errorString.contains('bad request')) {
      return false;
    }

    return true;
  }

  @override
  Future<void> execute() async {
    _currentAttempt = 0;

    while (_currentAttempt < maxRetries) {
      try {
        _currentAttempt++;
        await performWork();
        return; // Success, exit retry loop
      } catch (error) {
        if (_currentAttempt >= maxRetries || !isRetryableError(error)) {
          // Max retries reached or non-retryable error
          rethrow;
        }

        // Calculate delay for next retry
        final delay = _calculateDelay(_currentAttempt);

        // Update progress to show retry attempt
        final backgroundProcessor = BackgroundProcessor();
        backgroundProcessor.updateTaskProgress(
          id,
          _currentAttempt / (maxRetries + 1),
        );

        // Wait before retrying
        await Future.delayed(delay);
      }
    }
  }

  Duration _calculateDelay(int attempt) {
    // Exponential backoff with jitter
    final exponentialDelay =
        baseDelay * math.pow(backoffMultiplier, attempt - 1);
    final jitter = math.Random().nextDouble() * 0.1; // 10% jitter
    final delayWithJitter = exponentialDelay * (1 + jitter);

    // Cap at max delay
    return Duration(
      milliseconds: math
          .min(delayWithJitter.inMilliseconds, maxDelay.inMilliseconds)
          .round(),
    );
  }

  /// Get current attempt number (1-based)
  int get currentAttempt => _currentAttempt;

  /// Get remaining retry attempts
  int get remainingRetries => math.max(0, maxRetries - _currentAttempt);
}

/// Retryable file upload task
class RetryableFileUploadTask extends RetryableBackgroundTask {
  final Future<void> Function() uploadFunction;
  final Function(dynamic error, int attempt)? onRetry;

  RetryableFileUploadTask({
    required super.id,
    required super.name,
    required this.uploadFunction,
    this.onRetry,
    super.maxRetries = 3,
    super.baseDelay = const Duration(seconds: 2),
  });

  @override
  Future<void> performWork() async {
    try {
      await uploadFunction();
    } catch (error) {
      onRetry?.call(error, currentAttempt);
      rethrow;
    }
  }

  @override
  bool isRetryableError(dynamic error) {
    final errorString = error.toString().toLowerCase();

    // Retry network-related errors
    if (errorString.contains('network') ||
        errorString.contains('timeout') ||
        errorString.contains('connection') ||
        errorString.contains('socket')) {
      return true;
    }

    // Retry server errors (5xx)
    if (errorString.contains('server error') ||
        errorString.contains('internal error') ||
        errorString.contains('service unavailable')) {
      return true;
    }

    return super.isRetryableError(error);
  }
}

/// Retryable data sync task
class RetryableDataSyncTask extends RetryableBackgroundTask {
  final Future<void> Function() syncFunction;
  final Function(dynamic error, int attempt)? onRetry;

  RetryableDataSyncTask({
    required super.id,
    required super.name,
    required this.syncFunction,
    this.onRetry,
    super.maxRetries = 5, // More retries for data sync
    super.baseDelay = const Duration(seconds: 1),
  });

  @override
  Future<void> performWork() async {
    try {
      await syncFunction();
    } catch (error) {
      onRetry?.call(error, currentAttempt);
      rethrow;
    }
  }

  @override
  bool isRetryableError(dynamic error) {
    final errorString = error.toString().toLowerCase();

    // Retry Firestore-specific errors
    if (errorString.contains('firestore') ||
        errorString.contains('deadline exceeded') ||
        errorString.contains('unavailable') ||
        errorString.contains('resource exhausted')) {
      return true;
    }

    return super.isRetryableError(error);
  }
}

/// Utility class for creating retryable operations
class RetryableOperations {
  /// Create a retryable file upload operation
  static RetryableFileUploadTask createFileUpload({
    required String taskId,
    required String taskName,
    required Future<void> Function() uploadFunction,
    Function(dynamic error, int attempt)? onRetry,
    int maxRetries = 3,
    Duration baseDelay = const Duration(seconds: 2),
  }) {
    return RetryableFileUploadTask(
      id: taskId,
      name: taskName,
      uploadFunction: uploadFunction,
      onRetry: onRetry,
      maxRetries: maxRetries,
      baseDelay: baseDelay,
    );
  }

  /// Create a retryable data sync operation
  static RetryableDataSyncTask createDataSync({
    required String taskId,
    required String taskName,
    required Future<void> Function() syncFunction,
    Function(dynamic error, int attempt)? onRetry,
    int maxRetries = 5,
    Duration baseDelay = const Duration(seconds: 1),
  }) {
    return RetryableDataSyncTask(
      id: taskId,
      name: taskName,
      syncFunction: syncFunction,
      onRetry: onRetry,
      maxRetries: maxRetries,
      baseDelay: baseDelay,
    );
  }

  /// Execute a function with retry logic (without background processing)
  static Future<T> executeWithRetry<T>(
    Future<T> Function() operation, {
    int maxRetries = 3,
    Duration baseDelay = const Duration(seconds: 1),
    double backoffMultiplier = 2.0,
    Duration maxDelay = const Duration(minutes: 5),
    bool Function(dynamic error)? isRetryable,
  }) async {
    int attempt = 0;

    while (attempt < maxRetries) {
      try {
        attempt++;
        return await operation();
      } catch (error) {
        final shouldRetry =
            isRetryable?.call(error) ?? _defaultIsRetryable(error);

        if (attempt >= maxRetries || !shouldRetry) {
          rethrow;
        }

        // Calculate delay
        final exponentialDelay =
            baseDelay * math.pow(backoffMultiplier, attempt - 1);
        final jitter = math.Random().nextDouble() * 0.1;
        final delayWithJitter = exponentialDelay * (1 + jitter);
        final delay = Duration(
          milliseconds: math
              .min(delayWithJitter.inMilliseconds, maxDelay.inMilliseconds)
              .round(),
        );

        await Future.delayed(delay);
      }
    }

    throw StateError('This should never be reached');
  }

  static bool _defaultIsRetryable(dynamic error) {
    final errorString = error.toString().toLowerCase();

    // Don't retry authentication or permission errors
    if (errorString.contains('permission') ||
        errorString.contains('unauthorized') ||
        errorString.contains('forbidden')) {
      return false;
    }

    // Don't retry validation errors
    if (errorString.contains('validation') ||
        errorString.contains('invalid format')) {
      return false;
    }

    return true;
  }
}
