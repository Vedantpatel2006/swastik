import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

import '../../models/image_optimization_models.dart';
import '../preloader/intelligent_image_preloader.dart';
import 'enhanced_image_cache_manager.dart';
import 'image_cache_optimizer.dart';

/// Comprehensive image cache service configuration
class ImageCacheServiceConfig {
  final IntelligentCacheConfig cacheConfig;
  final OptimizationStrategy defaultOptimizationStrategy;
  final bool enableIntelligentPreloading;
  final bool enableAutomaticOptimization;
  final bool enablePredictivePreloading;
  final bool enableBackgroundProcessing;
  final int maxConcurrentOperations;
  final Duration optimizationInterval;

  const ImageCacheServiceConfig({
    this.cacheConfig = const IntelligentCacheConfig(),
    this.defaultOptimizationStrategy = OptimizationStrategy.balanced,
    this.enableIntelligentPreloading = true,
    this.enableAutomaticOptimization = true,
    this.enablePredictivePreloading = true,
    this.enableBackgroundProcessing = true,
    this.maxConcurrentOperations = 5,
    this.optimizationInterval = const Duration(hours: 6),
  });
}

/// Image cache operation result
class ImageCacheOperationResult {
  final String operation;
  final String imageKey;
  final bool success;
  final String? cachedPath;
  final String? error;
  final Duration executionTime;
  final Map<String, dynamic> metadata;

  const ImageCacheOperationResult({
    required this.operation,
    required this.imageKey,
    required this.success,
    this.cachedPath,
    this.error,
    required this.executionTime,
    this.metadata = const {},
  });
}

/// Comprehensive image cache service with intelligent caching, preloading, and optimization
class ComprehensiveImageCacheService {
  static final ComprehensiveImageCacheService _instance =
      ComprehensiveImageCacheService._internal();
  factory ComprehensiveImageCacheService() => _instance;
  ComprehensiveImageCacheService._internal();

  // Core components
  EnhancedImageCacheManager? _cacheManager;
  IntelligentImagePreloader? _preloader;
  ImageCacheOptimizer? _optimizer;

  // Configuration
  ImageCacheServiceConfig _config = const ImageCacheServiceConfig();

  // State management
  bool _isInitialized = false;
  final Set<String> _currentOperations = {};
  final List<ImageCacheOperationResult> _operationHistory = [];

  // Statistics
  int _totalOperations = 0;
  int _successfulOperations = 0;
  int _cacheHits = 0;
  int _cacheMisses = 0;
  int _preloadHits = 0;

  /// Initialize the comprehensive image cache service
  Future<void> initialize({ImageCacheServiceConfig? config}) async {
    if (_isInitialized) return;

    try {
      _config = config ?? _config;

      // Initialize core components
      _cacheManager = EnhancedImageCacheManager();
      _preloader = IntelligentImagePreloader();
      _optimizer = ImageCacheOptimizer();

      // Initialize components with configuration
      await _cacheManager!.initialize(config: _config.cacheConfig);

      await _preloader!.initialize(
        cacheManager: _cacheManager,
        enablePredictivePreloading: _config.enablePredictivePreloading,
      );

      await _optimizer!.initialize(
        cacheManager: _cacheManager,
        defaultStrategy: _config.defaultOptimizationStrategy,
        scheduledInterval: _config.optimizationInterval,
        enableBackgroundOptimization: _config.enableBackgroundProcessing,
      );

      _isInitialized = true;

      if (kDebugMode) {
        debugPrint('ComprehensiveImageCacheService: Initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ComprehensiveImageCacheService: Error initializing - $e');
      }
      rethrow;
    }
  }

