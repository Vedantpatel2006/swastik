import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'state_optimization_service.dart';

/// Advanced state management service with separation of concerns
class AdvancedStateService {
  static final AdvancedStateService _instance =
      AdvancedStateService._internal();
  factory AdvancedStateService() => _instance;
  AdvancedStateService._internal();

  final StateOptimizationService _optimization = StateOptimizationService();
  final Map<String, StateSlice> _slices = {};
  final Map<String, List<VoidCallback>> _globalListeners = {};

  /// Create or get a state slice
  StateSlice<T> getSlice<T>(String name, T initialValue) {
    if (_slices.containsKey(name)) {
      return _slices[name] as StateSlice<T>;
    }

    final slice = StateSlice<T>(name, initialValue, this);
    _slices[name] = slice;
    return slice;
  }

  /// Add global state listener
  void addGlobalListener(String key, VoidCallback listener) {
    _globalListeners.putIfAbsent(key, () => []).add(listener);
  }

  /// Remove global state listener
  void removeGlobalListener(String key, VoidCallback listener) {
    _globalListeners[key]?.remove(listener);
    if (_globalListeners[key]?.isEmpty == true) {
      _globalListeners.remove(key);
    }
  }

  /// Notify global listeners with optimization
  void notifyGlobalListeners(String key) {
    final listeners = _globalListeners[key];
    if (listeners == null || listeners.isEmpty) return;

    _optimization.batch('global_$key', () {
      for (final listener in listeners) {
        try {
          listener();
        } catch (e) {
          if (kDebugMode) {
            debugPrint('Error in global listener: $e');
          }
        }
      }
    });
  }

  /// Batch multiple state updates across slices
  void batchUpdates(Map<String, dynamic> updates) {
    _optimization.batch('batch_updates', () {
      for (final entry in updates.entries) {
        final slice = _slices[entry.key];
        if (slice != null) {
          slice._setValue(entry.value, notify: false);
        }
      }

      // Notify all affected slices
      for (final key in updates.keys) {
        final slice = _slices[key];
        slice?._notifyListeners();
      }
    });
  }

  /// Get state statistics
  Map<String, dynamic> getStats() {
    return {
      'slices': _slices.length,
      'globalListeners': _globalListeners.length,
      'optimization': _optimization.getStats(),
    };
  }

  /// Dispose all state
  void dispose() {
    for (final slice in _slices.values) {
      slice.dispose();
    }
    _slices.clear();
    _globalListeners.clear();
    _optimization.cancelAll();
  }
}

/// Individual state slice with optimized notifications
class StateSlice<T> extends ChangeNotifier {
  final String name;
  final AdvancedStateService _service;
  final StateOptimizationService _optimization = StateOptimizationService();

  T _value;
  final List<T> _history = [];
  final Map<String, VoidCallback> _computedCache = {};
  bool _disposed = false;

  StateSlice(this.name, this._value, this._service);

  /// Current value
  T get value => _value;

  /// Value history (last 10 values)
  List<T> get history => List.unmodifiable(_history);

  /// Set value with optional notification
  void setValue(T newValue, {bool notify = true}) {
    if (_disposed) return;

    _setValue(newValue, notify: notify);
  }

  void _setValue(T newValue, {bool notify = true}) {
    if (_value == newValue) return;

    // Add to history
    _history.add(_value);
    if (_history.length > 10) {
      _history.removeAt(0);
    }

    _value = newValue;

    // Invalidate computed cache
    _computedCache.clear();

    if (notify) {
      _notifyListeners();
    }
  }

  /// Update value using a function
  void updateValue(T Function(T current) updater, {bool notify = true}) {
    setValue(updater(_value), notify: notify);
  }

  /// Debounced value update
  void setValueDebounced(
    T newValue, {
    Duration delay = const Duration(milliseconds: 300),
  }) {
    if (_disposed) return;

    _optimization.debounce('${name}_update', () {
      setValue(newValue);
    }, delay: delay);
  }

