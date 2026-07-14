import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Advanced state optimization service providing debouncing, throttling, and batching
class StateOptimizationService {
  static final StateOptimizationService _instance =
      StateOptimizationService._internal();
  factory StateOptimizationService() => _instance;
  StateOptimizationService._internal();

  final Map<String, Timer> _debounceTimers = {};
  final Map<String, DateTime> _lastThrottleExecution = {};
  final Map<String, List<VoidCallback>> _batchedCallbacks = {};
  final Map<String, Timer> _batchTimers = {};

  /// Debounce a function call - only executes after a delay with no new calls
  void debounce(
    String key,
    VoidCallback callback, {
    Duration delay = const Duration(milliseconds: 300),
  }) {
    // Cancel existing timer
    _debounceTimers[key]?.cancel();

    // Create new timer
    _debounceTimers[key] = Timer(delay, () {
      callback();
      _debounceTimers.remove(key);
    });
  }

  /// Throttle a function call - limits execution frequency
  void throttle(
    String key,
    VoidCallback callback, {
    Duration interval = const Duration(milliseconds: 100),
  }) {
    final now = DateTime.now();
    final lastExecution = _lastThrottleExecution[key];

    if (lastExecution == null || now.difference(lastExecution) >= interval) {
      _lastThrottleExecution[key] = now;
      callback();
    }
  }

  /// Batch multiple callbacks to execute together
  void batch(
    String key,
    VoidCallback callback, {
    Duration batchWindow = const Duration(milliseconds: 16), // ~60fps
  }) {
    // Add callback to batch
    _batchedCallbacks.putIfAbsent(key, () => []).add(callback);

    // Cancel existing batch timer
    _batchTimers[key]?.cancel();

    // Create new batch timer
    _batchTimers[key] = Timer(batchWindow, () {
      final callbacks = _batchedCallbacks[key] ?? [];
      _batchedCallbacks.remove(key);
      _batchTimers.remove(key);

      // Execute all batched callbacks
      for (final callback in callbacks) {
        try {
          callback();
        } catch (e) {
          if (kDebugMode) {
            debugPrint('Error executing batched callback: $e');
          }
        }
      }
    });
  }

  /// Cancel all pending operations for a key
  void cancel(String key) {
    _debounceTimers[key]?.cancel();
    _debounceTimers.remove(key);

    _lastThrottleExecution.remove(key);

    _batchTimers[key]?.cancel();
    _batchTimers.remove(key);
    _batchedCallbacks.remove(key);
  }

  /// Cancel all pending operations
  void cancelAll() {
    for (final timer in _debounceTimers.values) {
      timer.cancel();
    }
    _debounceTimers.clear();

    for (final timer in _batchTimers.values) {
      timer.cancel();
    }
    _batchTimers.clear();

    _lastThrottleExecution.clear();
    _batchedCallbacks.clear();
  }

  /// Get statistics about pending operations
  Map<String, dynamic> getStats() {
    return {
      'pendingDebounces': _debounceTimers.length,
      'pendingBatches': _batchTimers.length,
      'throttleKeys': _lastThrottleExecution.length,
    };
  }
}

/// Mixin for widgets that need state optimization
mixin StateOptimizationMixin<T extends StatefulWidget> on State<T> {
  final StateOptimizationService _stateOptimization =
      StateOptimizationService();

  /// Debounce a state update
  void debounceStateUpdate(
    String key,
    VoidCallback stateUpdate, {
    Duration delay = const Duration(milliseconds: 300),
  }) {
    _stateOptimization.debounce('${widget.runtimeType}_$key', () {
      if (mounted) {
        stateUpdate();
      }
    }, delay: delay);
  }

  /// Throttle a state update
  void throttleStateUpdate(
    String key,
    VoidCallback stateUpdate, {
    Duration interval = const Duration(milliseconds: 100),
  }) {
    _stateOptimization.throttle('${widget.runtimeType}_$key', () {
      if (mounted) {
        stateUpdate();
      }
    }, interval: interval);
  }

  /// Batch multiple state updates
  void batchStateUpdate(
    String key,
    VoidCallback stateUpdate, {
    Duration batchWindow = const Duration(milliseconds: 16),
  }) {
    _stateOptimization.batch('${widget.runtimeType}_$key', () {
      if (mounted) {
        stateUpdate();
      }
    }, batchWindow: batchWindow);
  }

  @override
  void dispose() {
    // Cancel all pending operations for this widget
    _stateOptimization.cancel('${widget.runtimeType}');
    super.dispose();
  }
}

/// Advanced ChangeNotifier with built-in optimization
abstract class OptimizedChangeNotifier extends ChangeNotifier {
  final StateOptimizationService _stateOptimization =
      StateOptimizationService();
  bool _disposed = false;

  /// Debounced notification
  void notifyListenersDebounced({
    Duration delay = const Duration(milliseconds: 300),
  }) {
    if (_disposed) return;

    _stateOptimization.debounce('${runtimeType}_notify', () {
      if (!_disposed) {
        notifyListeners();
      }
    }, delay: delay);
  }

  /// Throttled notification
  void notifyListenersThrottled({
    Duration interval = const Duration(milliseconds: 16),
  }) {
    if (_disposed) return;

    _stateOptimization.throttle('${runtimeType}_notify', () {
      if (!_disposed) {
        notifyListeners();
      }
    }, interval: interval);
  }

  /// Batched notification
  void notifyListenersBatched({
    Duration batchWindow = const Duration(milliseconds: 16),
  }) {
    if (_disposed) return;

    _stateOptimization.batch('${runtimeType}_notify', () {
      if (!_disposed) {
        notifyListeners();
      }
    }, batchWindow: batchWindow);
  }

  @override
  void dispose() {
    _disposed = true;
    _stateOptimization.cancel('${runtimeType}_notify');
    super.dispose();
  }
}

/// State change batching utility for multiple providers
class StateChangeBatcher {
  static final StateChangeBatcher _instance = StateChangeBatcher._internal();
  factory StateChangeBatcher() => _instance;
  StateChangeBatcher._internal();

  final List<VoidCallback> _pendingNotifications = [];
  Timer? _batchTimer;
  bool _isBatching = false;

  /// Start batching state changes
  void startBatch() {
    _isBatching = true;
  }

  /// Add a notification to the batch
  void addNotification(VoidCallback notification) {
    if (_isBatching) {
      _pendingNotifications.add(notification);
    } else {
      notification();
    }
  }

  /// Execute all batched notifications
  void executeBatch() {
    if (!_isBatching) return;

    _isBatching = false;

    // Execute all pending notifications
    for (final notification in _pendingNotifications) {
      try {
        notification();
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Error executing batched notification: $e');
        }
      }
    }

    _pendingNotifications.clear();
  }

  /// Auto-batch notifications within a time window
  void autoBatch(
    VoidCallback notification, {
    Duration batchWindow = const Duration(milliseconds: 16),
  }) {
    _pendingNotifications.add(notification);

    _batchTimer?.cancel();
    _batchTimer = Timer(batchWindow, () {
      executeBatch();
    });
  }

  /// Cancel all pending notifications
  void cancelBatch() {
    _isBatching = false;
    _pendingNotifications.clear();
    _batchTimer?.cancel();
  }
}

/// Extension for easy state optimization access
extension StateOptimizationExtensions on State {
  StateOptimizationService get stateOptimization => StateOptimizationService();
  StateChangeBatcher get stateBatcher => StateChangeBatcher();
}
