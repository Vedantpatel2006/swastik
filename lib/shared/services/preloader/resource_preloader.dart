import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../cache/data_cache_manager.dart';
import '../cache/image_cache_manager.dart';
import '../service_locator.dart';

/// Resource type for preloading
enum ResourceType {
  criticalData,
  images,
  fonts,
  configuration,
  userPreferences,
}

/// User action type for tracking
enum UserActionType { screenVisit, buttonTap, search, scroll }

/// Resource preload configuration
class ResourcePreloadConfig {
  final String key;
  final ResourceType type;
  final int priority; // Lower number = higher priority
  final Future<void> Function() loader;
  final bool requiresNetwork;
  final Duration timeout;

  ResourcePreloadConfig({
    required this.key,
    required this.type,
    required this.loader,
    this.priority = 5,
    this.requiresNetwork = false,
    this.timeout = const Duration(seconds: 30),
  });
}

/// Result of resource preloading
class ResourcePreloadResult {
  final String key;
  final ResourceType type;
  final bool success;
  final String? error;
  final Duration loadTime;

  ResourcePreloadResult({
    required this.key,
    required this.type,
    required this.success,
    this.error,
    required this.loadTime,
  });

  @override
  String toString() =>
      'ResourcePreloadResult($key, $type, success: $success, time: ${loadTime.inMilliseconds}ms)';
}

/// Resource preloader for app startup optimization
class ResourcePreloader {
  static ResourcePreloader? _instance;
  factory ResourcePreloader() => _instance ??= ResourcePreloader._internal();
  ResourcePreloader._internal();

  DataCacheManager? _dataCache;
  ImageCacheManager? _imageCache;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Protected getters for testing
  @protected
  DataCacheManager get dataCache {
    _dataCache ??= ServiceLocator().dataCache;
    return _dataCache!;
  }

  @protected
  ImageCacheManager get imageCache {
    _imageCache ??= ServiceLocator().imageCache;
    return _imageCache!;
  }

  @protected
  FirebaseFirestore get firestore => _firestore;

  final List<ResourcePreloadConfig> _preloadConfigs = [];
  final List<ResourcePreloadResult> _results = [];
  bool _isInitialized = false;
  bool _isPreloading = false;

  /// Initialize the resource preloader
  Future<void> initialize() async {
    if (_isInitialized) return;

    _registerDefaultPreloadConfigs();
    _isInitialized = true;

    if (kDebugMode) {
      debugPrint(
        'ResourcePreloader: Initialized with ${_preloadConfigs.length} configurations',
      );
    }
  }

  /// Register default preload configurations
  void _registerDefaultPreloadConfigs() {
    // Critical app configuration
    registerPreloadConfig(
      ResourcePreloadConfig(
        key: 'app_config',
        type: ResourceType.configuration,
        priority: 1,
        requiresNetwork: true,
        loader: _preloadAppConfiguration,
      ),
    );

    // User preferences and settings
    registerPreloadConfig(
      ResourcePreloadConfig(
        key: 'user_preferences',
        type: ResourceType.userPreferences,
        priority: 2,
        requiresNetwork: false,
        loader: _preloadUserPreferences,
      ),
    );

    // Critical temple data
    registerPreloadConfig(
      ResourcePreloadConfig(
        key: 'featured_temples',
        type: ResourceType.criticalData,
        priority: 3,
        requiresNetwork: true,
        loader: _preloadFeaturedTemples,
      ),
    );

    // Essential images
    registerPreloadConfig(
      ResourcePreloadConfig(
        key: 'essential_images',
        type: ResourceType.images,
        priority: 4,
        requiresNetwork: true,
        loader: _preloadEssentialImages,
      ),
    );

    // Font preloading (if needed)
    registerPreloadConfig(
      ResourcePreloadConfig(
        key: 'custom_fonts',
        type: ResourceType.fonts,
        priority: 5,
        requiresNetwork: false,
        loader: _preloadCustomFonts,
      ),
    );
  }

