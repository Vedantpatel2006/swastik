import 'package:flutter/material.dart';

/// Mixin that provides caching utilities for stateful widgets to optimize build() methods
///
/// This mixin helps move heavy computations out of build() methods by providing
/// caching mechanisms and lifecycle management for expensive operations.
mixin BuildOptimizationMixin<T extends StatefulWidget> on State<T> {
  /// Cache for storing computed values
  final Map<String, dynamic> _computedCache = {};

  /// Cache for storing expensive widget builds
  final Map<String, Widget> _widgetCache = {};

  /// Set to track which cache keys are currently being computed
  final Set<String> _computingKeys = {};

  /// Timestamp of last cache invalidation
  DateTime? _lastCacheInvalidation;

  /// Maximum cache age in milliseconds (default: 5 minutes)
  int get maxCacheAge => 5 * 60 * 1000;

  /// Whether to enable debug logging for cache operations
  bool get enableCacheDebugLogging => false;

  @override
  void initState() {
    super.initState();
    _lastCacheInvalidation = DateTime.now();
  }

  @override
  void dispose() {
    _clearAllCaches();
    super.dispose();
  }

  /// Computes a value once and caches it until invalidated
  ///
  /// [key] - Unique identifier for the cached value
  /// [computation] - Function that computes the value
  /// [dependencies] - Optional list of dependencies that trigger cache invalidation
  V computeOnce<V>(
    String key,
    V Function() computation, {
    List<dynamic>? dependencies,
  }) {
    // Check if we're already computing this key to prevent infinite loops
    if (_computingKeys.contains(key)) {
      if (enableCacheDebugLogging) {
        debugPrint(
          'BuildOptimizationMixin: Circular computation detected for key: $key',
        );
      }
      return computation();
    }

    // Check if cached value exists and is still valid
    if (_computedCache.containsKey(key)) {
      final cachedValue = _computedCache[key];
      if (_isCacheValid(key, dependencies)) {
        if (enableCacheDebugLogging) {
          debugPrint('BuildOptimizationMixin: Cache hit for key: $key');
        }
        return cachedValue as V;
      }
    }

    // Compute and cache the value
    _computingKeys.add(key);
    try {
      if (enableCacheDebugLogging) {
        debugPrint('BuildOptimizationMixin: Computing value for key: $key');
      }

      final value = computation();
      _computedCache[key] = value;

      // Store dependencies hash for validation
      if (dependencies != null) {
        _computedCache['${key}_deps'] = _hashDependencies(dependencies);
      }

      if (enableCacheDebugLogging) {
        debugPrint('BuildOptimizationMixin: Cached value for key: $key');
      }

      return value;
    } finally {
      _computingKeys.remove(key);
    }
  }

  /// Builds a widget once and caches it until invalidated
  ///
  /// [key] - Unique identifier for the cached widget
  /// [builder] - Function that builds the widget
  /// [dependencies] - Optional list of dependencies that trigger cache invalidation
  Widget buildOnce(
    String key,
    Widget Function() builder, {
    List<dynamic>? dependencies,
  }) {
    // Check if cached widget exists and is still valid
    if (_widgetCache.containsKey(key)) {
      if (_isCacheValid(key, dependencies)) {
        if (enableCacheDebugLogging) {
          debugPrint('BuildOptimizationMixin: Widget cache hit for key: $key');
        }
        return _widgetCache[key]!;
      }
    }

    // Build and cache the widget
    if (enableCacheDebugLogging) {
      debugPrint('BuildOptimizationMixin: Building widget for key: $key');
    }

    final widget = builder();
    _widgetCache[key] = widget;

    // Store dependencies hash for validation
    if (dependencies != null) {
      _computedCache['${key}_widget_deps'] = _hashDependencies(dependencies);
    }

    if (enableCacheDebugLogging) {
      debugPrint('BuildOptimizationMixin: Cached widget for key: $key');
    }

    return widget;
  }

  /// Memoizes an expensive computation with automatic dependency tracking
  ///
  /// [key] - Unique identifier for the memoized value
  /// [computation] - Function that computes the value
  /// [dependencies] - List of dependencies that trigger recomputation
  V memoize<V>(
    String key,
    V Function() computation,
    List<dynamic> dependencies,
  ) {
    return computeOnce(key, computation, dependencies: dependencies);
  }

  /// Invalidates cache for a specific key
  void invalidateCache([String? key]) {
    if (key != null) {
      _computedCache.remove(key);
      _computedCache.remove('${key}_deps');
      _widgetCache.remove(key);
      _computedCache.remove('${key}_widget_deps');

      if (enableCacheDebugLogging) {
        debugPrint('BuildOptimizationMixin: Invalidated cache for key: $key');
      }
    } else {
      _clearAllCaches();
      _lastCacheInvalidation = DateTime.now();

      if (enableCacheDebugLogging) {
        debugPrint('BuildOptimizationMixin: Invalidated all caches');
      }
    }
  }

  /// Invalidates all cached values and widgets
  void invalidateAllCaches() {
    invalidateCache();
  }

  /// Checks if a cached value is still valid based on dependencies and age
  bool _isCacheValid(String key, List<dynamic>? dependencies) {
    // Check cache age
    if (_lastCacheInvalidation != null) {
      final cacheAge = DateTime.now()
          .difference(_lastCacheInvalidation!)
          .inMilliseconds;
      if (cacheAge > maxCacheAge) {
        return false;
      }
    }

    // Check dependencies if provided
    if (dependencies != null) {
      final currentHash = _hashDependencies(dependencies);
      final cachedHash =
          _computedCache['${key}_deps'] ?? _computedCache['${key}_widget_deps'];

      if (cachedHash != currentHash) {
        return false;
      }
    }

    return true;
  }

  /// Creates a hash of dependencies for comparison
  int _hashDependencies(List<dynamic> dependencies) {
    return Object.hashAll(dependencies);
  }

  /// Clears all caches
  void _clearAllCaches() {
    _computedCache.clear();
    _widgetCache.clear();
    _computingKeys.clear();
  }

  /// Gets cache statistics for debugging
  Map<String, dynamic> getCacheStats() {
    return {
      'computedCacheSize': _computedCache.length,
      'widgetCacheSize': _widgetCache.length,
      'computingKeysCount': _computingKeys.length,
      'lastInvalidation': _lastCacheInvalidation?.toIso8601String(),
    };
  }

  /// Precomputes values that are likely to be needed
  ///
  /// This method can be called in initState() or didChangeDependencies()
  /// to precompute expensive values before they're needed in build()
  void precomputeValues(Map<String, dynamic Function()> computations) {
    for (final entry in computations.entries) {
      computeOnce(entry.key, entry.value);
    }
  }

  /// Schedules cache invalidation after the current frame
  void scheduleInvalidation([String? key]) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        invalidateCache(key);
      }
    });
  }
}

