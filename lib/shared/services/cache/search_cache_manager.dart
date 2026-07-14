import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'cache_manager.dart';
import '../../models/temple.dart';
import '../../models/temple_filters.dart';

/// Search result cache entry with query metadata
class SearchCacheEntry extends CacheEntry<List<Temple>> {
  final String query;
  final TempleFilters? filters;
  final int resultCount;
  final Map<String, dynamic> metadata;

  SearchCacheEntry({
    required super.key,
    required super.data,
    required this.query,
    this.filters,
    required this.resultCount,
    this.metadata = const {},
    required super.createdAt,
    super.expiresAt,
    super.accessCount = 1,
    super.lastAccessed,
  });

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json.addAll({
      'query': query,
      'filters': filters?.toJson(),
      'resultCount': resultCount,
      'metadata': metadata,
      'temples': data.map((temple) => temple.toCacheJson()).toList(),
    });
    return json;
  }

  factory SearchCacheEntry.fromJson(Map<String, dynamic> json) {
    final templesData = json['temples'] as List<dynamic>;
    final temples = templesData
        .map(
          (templeJson) =>
              Temple.fromCacheJson(templeJson as Map<String, dynamic>),
        )
        .toList();

    return SearchCacheEntry(
      key: json['key'],
      data: temples,
      query: json['query'],
      filters: json['filters'] != null
          ? TempleFilters.fromJson(json['filters'])
          : null,
      resultCount: json['resultCount'],
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
      createdAt: DateTime.parse(json['createdAt']),
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'])
          : null,
      accessCount: json['accessCount'] ?? 1,
      lastAccessed: DateTime.parse(json['lastAccessed']),
    );
  }

  /// Check if the search parameters match this cache entry
  bool matchesSearch(String searchQuery, TempleFilters? searchFilters) {
    if (query != searchQuery) return false;

    // Compare filters
    if (filters == null && searchFilters == null) return true;
    if (filters == null || searchFilters == null) return false;

    return filters!.isEquivalentTo(searchFilters);
  }
}

/// Search cache manager for temple search results with intelligent caching
class SearchCacheManager implements CacheManager<List<Temple>> {
  static final SearchCacheManager _instance = SearchCacheManager._internal();
  factory SearchCacheManager() => _instance;
  SearchCacheManager._internal();

  static const String _prefsKey = 'search_cache_metadata';
  SharedPreferences? _prefs;

  final Map<String, SearchCacheEntry> _cache = {};
  final int maxEntries = 20; // Reduced for memory optimization
  final Duration defaultTTL = const Duration(
    minutes: 15,
  ); // Shorter TTL for memory optimization
  final Duration popularSearchTTL = const Duration(
    minutes: 45,
  ); // Reduced popular search TTL

  // Statistics tracking
  int _hitCount = 0;
  int _missCount = 0;
  int _evictionCount = 0;

  // Popular search tracking
  final Map<String, int> _searchFrequency = {};
  final Map<String, DateTime> _lastSearchTime = {};

  // Periodic cleanup timer
  Timer? _cleanupTimer;

  /// Initialize the search cache manager
  Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      await _loadCacheMetadata();

      // Start periodic cleanup
      _startPeriodicCleanup();