  /// Register a custom preload configuration
  void registerPreloadConfig(ResourcePreloadConfig config) {
    _preloadConfigs.add(config);

    // Sort by priority (lower number = higher priority)
    _preloadConfigs.sort((a, b) => a.priority.compareTo(b.priority));

    if (kDebugMode) {
      debugPrint(
        'ResourcePreloader: Registered ${config.key} with priority ${config.priority}',
      );
    }
  }

  /// Preload all critical resources for app startup
  Future<List<ResourcePreloadResult>> preloadStartupResources({
    Function(String status)? onStatusUpdate,
    Function(double progress)? onProgress,
  }) async {
    if (!_isInitialized) {
      throw StateError('ResourcePreloader not initialized');
    }

    if (_isPreloading) {
      if (kDebugMode) {
        debugPrint('ResourcePreloader: Already preloading, skipping');
      }
      return _results;
    }

    _isPreloading = true;
    _results.clear();

    try {
      onStatusUpdate?.call('Initializing app resources...');

      final criticalConfigs = _preloadConfigs
          .where((config) => config.priority <= 3)
          .toList();

      if (kDebugMode) {
        debugPrint(
          'ResourcePreloader: Starting preload of ${criticalConfigs.length} critical resources',
        );
      }

      for (int i = 0; i < criticalConfigs.length; i++) {
        final config = criticalConfigs[i];
        final progress = (i + 1) / criticalConfigs.length;

        onStatusUpdate?.call('Loading ${config.key}...');
        onProgress?.call(progress * 0.8); // Reserve 20% for final setup

        final result = await _executePreload(config);
        _results.add(result);

        if (kDebugMode) {
          debugPrint('ResourcePreloader: ${result.toString()}');
        }
      }

      // Final setup phase
      onStatusUpdate?.call('Finalizing setup...');
      onProgress?.call(0.9);

      await _finalizeSetup();

      onStatusUpdate?.call('Ready!');
      onProgress?.call(1.0);

      if (kDebugMode) {
        final successCount = _results.where((r) => r.success).length;
        debugPrint(
          'ResourcePreloader: Completed startup preload - $successCount/${_results.length} successful',
        );
      }

      return _results;
    } finally {
      _isPreloading = false;
    }
  }

  /// Execute a single preload operation
  Future<ResourcePreloadResult> _executePreload(
    ResourcePreloadConfig config,
  ) async {
    final stopwatch = Stopwatch()..start();

    try {
      await config.loader().timeout(config.timeout);

      stopwatch.stop();

      return ResourcePreloadResult(
        key: config.key,
        type: config.type,
        success: true,
        loadTime: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();

      return ResourcePreloadResult(
        key: config.key,
        type: config.type,
        success: false,
        error: e.toString(),
        loadTime: stopwatch.elapsed,
      );
    }
  }

  /// Preload app configuration
  Future<void> _preloadAppConfiguration() async {
    try {
      // Load app configuration from Firestore
      final configDoc = await firestore
          .collection('app_config')
          .doc('general')
          .get();

      if (configDoc.exists) {
        await dataCache.cacheData(
          'app_config',
          configDoc.data() ?? {},
          ttl: const Duration(hours: 6),
        );
      }

      if (kDebugMode) {
        debugPrint('ResourcePreloader: App configuration preloaded');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'ResourcePreloader: Failed to preload app configuration - $e',
        );
      }
      rethrow;
    }
  }