  /// Throttled value update
  void setValueThrottled(
    T newValue, {
    Duration interval = const Duration(milliseconds: 100),
  }) {
    if (_disposed) return;

    _optimization.throttle('${name}_update', () {
      setValue(newValue);
    }, interval: interval);
  }

  /// Computed value with caching
  R computeValue<R>(String key, R Function(T value) computation) {
    final cacheKey = '${name}_$key';

    if (_computedCache.containsKey(cacheKey)) {
      return _computedCache[cacheKey] as R;
    }

    final result = computation(_value);
    _computedCache[cacheKey] = result as VoidCallback;
    return result;
  }

  /// Reset to initial value
  void reset(T initialValue) {
    setValue(initialValue);
    _history.clear();
  }

  /// Optimized notification
  void _notifyListeners() {
    if (_disposed) return;

    _optimization.throttle('${name}_notify', () {
      if (!_disposed) {
        notifyListeners();
        _service.notifyGlobalListeners(name);
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _optimization.cancel('${name}_update');
    _optimization.cancel('${name}_notify');
    _computedCache.clear();
    _history.clear();
    super.dispose();
  }
}

/// State management extensions for BuildContext
extension AdvancedStateExtensions on BuildContext {
  /// Get state slice
  StateSlice<T> getStateSlice<T>(String name, T initialValue) {
    return AdvancedStateService().getSlice<T>(name, initialValue);
  }

  /// Watch state slice changes
  T watchState<T>(String name, T initialValue) {
    final slice = getStateSlice<T>(name, initialValue);
    return slice.value;
  }

  /// Read state slice value without watching
  T readState<T>(String name, T initialValue) {
    final slice = getStateSlice<T>(name, initialValue);
    return slice.value;
  }
}

/// Mixin for widgets that need advanced state management
mixin AdvancedStateMixin<T extends StatefulWidget> on State<T> {
  final Map<String, StateSlice> _slices = {};
  final AdvancedStateService _stateService = AdvancedStateService();

  /// Get or create a state slice
  StateSlice<V> useStateSlice<V>(String name, V initialValue) {
    if (_slices.containsKey(name)) {
      return _slices[name] as StateSlice<V>;
    }

    final slice = _stateService.getSlice<V>(name, initialValue);
    _slices[name] = slice;

    // Add listener to trigger rebuilds
    slice.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });

    return slice;
  }

  /// Batch multiple state updates
  void batchStateUpdates(Map<String, dynamic> updates) {
    _stateService.batchUpdates(updates);
  }

  @override
  void dispose() {
    // Remove listeners
    for (final slice in _slices.values) {
      slice.removeListener(() {});
    }
    _slices.clear();
    super.dispose();
  }
}

/// Provider-style state management with advanced optimization
class OptimizedStateProvider<T> extends InheritedNotifier<StateSlice<T>> {
  const OptimizedStateProvider({
    super.key,
    required StateSlice<T> slice,
    required super.child,
  }) : super(notifier: slice);

  static StateSlice<T>? of<T>(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<OptimizedStateProvider<T>>()
        ?.notifier;
  }

  static T? valueOf<T>(BuildContext context) {
    return of<T>(context)?.value;
  }
}

/// State management utilities
class StateUtils {
  /// Debounce a function call
  static void debounce(
    String key,
    VoidCallback callback, {
    Duration delay = const Duration(milliseconds: 300),
  }) {
    StateOptimizationService().debounce(key, callback, delay: delay);
  }

  /// Throttle a function call
  static void throttle(
    String key,
    VoidCallback callback, {
    Duration interval = const Duration(milliseconds: 100),
  }) {
    StateOptimizationService().throttle(key, callback, interval: interval);
  }

  /// Batch multiple function calls
  static void batch(
    String key,
    VoidCallback callback, {
    Duration batchWindow = const Duration(milliseconds: 16),
  }) {
    StateOptimizationService().batch(key, callback, batchWindow: batchWindow);
  }
}