  /// Get cached image with intelligent fallback and preloading
  Future<File?> getImage(
    String imageKey, {
    String? imagePath,
    String? sourceUrl,
    ImageSizeType preferredSize = ImageSizeType.medium,
    List<ImageFormat> preferredFormats = const [
      ImageFormat.webp,
      ImageFormat.jpeg,
    ],
    bool enablePreloading = true,
    int priority = 5,
    List<String> tags = const [],
    String? userId,
  }) async {
    if (!_isInitialized) await initialize();

    final stopwatch = Stopwatch()..start();
    _totalOperations++;

    try {
      // Check if already in cache
      final cachedFile = await _cacheManager!.getCachedImage(
        imageKey,
        preferredSize: preferredSize,
        preferredFormats: preferredFormats,
      );

      if (cachedFile != null) {
        _cacheHits++;
        _successfulOperations++;

        // Record user access for predictive preloading
        if (userId != null && _config.enablePredictivePreloading) {
          _preloader!.recordImageAccess(userId, imageKey, tags);
        }

        stopwatch.stop();

        _recordOperation(
          ImageCacheOperationResult(
            operation: 'get_cached',
            imageKey: imageKey,
            success: true,
            cachedPath: cachedFile.path,
            executionTime: stopwatch.elapsed,
            metadata: {'size': preferredSize.name, 'fromCache': true},
          ),
        );

        return cachedFile;
      }

      _cacheMisses++;

      // If not in cache and we have a source, try to cache it
      if (imagePath != null) {
        final cachedPath = await _cacheOptimizedImage(
          imageKey,
          imagePath,
          sizeType: preferredSize,
          preferredFormats: preferredFormats,
          sourceUrl: sourceUrl,
          priority: priority,
          tags: tags,
        );

        if (cachedPath != null) {
          _successfulOperations++;

          // Record user access
          if (userId != null && _config.enablePredictivePreloading) {
            _preloader!.recordImageAccess(userId, imageKey, tags);
          }

          stopwatch.stop();

          _recordOperation(
            ImageCacheOperationResult(
              operation: 'get_and_cache',
              imageKey: imageKey,
              success: true,
              cachedPath: cachedPath,
              executionTime: stopwatch.elapsed,
              metadata: {'size': preferredSize.name, 'fromCache': false},
            ),
          );

          return File(cachedPath);
        }
      }

      // If we still don't have the image, trigger preloading for future requests
      if (enablePreloading &&
          _config.enableIntelligentPreloading &&
          imagePath != null) {
        await _preloader!.preloadImage(
          ImagePreloadRequest(
            key: imageKey,
            imagePath: imagePath,
            sourceUrl: sourceUrl,
            sizeType: preferredSize,
            preferredFormats: preferredFormats,
            strategy: PreloadStrategy.onDemand,
            priority: priority,
            tags: tags,
          ),
        );
      }

      stopwatch.stop();

      _recordOperation(
        ImageCacheOperationResult(
          operation: 'get_failed',
          imageKey: imageKey,
          success: false,
          error: 'Image not found in cache and no source provided',
          executionTime: stopwatch.elapsed,
        ),
      );

      return null;
    } catch (e) {
      stopwatch.stop();

      _recordOperation(
        ImageCacheOperationResult(
          operation: 'get_error',
          imageKey: imageKey,
          success: false,
          error: e.toString(),
          executionTime: stopwatch.elapsed,
        ),
      );

      if (kDebugMode) {
        debugPrint(
          'ComprehensiveImageCacheService: Error getting image $imageKey - $e',
        );
      }

      return null;
    }
  }

  /// Cache an optimized image
  Future<String?> _cacheOptimizedImage(
    String imageKey,
    String imagePath, {
    ImageSizeType sizeType = ImageSizeType.medium,
    List<ImageFormat> preferredFormats = const [
      ImageFormat.webp,
      ImageFormat.jpeg,
    ],
    String? sourceUrl,
    int priority = 5,
    List<String> tags = const [],
  }) async {
    if (_currentOperations.contains(imageKey)) {
      // Wait for ongoing operation to complete
      while (_currentOperations.contains(imageKey)) {
        await Future.delayed(const Duration(milliseconds: 100));
      }

      // Check if it's now cached
      final cached = await _cacheManager!.getCachedImage(imageKey);
      return cached?.path;
    }

    _currentOperations.add(imageKey);

    try {
      return await _cacheManager!.cacheOptimizedImage(
        imageKey,
        imagePath,
        sizeType: sizeType,
        preferredFormats: preferredFormats,
        sourceUrl: sourceUrl,
        priority: priority,
        tags: tags,
      );
    } finally {
      _currentOperations.remove(imageKey);
    }
  }