  /// Preload user preferences
  Future<void> _preloadUserPreferences() async {
    try {
      // This would typically load from SharedPreferences or secure storage
      // For now, we'll create a placeholder
      final preferences = {
        'theme': 'light',
        'language': 'en',
        'notifications_enabled': true,
        'cache_images': true,
        'preload_data': true,
      };

      await dataCache.cacheData(
        'user_preferences',
        preferences,
        ttl: const Duration(days: 7),
      );

      if (kDebugMode) {
        debugPrint('ResourcePreloader: User preferences preloaded');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'ResourcePreloader: Failed to preload user preferences - $e',
        );
      }
      rethrow;
    }
  }

  /// Preload featured temples data
  Future<void> _preloadFeaturedTemples() async {
    try {
      final query = await firestore
          .collection('temples')
          .where('featured', isEqualTo: true)
          .limit(10)
          .get();

      final temples = query.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();

      await dataCache.cacheDataList(
        'featured_temples',
        temples,
        ttl: const Duration(hours: 2),
      );

      if (kDebugMode) {
        debugPrint(
          'ResourcePreloader: Featured temples preloaded (${temples.length} items)',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'ResourcePreloader: Failed to preload featured temples - $e',
        );
      }
      rethrow;
    }
  }

  /// Preload essential images
  Future<void> _preloadEssentialImages() async {
    try {
      final essentialImages = [
        'assets/images/swastik.png',
        // Add more essential image paths here
      ];

      for (final imagePath in essentialImages) {
        try {
          // For asset images, we can preload them into memory
          final imageData = await rootBundle.load(imagePath);

          // Cache the image data
          await imageCache.cacheImageFromBytes(
            imagePath,
            imageData.buffer.asUint8List(),
            ttl: const Duration(days: 30),
          );
        } catch (e) {
          if (kDebugMode) {
            debugPrint(
              'ResourcePreloader: Failed to preload image $imagePath - $e',
            );
          }
          // Continue with other images even if one fails
        }
      }

      if (kDebugMode) {
        debugPrint('ResourcePreloader: Essential images preloaded');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'ResourcePreloader: Failed to preload essential images - $e',
        );
      }
      rethrow;
    }
  }

  /// Preload custom fonts
  Future<void> _preloadCustomFonts() async {
    try {
      // Custom fonts are typically loaded automatically by Flutter
      // This is a placeholder for any custom font loading logic

      if (kDebugMode) {
        debugPrint('ResourcePreloader: Custom fonts preloaded');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ResourcePreloader: Failed to preload custom fonts - $e');
      }
      rethrow;
    }
  }

  /// Finalize setup after preloading
  Future<void> _finalizeSetup() async {
    try {
      // Perform any final setup tasks
      await Future.delayed(const Duration(milliseconds: 100));

      if (kDebugMode) {
        debugPrint('ResourcePreloader: Setup finalized');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ResourcePreloader: Failed to finalize setup - $e');
      }
    }
  }

  /// Get preload statistics
  Map<String, dynamic> getStatistics() {
    final successCount = _results.where((r) => r.success).length;
    final totalTime = _results.fold<Duration>(
      Duration.zero,
      (total, result) => total + result.loadTime,
    );

    return {
      'totalConfigs': _preloadConfigs.length,
      'completedPreloads': _results.length,
      'successfulPreloads': successCount,
      'failedPreloads': _results.length - successCount,
      'totalLoadTime': totalTime.inMilliseconds,
      'averageLoadTime': _results.isNotEmpty
          ? (totalTime.inMilliseconds / _results.length).round()
          : 0,
      'isPreloading': _isPreloading,
    };
  }

  /// Get detailed results
  List<ResourcePreloadResult> getResults() => List.unmodifiable(_results);

  /// Clear preload results
  void clearResults() {
    _results.clear();
  }

  /// Track user action (stub method for compatibility)
  void trackUserAction(
    dynamic actionType,
    String screenName, {
    Map<String, dynamic>? metadata,
  }) {
    // Stub implementation - could be extended for analytics
    if (kDebugMode) {
      debugPrint('ResourcePreloader: User action tracked - $screenName');
    }
  }

  /// Get cached data or preload (stub method for compatibility)
  Future<dynamic> getCachedOrPreload(String key) async {
    // Stub implementation - return null for now
    return null;
  }

  /// Dispose resources
  void dispose() {
    _preloadConfigs.clear();
    _results.clear();
    _isInitialized = false;

    if (kDebugMode) {
      debugPrint('ResourcePreloader: Disposed');
    }
  }
}