      if (kDebugMode) {
        debugPrint(
          'SearchCache: Initialized with ${_cache.length} cached searches',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SearchCache: Error initializing - $e');
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
        try {
          final searchEntry = SearchCacheEntry.fromJson(entry.value);
          _cache[entry.key] = searchEntry;
        } catch (e) {
          if (kDebugMode) {
            debugPrint(
              'SearchCache: Error deserializing entry ${entry.key} - $e',
            );
          }
          // Skip corrupted entries and continue loading others
          continue;
        }
      }

      // Load search frequency data with error handling
      try {
        final frequencyJson = _prefs!.getString('${_prefsKey}_frequency');
        if (frequencyJson != null) {
          final frequencyData =
              jsonDecode(frequencyJson) as Map<String, dynamic>;
          _searchFrequency.addAll(
            frequencyData.map((key, value) => MapEntry(key, value as int)),
          );
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('SearchCache: Error loading frequency data - $e');
        }
        // Continue without frequency data if deserialization fails
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SearchCache: Critical error loading metadata - $e');
      }
      // Clear preferences if completely corrupted
      try {
        await _prefs!.remove(_prefsKey);
        await _prefs!.remove('${_prefsKey}_frequency');
      } catch (clearError) {
        if (kDebugMode) {
          debugPrint(
            'SearchCache: Error clearing corrupted preferences - $clearError',
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
            debugPrint('SearchCache: Critical error saving metadata - $e');
          }
          // Skip corrupted entries and continue
          continue;
        }
      }

      final metadataJson = jsonEncode(metadata);
      await _prefs!.setString(_prefsKey, metadataJson);

      // Save search frequency data with error handling
      try {
        final frequencyJson = jsonEncode(_searchFrequency);
        await _prefs!.setString('${_prefsKey}_frequency', frequencyJson);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('SearchCache: Error saving frequency data - $e');
        }
        // Continue without frequency data if serialization fails
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SearchCache: Critical error saving metadata - $e');
      }
      // Clear corrupted cache if serialization completely fails
      _cache.clear();
      _searchFrequency.clear();
    }
  }

  /// Cache search results with enhanced expiration logic
  Future<void> cacheSearchResults(
    String query,
    List<Temple> results, {
    TempleFilters? filters,
    Duration? ttl,
    Map<String, dynamic>? metadata,
  }) async {
    final cacheKey = _generateSearchKey(query, filters);

    // Track search frequency and patterns
    _searchFrequency[query] = (_searchFrequency[query] ?? 0) + 1;
    _lastSearchTime[query] = DateTime.now();

    // Determine TTL based on multiple factors
    Duration effectiveTTL = _calculateOptimalTTL(query, results, filters);
    if (ttl != null) {
      effectiveTTL = ttl;
    }

    // Check if we need to evict entries
    if (_cache.length >= maxEntries) {
      await _evictLeastUsedEntries();
    }

    // Enhanced metadata with performance tracking
    final enhancedMetadata = <String, dynamic>{
      ...metadata ?? {},
      'cacheTime': DateTime.now().toIso8601String(),
      'resultCount': results.length,
      'searchFrequency': _searchFrequency[query],
      'queryComplexity': _calculateQueryComplexity(query, filters),
      'dataFreshness': _calculateDataFreshness(results),
    };

    final entry = SearchCacheEntry(
      key: cacheKey,
      data: results,
      query: query,
      filters: filters,
      resultCount: results.length,
      metadata: enhancedMetadata,
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(effectiveTTL),
    );

    _cache[cacheKey] = entry;
    await _saveCacheMetadata();

    if (kDebugMode) {
      debugPrint(
        'SearchCache: Cached search "$query" with ${results.length} results '
        '(TTL: ${effectiveTTL.inMinutes}min, Complexity: ${enhancedMetadata['queryComplexity']})',
      );
    }
  }

  /// Calculate optimal TTL based on search characteristics
  Duration _calculateOptimalTTL(
    String query,
    List<Temple> results,
    TempleFilters? filters,
  ) {
    Duration baseTTL = defaultTTL;

    // Popular searches get longer TTL
    if (_isPopularSearch(query)) {
      baseTTL = popularSearchTTL;
    }

    // Empty queries (browse all) get shorter TTL as data changes more frequently
    if (query.isEmpty) {
      baseTTL = const Duration(minutes: 15);
    }

    // Location-based searches get shorter TTL
    if (filters?.userLocation != null) {
      baseTTL = const Duration(minutes: 20);
    }

    // Live darshan searches get very short TTL
    if (filters?.hasLiveDarshan == true) {
      baseTTL = const Duration(minutes: 5);
    }

    // Large result sets get longer TTL (expensive to recompute)
    if (results.length > 50) {
      baseTTL = Duration(milliseconds: (baseTTL.inMilliseconds * 1.5).round());
    }

    // Recent searches get shorter TTL to ensure freshness
    final lastSearch = _lastSearchTime[query];
    if (lastSearch != null &&
        DateTime.now().difference(lastSearch).inMinutes < 5) {
      baseTTL = Duration(milliseconds: (baseTTL.inMilliseconds * 0.7).round());
    }

    return baseTTL;
  }

  /// Calculate query complexity score
  int _calculateQueryComplexity(String query, TempleFilters? filters) {
    int complexity = 0;

    // Text query complexity
    if (query.isNotEmpty) {
      complexity += query.split(' ').length;
    }

    // Filter complexity
    if (filters != null) {
      if (filters.traditions?.isNotEmpty == true) complexity += 2;
      if (filters.features?.isNotEmpty == true) complexity += 2;
      if (filters.userLocation != null) complexity += 3;
      if (filters.maxDistance != null) complexity += 1;
      if (filters.hasLiveDarshan == true) complexity += 2;
      if (filters.states?.isNotEmpty == true) complexity += 1;
      if (filters.cities?.isNotEmpty == true) complexity += 1;
    }

    return complexity;
  }

  /// Calculate data freshness score based on temple update times
  double _calculateDataFreshness(List<Temple> temples) {
    if (temples.isEmpty) return 1.0;

    final now = DateTime.now();
    double totalFreshness = 0.0;

    for (final temple in temples) {
      final daysSinceUpdate = now.difference(temple.updatedAt).inDays;
      final freshness = daysSinceUpdate <= 1
          ? 1.0
          : daysSinceUpdate <= 7
          ? 0.8
          : daysSinceUpdate <= 30
          ? 0.6
          : 0.4;
      totalFreshness += freshness;
    }

    return totalFreshness / temples.length;
  }

  /// Get cached search results
  Future<List<Temple>?> getCachedSearchResults(
    String query, {
    TempleFilters? filters,
  }) async {
    final cacheKey = _generateSearchKey(query, filters);
    final entry = _cache[cacheKey];

    if (entry == null) {
      _missCount++;
      return null;
    }

    if (entry.isExpired) {
      await remove(cacheKey);
      _missCount++;
      return null;
    }

    // Check if search parameters match
    if (!entry.matchesSearch(query, filters)) {
      _missCount++;
      return null;
    }

    entry.markAccessed();
    _hitCount++;
    await _saveCacheMetadata();

    if (kDebugMode) {
      debugPrint(
        'SearchCache: Cache hit for "$query" (${entry.resultCount} results)',
      );
    }

    return entry.data;
  }

  /// Check if search results are cached
  Future<bool> hasSearchResults(String query, {TempleFilters? filters}) async {
    final results = await getCachedSearchResults(query, filters: filters);
    return results != null;
  }

  /// Get search suggestions based on cached queries
  /// Enhanced to support recent searches and popular temple suggestions
  List<String> getSearchSuggestions(String partialQuery, {int limit = 10}) {
    if (partialQuery.isEmpty) {
      // Return recent searches and popular searches
      return _getRecentAndPopularSearches(limit);
    }

    final suggestions = <String>[];
    final lowerQuery = partialQuery.toLowerCase();

    // Find matching cached queries
    for (final entry in _cache.values) {
      if (entry.query.toLowerCase().contains(lowerQuery) &&
          !suggestions.contains(entry.query) &&
          entry.query.isNotEmpty) {
        suggestions.add(entry.query);
      }
    }

    // Sort by relevance, frequency, and recency
    suggestions.sort((a, b) {
      final aLower = a.toLowerCase();
      final bLower = b.toLowerCase();

      // Prioritize exact starts with query
      final aStartsWith = aLower.startsWith(lowerQuery);
      final bStartsWith = bLower.startsWith(lowerQuery);

      if (aStartsWith && !bStartsWith) return -1;
      if (!aStartsWith && bStartsWith) return 1;

      // Then by frequency
      final aFreq = _searchFrequency[a] ?? 0;
      final bFreq = _searchFrequency[b] ?? 0;

      if (aFreq != bFreq) {
        return bFreq.compareTo(aFreq); // Higher frequency first
      }

      // Finally by recency
      final aTime = _lastSearchTime[a] ?? DateTime(1970);
      final bTime = _lastSearchTime[b] ?? DateTime(1970);
      return bTime.compareTo(aTime); // More recent first
    });

    return suggestions.take(limit).toList();
  }

  /// Get recent and popular searches for empty query
  List<String> _getRecentAndPopularSearches(int limit) {
    final suggestions = <String>[];

    // Get recent searches (last 5)
    final recentSearches = _getRecentSearches(5);
    suggestions.addAll(recentSearches);

    // Get popular searches (remaining slots)
    final remainingSlots = limit - suggestions.length;
    if (remainingSlots > 0) {
      final popularSearches = _getPopularSearches(remainingSlots);
      // Add popular searches that aren't already in recent
      for (final popular in popularSearches) {
        if (!suggestions.contains(popular)) {
          suggestions.add(popular);
        }
      }
    }

    return suggestions.take(limit).toList();
  }

  /// Get recent searches based on last search time
  List<String> _getRecentSearches(int limit) {
    final recentEntries = _lastSearchTime.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value)); // Most recent first

    return recentEntries
        .take(limit)
        .map((entry) => entry.key)
        .where((query) => query.isNotEmpty)
        .toList();
  }

  /// Get popular searches
  List<String> _getPopularSearches(int limit) {
    final sortedSearches = _searchFrequency.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedSearches.take(limit).map((entry) => entry.key).toList();
  }

  /// Check if a search is popular
  bool _isPopularSearch(String query) {
    final frequency = _searchFrequency[query] ?? 0;
    return frequency >= 3; // Consider popular if searched 3+ times
  }

  /// Generate cache key for search
  String _generateSearchKey(String query, TempleFilters? filters) {
    final filterHash = filters?.hashCode ?? 0;
    return 'search_${query.hashCode}_$filterHash';
  }

  /// Evict least used entries to make room
  Future<void> _evictLeastUsedEntries() async {
    if (_cache.isEmpty) return;

    // Sort by access count and last accessed time
    final entries = _cache.values.toList()
      ..sort((a, b) {
        final accessComparison = a.accessCount.compareTo(b.accessCount);
        if (accessComparison != 0) return accessComparison;
        return a.lastAccessed.compareTo(b.lastAccessed);
      });

    // Remove oldest 25% of entries
    final toRemove = (entries.length * 0.25).ceil();
    for (int i = 0; i < toRemove && i < entries.length; i++) {
      await remove(entries[i].key);
      _evictionCount++;
    }

    if (kDebugMode) {
      debugPrint('SearchCache: Evicted $toRemove least used entries');
    }
  }

  /// Start periodic cleanup of expired entries
  void _startPeriodicCleanup() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(const Duration(minutes: 15), (_) {
      evictExpired();
    });
  }

  /// Cancel the periodic cleanup timer (call when the cache is no longer needed)
  void cancelCleanup() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
  }

  @override
  Future<List<Temple>?> get(String key) async {
    final entry = _cache[key];
    if (entry == null || entry.isExpired) {
      return null;
    }

    entry.markAccessed();
    return entry.data;
  }

  @override
  Future<void> set(String key, List<Temple> data, {Duration? ttl}) async {
    // Delegate to cacheSearchResults with the key used as the query
    await cacheSearchResults(key, data, ttl: ttl);
  }

  @override
  Future<void> remove(String key) async {
    final entry = _cache.remove(key);
    if (entry != null) {
      await _saveCacheMetadata();

      if (kDebugMode) {
        debugPrint('SearchCache: Removed search "${entry.query}"');
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
    _searchFrequency.clear();
    _lastSearchTime.clear();
    _hitCount = 0;
    _missCount = 0;
    _evictionCount = 0;
    await _saveCacheMetadata();

    if (kDebugMode) {
      debugPrint('SearchCache: Cleared $count search entries');
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
    await _evictLeastUsedEntries();
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
      debugPrint('SearchCache: Evicted ${expiredKeys.length} expired searches');
    }
  }

  @override
  Future<List<String>> getKeys() async {
    await evictExpired();
    return _cache.keys.toList();
  }

  @override
  Future<int> getSize() async {
    return _calculateTotalSize();
  }

  /// Calculate total cache size (approximate)
  int _calculateTotalSize() {
    int totalSize = 0;
    for (final entry in _cache.values) {
      // Approximate size calculation
      totalSize += entry.resultCount * 1024; // Rough estimate per temple
    }
    return totalSize;
  }

  /// Calculate cache health score (0.0 to 1.0)
  // Removed _calculateCacheHealth - unused method

  /// Invalidate searches containing specific terms
  Future<void> invalidateSearchesContaining(String term) async {
    final keysToRemove = <String>[];
    final lowerTerm = term.toLowerCase();

    for (final entry in _cache.values) {
      if (entry.query.toLowerCase().contains(lowerTerm)) {
        keysToRemove.add(entry.key);
      }
    }

    for (final key in keysToRemove) {
      await remove(key);
    }

    if (kDebugMode && keysToRemove.isNotEmpty) {
      debugPrint(
        'SearchCache: Invalidated ${keysToRemove.length} searches containing "$term"',
      );
    }
  }

  /// Refresh search results for a specific query
  Future<void> refreshSearch(String query, {TempleFilters? filters}) async {
    final cacheKey = _generateSearchKey(query, filters);
    await remove(cacheKey);
  }

  /// Compress cache to reduce memory usage
  Future<void> compressCache({double targetRatio = 0.5}) async {
    try {
      final keys = _cache.keys.toList();
      final targetSize = (keys.length * targetRatio).round();

      // Sort by access count and last accessed time
      keys.sort((a, b) {
        final entryA = _cache[a]!;
        final entryB = _cache[b]!;

        // Prioritize by access count first, then by last accessed time
        final accessComparison = entryA.accessCount.compareTo(
          entryB.accessCount,
        );
        if (accessComparison != 0) return accessComparison;

        return entryA.lastAccessed.compareTo(entryB.lastAccessed);
      });

      // Remove least accessed entries
      for (int i = 0; i < keys.length - targetSize; i++) {
        _cache.remove(keys[i]);
      }

      await _persistCache();
    } catch (e) {
      if (kDebugMode) {
        print('Error compressing search cache: $e');
      }
    }
  }

  /// Clear all cache entries
  Future<void> clearAll() async {
    try {
      _cache.clear();
      await _persistCache();
    } catch (e) {
      if (kDebugMode) {
        print('Error clearing search cache: $e');
      }
    }
  }

  /// Persist cache to SharedPreferences
  Future<void> _persistCache() async {
    await _saveCacheMetadata();
  }
}
