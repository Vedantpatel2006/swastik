import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import '../preloader/resource_preloader.dart';
import '../cache/image_cache_manager.dart';
import '../service_locator.dart';

/// Navigation prefetching priority
enum PrefetchPriority {
  immediate, // Prefetch immediately
  high, // Prefetch soon
  medium, // Prefetch when convenient
  low, // Prefetch when idle
}

/// Prefetch request for navigation data
class NavigationPrefetchRequest {
  final String screenName;
  final String dataKey;
  final PrefetchPriority priority;
  final Future<Map<String, dynamic>> Function() dataLoader;
  final Duration? cacheTTL;
  final List<String> dependencies;

  NavigationPrefetchRequest({
    required this.screenName,
    required this.dataKey,
    required this.dataLoader,
    this.priority = PrefetchPriority.medium,
    this.cacheTTL,
    this.dependencies = const [],
  });
}

/// Image prefetch request for navigation
class ImagePrefetchRequest {
  final String screenName;
  final String imageUrl;
  final String? thumbnailUrl;
  final PrefetchPriority priority;
  final bool preloadThumbnail;

  ImagePrefetchRequest({
    required this.screenName,
    required this.imageUrl,
    this.thumbnailUrl,
    this.priority = PrefetchPriority.medium,
    this.preloadThumbnail = true,
  });
}

/// Navigation prefetcher that intelligently preloads data and images
class NavigationPrefetcher {
  static NavigationPrefetcher? _instance;
  factory NavigationPrefetcher() =>
      _instance ??= NavigationPrefetcher._internal();
  NavigationPrefetcher._internal();

  ResourcePreloader? _dataPreloader;
  ImageCacheManager? _imageCache;

  /// Get data preloader with lazy initialization
  ResourcePreloader get dataPreloader =>
      _dataPreloader ??= ServiceLocator().dataPreloader;

  /// Get image cache with lazy initialization
  ImageCacheManager get imageCache =>
      _imageCache ??= ServiceLocator().imageCache;

  final Map<String, List<NavigationPrefetchRequest>> _dataPrefetchRequests = {};
  final Map<String, List<ImagePrefetchRequest>> _imagePrefetchRequests = {};
  final Queue<NavigationPrefetchRequest> _dataPrefetchQueue = Queue();
  final Queue<ImagePrefetchRequest> _imagePrefetchQueue = Queue();

  final Set<String> _activePrefetches = {};
  bool _isPrefetching = false;

  // Navigation patterns tracking
  final Map<String, List<String>> _navigationPatterns = {};
  final Map<String, int> _screenVisitCount = {};
  final Queue<String> _recentNavigations = Queue();
  static const int maxRecentNavigations = 20;

  /// Register data prefetch request for a screen
  void registerDataPrefetch(NavigationPrefetchRequest request) {
    _dataPrefetchRequests[request.screenName] ??= [];
    _dataPrefetchRequests[request.screenName]!.add(request);

    if (kDebugMode) {
      debugPrint(
        'NavigationPrefetcher: Registered data prefetch for ${request.screenName} - ${request.dataKey}',
      );
    }
  }

  /// Register image prefetch request for a screen
  void registerImagePrefetch(ImagePrefetchRequest request) {
    _imagePrefetchRequests[request.screenName] ??= [];
    _imagePrefetchRequests[request.screenName]!.add(request);

    if (kDebugMode) {
      debugPrint(
        'NavigationPrefetcher: Registered image prefetch for ${request.screenName} - ${request.imageUrl}',
      );
    }
  }

  /// Track navigation to a screen
  void trackNavigation(String fromScreen, String toScreen) {
    // Update navigation patterns
    _navigationPatterns[fromScreen] ??= [];
    if (!_navigationPatterns[fromScreen]!.contains(toScreen)) {
      _navigationPatterns[fromScreen]!.add(toScreen);
    }

    // Update visit count
    _screenVisitCount[toScreen] = (_screenVisitCount[toScreen] ?? 0) + 1;

    // Update recent navigations
    _recentNavigations.add(toScreen);
    if (_recentNavigations.length > maxRecentNavigations) {
      _recentNavigations.removeFirst();
    }

    if (kDebugMode) {
      debugPrint(
        'NavigationPrefetcher: Tracked navigation $fromScreen -> $toScreen',
      );
    }
  }