/// Extension methods for common optimization patterns
extension BuildOptimizationExtensions on State {
  /// Safely calls setState only if the widget is still mounted
  void safeSetState(VoidCallback fn) {
    if (mounted) {
      // ignore: invalid_use_of_protected_member
      setState(fn);
    }
  }

  /// Debounces setState calls to prevent excessive rebuilds
  void debouncedSetState(
    VoidCallback fn, {
    Duration delay = const Duration(milliseconds: 100),
  }) {
    Future.delayed(delay, () {
      if (mounted) {
        // ignore: invalid_use_of_protected_member
        setState(fn);
      }
    });
  }
}

/// Utility class for managing expensive computations outside of build methods
class ComputationManager {
  static final Map<String, dynamic> _globalCache = {};
  static final Map<String, DateTime> _computationTimes = {};

  /// Performs an expensive computation and caches the result globally
  static V computeExpensive<V>(
    String key,
    V Function() computation, {
    Duration? maxAge,
  }) {
    final now = DateTime.now();

    // Check if we have a cached value that's still valid
    if (_globalCache.containsKey(key)) {
      final computationTime = _computationTimes[key];
      if (computationTime != null && maxAge != null) {
        if (now.difference(computationTime) < maxAge) {
          return _globalCache[key] as V;
        }
      } else if (maxAge == null) {
        return _globalCache[key] as V;
      }
    }

    // Compute and cache the value
    final value = computation();
    _globalCache[key] = value;
    _computationTimes[key] = now;

    return value;
  }

  /// Clears the global computation cache
  static void clearCache([String? key]) {
    if (key != null) {
      _globalCache.remove(key);
      _computationTimes.remove(key);
    } else {
      _globalCache.clear();
      _computationTimes.clear();
    }
  }
}
