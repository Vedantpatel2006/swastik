import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../cache/data_cache_manager.dart';
import '../service_locator.dart';

/// Priority levels for preloading operations
enum PreloadPriority {
  critical, // Must be loaded immediately
  high, // Should be loaded soon
  medium, // Can be loaded when convenient
  low, // Load when idle
}

/// Preload strategy based on user behavior
enum PreloadStrategy {
  immediate, // Load right away
  predictive, // Load based on user patterns
  lazy, // Load when needed
  background, // Load in background when idle
}

/// Preload request configuration
class PreloadRequest {
  final String key;
  final String description;
  final PreloadPriority priority;
  final PreloadStrategy strategy;
  final Future<Map<String, dynamic>> Function() dataLoader;
  final Duration? cacheTTL;
  final List<String> dependencies;
  final bool requiresNetwork;

  PreloadRequest({
    required this.key,
    required this.description,
    required this.dataLoader,
    this.priority = PreloadPriority.medium,
    this.strategy = PreloadStrategy.predictive,
    this.cacheTTL,
    this.dependencies = const [],
    this.requiresNetwork = true,
  });

  @override
  String toString() => 'PreloadRequest($key, $priority, $strategy)';
}

/// Result of a preload operation
class PreloadResult {
  final String key;
  final bool success;
  final Map<String, dynamic>? data;
  final String? error;
  final Duration loadTime;
  final bool fromCache;

  PreloadResult({
    required this.key,
    required this.success,
    this.data,
    this.error,
    required this.loadTime,
    this.fromCache = false,
  });

  @override
  String toString() =>
      'PreloadResult($key, success: $success, fromCache: $fromCache, time: ${loadTime.inMilliseconds}ms)';
}

/// User behavior tracking for predictive preloading
class UserBehaviorTracker {
  final Map<String, int> _screenVisitCount = {};
  final Map<String, DateTime> _lastVisitTime = {};
  final Map<String, List<String>> _navigationPatterns = {};
  final Queue<String> _recentScreens = Queue();
  static const int maxRecentScreens = 10;

  /// Track screen visit
  void trackScreenVisit(String screenName) {
    _screenVisitCount[screenName] = (_screenVisitCount[screenName] ?? 0) + 1;
    _lastVisitTime[screenName] = DateTime.now();

    // Track navigation patterns
    if (_recentScreens.isNotEmpty) {
      final previousScreen = _recentScreens.last;
      _navigationPatterns[previousScreen] ??= [];
      if (!_navigationPatterns[previousScreen]!.contains(screenName)) {
        _navigationPatterns[previousScreen]!.add(screenName);
      }
    }

    _recentScreens.add(screenName);
    if (_recentScreens.length > maxRecentScreens) {
      _recentScreens.removeFirst();
    }

    if (kDebugMode) {
      debugPrint(
        'UserBehavior: Visited $screenName (${_screenVisitCount[screenName]} times)',
      );
    }
  }

  /// Get likely next screens based on patterns
  List<String> getPredictedNextScreens(String currentScreen) {
    final patterns = _navigationPatterns[currentScreen] ?? [];

    // Sort by visit frequency
    patterns.sort((a, b) {
      final aCount = _screenVisitCount[a] ?? 0;
      final bCount = _screenVisitCount[b] ?? 0;
      return bCount.compareTo(aCount);
    });

    return patterns.take(3).toList(); // Return top 3 predictions
  }

  /// Get frequently visited screens
  List<String> getFrequentScreens({int limit = 5}) {
    final entries = _screenVisitCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return entries.take(limit).map((e) => e.key).toList();
  }

  /// Check if screen was visited recently
  bool wasVisitedRecently(
    String screenName, {
    Duration within = const Duration(hours: 1),
  }) {
    final lastVisit = _lastVisitTime[screenName];
    if (lastVisit == null) return false;

    return DateTime.now().difference(lastVisit) <= within;
  }
}

/// Intelligent data preloader with predictive capabilities
class DataPreloader {
  static DataPreloader? _instance;
  factory DataPreloader() => _instance ??= DataPreloader._internal();
  DataPreloader._internal();

  DataCacheManager? _cacheManager;
  final UserBehaviorTracker _behaviorTracker = UserBehaviorTracker();

  /// Get cache manager with lazy initialization
  DataCacheManager get cacheManager {
    _cacheManager ??= ServiceLocator().dataCache;
    return _cacheManager!;
  }

  final Map<String, PreloadRequest> _preloadRequests = {};
  final Map<String, Timer> _scheduledPreloads = {};
  final Set<String> _activePreloads = {};
  final Queue<PreloadRequest> _preloadQueue = Queue();

