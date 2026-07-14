import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../constants/performance_constants.dart';
import '../../models/image_optimization_models.dart';
import '../image/comprehensive_image_optimizer.dart';
import 'image_cache_manager.dart';

/// Enhanced image cache entry with additional metadata
class EnhancedImageCacheEntry extends ImageCacheEntry {
  final ImageSizeType sizeType;
  final ImageFormat format;
  final String? sourceUrl;
  final bool isPreloaded;
  final int priority; // Higher number = higher priority
  final List<String> tags; // For categorization and cleanup
  final DateTime? lastOptimized;

  EnhancedImageCacheEntry({
    required super.key,
    required super.filePath,
    required super.fileSize,
    required super.createdAt,
    super.expiresAt,
    super.originalUrl,
    super.accessCount = 1,
    super.lastAccessed,
    required this.sizeType,
    required this.format,
    this.sourceUrl,
    this.isPreloaded = false,
    this.priority = 5,
    this.tags = const [],
    this.lastOptimized,
  });

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json.addAll({
      'sizeType': sizeType.name,
      'format': format.name,
      'sourceUrl': sourceUrl,
      'isPreloaded': isPreloaded,
      'priority': priority,
      'tags': tags,
      'lastOptimized': lastOptimized?.toIso8601String(),
    });
    return json;
  }

  factory EnhancedImageCacheEntry.fromJson(Map<String, dynamic> json) {
    return EnhancedImageCacheEntry(
      key: json['key'],
      filePath: json['filePath'],
      fileSize: json['fileSize'],
      originalUrl: json['originalUrl'],
      createdAt: DateTime.parse(json['createdAt']),
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'])
          : null,
      accessCount: json['accessCount'] ?? 1,
      lastAccessed: DateTime.parse(json['lastAccessed']),
      sizeType: ImageSizeType.values.firstWhere(
        (type) => type.name == json['sizeType'],
        orElse: () => ImageSizeType.medium,
      ),
      format: ImageFormat.values.firstWhere(
        (format) => format.name == json['format'],
        orElse: () => ImageFormat.jpeg,
      ),
      sourceUrl: json['sourceUrl'],
      isPreloaded: json['isPreloaded'] ?? false,
      priority: json['priority'] ?? 5,
      tags: List<String>.from(json['tags'] ?? []),
      lastOptimized: json['lastOptimized'] != null
          ? DateTime.parse(json['lastOptimized'])
          : null,
    );
  }

  /// Check if entry needs re-optimization
  bool get needsReoptimization {
    if (lastOptimized == null) return true;
    return DateTime.now().difference(lastOptimized!).inDays > 30;
  }

  /// Calculate priority score for eviction decisions
  double get priorityScore {
    double score = priority.toDouble();

    // Boost score for recently accessed items
    final hoursSinceAccess = DateTime.now().difference(lastAccessed).inHours;
    if (hoursSinceAccess < 1)
      score += 10;
    else if (hoursSinceAccess < 24)
      score += 5;

    // Boost score for frequently accessed items
    score += (accessCount / 10).clamp(0, 5);

    // Boost score for preloaded items
    if (isPreloaded) score += 3;

    return score;
  }
}

/// Configuration for intelligent caching behavior
class IntelligentCacheConfig {
  final int maxSizeBytes;
  final Duration defaultTTL;
  final Duration preloadTTL;
  final double evictionThreshold;
  final double compressionTarget;
  final int maxConcurrentPreloads;
  final List<ImageSizeType> prioritySizes;
  final List<ImageFormat> preferredFormats;
  final bool enableAutoOptimization;
  final bool enablePredictivePreloading;

