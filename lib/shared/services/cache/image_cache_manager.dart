import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'cache_manager.dart';
import '../../constants/performance_constants.dart';

/// Image cache entry with file path and metadata
class ImageCacheEntry extends CacheEntry<String> {
  final String filePath;
  final int fileSize;
  final String? originalUrl;

  ImageCacheEntry({
    required String key,
    required this.filePath,
    required this.fileSize,
    required DateTime createdAt,
    DateTime? expiresAt,
    this.originalUrl,
    int accessCount = 1,
    DateTime? lastAccessed,
  }) : super(
         key: key,
         data: filePath,
         createdAt: createdAt,
         expiresAt: expiresAt,
         accessCount: accessCount,
         lastAccessed: lastAccessed,
       );

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json.addAll({
      'filePath': filePath,
      'fileSize': fileSize,
      'originalUrl': originalUrl,
    });
    return json;
  }

  factory ImageCacheEntry.fromJson(Map<String, dynamic> json) {
    return ImageCacheEntry(
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
    );
  }
}

/// Image cache manager with file system persistence
class ImageCacheManager implements CacheManager<String> {
  static final ImageCacheManager _instance = ImageCacheManager._internal();
  factory ImageCacheManager() => _instance;
  ImageCacheManager._internal();

  static const String _prefsKey = 'image_cache_metadata';
  Directory? _cacheDirectory;
  SharedPreferences? _prefs;

  final Map<String, ImageCacheEntry> _cache = {};
  final int maxSize = PerformanceConstants.maxImageCacheSize;
  final Duration defaultTTL = PerformanceConstants.defaultCacheTTL;

  // Statistics tracking
  int _hitCount = 0;
  int _missCount = 0;
  int _evictionCount = 0;

  /// Initialize the image cache manager
  Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _cacheDirectory = await _getCacheDirectory();
      await _loadCacheMetadata();