  bool _isInitialized = false;
  bool _isPreloading = false;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  bool _hasNetworkConnection = true;

  // Statistics
  int _totalPreloads = 0;
  int _successfulPreloads = 0;
  int _cacheHits = 0;
  final List<PreloadResult> _recentResults = [];

  /// Initialize the data preloader
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Monitor network connectivity
      _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
        result,
      ) {
        _hasNetworkConnection = result != ConnectivityResult.none;

        if (kDebugMode) {
          debugPrint(
            'DataPreloader: Network connectivity changed - $_hasNetworkConnection',
          );
        }

        if (_hasNetworkConnection) {
          _processQueuedPreloads();
        }
      });

      // Check initial connectivity
      final connectivity = await Connectivity().checkConnectivity();
      _hasNetworkConnection = connectivity != ConnectivityResult.none;

      _isInitialized = true;

      if (kDebugMode) {
        debugPrint('DataPreloader: Initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('DataPreloader: Error initializing - $e');
      }
      rethrow;
    }
  }

  /// Register a preload request
  void registerPreloadRequest(PreloadRequest request) {
    _preloadRequests[request.key] = request;

    if (kDebugMode) {
      debugPrint(
        'DataPreloader: Registered ${request.key} with priority ${request.priority}',
      );
    }
  }

  /// Preload data for app startup
  Future<void> preloadStartupData() async {
    if (!_isInitialized) {
      throw StateError('DataPreloader not initialized');
    }

    final startupRequests = _preloadRequests.values
        .where((req) => req.priority == PreloadPriority.critical)
        .toList();

    if (startupRequests.isEmpty) {
      if (kDebugMode) {
        debugPrint('DataPreloader: No critical startup data to preload');
      }
      return;
    }

    if (kDebugMode) {
      debugPrint(
        'DataPreloader: Preloading ${startupRequests.length} critical items for startup',
      );
    }

    final futures = startupRequests.map((request) => _executePreload(request));
    await Future.wait(futures);

    if (kDebugMode) {
      debugPrint('DataPreloader: Startup preloading completed');
    }
  }

  /// Preload data based on user behavior prediction
  Future<void> preloadPredictiveData(String currentScreen) async {
    if (!_isInitialized || !_hasNetworkConnection) return;

    _behaviorTracker.trackScreenVisit(currentScreen);

    final predictedScreens = _behaviorTracker.getPredictedNextScreens(
      currentScreen,
    );

    if (predictedScreens.isEmpty) return;

    if (kDebugMode) {
      debugPrint(
        'DataPreloader: Predicted next screens from $currentScreen: $predictedScreens',
      );
    }

    for (final screenName in predictedScreens) {
      final requests = _preloadRequests.values
          .where(
            (req) =>
                req.key.contains(screenName.toLowerCase()) &&
                req.strategy == PreloadStrategy.predictive,
          )
          .toList();

      for (final request in requests) {
        _schedulePreload(request, delay: const Duration(milliseconds: 500));
      }
    }
  }

  /// Preload data for a specific screen or feature
  Future<PreloadResult> preloadForScreen(
    String screenName, {
    bool force = false,
  }) async {
    final screenKey = screenName.toLowerCase();
    final request = _preloadRequests[screenKey];

    if (request == null) {
      return PreloadResult(
        key: screenKey,
        success: false,
        error: 'No preload request found for $screenName',
        loadTime: Duration.zero,
      );
    }

    return await _executePreload(request, force: force);
  }

  /// Get cached data if available, otherwise trigger preload
  Future<Map<String, dynamic>?> getCachedOrPreload(String key) async {
    // First check cache
    final cachedData = await cacheManager.get(key);
    if (cachedData != null) {
      _cacheHits++;

      if (kDebugMode) {
        debugPrint('DataPreloader: Cache hit for $key');
      }

      return cachedData;
    }

    // If not in cache, try to preload
    final request = _preloadRequests[key];
    if (request != null) {
      final result = await _executePreload(request);
      return result.success ? result.data : null;
    }

    return null;
  }

  /// Schedule a preload operation with delay
  void _schedulePreload(
    PreloadRequest request, {
    Duration delay = Duration.zero,
  }) {
    // Cancel existing scheduled preload for this key
    _scheduledPreloads[request.key]?.cancel();

    _scheduledPreloads[request.key] = Timer(delay, () {
      _queuePreload(request);
      _scheduledPreloads.remove(request.key);
    });
  }

  /// Queue a preload request for background processing
  void _queuePreload(PreloadRequest request) {
    if (_activePreloads.contains(request.key)) {
      return; // Already being processed
    }

    _preloadQueue.add(request);
    _processQueuedPreloads();
  }

  /// Process queued preload requests
  Future<void> _processQueuedPreloads() async {
    if (_isPreloading || _preloadQueue.isEmpty || !_hasNetworkConnection) {
      return;
    }

    _isPreloading = true;

    try {
      while (_preloadQueue.isNotEmpty && _hasNetworkConnection) {
        final request = _preloadQueue.removeFirst();

        // Skip if requires network but no connection
        if (request.requiresNetwork && !_hasNetworkConnection) {
          continue;
        }

        await _executePreload(request);

        // Small delay between preloads to avoid overwhelming the system
        await Future.delayed(const Duration(milliseconds: 100));
      }
    } finally {
      _isPreloading = false;
    }
  }

  /// Execute a preload operation
  Future<PreloadResult> _executePreload(
    PreloadRequest request, {
    bool force = false,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      _activePreloads.add(request.key);
      _totalPreloads++;

      // Check if already cached and not forcing reload
      if (!force) {
        final cached = await cacheManager.get(request.key);
        if (cached != null) {
          stopwatch.stop();
          _cacheHits++;

          final result = PreloadResult(
            key: request.key,
            success: true,
            data: cached,
            loadTime: stopwatch.elapsed,
            fromCache: true,
          );

          _recordResult(result);
          return result;
        }
      }

      // Check dependencies
      for (final dependency in request.dependencies) {
        final depCached = await cacheManager.get(dependency);
        if (depCached == null) {
          // Try to load dependency first
          final depRequest = _preloadRequests[dependency];
          if (depRequest != null) {
            await _executePreload(depRequest);
          }
        }
      }

      // Load data
      final data = await request.dataLoader();

      // Cache the result
      await cacheManager.set(request.key, data, ttl: request.cacheTTL);

      stopwatch.stop();
      _successfulPreloads++;

      final result = PreloadResult(
        key: request.key,
        success: true,
        data: data,
        loadTime: stopwatch.elapsed,
        fromCache: false,
      );

      _recordResult(result);

      if (kDebugMode) {
        debugPrint(
          'DataPreloader: Successfully preloaded ${request.key} in ${stopwatch.elapsedMilliseconds}ms',
        );
      }

      return result;
    } catch (e) {
      stopwatch.stop();

      final result = PreloadResult(
        key: request.key,
        success: false,
        error: e.toString(),
        loadTime: stopwatch.elapsed,
      );

      _recordResult(result);

      if (kDebugMode) {
        debugPrint('DataPreloader: Failed to preload ${request.key} - $e');
      }

      return result;
    } finally {
      _activePreloads.remove(request.key);
    }
  }

  /// Record preload result for statistics
  void _recordResult(PreloadResult result) {
    _recentResults.add(result);

    // Keep only recent results
    if (_recentResults.length > 50) {
      _recentResults.removeAt(0);
    }
  }

  /// Get preloader statistics
  Map<String, dynamic> getStatistics() {
    final successRate = _totalPreloads > 0
        ? _successfulPreloads / _totalPreloads
        : 0.0;
    final cacheHitRate = _totalPreloads > 0 ? _cacheHits / _totalPreloads : 0.0;

    return {
      'totalPreloads': _totalPreloads,
      'successfulPreloads': _successfulPreloads,
      'cacheHits': _cacheHits,
      'successRate': successRate,
      'cacheHitRate': cacheHitRate,
      'activePreloads': _activePreloads.length,
      'queuedPreloads': _preloadQueue.length,
      'registeredRequests': _preloadRequests.length,
      'hasNetworkConnection': _hasNetworkConnection,
      'frequentScreens': _behaviorTracker.getFrequentScreens(),
    };
  }

  /// Get user behavior insights
  Map<String, dynamic> getBehaviorInsights() {
    return {
      'frequentScreens': _behaviorTracker.getFrequentScreens(),
      'recentResults': _recentResults
          .take(10)
          .map((r) => r.toString())
          .toList(),
    };
  }

  /// Clear all cached preload data
  Future<void> clearCache() async {
    await cacheManager.clear();

    if (kDebugMode) {
      debugPrint('DataPreloader: Cache cleared');
    }
  }

  /// Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();

    for (final timer in _scheduledPreloads.values) {
      timer.cancel();
    }
    _scheduledPreloads.clear();

    _preloadQueue.clear();
    _activePreloads.clear();

    _isInitialized = false;

    if (kDebugMode) {
      debugPrint('DataPreloader: Disposed');
    }
  }
}
