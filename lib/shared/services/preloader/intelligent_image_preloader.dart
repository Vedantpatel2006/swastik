import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../constants/performance_constants.dart';
import '../../models/image_optimization_models.dart';
import '../cache/enhanced_image_cache_manager.dart';

/// Preload strategy for different scenarios
enum PreloadStrategy {
  immediate, // Preload immediately
  onDemand, // Preload when requested
  predictive, // Preload based on user behavior
  scheduled, // Preload at specific times
}

/// Image preload request configuration
class ImagePreloadRequest {
  final String key;
  final String imagePath;
  final String? sourceUrl;
  final ImageSizeType sizeType;
  final List<ImageFormat> preferredFormats;
  final PreloadStrategy strategy;
  final int priority;
  final List<String> tags;
  final Duration? delay;
  final bool requiresNetwork;

  const ImagePreloadRequest({
    required this.key,
    required this.imagePath,
    this.sourceUrl,
    this.sizeType = ImageSizeType.medium,
    this.preferredFormats = const [ImageFormat.webp, ImageFormat.jpeg],
    this.strategy = PreloadStrategy.onDemand,
    this.priority = 5,
    this.tags = const [],
    this.delay,
    this.requiresNetwork = false,
  });

  /// Create a copy with modified properties
  ImagePreloadRequest copyWith({
    String? key,
    String? imagePath,
    String? sourceUrl,
    ImageSizeType? sizeType,
    List<ImageFormat>? preferredFormats,
    PreloadStrategy? strategy,
    int? priority,
    List<String>? tags,
    Duration? delay,
    bool? requiresNetwork,
  }) {
    return ImagePreloadRequest(
      key: key ?? this.key,
      imagePath: imagePath ?? this.imagePath,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      sizeType: sizeType ?? this.sizeType,
      preferredFormats: preferredFormats ?? this.preferredFormats,
      strategy: strategy ?? this.strategy,
      priority: priority ?? this.priority,
      tags: tags ?? this.tags,
      delay: delay ?? this.delay,
      requiresNetwork: requiresNetwork ?? this.requiresNetwork,
    );
  }
}

/// Result of image preload operation
class ImagePreloadResult {
  final String key;
  final bool success;
  final String? cachedPath;
  final String? error;
  final Duration loadTime;
  final int fileSize;
  final ImageSizeType sizeType;
  final ImageFormat format;

  const ImagePreloadResult({
    required this.key,
    required this.success,
    this.cachedPath,
    this.error,
    required this.loadTime,
    this.fileSize = 0,
    this.sizeType = ImageSizeType.medium,
    this.format = ImageFormat.jpeg,
  });

  @override
  String toString() =>
      'ImagePreloadResult($key, success: $success, size: ${(fileSize / 1024).toStringAsFixed(1)}KB, time: ${loadTime.inMilliseconds}ms)';
}

/// User behavior pattern for predictive preloading
class UserBehaviorPattern {
  final String userId;
  final Map<String, int> imageAccessCounts;
  final Map<String, DateTime> lastAccessTimes;
  final Map<String, List<String>> sequentialPatterns;
  final Map<String, double> categoryPreferences;

  UserBehaviorPattern({
    required this.userId,
    this.imageAccessCounts = const {},
    this.lastAccessTimes = const {},
    this.sequentialPatterns = const {},
    this.categoryPreferences = const {},
  });

  /// Update pattern with new access
  void recordAccess(String imageKey, List<String> tags) {
    imageAccessCounts[imageKey] = (imageAccessCounts[imageKey] ?? 0) + 1;
    lastAccessTimes[imageKey] = DateTime.now();

    // Update category preferences
    for (final tag in tags) {
      categoryPreferences[tag] = (categoryPreferences[tag] ?? 0.0) + 0.1;
    }
  }

  /// Get predicted next images
  List<String> getPredictedImages(String currentImage, {int limit = 5}) {
    final patterns = sequentialPatterns[currentImage] ?? [];
    return patterns.take(limit).toList();
  }

  /// Get images by preference score
  List<String> getImagesByPreference({int limit = 10}) {
    final entries = imageAccessCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return entries.take(limit).map((e) => e.key).toList();
  }
}

/// Intelligent image preloader with predictive capabilities
class IntelligentImagePreloader {
  static final IntelligentImagePreloader _instance =
      IntelligentImagePreloader._internal();
  factory IntelligentImagePreloader() => _instance;
  IntelligentImagePreloader._internal();

  EnhancedImageCacheManager? _cacheManager;
  Timer? _preloadTimer;
  Timer? _cleanupTimer;