      if (kDebugMode) {
        debugPrint(
          'ImageCache: Initialized with ${_cache.length} cached images',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ImageCache: Error initializing - $e');
      }
    }
  }

  /// Get cache directory
  Future<Directory> _getCacheDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${appDir.path}/image_cache');
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
          final imageEntry = ImageCacheEntry.fromJson(entry.value);

          // Check if file still exists
          final file = File(imageEntry.filePath);
          if (await file.exists()) {
            _cache[entry.key] = imageEntry;
          } else {
            if (kDebugMode) {
              debugPrint(
                'ImageCache: File missing for cached entry ${entry.key}',
              );
            }
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint(
              'ImageCache: Error deserializing entry ${entry.key} - $e',
            );
          }
          // Skip corrupted entries and continue loading others
          continue;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ImageCache: Critical error loading metadata - $e');
      }
      // Clear preferences if completely corrupted
      try {
        await _prefs!.remove(_prefsKey);
      } catch (clearError) {
        if (kDebugMode) {
          debugPrint(
            'ImageCache: Error clearing corrupted preferences - $clearError',
          );
        }
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
            debugPrint('ImageCache: Error serializing entry ${entry.key} - $e');
          }
          // Skip corrupted entries
          continue;
        }
      }

      final metadataJson = jsonEncode(metadata);
      await _prefs!.setString(_prefsKey, metadataJson);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ImageCache: Critical error saving metadata - $e');
      }
      // Clear corrupted cache if serialization completely fails
      _cache.clear();
    }
  }

  /// Cache an image from bytes
  Future<String?> cacheImageFromBytes(
    String key,
    Uint8List imageBytes, {
    Duration? ttl,
    String? originalUrl,
  }) async {
    if (_cacheDirectory == null) {
      await initialize();
    }

    try {
      // Check if we need to evict entries before adding new one
      final currentSize = await getSize();
      final newEntrySize = imageBytes.length;

      if (currentSize + newEntrySize > maxSize) {
        await evictLRU();

        // If still over limit after LRU eviction, evict more aggressively
        if (await getSize() + newEntrySize > maxSize) {
          await _evictBySize(newEntrySize);
        }
      }

      final fileName = _generateFileName(key);
      final filePath = '${_cacheDirectory!.path}/$fileName';
      final file = File(filePath);

      await file.writeAsBytes(imageBytes);

      final entry = ImageCacheEntry(
        key: key,
        filePath: filePath,
        fileSize: imageBytes.length,
        originalUrl: originalUrl,
        createdAt: DateTime.now(),
        expiresAt: ttl != null
            ? DateTime.now().add(ttl)
            : DateTime.now().add(defaultTTL),
      );

      _cache[key] = entry;
      await _saveCacheMetadata();

      if (kDebugMode) {
        debugPrint(
          'ImageCache: Cached $key (${(imageBytes.length / 1024).toStringAsFixed(1)}KB)',
        );
      }

      return filePath;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ImageCache: Error caching image - $e');
      }
      return null;
    }
  }

  /// Cache an image from file
  Future<String?> cacheImageFromFile(
    String key,
    File imageFile, {
    Duration? ttl,
    String? originalUrl,
  }) async {
    if (!await imageFile.exists()) return null;

    final imageBytes = await imageFile.readAsBytes();
    return await cacheImageFromBytes(
      key,
      imageBytes,
      ttl: ttl,
      originalUrl: originalUrl,
    );
  }

  /// Get cached image file
  Future<File?> getCachedImageFile(String key) async {
    final entry = await _getCacheEntry(key);
    if (entry == null) return null;

    final file = File(entry.filePath);
    if (await file.exists()) {
      entry.markAccessed();
      _hitCount++;
      await _saveCacheMetadata();
      return file;
    } else {
      // File was deleted externally, remove from cache
      await remove(key);
      return null;
    }
  }

  /// Get cached image bytes
  Future<Uint8List?> getCachedImageBytes(String key) async {
    final file = await getCachedImageFile(key);
    if (file == null) return null;

    try {
      return await file.readAsBytes();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ImageCache: Error reading cached image - $e');
      }
      return null;
    }
  }

  /// Get cache entry
  Future<ImageCacheEntry?> _getCacheEntry(String key) async {
    final entry = _cache[key];

    if (entry == null) {
      _missCount++;
      return null;
    }

    if (entry.isExpired) {
      await remove(key);
      _missCount++;
      return null;
    }

    return entry;
  }

  @override
  Future<String?> get(String key) async {
    final entry = await _getCacheEntry(key);
    return entry?.filePath;
  }

  @override
  Future<void> set(String key, String filePath, {Duration? ttl}) async {
    // This method is not used directly for images
    // Use cacheImageFromBytes or cacheImageFromFile instead
    throw UnsupportedError(
      'Use cacheImageFromBytes or cacheImageFromFile instead',
    );
  }

  @override
  Future<void> remove(String key) async {
    final entry = _cache[key];
    if (entry != null) {
      // Delete the file
      try {
        final file = File(entry.filePath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('ImageCache: Error deleting file ${entry.filePath} - $e');
        }
      }

      _cache.remove(key);
      await _saveCacheMetadata();

      if (kDebugMode) {
        debugPrint('ImageCache: Removed $key');
      }
    }
  }

  @override
  Future<bool> containsKey(String key) async {
    final entry = _cache[key];
    if (entry == null) return false;

    if (entry.isExpired) {
      await remove(key);
      return false;
    }

    return true;
  }

  @override
  Future<void> clear() async {
    // Delete all cached files
    for (final entry in _cache.values) {
      try {
        final file = File(entry.filePath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('ImageCache: Error deleting file ${entry.filePath} - $e');
        }
      }
    }

    final count = _cache.length;
    _cache.clear();
    _hitCount = 0;
    _missCount = 0;
    _evictionCount = 0;
    await _saveCacheMetadata();

    if (kDebugMode) {
      debugPrint('ImageCache: Cleared $count entries');
    }
  }

  @override
  CacheStatistics getStatistics() {
    return CacheStatistics(
      totalEntries: _cache.length,
      hitCount: _hitCount,
      missCount: _missCount,
      evictionCount: _evictionCount,
      totalSize: _calculateTotalSize(),
    );
  }

  @override
  Future<void> evictLRU() async {
    if (_cache.isEmpty) return;

    // Sort by last accessed time (oldest first)
    final entries = _cache.values.toList()
      ..sort((a, b) => a.lastAccessed.compareTo(b.lastAccessed));

    // Remove oldest 25% of entries
    final toRemove = (entries.length * 0.25).ceil();
    for (int i = 0; i < toRemove && i < entries.length; i++) {
      await remove(entries[i].key);
      _evictionCount++;
    }

    if (kDebugMode) {
      debugPrint('ImageCache: Evicted $toRemove LRU entries');
    }
  }

  @override
  Future<void> evictExpired() async {
    final expiredKeys = <String>[];

    for (final entry in _cache.values) {
      if (entry.isExpired) {
        expiredKeys.add(entry.key);
      }
    }

    for (final key in expiredKeys) {
      await remove(key);
      _evictionCount++;
    }

    if (kDebugMode && expiredKeys.isNotEmpty) {
      debugPrint('ImageCache: Evicted ${expiredKeys.length} expired entries');
    }
  }

  @override
  Future<List<String>> getKeys() async {
    await evictExpired(); // Clean up expired entries first
    return _cache.keys.toList();
  }

  @override
  Future<int> getSize() async {
    return _calculateTotalSize();
  }

  /// Calculate total cache size in bytes
  int _calculateTotalSize() {
    int totalSize = 0;
    for (final entry in _cache.values) {
      totalSize += entry.fileSize;
    }
    return totalSize;
  }

  /// Generate a unique filename for the cached image
  String _generateFileName(String key) {
    final hash = sha256.convert(utf8.encode(key)).toString();
    return '$hash.cache';
  }

  /// Get cache directory path
  String? get cacheDirectoryPath => _cacheDirectory?.path;

  /// Get total number of cached images
  int get cachedImageCount => _cache.length;

  /// Get list of all cached image keys
  List<String> get cachedImageKeys => _cache.keys.toList();

  /// Check if image is cached
  Future<bool> isImageCached(String key) async {
    return await containsKey(key);
  }

  /// Get cache entry info
  Future<Map<String, dynamic>?> getCacheEntryInfo(String key) async {
    final entry = _cache[key];
    if (entry == null) return null;

    if (entry.isExpired) {
      await remove(key);
      return null;
    }

    return {
      'key': entry.key,
      'filePath': entry.filePath,
      'fileSize': entry.fileSize,
      'originalUrl': entry.originalUrl,
      'createdAt': entry.createdAt.toIso8601String(),
      'expiresAt': entry.expiresAt?.toIso8601String(),
      'accessCount': entry.accessCount,
      'lastAccessed': entry.lastAccessed.toIso8601String(),
      'isExpired': entry.isExpired,
      'isStale': entry.isStale,
    };
  }

  /// Evict entries by size to make room for new entry
  Future<void> _evictBySize(int requiredSpace) async {
    if (_cache.isEmpty) return;

    // Sort by last accessed time (oldest first)
    final entries = _cache.values.toList()
      ..sort((a, b) => a.lastAccessed.compareTo(b.lastAccessed));

    int freedSpace = 0;
    int removedCount = 0;

    for (final entry in entries) {
      if (freedSpace >= requiredSpace) break;

      freedSpace += entry.fileSize;
      await remove(entry.key);
      removedCount++;
      _evictionCount++;
    }

    if (kDebugMode) {
      debugPrint(
        'ImageCache: Evicted $removedCount entries to free ${(freedSpace / 1024).toStringAsFixed(1)}KB',
      );
    }
  }

  /// Compress cache by removing oldest entries until under target size
  Future<void> compressCache({double targetRatio = 0.8}) async {
    final currentSize = await getSize();
    final targetSize = (maxSize * targetRatio).round();

    if (currentSize <= targetSize) return;

    final excessSize = currentSize - targetSize;
    await _evictBySize(excessSize);
  }

  /// Get cache usage ratio (0.0 to 1.0)
  Future<double> getCacheUsageRatio() async {
    final currentSize = await getSize();
    return currentSize / maxSize;
  }

  /// Check if cache is near capacity
  Future<bool> isNearCapacity({double threshold = 0.9}) async {
    final usage = await getCacheUsageRatio();
    return usage >= threshold;
  }

  /// Invalidate cache entries by pattern
  Future<void> invalidateByPattern(String pattern) async {
    final regex = RegExp(pattern);
    final keysToRemove = <String>[];

    for (final key in _cache.keys) {
      if (regex.hasMatch(key)) {
        keysToRemove.add(key);
      }
    }

    for (final key in keysToRemove) {
      await remove(key);
    }

    if (kDebugMode && keysToRemove.isNotEmpty) {
      debugPrint(
        'ImageCache: Invalidated ${keysToRemove.length} entries matching pattern: $pattern',
      );
    }
  }

  /// Refresh cache entry (mark as expired to force reload)
  Future<void> refreshEntry(String key) async {
    final entry = _cache[key];
    if (entry != null) {
      // Create a new entry with past expiration date
      final refreshedEntry = ImageCacheEntry(
        key: entry.key,
        filePath: entry.filePath,
        fileSize: entry.fileSize,
        originalUrl: entry.originalUrl,
        createdAt: entry.createdAt,
        expiresAt: DateTime.now().subtract(const Duration(seconds: 1)),
        accessCount: entry.accessCount,
        lastAccessed: entry.lastAccessed,
      );

      _cache[key] = refreshedEntry;
      await _saveCacheMetadata();

      if (kDebugMode) {
        debugPrint('ImageCache: Marked $key for refresh');
      }
    }
  }

  /// Get detailed cache statistics for monitoring
  Future<Map<String, dynamic>> getDetailedStatistics() async {
    final currentSize = await getSize();
    final usageRatio = await getCacheUsageRatio();
    final now = DateTime.now();

    final recentlyAccessed = _cache.values
        .where((entry) => now.difference(entry.lastAccessed).inMinutes < 60)
        .length;

    final expiredEntries = _cache.values
        .where((entry) => entry.isExpired)
        .length;
    final staleEntries = _cache.values.where((entry) => entry.isStale).length;

    final averageFileSize = _cache.isNotEmpty
        ? _cache.values.map((e) => e.fileSize).reduce((a, b) => a + b) /
              _cache.length
        : 0;

    return {
      'totalEntries': _cache.length,
      'totalSize': currentSize,
      'maxSize': maxSize,
      'usageRatio': usageRatio,
      'hitCount': _hitCount,
      'missCount': _missCount,
      'evictionCount': _evictionCount,
      'hitRate': _hitCount + _missCount > 0
          ? _hitCount / (_hitCount + _missCount)
          : 0.0,
      'recentlyAccessed': recentlyAccessed,
      'expiredEntries': expiredEntries,
      'staleEntries': staleEntries,
      'averageFileSize': averageFileSize,
      'cacheHealth': _calculateCacheHealth(),
      'isNearCapacity': usageRatio > 0.9,
    };
  }

  /// Calculate cache health score (0.0 to 1.0)
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

  // Performance metrics functionality has been removed

  // Removed _calculateCacheEfficiency - unused method
  /// Clear all cache entries
  Future<void> clearAll() async {
    try {
      _cache.clear();
      _hitCount = 0;
      _missCount = 0;
      await _persistMetadata();
    } catch (e) {
      if (kDebugMode) {
        print('Error clearing image cache: $e');
      }
    }
  }

  /// Persist metadata to SharedPreferences
  Future<void> _persistMetadata() async {
    await _saveCacheMetadata();
  }
}