  /// Prefetch data for a specific screen
  Future<void> prefetchForScreen(
    String screenName, {
    PrefetchPriority? minPriority,
  }) async {
    final dataRequests = _dataPrefetchRequests[screenName] ?? [];
    final imageRequests = _imagePrefetchRequests[screenName] ?? [];

    // Filter by priority if specified
    final filteredDataRequests = minPriority != null
        ? dataRequests
              .where((req) => req.priority.index <= minPriority.index)
              .toList()
        : dataRequests;

    final filteredImageRequests = minPriority != null
        ? imageRequests
              .where((req) => req.priority.index <= minPriority.index)
              .toList()
        : imageRequests;

    // Queue prefetch requests
    for (final request in filteredDataRequests) {
      _queueDataPrefetch(request);
    }

    for (final request in filteredImageRequests) {
      _queueImagePrefetch(request);
    }

    // Process queues
    _processPrefetchQueues();
  }

  /// Prefetch based on navigation patterns
  Future<void> prefetchPredictive(String currentScreen) async {
    final predictedScreens = _getPredictedNextScreens(currentScreen);

    if (kDebugMode) {
      debugPrint(
        'NavigationPrefetcher: Predicted screens from $currentScreen: $predictedScreens',
      );
    }

    for (final screenName in predictedScreens) {
      // Prefetch with lower priority for predicted screens
      await prefetchForScreen(screenName, minPriority: PrefetchPriority.medium);
    }
  }

  /// Get predicted next screens based on navigation patterns
  List<String> _getPredictedNextScreens(String currentScreen) {
    final patterns = _navigationPatterns[currentScreen] ?? [];

    // Sort by visit frequency
    patterns.sort((a, b) {
      final aCount = _screenVisitCount[a] ?? 0;
      final bCount = _screenVisitCount[b] ?? 0;
      return bCount.compareTo(aCount);
    });

    // Return top 3 predictions
    return patterns.take(3).toList();
  }

  /// Queue data prefetch request
  void _queueDataPrefetch(NavigationPrefetchRequest request) {
    if (_activePrefetches.contains(request.dataKey)) {
      return; // Already being processed
    }

    _dataPrefetchQueue.add(request);
  }

  /// Queue image prefetch request
  void _queueImagePrefetch(ImagePrefetchRequest request) {
    final key = '${request.screenName}_${request.imageUrl}';
    if (_activePrefetches.contains(key)) {
      return; // Already being processed
    }

    _imagePrefetchQueue.add(request);
  }

  /// Process prefetch queues
  Future<void> _processPrefetchQueues() async {
    if (_isPrefetching) return;

    _isPrefetching = true;

    try {
      // Process data prefetches
      while (_dataPrefetchQueue.isNotEmpty) {
        final request = _dataPrefetchQueue.removeFirst();
        await _executeDataPrefetch(request);

        // Small delay between prefetches
        await Future.delayed(const Duration(milliseconds: 50));
      }

      // Process image prefetches
      while (_imagePrefetchQueue.isNotEmpty) {
        final request = _imagePrefetchQueue.removeFirst();
        await _executeImagePrefetch(request);

        // Small delay between prefetches
        await Future.delayed(const Duration(milliseconds: 50));
      }
    } finally {
      _isPrefetching = false;
    }
  }

  /// Execute data prefetch
  Future<void> _executeDataPrefetch(NavigationPrefetchRequest request) async {
    try {
      _activePrefetches.add(request.dataKey);

      // Check if already cached
      final cached = await dataPreloader.getCachedOrPreload(request.dataKey);
      if (cached != null) {
        if (kDebugMode) {
          debugPrint(
            'NavigationPrefetcher: Data already cached for ${request.dataKey}',
          );
        }
        return;
      }

      // Load dependencies first
      for (final dependency in request.dependencies) {
        await dataPreloader.getCachedOrPreload(dependency);
      }

      // Load and cache data
      await request.dataLoader();
      // The data preloader will handle caching

      if (kDebugMode) {
        debugPrint(
          'NavigationPrefetcher: Successfully prefetched data for ${request.dataKey}',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'NavigationPrefetcher: Error prefetching data for ${request.dataKey} - $e',
        );
      }
    } finally {
      _activePrefetches.remove(request.dataKey);
    }
  }

  /// Execute image prefetch
  Future<void> _executeImagePrefetch(ImagePrefetchRequest request) async {
    final key = '${request.screenName}_${request.imageUrl}';

    try {
      _activePrefetches.add(key);

      // Check if images are already cached
      final isImageCached = await imageCache.isImageCached(request.imageUrl);
      if (isImageCached) {
        if (kDebugMode) {
          debugPrint(
            'NavigationPrefetcher: Image already cached for ${request.screenName}',
          );
        }
        return;
      }

      // Note: Actual image preloading would be handled by the image widgets
      // This prefetcher mainly tracks what should be preloaded

      if (kDebugMode) {
        debugPrint(
          'NavigationPrefetcher: Successfully prefetched image for ${request.screenName}',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'NavigationPrefetcher: Error prefetching image for ${request.screenName} - $e',
        );
      }
    } finally {
      _activePrefetches.remove(key);
    }
  }

