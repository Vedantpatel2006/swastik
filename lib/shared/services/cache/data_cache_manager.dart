import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'cache_manager.dart';
import '../../constants/performance_constants.dart';

/// Data cache entry for generic data storage
class DataCacheEntry extends CacheEntry<Map<String, dynamic>> {
  final int dataSize;

  DataCacheEntry({
    required String key,
    required Map<String, dynamic> data,
    required DateTime createdAt,
    DateTime? expiresAt,
    this.dataSize = 0,
    int accessCount = 1,
    DateTime? lastAccessed,
  }) : super(
         key: key,
         data: data,
         createdAt: createdAt,
         expiresAt: expiresAt,
         accessCount: accessCount,
         lastAccessed: lastAccessed,
       );

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json.addAll({'data': data, 'dataSize': dataSize});
    return json;
  }

  factory DataCacheEntry.fromJson(Map<String, dynamic> json) {
    return DataCacheEntry(
      key: json['key'],
      data: Map<String, dynamic>.from(json['data']),
      dataSize: json['dataSize'] ?? 0,
      createdAt: DateTime.parse(json['createdAt']),
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'])
          : null,
      accessCount: json['accessCount'] ?? 1,
      lastAccessed: DateTime.parse(json['lastAccessed']),
    );
  }
}

/// Data cache manager for generic data storage
class DataCacheManager implements CacheManager<Map<String, dynamic>> {
  static final DataCacheManager _instance = DataCacheManager._internal();
  factory DataCacheManager() => _instance;
  DataCacheManager._internal();

  static const String _prefsKey = 'data_cache_metadata';
  SharedPreferences? _prefs;

  final Map<String, DataCacheEntry> _cache = {};
  final int maxSize = PerformanceConstants.maxDataCacheSize;
  final Duration defaultTTL = PerformanceConstants.defaultCacheTTL;

  // Statistics tracking
  int _hitCount = 0;
  int _missCount = 0;
  int _evictionCount = 0;

  /// Initialize the data cache manager
  Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      await _loadCacheMetadata();