  /// Preload images for anticipated user actions
  Future<void> preloadImages(
    List<String> imageKeys,
    List<String> imagePaths, {
    ImageSizeType sizeType = ImageSizeType.medium,
    PreloadStrategy strategy = PreloadStrategy.onDemand,
    int priority = 5,
    List<String> tags = const [],
    String? userId,
  }) async {
    if (!_isInitialized) await initialize();

    if (!_config.enableIntelligentPreloading) return;

    final requests = <ImagePreloadRequest>[];

    for (int i = 0; i < imageKeys.length && i < imagePaths.length; i++) {
      requests.add(
        ImagePreloadRequest(
          key: imageKeys[i],
          imagePath: imagePaths[i],
          sizeType: sizeType,
          strategy: strategy,
          priority: priority,
          tags: tags,
        ),
      );
    }

    await _preloader!.preloadImages(requests);

    if (kDebugMode) {
      debugPrint(
        'ComprehensiveImageCacheService: Queued ${requests.length} images for preloading',
      );
    }
  }

  /// Preload images by category
  Future<void> preloadByCategory(
    String category,
    Map<String, String> imageMap, {
    ImageSizeType sizeType = ImageSizeType.medium,
    int priority = 5,
  }) async {
    if (!_isInitialized) await initialize();

    await _preloader!.preloadByCategory(
      category,
      imageMap.values.toList(),
      sizeType: sizeType,
      priority: priority,
    );

    if (kDebugMode) {
      debugPrint(
        'ComprehensiveImageCacheService: Queued ${imageMap.length} images for category $category',
      );
    }
  }

  /// Optimize cache with specified strategy
  Future<CacheOptimizationResult> optimizeCache({
    OptimizationStrategy? strategy,
    CleanupTrigger trigger = CleanupTrigger.manual,
  }) async {
    if (!_isInitialized) await initialize();

    if (!_config.enableAutomaticOptimization &&
        trigger != CleanupTrigger.manual) {
      return CacheOptimizationResult(
        taskId: 'disabled_${DateTime.now().millisecondsSinceEpoch}',
        strategy: strategy ?? _config.defaultOptimizationStrategy,
        success: false,
        executionTime: Duration.zero,
        error: 'Automatic optimization is disabled',
      );
    }

    return await _optimizer!.optimizeCache(
      strategy: strategy,
      trigger: trigger,
    );
  }

  /// Clear cache by tags
  Future<void> clearCacheByTags(List<String> tags) async {
    if (!_isInitialized) await initialize();

    await _cacheManager!.clearByTags(tags);

    if (kDebugMode) {
      debugPrint(
        'ComprehensiveImageCacheService: Cleared cache for tags: ${tags.join(", ")}',
      );
    }
  }