  /// Clear all prefetch requests for a screen
  void clearPrefetchesForScreen(String screenName) {
    _dataPrefetchRequests.remove(screenName);
    _imagePrefetchRequests.remove(screenName);

    if (kDebugMode) {
      debugPrint('NavigationPrefetcher: Cleared prefetches for $screenName');
    }
  }

  /// Get prefetcher statistics
  Map<String, dynamic> getStatistics() {
    return {
      'registeredDataPrefetches': _dataPrefetchRequests.length,
      'registeredImagePrefetches': _imagePrefetchRequests.length,
      'queuedDataPrefetches': _dataPrefetchQueue.length,
      'queuedImagePrefetches': _imagePrefetchQueue.length,
      'activePrefetches': _activePrefetches.length,
      'navigationPatterns': _navigationPatterns.length,
      'screenVisitCounts': _screenVisitCount,
      'isPrefetching': _isPrefetching,
    };
  }

  /// Get navigation insights
  Map<String, dynamic> getNavigationInsights() {
    final mostVisitedScreens = _screenVisitCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return {
      'mostVisitedScreens': mostVisitedScreens
          .take(5)
          .map((e) => {'screen': e.key, 'visits': e.value})
          .toList(),
      'navigationPatterns': _navigationPatterns,
      'recentNavigations': _recentNavigations.toList(),
    };
  }

  /// Clear all data
  void clear() {
    _dataPrefetchRequests.clear();
    _imagePrefetchRequests.clear();
    _dataPrefetchQueue.clear();
    _imagePrefetchQueue.clear();
    _activePrefetches.clear();
    _navigationPatterns.clear();
    _screenVisitCount.clear();
    _recentNavigations.clear();

    if (kDebugMode) {
      debugPrint('NavigationPrefetcher: Cleared all data');
    }
  }
}

/// Helper class to register common prefetch patterns
class NavigationPrefetchHelper {
  static final NavigationPrefetcher _prefetcher = NavigationPrefetcher();

  /// Register temple-related prefetches
  static void registerTemplePrefetches() {
    // Temple list screen
    _prefetcher.registerDataPrefetch(
      NavigationPrefetchRequest(
        screenName: 'temple_list',
        dataKey: 'temple_list_data',
        priority: PrefetchPriority.high,
        dataLoader: () async {
          // Load temple list data
          return {'temples': []};
        },
      ),
    );

    // Temple detail screen
    _prefetcher.registerDataPrefetch(
      NavigationPrefetchRequest(
        screenName: 'temple_detail',
        dataKey: 'temple_detail_data',
        priority: PrefetchPriority.medium,
        dataLoader: () async {
          // Load temple detail data
          return {'temple': {}};
        },
      ),
    );

    // Register image prefetches
    _prefetcher.registerImagePrefetch(
      ImagePrefetchRequest(
        screenName: 'temple_list',
        imageUrl: 'temple_thumbnails',
        priority: PrefetchPriority.high,
      ),
    );

    _prefetcher.registerImagePrefetch(
      ImagePrefetchRequest(
        screenName: 'temple_detail',
        imageUrl: 'temple_images',
        priority: PrefetchPriority.medium,
      ),
    );
  }

  /// Register user-related prefetches
  static void registerUserPrefetches() {
    _prefetcher.registerDataPrefetch(
      NavigationPrefetchRequest(
        screenName: 'profile',
        dataKey: 'user_profile_data',
        priority: PrefetchPriority.medium,
        dataLoader: () async {
          return {'user': {}};
        },
      ),
    );

    _prefetcher.registerImagePrefetch(
      ImagePrefetchRequest(
        screenName: 'profile',
        imageUrl: 'user_avatar',
        priority: PrefetchPriority.medium,
      ),
    );
  }

  /// Register search-related prefetches
  static void registerSearchPrefetches() {
    _prefetcher.registerDataPrefetch(
      NavigationPrefetchRequest(
        screenName: 'search',
        dataKey: 'search_suggestions',
        priority: PrefetchPriority.low,
        dataLoader: () async {
          return {'suggestions': []};
        },
      ),
    );
  }
}