      if (kDebugMode) {
        debugPrint(
          'DataCache: Initialized with ${_cache.length} cached entries',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('DataCache: Error initializing - $e');
      }
    }
  }



  /// Load cache metadata from shared preferences
  Future<void> _loadCacheMetadata() async {
    if (_prefs == null) return;

    final metadataJson = _prefs!.getString(_prefsKey);
    if (metadataJson == null) return;

    try {
      final metadata = jsonDecode(metadataJson) as Map<String, dynamic>;

      for (final entry in metadata.entries) {
        final dataEntry = DataCacheEntry.fromJson(entry.value);
        _cache[entry.key] = dataEntry;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('DataCache: Error loading metadata - $e');
      }
    }
  }

  /// Save cache metadata to shared preferences
  Future<void> _saveCacheMetadata() async {
    if (_prefs == null) return;

    try {
      final metadata = <String, dynamic>{};

      for (final entry in _cache.entries) {
        metadata[entry.key] = entry.value.toJson();
      }

      await _prefs!.setString(_prefsKey, jsonEncode(metadata));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('DataCache: Error saving metadata - $e');
      }
    }
  }

  /// Get cache entry
  Future<DataCacheEntry?> _getCacheEntry(String key) async {
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
  Future<Map<String, dynamic>?> get(String key) async {
    final entry = await _getCacheEntry(key);
    if (entry == null) return null;

    entry.markAccessed();
    _hitCount++;
    await _saveCacheMetadata();
    return entry.data;
  }

  @override
  Future<void> set(
    String key,
    Map<String, dynamic> data, {
    Duration? ttl,
  }) async {
    // Check if we need to evict entries before adding new one
    final dataJson = jsonEncode(data);
    final dataSize = dataJson.length;
    final currentSize = await getSize();

    if (currentSize + dataSize > maxSize) {
      await evictLRU();

      // If still over limit after LRU eviction, evict more aggressively
      if (await getSize() + dataSize > maxSize) {
        await _evictBySize(dataSize);
      }
    }

    final entry = DataCacheEntry(
      key: key,
      data: data,
      dataSize: dataSize,
      createdAt: DateTime.now(),
      expiresAt: ttl != null
          ? DateTime.now().add(ttl)
          : DateTime.now().add(defaultTTL),
    );

    _cache[key] = entry;
    await _saveCacheMetadata();

    if (kDebugMode) {
      debugPrint(
        'DataCache: Cached $key (${(dataSize / 1024).toStringAsFixed(1)}KB)',
      );
    }
  }

  @override
  Future<void> remove(String key) async {
    final entry = _cache.remove(key);
    if (entry != null) {
      await _saveCacheMetadata();

      if (kDebugMode) {
        debugPrint('DataCache: Removed $key');
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
    final count = _cache.length;
    _cache.clear();
    _hitCount = 0;
    _missCount = 0;
    _evictionCount = 0;
    await _saveCacheMetadata();

    if (kDebugMode) {
      debugPrint('DataCache: Cleared $count entries');
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
      debugPrint('DataCache: Evicted $toRemove LRU entries');
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
      debugPrint('DataCache: Evicted ${expiredKeys.length} expired entries');
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
      totalSize += entry.dataSize;
    }
    return totalSize;
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

      freedSpace += entry.dataSize;
      await remove(entry.key);
      removedCount++;
      _evictionCount++;
    }

    if (kDebugMode) {
      debugPrint(
        'DataCache: Evicted $removedCount entries to free ${(freedSpace / 1024).toStringAsFixed(1)}KB',
      );
    }
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

  /// Cache data with a specific key
  Future<void> cacheData(
    String key,
    Map<String, dynamic> data, {
    Duration? ttl,
  }) async {
    await set(key, data, ttl: ttl);
  }

  /// Cache a list of data items
  Future<void> cacheDataList(
    String key,
    List<Map<String, dynamic>> dataList, {
    Duration? ttl,
  }) async {
    final listData = {'items': dataList, 'count': dataList.length};
    await set(key, listData, ttl: ttl);
  }

  /// Get cached data list
  Future<List<Map<String, dynamic>>?> getCachedDataList(String key) async {
    final cachedData = await get(key);
    if (cachedData == null) return null;

    final items = cachedData['items'];
    if (items is List) {
      return items.cast<Map<String, dynamic>>();
    }
    return null;
  }

  /// Get cached data
  Future<Map<String, dynamic>?> getCachedData(String key) async {
    return await get(key);
  }

  /// Get the count of cached data entries
  int get cachedDataCount => _cache.length;

  /// Get all cached data keys
  List<String> get cachedDataKeys => _cache.keys.toList();

  /// Check if data is cached for a specific key
  Future<bool> isDataCached(String key) async {
    return await containsKey(key);
  }

  /// Get cache entry information
  Future<Map<String, dynamic>?> getCacheEntryInfo(String key) async {
    final entry = _cache[key];
    if (entry == null) return null;

    return {
      'key': entry.key,
      'dataSize': entry.dataSize,
      'createdAt': entry.createdAt.toIso8601String(),
      'expiresAt': entry.expiresAt?.toIso8601String(),
      'accessCount': entry.accessCount,
      'lastAccessed': entry.lastAccessed.toIso8601String(),
      'isExpired': entry.isExpired,
    };
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
        'DataCache: Invalidated ${keysToRemove.length} entries matching pattern: $pattern',
      );
    }
  }

  /// Refresh a cache entry by removing it (forcing a reload)
  Future<void> refreshEntry(String key) async {
    await remove(key);
  }

  /// Compress cache by removing oldest entries until under target size
  Future<void> compressCache({double targetRatio = 0.8}) async {
    final currentSize = await getSize();
    final targetSize = (maxSize * targetRatio).round();

    if (currentSize <= targetSize) return;

    // Sort entries by last accessed time (oldest first)
    final entries = _cache.values.toList()
      ..sort((a, b) => a.lastAccessed.compareTo(b.lastAccessed));

    int removedSize = 0;
    int removedCount = 0;
    final excessSize = currentSize - targetSize;

    for (final entry in entries) {
      if (removedSize >= excessSize) break;

      removedSize += entry.dataSize;
      await remove(entry.key);
      removedCount++;
    }

    if (kDebugMode) {
      debugPrint(
        'DataCache: Compressed cache - removed $removedCount entries, '
        'freed ${(removedSize / 1024).toStringAsFixed(1)}KB',
      );
    }
  }

  /// Clear all cache entries
  Future<void> clearAll() async {
    try {
      _cache.clear();
      _hitCount = 0;
      _missCount = 0;
      _evictionCount = 0;
      // Use _saveCacheMetadata to actually persist the cleared state to
      // SharedPreferences — _persistCache() is a no-op placeholder.
      await _saveCacheMetadata();
    } catch (e) {
      if (kDebugMode) {
        print('Error clearing data cache: $e');
      }
    }
  }
}
