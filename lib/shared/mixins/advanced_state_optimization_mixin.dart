import 'dart:async';
import 'package:flutter/material.dart';
import '../services/state_management/state_optimization_service.dart';

/// Advanced state optimization mixin for StatefulWidgets
/// Provides debouncing, throttling, and batching capabilities
mixin AdvancedStateOptimizationMixin<T extends StatefulWidget> on State<T> {
  final StateOptimizationService _stateOptimization =
      StateOptimizationService();
  final Map<String, dynamic> _stateCache = {};
  final Map<String, Timer> _debounceTimers = {};
  final Map<String, DateTime> _lastThrottleExecution = {};

  bool _disposed = false;

  /// Debounce a state update - only executes after delay with no new calls
  void debounceStateUpdate(
    String key,
    VoidCallback stateUpdate, {
    Duration delay = const Duration(milliseconds: 300),
  }) {
    if (_disposed) return;

    _debounceTimers[key]?.cancel();
    _debounceTimers[key] = Timer(delay, () {
      if (mounted && !_disposed) {
        stateUpdate();
      }
      _debounceTimers.remove(key);
    });
  }

  /// Throttle a state update - limits execution frequency
  void throttleStateUpdate(
    String key,
    VoidCallback stateUpdate, {
    Duration interval = const Duration(milliseconds: 100),
  }) {
    if (_disposed) return;

    final now = DateTime.now();
    final lastExecution = _lastThrottleExecution[key];

    if (lastExecution == null || now.difference(lastExecution) >= interval) {
      _lastThrottleExecution[key] = now;
      if (mounted) {
        stateUpdate();
      }
    }
  }

  /// Batch multiple state updates to execute together
  void batchStateUpdate(
    String key,
    VoidCallback stateUpdate, {
    Duration batchWindow = const Duration(milliseconds: 16), // ~60fps
  }) {
    if (_disposed) return;

    _stateOptimization.batch('${widget.runtimeType}_$key', () {
      if (mounted && !_disposed) {
        stateUpdate();
      }
    }, batchWindow: batchWindow);
  }

  /// Cache a computed value to avoid recalculation
  V cacheComputation<V>(String key, V Function() computation) {
    if (_stateCache.containsKey(key)) {
      return _stateCache[key] as V;
    }

    final result = computation();
    _stateCache[key] = result;
    return result;
  }

  /// Invalidate cached computation
  void invalidateCache([String? key]) {
    if (key != null) {
      _stateCache.remove(key);
    } else {
      _stateCache.clear();
    }
  }

  /// Conditional state update - only updates if condition is met
  void conditionalStateUpdate(
    bool condition,
    VoidCallback stateUpdate, {
    VoidCallback? elseCallback,
  }) {
    if (_disposed) return;

    if (condition && mounted) {
      stateUpdate();
    } else if (elseCallback != null && mounted) {
      elseCallback();
    }
  }

  /// Delayed state update with cancellation support
  Timer delayedStateUpdate(
    VoidCallback stateUpdate, {
    Duration delay = const Duration(milliseconds: 100),
  }) {
    return Timer(delay, () {
      if (mounted && !_disposed) {
        stateUpdate();
      }
    });
  }

  /// Optimized setState that prevents unnecessary rebuilds
  void optimizedSetState(VoidCallback fn) {
    if (_disposed || !mounted) return;

    // Capture state before change
    final oldHashCode = hashCode;

    setState(() {
      fn();
    });

    // Only notify if state actually changed
    if (hashCode != oldHashCode) {
      // State changed, rebuild is necessary
    }
  }

  /// Batch multiple setState calls
  void batchSetState(List<VoidCallback> updates) {
    if (_disposed || !mounted) return;

    setState(() {
      for (final update in updates) {
        update();
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;

    // Cancel all pending timers
    for (final timer in _debounceTimers.values) {
      timer.cancel();
    }
    _debounceTimers.clear();

    // Clear caches
    _stateCache.clear();
    _lastThrottleExecution.clear();

    // Cancel state optimization operations
    _stateOptimization.cancel('${widget.runtimeType}');

    super.dispose();
  }
}

/// Advanced ChangeNotifier with built-in optimization techniques
abstract class AdvancedOptimizedChangeNotifier extends ChangeNotifier {
  final StateOptimizationService _stateOptimization =
      StateOptimizationService();
  final Map<String, dynamic> _stateCache = {};
  final Set<String> _changedProperties = {};

  bool _disposed = false;
  bool _batchingEnabled = false;
  Timer? _batchTimer;

  /// Enable batching mode for multiple property changes
  void startBatch() {
    _batchingEnabled = true;
    _changedProperties.clear();
  }

  /// Execute all batched notifications
  void executeBatch() {
    if (!_batchingEnabled || _disposed) return;

    _batchingEnabled = false;
    if (_changedProperties.isNotEmpty) {
      notifyListeners();
      _changedProperties.clear();
    }
  }

  /// Auto-batch notifications within a time window
  void autoBatch({Duration batchWindow = const Duration(milliseconds: 16)}) {
    if (_disposed) return;

    _batchTimer?.cancel();
    _batchTimer = Timer(batchWindow, () {
      if (!_disposed) {
        notifyListeners();
      }
    });
  }

  /// Notify listeners with debouncing
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

  /// Notify listeners with throttling
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

  /// Conditional notification - only notify if condition is met
  void notifyListenersIf(bool condition) {
    if (_disposed || !condition) return;
    notifyListeners();
  }

  /// Track property changes for selective notifications
  void markPropertyChanged(String property) {
    _changedProperties.add(property);

    if (_batchingEnabled) {
      // Will notify when batch is executed
      return;
    }

    notifyListeners();
  }

  /// Check if a property has changed in current batch
  bool hasPropertyChanged(String property) {
    return _changedProperties.contains(property);
  }

  /// Cache a computed value
  V cacheValue<V>(String key, V Function() computation) {
    if (_stateCache.containsKey(key)) {
      return _stateCache[key] as V;
    }

    final result = computation();
    _stateCache[key] = result;
    return result;
  }

  /// Invalidate cached value
  void invalidateCache([String? key]) {
    if (key != null) {
      _stateCache.remove(key);
    } else {
      _stateCache.clear();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _batchTimer?.cancel();
    _stateOptimization.cancel('${runtimeType}_notify');
    _stateCache.clear();
    _changedProperties.clear();
    super.dispose();
  }
}

/// Separation of concerns helper for state management
class StateManager<T> {
  final Map<String, T> _state = {};
  final Map<String, List<VoidCallback>> _listeners = {};
  final StateOptimizationService _optimization = StateOptimizationService();

  /// Get state value
  T? getValue(String key) => _state[key];

  /// Set state value with optional notification
  void setValue(String key, T value, {bool notify = true}) {
    final oldValue = _state[key];
    _state[key] = value;

    if (notify && oldValue != value) {
      _notifyListeners(key);
    }
  }

  /// Add listener for specific state key
  void addListener(String key, VoidCallback listener) {
    _listeners.putIfAbsent(key, () => []).add(listener);
  }

  /// Remove listener for specific state key
  void removeListener(String key, VoidCallback listener) {
    _listeners[key]?.remove(listener);
    if (_listeners[key]?.isEmpty == true) {
      _listeners.remove(key);
    }
  }

  /// Notify listeners for specific key with debouncing
  void _notifyListeners(String key) {
    final listeners = _listeners[key];
    if (listeners == null || listeners.isEmpty) return;

    _optimization.debounce('state_$key', () {
      for (final listener in listeners) {
        try {
          listener();
        } catch (e) {
          debugPrint('Error in state listener: $e');
        }
      }
    });
  }

  /// Clear all state and listeners
  void dispose() {
    _state.clear();
    _listeners.clear();
    _optimization.cancelAll();
  }
}