  const IntelligentCacheConfig({
    this.maxSizeBytes = PerformanceConstants.maxImageCacheSize,
    this.defaultTTL = PerformanceConstants.imageCacheTTL,
    this.preloadTTL = const Duration(days: 3),
    this.evictionThreshold = PerformanceConstants.cacheEvictionThreshold,
    this.compressionTarget = PerformanceConstants.cacheCompressionTarget,
    this.maxConcurrentPreloads = 3,
    this.prioritySizes = const [
      ImageSizeType.thumbnail,
      ImageSizeType.medium,
      ImageSizeType.large,
    ],
    this.preferredFormats = const [ImageFormat.webp, ImageFormat.jpeg],
    this.enableAutoOptimization = true,
    this.enablePredictivePreloading = true,
  });
}

/// Enhanced image cache manager with intelligent caching and preloading
class EnhancedImageCacheManager {
  static final EnhancedImageCacheManager _instance =
      EnhancedImageCacheManager._internal();
  factory EnhancedImageCacheManager() => _instance;
  EnhancedImageCacheManager._internal();

  static const String _prefsKey = 'enhanced_image_cache_metadata';
  static const String _usageStatsKey = 'image_cache_usage_stats';

  Directory? _cacheDirectory;
  SharedPreferences? _prefs;
  ComprehensiveImageOptimizer? _optimizer;
  Timer? _cleanupTimer;
  Timer? _preloadTimer;

  final Map<String, EnhancedImageCacheEntry> _cache = {};
  final Map<String, int> _usageStats = {}; // Track usage patterns
  final Set<String> _preloadQueue = {};
  final Set<String> _currentlyPreloading = {};

  IntelligentCacheConfig _config = const IntelligentCacheConfig();

  // Statistics
  int _hitCount = 0;
  int _missCount = 0;
  int _evictionCount = 0;
  int _preloadCount = 0;
  int _optimizationCount = 0;

  bool _isInitialized = false;