  /// Clear all cached images
  Future<void> clearAllCache() async {
    if (!_isInitialized) await initialize();

    // Clear all cache entries
    _cacheManager!.dispose();
    await _cacheManager!.initialize();
    _preloader!.clearQueue();

    if (kDebugMode) {
      debugPrint('ComprehensiveImageCacheService: Cleared all cache');
    }
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStatistics() {
    if (!_isInitialized) {
      return {'error': 'Service not initialized'};
    }

    final cacheStats = _cacheManager!.getDetailedStatistics();
    final preloaderStats = _preloader!.getStatistics();
    final optimizerStats = _optimizer!.getStatistics();

    final hitRate = _totalOperations > 0
        ? (_cacheHits / _totalOperations) * 100
        : 0.0;

    final successRate = _totalOperations > 0
        ? (_successfulOperations / _totalOperations) * 100
        : 0.0;

    return {
      'service': {
        'totalOperations': _totalOperations,
        'successfulOperations': _successfulOperations,
        'successRate': successRate,
        'cacheHits': _cacheHits,
        'cacheMisses': _cacheMisses,
        'hitRate': hitRate,
        'preloadHits': _preloadHits,
        'currentOperations': _currentOperations.length,
        'operationHistory': _operationHistory.length,
      },
      'cache': cacheStats,
      'preloader': preloaderStats,
      'optimizer': optimizerStats,
      'config': {
        'enableIntelligentPreloading': _config.enableIntelligentPreloading,
        'enableAutomaticOptimization': _config.enableAutomaticOptimization,
        'enablePredictivePreloading': _config.enablePredictivePreloading,
        'enableBackgroundProcessing': _config.enableBackgroundProcessing,
        'maxConcurrentOperations': _config.maxConcurrentOperations,
      },
    };
  }

  /// Get recent operation history
  List<ImageCacheOperationResult> getOperationHistory({int limit = 50}) {
    return _operationHistory.reversed.take(limit).toList();
  }

  /// Record operation result
  void _recordOperation(ImageCacheOperationResult result) {
    _operationHistory.add(result);

    // Keep only recent operations
    if (_operationHistory.length > 200) {
      _operationHistory.removeAt(0);
    }
  }

  /// Update service configuration
  Future<void> updateConfiguration(ImageCacheServiceConfig newConfig) async {
    _config = newConfig;

    if (_isInitialized) {
      // Update component configurations
      await _cacheManager!.initialize(config: _config.cacheConfig);

      _preloader!.updateConfiguration(
        enablePredictivePreloading: _config.enablePredictivePreloading,
      );

      _optimizer!.updateConfiguration(
        defaultStrategy: _config.defaultOptimizationStrategy,
        scheduledInterval: _config.optimizationInterval,
        enableBackgroundOptimization: _config.enableBackgroundProcessing,
      );
    }

    if (kDebugMode) {
      debugPrint('ComprehensiveImageCacheService: Configuration updated');
    }
  }

  /// Check if image is cached
  Future<bool> isImageCached(String imageKey) async {
    if (!_isInitialized) await initialize();

    final cached = await _cacheManager!.getCachedImage(imageKey);
    return cached != null;
  }

  /// Get cached image info
  Future<Map<String, dynamic>?> getCachedImageInfo(String imageKey) async {
    if (!_isInitialized) await initialize();

    // This would get detailed info about a cached image
    // For now, return basic info
    final cached = await _cacheManager!.getCachedImage(imageKey);
    if (cached == null) return null;

    final stat = await cached.stat();
    return {
      'path': cached.path,
      'size': stat.size,
      'modified': stat.modified.toIso8601String(),
      'exists': await cached.exists(),
    };
  }

  /// Warm up cache with essential images
  Future<void> warmUpCache(Map<String, String> essentialImages) async {
    if (!_isInitialized) await initialize();

    final requests = essentialImages.entries
        .map(
          (entry) => ImagePreloadRequest(
            key: entry.key,
            imagePath: entry.value,
            strategy: PreloadStrategy.immediate,
            priority: 10, // High priority for essential images
            tags: ['essential', 'warmup'],
          ),
        )
        .toList();

    await _preloader!.preloadImages(requests);

    if (kDebugMode) {
      debugPrint(
        'ComprehensiveImageCacheService: Warming up cache with ${essentialImages.length} essential images',
      );
    }
  }

  /// Schedule cache optimization
  void scheduleOptimization({
    required DateTime scheduledTime,
    OptimizationStrategy strategy = OptimizationStrategy.balanced,
    Map<String, dynamic> parameters = const {},
  }) {
    if (!_isInitialized) return;

    _optimizer!.scheduleOptimization(
      scheduledTime: scheduledTime,
      strategy: strategy,
      parameters: parameters,
    );
  }

  /// Handle low memory warning
  Future<void> handleLowMemoryWarning() async {
    if (!_isInitialized) return;

    // Trigger aggressive optimization to free memory
    await _optimizer!.optimizeCache(
      strategy: OptimizationStrategy.aggressive,
      trigger: CleanupTrigger.lowMemory,
    );

    // Clear preload queue to reduce memory pressure
    _preloader!.clearQueue();

    if (kDebugMode) {
      debugPrint('ComprehensiveImageCacheService: Handled low memory warning');
    }
  }

  /// Handle app going to background
  Future<void> handleAppBackground() async {
    if (!_isInitialized) return;

    // Trigger background optimization
    if (_config.enableBackgroundProcessing) {
      await _optimizer!.optimizeCache(
        strategy: OptimizationStrategy.balanced,
        trigger: CleanupTrigger.appBackground,
      );
    }

    if (kDebugMode) {
      debugPrint('ComprehensiveImageCacheService: Handled app background');
    }
  }

  /// Dispose all resources
  void dispose() {
    _cacheManager?.dispose();
    _preloader?.dispose();
    _optimizer?.dispose();

    _currentOperations.clear();
    _operationHistory.clear();
    _isInitialized = false;

    if (kDebugMode) {
      debugPrint('ComprehensiveImageCacheService: Disposed');
    }
  }
}
