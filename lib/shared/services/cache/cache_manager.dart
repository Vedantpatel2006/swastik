import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../constants/performance_constants.dart';

/// Cache entry model with TTL and LRU tracking
class CacheEntry<T> {
  final String key;
  final T data;
  final DateTime createdAt;
  final DateTime? expiresAt;
  int accessCount;
  DateTime lastAccessed;

  CacheEntry({
    required this.key,
    required this.data,
    required this.createdAt,
    this.expiresAt,
    this.accessCount = 1,
    DateTime? lastAccessed,
  }) : lastAccessed = lastAccessed ?? DateTime.now();

  /// Check if the cache entry is expired
  bool get isExpired => expiresAt?.isBefore(DateTime.now()) ?? false;

  /// Check if the cache entry is stale (not accessed recently)
  bool get isStale => DateTime.now().difference(lastAccessed).inHours > 1;

  /// Update access tracking
  void markAccessed() {
    accessCount++;
    lastAccessed = DateTime.now();
  }

  /// Convert to JSON for persistence
  /// Note: Subclasses should override this to properly serialize their data
  Map<String, dynamic> toJson() {
    return {
      'key': key,
      // 'data': data, // Removed - subclasses should handle data serialization
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt?.toIso8601String(),
      'accessCount': accessCount,
      'lastAccessed': lastAccessed.toIso8601String(),
    };
  }

  /// Create from JSON
  factory CacheEntry.fromJson(Map<String, dynamic> json, T data) {
    return CacheEntry<T>(
      key: json['key'],
      data: data,
      createdAt: DateTime.parse(json['createdAt']),
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'])
          : null,
      accessCount: json['accessCount'] ?? 1,
      lastAccessed: DateTime.parse(json['lastAccessed']),
    );
  }
}

/// Cache statistics for monitoring
class CacheStatistics {
  final int totalEntries;
  final int hitCount;
  final int missCount;
  final int evictionCount;
  final double hitRate;
  final int totalSize;

  CacheStatistics({
    required this.totalEntries,
    required this.hitCount,
    required this.missCount,
    required this.evictionCount,
    required this.totalSize,
  }) : hitRate = hitCount + missCount > 0
           ? hitCount / (hitCount + missCount)
           : 0.0;

  @override
  String toString() {
    return 'CacheStats(entries: $totalEntries, hitRate: ${(hitRate * 100).toStringAsFixed(1)}%, size: ${(totalSize / 1024 / 1024).toStringAsFixed(1)}MB)';
  }
}

/// Abstract cache manager interface
abstract class CacheManager<T> {
  /// Get an item from cache
  Future<T?> get(String key);

  /// Set an item in cache with optional TTL
  Future<void> set(String key, T value, {Duration? ttl});

  /// Remove an item from cache
  Future<void> remove(String key);

  /// Check if key exists in cache
  Future<bool> containsKey(String key);

  /// Clear all cache entries
  Future<void> clear();

  /// Get cache statistics
  CacheStatistics getStatistics();

  /// Evict least recently used entries
  Future<void> evictLRU();

  /// Evict expired entries
  Future<void> evictExpired();

  /// Get all cache keys
  Future<List<String>> getKeys();

  /// Get cache size in bytes
  Future<int> getSize();
}

/// Base implementation of cache manager
abstract class BaseCacheManager<T> implements CacheManager<T> {
  @protected
  final Map<String, CacheEntry<T>> _cache = {};
  final int maxSize;
  final Duration defaultTTL;

  // Statistics tracking
  int _hitCount = 0;
  int _missCount = 0;
  int _evictionCount = 0;

  BaseCacheManager({
    required this.maxSize,
    this.defaultTTL = PerformanceConstants.defaultCacheTTL,
  });

  @override
  Future<T?> get(String key) async {
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

    entry.markAccessed();
    _hitCount++;
    return entry.data;
  }

  @override
  Future<void> set(String key, T value, {Duration? ttl}) async {
    final expiresAt = ttl != null
        ? DateTime.now().add(ttl)
        : DateTime.now().add(defaultTTL);

    final entry = CacheEntry<T>(
      key: key,
      data: value,
      createdAt: DateTime.now(),
      expiresAt: expiresAt,
    );

    _cache[key] = entry;

    // Check if we need to evict entries
    if (await getSize() > maxSize) {
      await evictLRU();
    }

    if (kDebugMode) {
      debugPrint('Cache: Set $key (expires: ${expiresAt.toLocal()})');
    }
  }

  @override
  Future<void> remove(String key) async {
    final removed = _cache.remove(key);
    if (removed != null && kDebugMode) {
      debugPrint('Cache: Removed $key');
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

    if (kDebugMode) {
      debugPrint('Cache: Cleared $count entries');
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
      debugPrint('Cache: Evicted $toRemove LRU entries');
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
      debugPrint('Cache: Evicted ${expiredKeys.length} expired entries');
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
      totalSize += _calculateEntrySize(entry);
    }
    return totalSize;
  }

  /// Calculate size of a single cache entry
  /// Override this method in subclasses for specific size calculations
  int _calculateEntrySize(CacheEntry<T> entry) {
    try {
      // Default implementation using JSON encoding
      final json = jsonEncode(entry.toJson());
      return utf8.encode(json).length;
    } catch (e) {
      // Fallback to estimated size
      return 1024; // 1KB estimate
    }
  }
}