  /// Initialize the enhanced cache manager
  Future<void> initialize({IntelligentCacheConfig? config}) async {
    if (_isInitialized) return;

    try {
      _config = config ?? _config;
      _prefs = await SharedPreferences.getInstance();
      _cacheDirectory = await _getCacheDirectory();
      _optimizer = ComprehensiveImageOptimizer();

      await _loadCacheMetadata();
      await _loadUsageStats();

      _startPeriodicCleanup();
      _startPreloadProcessor();

      _isInitialized = true;

      if (kDebugMode) {
        debugPrint(
          'EnhancedImageCache: Initialized with ${_cache.length} cached images',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('EnhancedImageCache: Error initializing - $e');
      }
    }
  }

  /// Get cache directory
  Future<Directory> _getCacheDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${appDir.path}/enhanced_image_cache');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  /// Load cache metadata from shared preferences
  Future<void> _loadCacheMetadata() async {
    if (_prefs == null) return;

    final metadataJson = _prefs!.getString(_prefsKey);
    if (metadataJson == null) return;

    try {
      final metadata = jsonDecode(metadataJson) as Map<String, dynamic>;

      for (final entry in metadata.entries) {
        try {
          final imageEntry = EnhancedImageCacheEntry.fromJson(entry.value);

          // Check if file still exists
          final file = File(imageEntry.filePath);
          if (await file.exists()) {
            _cache[entry.key] = imageEntry;
          } else {
            if (kDebugMode) {
              debugPrint(
                'EnhancedImageCache: File missing for cached entry ${entry.key}',
              );
            }
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint(
              'EnhancedImageCache: Error deserializing entry ${entry.key} - $e',
            );
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('EnhancedImageCache: Error loading metadata - $e');
      }
    }
  }

  /// Load usage statistics
  Future<void> _loadUsageStats() async {
    if (_prefs == null) return;

    final statsJson = _prefs!.getString(_usageStatsKey);
    if (statsJson == null) return;

    try {
      final stats = jsonDecode(statsJson) as Map<String, dynamic>;
      _usageStats.clear();
      stats.forEach((key, value) {
        _usageStats[key] = value as int;
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('EnhancedImageCache: Error loading usage stats - $e');
      }
    }
  }

  /// Save cache metadata to shared preferences
  Future<void> _saveCacheMetadata() async {
    if (_prefs == null) return;

    try {
      final metadata = <String, dynamic>{};

      for (final entry in _cache.entries) {
        try {
          metadata[entry.key] = entry.value.toJson();
        } catch (e) {
          if (kDebugMode) {
            debugPrint(
              'EnhancedImageCache: Error serializing entry ${entry.key} - $e',
            );
          }
        }
      }

      final metadataJson = jsonEncode(metadata);
      await _prefs!.setString(_prefsKey, metadataJson);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('EnhancedImageCache: Error saving metadata - $e');
      }
    }
  }

  /// Save usage statistics
  Future<void> _saveUsageStats() async {
    if (_prefs == null) return;

    try {
      final statsJson = jsonEncode(_usageStats);
      await _prefs!.setString(_usageStatsKey, statsJson);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('EnhancedImageCache: Error saving usage stats - $e');
      }
    }
  }

  /// Cache an optimized image with intelligent sizing
  Future<String?> cacheOptimizedImage(
    String key,
    String imagePath, {
    ImageSizeType sizeType = ImageSizeType.medium,
    List<ImageFormat> preferredFormats = const [
      ImageFormat.webp,
      ImageFormat.jpeg,
    ],
    Duration? ttl,
    String? sourceUrl,
    bool isPreloaded = false,
    int priority = 5,
    List<String> tags = const [],
  }) async {
    if (!_isInitialized) await initialize();

    try {
      // Check if we need to evict entries before adding new one
      await _ensureCapacity();

      // Optimize the image for the requested size and formats
      final result = await _optimizer!.optimizeForAllSizes(
        imagePath,
        targetSizes: {sizeType: _getSizeForType(sizeType)},
        formats: preferredFormats,
      );

      if (!result.success || result.optimizedPaths.isEmpty) {
        if (kDebugMode) {
          debugPrint(
            'EnhancedImageCache: Failed to optimize image - ${result.error}',
          );
        }
        return null;
      }

      // Get the best optimized path
      final optimizedPath = result.getBestPath(
        sizeType,
        preferredFormats: preferredFormats,
      );
      if (optimizedPath == null) return null;

      final optimizedFile = File(optimizedPath);
      final fileSize = await optimizedFile.length();

      // Create cache entry
      final entry = EnhancedImageCacheEntry(
        key: key,
        filePath: optimizedPath,
        fileSize: fileSize,
        createdAt: DateTime.now(),
        expiresAt: ttl != null
            ? DateTime.now().add(ttl)
            : DateTime.now().add(_config.defaultTTL),
        originalUrl: sourceUrl,
        sizeType: sizeType,
        format: preferredFormats.first,
        sourceUrl: sourceUrl,
        isPreloaded: isPreloaded,
        priority: priority,
        tags: tags,
        lastOptimized: DateTime.now(),
      );

      _cache[key] = entry;
      _updateUsageStats(key);
      await _saveCacheMetadata();
      await _saveUsageStats();

      _optimizationCount++;

      if (kDebugMode) {
        debugPrint(
          'EnhancedImageCache: Cached optimized $key (${(fileSize / 1024).toStringAsFixed(1)}KB)',
        );
      }

      return optimizedPath;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('EnhancedImageCache: Error caching optimized image - $e');
      }
      return null;
    }
  }

  /// Get cached image with intelligent format selection
  Future<File?> getCachedImage(
    String key, {
    ImageSizeType? preferredSize,
    List<ImageFormat>? preferredFormats,
  }) async {
    if (!_isInitialized) await initialize();

    final entry = await _getCacheEntry(key);
    if (entry == null) {
      _missCount++;
      return null;
    }

    // Check if we have the preferred size/format
    if (preferredSize != null && entry.sizeType != preferredSize) {
      // Try to find a better match or trigger optimization
      await _requestOptimization(key, preferredSize, preferredFormats);
    }

    final file = File(entry.filePath);
    if (await file.exists()) {
      entry.markAccessed();
      _updateUsageStats(key);
      _hitCount++;
      await _saveCacheMetadata();
      await _saveUsageStats();

      // Trigger predictive preloading
      if (_config.enablePredictivePreloading) {
        _triggerPredictivePreloading(key);
      }

      return file;
    } else {
      // File was deleted externally, remove from cache
      await _removeEntry(key);
      _missCount++;
      return null;
    }
  }

  /// Preload images for anticipated user actions
  Future<void> preloadImages(
    List<String> imageKeys, {
    ImageSizeType sizeType = ImageSizeType.medium,
    int priority = 3,
    List<String> tags = const [],
  }) async {
    if (!_isInitialized) await initialize();

    for (final key in imageKeys) {
      if (!_cache.containsKey(key) && !_preloadQueue.contains(key)) {
        _preloadQueue.add(key);

        if (kDebugMode) {
          debugPrint('EnhancedImageCache: Queued $key for preloading');
        }
      }
    }
  }

  /// Process preload queue
  void _startPreloadProcessor() {
    _preloadTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (_preloadQueue.isEmpty ||
          _currentlyPreloading.length >= _config.maxConcurrentPreloads) {
        return;
      }

      final keysToProcess = _preloadQueue
          .take(_config.maxConcurrentPreloads - _currentlyPreloading.length)
          .toList();

      for (final key in keysToProcess) {
        _preloadQueue.remove(key);
        _currentlyPreloading.add(key);

        // Process preload in background
        _processPreload(key).then((_) {
          _currentlyPreloading.remove(key);
        });
      }
    });
  }

  /// Process individual preload request
  Future<void> _processPreload(String key) async {
    try {
      // This would typically fetch the image from network or other source
      // For now, we'll simulate the preload process

      if (kDebugMode) {
        debugPrint('EnhancedImageCache: Processing preload for $key');
      }

      _preloadCount++;

      // Simulate preload delay
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('EnhancedImageCache: Error preloading $key - $e');
      }
    }
  }

  /// Ensure cache has enough capacity
  Future<void> _ensureCapacity() async {
    final currentSize = _calculateTotalSize();
    final threshold = (_config.maxSizeBytes * _config.evictionThreshold)
        .round();

    if (currentSize > threshold) {
      await _performIntelligentEviction();
    }
  }

  /// Perform intelligent LRU eviction with priority consideration
  Future<void> _performIntelligentEviction() async {
    if (_cache.isEmpty) return;

    // Sort entries by priority score (lowest first for eviction)
    final entries = _cache.values.toList()
      ..sort((a, b) => a.priorityScore.compareTo(b.priorityScore));

    final targetSize = (_config.maxSizeBytes * _config.compressionTarget)
        .round();
    int currentSize = _calculateTotalSize();
    int removedCount = 0;

    for (final entry in entries) {
      if (currentSize <= targetSize) break;

      currentSize -= entry.fileSize;
      await _removeEntry(entry.key);
      removedCount++;
      _evictionCount++;
    }

    if (kDebugMode) {
      debugPrint(
        'EnhancedImageCache: Intelligent eviction removed $removedCount entries',
      );
    }
  }

  /// Start periodic cleanup
  void _startPeriodicCleanup() {
    _cleanupTimer = Timer.periodic(PerformanceConstants.cacheCleanupInterval, (
      timer,
    ) async {
      await _performPeriodicCleanup();
    });
  }

  /// Perform periodic cleanup
  Future<void> _performPeriodicCleanup() async {
    try {
      // Remove expired entries
      await _removeExpiredEntries();

      // Clean up orphaned files
      await _cleanupOrphanedFiles();

      // Re-optimize old entries if enabled
      if (_config.enableAutoOptimization) {
        await _reoptimizeOldEntries();
      }

      // Update usage statistics
      await _saveUsageStats();

      if (kDebugMode) {
        debugPrint('EnhancedImageCache: Periodic cleanup completed');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('EnhancedImageCache: Error during periodic cleanup - $e');
      }
    }
  }

  /// Remove expired entries
  Future<void> _removeExpiredEntries() async {
    final expiredKeys = <String>[];

    for (final entry in _cache.values) {
      if (entry.isExpired) {
        expiredKeys.add(entry.key);
      }
    }

    for (final key in expiredKeys) {
      await _removeEntry(key);
    }

    if (kDebugMode && expiredKeys.isNotEmpty) {
      debugPrint(
        'EnhancedImageCache: Removed ${expiredKeys.length} expired entries',
      );
    }
  }

  /// Clean up orphaned files
  Future<void> _cleanupOrphanedFiles() async {
    if (_cacheDirectory == null) return;

    try {
      final files = await _cacheDirectory!.list().toList();
      final cachedPaths = _cache.values.map((e) => e.filePath).toSet();

      int removedCount = 0;

      for (final file in files) {
        if (file is File && !cachedPaths.contains(file.path)) {
          try {
            await file.delete();
            removedCount++;
          } catch (e) {
            if (kDebugMode) {
              debugPrint(
                'EnhancedImageCache: Error deleting orphaned file ${file.path} - $e',
              );
            }
          }
        }
      }

      if (kDebugMode && removedCount > 0) {
        debugPrint(
          'EnhancedImageCache: Cleaned up $removedCount orphaned files',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('EnhancedImageCache: Error cleaning up orphaned files - $e');
      }
    }
  }

  /// Re-optimize old entries
  Future<void> _reoptimizeOldEntries() async {
    final entriesToReoptimize = _cache.values
        .where((entry) => entry.needsReoptimization)
        .take(5) // Limit to avoid overwhelming the system
        .toList();

    for (final entry in entriesToReoptimize) {
      try {
        await _requestOptimization(entry.key, entry.sizeType, [entry.format]);
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
            'EnhancedImageCache: Error re-optimizing ${entry.key} - $e',
          );
        }
      }
    }
  }

  /// Request optimization for specific size/format
  Future<void> _requestOptimization(
    String key,
    ImageSizeType sizeType,
    List<ImageFormat>? formats,
  ) async {
    // This would trigger background optimization
    // For now, it's a placeholder
    if (kDebugMode) {
      debugPrint('EnhancedImageCache: Optimization requested for $key');
    }
  }

  /// Trigger predictive preloading based on usage patterns
  void _triggerPredictivePreloading(String accessedKey) {
    // Analyze usage patterns and predict next likely images
    // This is a simplified implementation
    final relatedKeys = _findRelatedKeys(accessedKey);

    for (final key in relatedKeys.take(3)) {
      if (!_cache.containsKey(key) && !_preloadQueue.contains(key)) {
        _preloadQueue.add(key);
      }
    }
  }

  /// Find related keys based on usage patterns
  List<String> _findRelatedKeys(String key) {
    // Simple implementation - in practice, this would use pattern matching
    final related = <String>[];

    // Find keys with similar tags or patterns
    final entry = _cache[key];
    if (entry != null) {
      for (final otherEntry in _cache.values) {
        if (otherEntry.key != key &&
            otherEntry.tags.any((tag) => entry.tags.contains(tag))) {
          related.add(otherEntry.key);
        }
      }
    }

    return related;
  }

  /// Get cache entry
  Future<EnhancedImageCacheEntry?> _getCacheEntry(String key) async {
    final entry = _cache[key];

    if (entry == null) return null;

    if (entry.isExpired) {
      await _removeEntry(key);
      return null;
    }

    return entry;
  }

  /// Remove cache entry
  Future<void> _removeEntry(String key) async {
    final entry = _cache[key];
    if (entry != null) {
      try {
        final file = File(entry.filePath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
            'EnhancedImageCache: Error deleting file ${entry.filePath} - $e',
          );
        }
      }

      _cache.remove(key);
      await _saveCacheMetadata();
    }
  }

  /// Update usage statistics
  void _updateUsageStats(String key) {
    _usageStats[key] = (_usageStats[key] ?? 0) + 1;
  }

  /// Calculate total cache size
  int _calculateTotalSize() {
    return _cache.values.fold<int>(0, (sum, entry) => sum + entry.fileSize);
  }

  /// Get size configuration for image size type
  OptimizedImageSize _getSizeForType(ImageSizeType type) {
    switch (type) {
      case ImageSizeType.thumbnail:
        return const OptimizedImageSize(width: 150, height: 150);
      case ImageSizeType.medium:
        return const OptimizedImageSize(width: 400, height: 400);
      case ImageSizeType.large:
        return const OptimizedImageSize(width: 800, height: 800);
      case ImageSizeType.original:
        return const OptimizedImageSize(width: -1, height: -1);
    }
  }

  /// Clear cache by tags
  Future<void> clearByTags(List<String> tags) async {
    final keysToRemove = <String>[];

    for (final entry in _cache.values) {
      if (entry.tags.any((tag) => tags.contains(tag))) {
        keysToRemove.add(entry.key);
      }
    }

    for (final key in keysToRemove) {
      await _removeEntry(key);
    }

    if (kDebugMode && keysToRemove.isNotEmpty) {
      debugPrint(
        'EnhancedImageCache: Cleared ${keysToRemove.length} entries by tags',
      );
    }
  }

  /// Get detailed cache statistics
  Map<String, dynamic> getDetailedStatistics() {
    final currentSize = _calculateTotalSize();
    final usageRatio = currentSize / _config.maxSizeBytes;

    return {
      'totalEntries': _cache.length,
      'totalSize': currentSize,
      'maxSize': _config.maxSizeBytes,
      'usageRatio': usageRatio,
      'hitCount': _hitCount,
      'missCount': _missCount,
      'evictionCount': _evictionCount,
      'preloadCount': _preloadCount,
      'optimizationCount': _optimizationCount,
      'hitRate': _hitCount + _missCount > 0
          ? _hitCount / (_hitCount + _missCount)
          : 0.0,
      'preloadQueueSize': _preloadQueue.length,
      'currentlyPreloading': _currentlyPreloading.length,
      'averageFileSize': _cache.isNotEmpty ? currentSize / _cache.length : 0,
      'cacheHealth': _calculateCacheHealth(),
    };
  }

  /// Calculate cache health score
  double _calculateCacheHealth() {
    if (_cache.isEmpty) return 1.0;

    double health = 1.0;

    // Reduce health for high expiration rate
    final expiredCount = _cache.values.where((entry) => entry.isExpired).length;
    final expiredRatio = expiredCount / _cache.length;
    health -= expiredRatio * 0.3;

    // Reduce health for low hit rate
    final totalRequests = _hitCount + _missCount;
    if (totalRequests > 0) {
      final hitRate = _hitCount / totalRequests;
      health -= (1.0 - hitRate) * 0.4;
    }

    // Reduce health for high eviction rate
    if (_cache.length > 0) {
      final evictionRatio = _evictionCount / (_cache.length + _evictionCount);
      health -= evictionRatio * 0.3;
    }

    return health.clamp(0.0, 1.0);
  }

  /// Dispose resources
  void dispose() {
    _cleanupTimer?.cancel();
    _preloadTimer?.cancel();
    _cache.clear();
    _usageStats.clear();
    _preloadQueue.clear();
    _currentlyPreloading.clear();
    _isInitialized = false;

    if (kDebugMode) {
      debugPrint('EnhancedImageCache: Disposed');
    }
  }
}