  final Map<String, ImagePreloadRequest> _preloadQueue = {};
  final Map<String, ImagePreloadRequest> _scheduledPreloads = {};
  final Set<String> _currentlyPreloading = {};
  final List<ImagePreloadResult> _recentResults = [];
  final Map<String, UserBehaviorPattern> _userPatterns = {};

  // Configuration
  int _maxConcurrentPreloads = PerformanceConstants.maxPreloadImages;
  int _maxQueueSize = 100;
  Duration _preloadInterval = const Duration(seconds: 2);
  bool _enablePredictivePreloading = true;
  bool _enableNetworkPreloading = true;

  // Statistics
  int _totalPreloaded = 0;
  int _successfulPreloads = 0;
  int _failedPreloads = 0;
  int _predictiveHits = 0;

  bool _isInitialized = false;

  /// Initialize the intelligent preloader
  Future<void> initialize({
    EnhancedImageCacheManager? cacheManager,
    int? maxConcurrentPreloads,
    bool? enablePredictivePreloading,
    bool? enableNetworkPreloading,
  }) async {
    if (_isInitialized) return;

    try {
      _cacheManager = cacheManager ?? EnhancedImageCacheManager();

      _maxConcurrentPreloads = maxConcurrentPreloads ?? _maxConcurrentPreloads;
      _enablePredictivePreloading =
          enablePredictivePreloading ?? _enablePredictivePreloading;
      _enableNetworkPreloading =
          enableNetworkPreloading ?? _enableNetworkPreloading;

      await _cacheManager!.initialize();

      _startPreloadProcessor();
      _startCleanupTimer();

      _isInitialized = true;

      if (kDebugMode) {
        debugPrint('IntelligentImagePreloader: Initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('IntelligentImagePreloader: Error initializing - $e');
      }
    }
  }

  /// Add image to preload queue
  Future<void> preloadImage(ImagePreloadRequest request) async {
    if (!_isInitialized) await initialize();

    // Check if already cached
    final cached = await _cacheManager!.getCachedImage(request.key);
    if (cached != null) {
      if (kDebugMode) {
        debugPrint('IntelligentImagePreloader: ${request.key} already cached');
      }
      return;
    }

    // Check if already in queue or currently preloading
    if (_preloadQueue.containsKey(request.key) ||
        _currentlyPreloading.contains(request.key)) {
      return;
    }

    // Add to appropriate queue based on strategy
    switch (request.strategy) {
      case PreloadStrategy.immediate:
        await _processPreloadRequest(request);
        break;
      case PreloadStrategy.scheduled:
        if (request.delay != null) {
          _schedulePreload(request);
        } else {
          _preloadQueue[request.key] = request;
        }
        break;
      case PreloadStrategy.onDemand:
      case PreloadStrategy.predictive:
        _preloadQueue[request.key] = request;
        break;
    }

    // Limit queue size
    if (_preloadQueue.length > _maxQueueSize) {
      _evictLowPriorityRequests();
    }

    if (kDebugMode) {
      debugPrint(
        'IntelligentImagePreloader: Queued ${request.key} for preloading',
      );
    }
  }

  /// Preload multiple images
  Future<void> preloadImages(List<ImagePreloadRequest> requests) async {
    for (final request in requests) {
      await preloadImage(request);
    }
  }

  /// Preload images for a specific category/tag
  Future<void> preloadByCategory(
    String category,
    List<String> imagePaths, {
    ImageSizeType sizeType = ImageSizeType.medium,
    int priority = 5,
  }) async {
    final requests = imagePaths
        .map(
          (path) => ImagePreloadRequest(
            key: _generateKey(path, sizeType),
            imagePath: path,
            sizeType: sizeType,
            priority: priority,
            tags: [category],
            strategy: PreloadStrategy.onDemand,
          ),
        )
        .toList();

    await preloadImages(requests);
  }

  /// Preload images based on user behavior patterns
  Future<void> preloadPredictive(
    String userId,
    String currentImageKey, {
    int limit = 5,
  }) async {
    if (!_enablePredictivePreloading) return;

    final pattern = _userPatterns[userId];
    if (pattern == null) return;

    final predictedImages = pattern.getPredictedImages(
      currentImageKey,
      limit: limit,
    );

    for (final imageKey in predictedImages) {
      final request = ImagePreloadRequest(
        key: imageKey,
        imagePath: imageKey, // This would be resolved from your image mapping
        strategy: PreloadStrategy.predictive,
        priority: 3, // Higher priority for predictive preloads
        tags: ['predictive'],
      );

      await preloadImage(request);
    }

    if (kDebugMode && predictedImages.isNotEmpty) {
      debugPrint(
        'IntelligentImagePreloader: Queued ${predictedImages.length} predictive preloads for user $userId',
      );
    }
  }

  /// Record user image access for pattern learning
  void recordImageAccess(String userId, String imageKey, List<String> tags) {
    if (!_enablePredictivePreloading) return;

    _userPatterns[userId] ??= UserBehaviorPattern(userId: userId);
    _userPatterns[userId]!.recordAccess(imageKey, tags);

    // Trigger predictive preloading
    preloadPredictive(userId, imageKey);
  }

  /// Schedule a preload for later execution
  void _schedulePreload(ImagePreloadRequest request) {
    if (request.delay == null) return;

    Timer(request.delay!, () {
      _preloadQueue[request.key] = request.copyWith(
        strategy: PreloadStrategy.onDemand,
        delay: null,
      );
    });

    _scheduledPreloads[request.key] = request;
  }

  /// Start the preload processor
  void _startPreloadProcessor() {
    _preloadTimer = Timer.periodic(_preloadInterval, (timer) async {
      await _processPreloadQueue();
    });
  }

  /// Process the preload queue
  Future<void> _processPreloadQueue() async {
    if (_preloadQueue.isEmpty ||
        _currentlyPreloading.length >= _maxConcurrentPreloads) {
      return;
    }

    // Sort requests by priority (higher number = higher priority)
    final sortedRequests = _preloadQueue.values.toList()
      ..sort((a, b) => b.priority.compareTo(a.priority));

    final requestsToProcess = sortedRequests
        .take(_maxConcurrentPreloads - _currentlyPreloading.length)
        .toList();

    for (final request in requestsToProcess) {
      _preloadQueue.remove(request.key);
      _currentlyPreloading.add(request.key);

      // Process in background
      _processPreloadRequest(request).then((result) {
        _currentlyPreloading.remove(request.key);
        _recentResults.add(result);

        // Keep only recent results
        if (_recentResults.length > 100) {
          _recentResults.removeAt(0);
        }
      });
    }
  }

  /// Process individual preload request
  Future<ImagePreloadResult> _processPreloadRequest(
    ImagePreloadRequest request,
  ) async {
    final stopwatch = Stopwatch()..start();

    try {
      // Check if network is required and available
      if (request.requiresNetwork && !_enableNetworkPreloading) {
        throw Exception('Network preloading disabled');
      }

      // Check if image file exists
      final imageFile = File(request.imagePath);
      if (!await imageFile.exists()) {
        // Try to load from assets if it's an asset path
        if (request.imagePath.startsWith('assets/')) {
          await _preloadAssetImage(request);
        } else {
          throw Exception('Image file not found: ${request.imagePath}');
        }
      }

      // Cache the optimized image
      final cachedPath = await _cacheManager!.cacheOptimizedImage(
        request.key,
        request.imagePath,
        sizeType: request.sizeType,
        preferredFormats: request.preferredFormats,
        isPreloaded: true,
        priority: request.priority,
        tags: request.tags,
        sourceUrl: request.sourceUrl,
      );

      if (cachedPath == null) {
        throw Exception('Failed to cache optimized image');
      }

      final cachedFile = File(cachedPath);
      final fileSize = await cachedFile.length();

      stopwatch.stop();

      _totalPreloaded++;
      _successfulPreloads++;

      if (request.strategy == PreloadStrategy.predictive) {
        _predictiveHits++;
      }

      if (kDebugMode) {
        debugPrint(
          'IntelligentImagePreloader: Successfully preloaded ${request.key} (${(fileSize / 1024).toStringAsFixed(1)}KB)',
        );
      }

      return ImagePreloadResult(
        key: request.key,
        success: true,
        cachedPath: cachedPath,
        loadTime: stopwatch.elapsed,
        fileSize: fileSize,
        sizeType: request.sizeType,
        format: request.preferredFormats.first,
      );
    } catch (e) {
      stopwatch.stop();

      _totalPreloaded++;
      _failedPreloads++;

      if (kDebugMode) {
        debugPrint(
          'IntelligentImagePreloader: Failed to preload ${request.key} - $e',
        );
      }

      return ImagePreloadResult(
        key: request.key,
        success: false,
        error: e.toString(),
        loadTime: stopwatch.elapsed,
      );
    }
  }

  /// Preload asset image
  Future<void> _preloadAssetImage(ImagePreloadRequest request) async {
    try {
      final imageData = await rootBundle.load(request.imagePath);
      final bytes = imageData.buffer.asUint8List();

      // Create a temporary file for optimization
      final tempFile = File('${Directory.systemTemp.path}/${request.key}_temp');
      await tempFile.writeAsBytes(bytes);

      // Update request to use temp file
      request.copyWith(imagePath: tempFile.path);
    } catch (e) {
      throw Exception('Failed to load asset image: $e');
    }
  }

  /// Evict low priority requests from queue
  void _evictLowPriorityRequests() {
    final sortedRequests = _preloadQueue.values.toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));

    final toRemove = sortedRequests.take(_preloadQueue.length - _maxQueueSize);

    for (final request in toRemove) {
      _preloadQueue.remove(request.key);
    }

    if (kDebugMode) {
      debugPrint(
        'IntelligentImagePreloader: Evicted ${toRemove.length} low priority requests',
      );
    }
  }

  /// Start cleanup timer
  void _startCleanupTimer() {
    _cleanupTimer = Timer.periodic(const Duration(minutes: 30), (timer) {
      _cleanupOldPatterns();
    });
  }

  /// Clean up old user patterns
  void _cleanupOldPatterns() {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));

    _userPatterns.removeWhere((userId, pattern) {
      final hasRecentActivity = pattern.lastAccessTimes.values.any(
        (time) => time.isAfter(cutoff),
      );
      return !hasRecentActivity;
    });

    if (kDebugMode) {
      debugPrint('IntelligentImagePreloader: Cleaned up old user patterns');
    }
  }

  /// Generate cache key for image
  String _generateKey(String imagePath, ImageSizeType sizeType) {
    return '${imagePath}_${sizeType.name}';
  }

  /// Cancel preload request
  void cancelPreload(String key) {
    _preloadQueue.remove(key);
    _scheduledPreloads.remove(key);

    if (kDebugMode) {
      debugPrint('IntelligentImagePreloader: Cancelled preload for $key');
    }
  }

  /// Clear all preload queues
  void clearQueue() {
    _preloadQueue.clear();
    _scheduledPreloads.clear();

    if (kDebugMode) {
      debugPrint('IntelligentImagePreloader: Cleared all preload queues');
    }
  }

  /// Get preloader statistics
  Map<String, dynamic> getStatistics() {
    final successRate = _totalPreloaded > 0
        ? (_successfulPreloads / _totalPreloaded) * 100
        : 0.0;

    final predictiveHitRate = _predictiveHits > 0
        ? (_predictiveHits / _successfulPreloads) * 100
        : 0.0;

    return {
      'totalPreloaded': _totalPreloaded,
      'successfulPreloads': _successfulPreloads,
      'failedPreloads': _failedPreloads,
      'successRate': successRate,
      'predictiveHits': _predictiveHits,
      'predictiveHitRate': predictiveHitRate,
      'queueSize': _preloadQueue.length,
      'scheduledPreloads': _scheduledPreloads.length,
      'currentlyPreloading': _currentlyPreloading.length,
      'userPatterns': _userPatterns.length,
      'recentResults': _recentResults.length,
      'maxConcurrentPreloads': _maxConcurrentPreloads,
      'enablePredictivePreloading': _enablePredictivePreloading,
      'enableNetworkPreloading': _enableNetworkPreloading,
    };
  }

  /// Get recent preload results
  List<ImagePreloadResult> getRecentResults({int limit = 20}) {
    return _recentResults.reversed.take(limit).toList();
  }

  /// Update configuration
  void updateConfiguration({
    int? maxConcurrentPreloads,
    int? maxQueueSize,
    Duration? preloadInterval,
    bool? enablePredictivePreloading,
    bool? enableNetworkPreloading,
  }) {
    _maxConcurrentPreloads = maxConcurrentPreloads ?? _maxConcurrentPreloads;
    _maxQueueSize = maxQueueSize ?? _maxQueueSize;
    _preloadInterval = preloadInterval ?? _preloadInterval;
    _enablePredictivePreloading =
        enablePredictivePreloading ?? _enablePredictivePreloading;
    _enableNetworkPreloading =
        enableNetworkPreloading ?? _enableNetworkPreloading;

    // Restart timer with new interval if changed
    if (preloadInterval != null) {
      _preloadTimer?.cancel();
      _startPreloadProcessor();
    }

    if (kDebugMode) {
      debugPrint('IntelligentImagePreloader: Configuration updated');
    }
  }

  /// Dispose resources
  void dispose() {
    _preloadTimer?.cancel();
    _cleanupTimer?.cancel();
    _preloadQueue.clear();
    _scheduledPreloads.clear();
    _currentlyPreloading.clear();
    _recentResults.clear();
    _userPatterns.clear();
    _isInitialized = false;

    if (kDebugMode) {
      debugPrint('IntelligentImagePreloader: Disposed');
    }
  }
}
