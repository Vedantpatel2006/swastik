import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../shared/models/temple.dart';
import '../../../shared/models/temple_filters.dart';
import '../../../shared/services/cache/search_cache_manager.dart';
import '../../../shared/services/offline/offline_manager.dart';
import 'user_temple_service.dart';

/// Enhanced search filters with additional search-specific options
class SearchFilters extends TempleFilters {
  final bool includeInactive;
  final DateTime? updatedAfter;
  final DateTime? updatedBefore;
  final List<String>? excludeIds;
  final int? minVisitCount;
  final double? minRating;
  final bool prioritizeLiveDarshan;
  final bool prioritizeNearby;

  const SearchFilters({
    // Inherit all TempleFilters properties
    super.searchQuery,
    super.traditions,
    super.features,
    super.maxDistance,
    super.userLocation,
    super.hasLiveDarshan,
    super.isActive,
    super.cities,
    super.states,
    super.sortBy,
    super.ascending,
    super.mainDeity,

    // Additional search-specific properties
    this.includeInactive = false,
    this.updatedAfter,
    this.updatedBefore,
    this.excludeIds,
    this.minVisitCount,
    this.minRating,
    this.prioritizeLiveDarshan = false,
    this.prioritizeNearby = false,
  });

  @override
  SearchFilters copyWith({
    String? searchQuery,
    List<String>? traditions,
    List<String>? features,
    double? maxDistance,
    Location? userLocation,
    bool? hasLiveDarshan,
    bool? isActive,
    List<String>? cities,
    List<String>? states,
    SortOption? sortBy,
    bool? ascending,
    double? latitude,
    double? longitude,
    double? radiusKm,
    String? category,
    bool? isLiveStreamAvailable,
    bool? hasEvents,
    double? minRating,
    String? favoriteUserId,
    String? mainDeity,
    bool? includeInactive,
    DateTime? updatedAfter,
    DateTime? updatedBefore,
    List<String>? excludeIds,
    int? minVisitCount,
    bool? prioritizeLiveDarshan,
    bool? prioritizeNearby,
  }) {
    return SearchFilters(
      searchQuery: searchQuery ?? this.searchQuery,
      traditions: traditions ?? this.traditions,
      features: features ?? this.features,
      maxDistance: maxDistance ?? this.maxDistance,
      userLocation: userLocation ?? this.userLocation,
      hasLiveDarshan: hasLiveDarshan ?? this.hasLiveDarshan,
      isActive: isActive ?? this.isActive,
      cities: cities ?? this.cities,
      states: states ?? this.states,
      sortBy: sortBy ?? this.sortBy,
      ascending: ascending ?? this.ascending,
      mainDeity: mainDeity ?? this.mainDeity,
      includeInactive: includeInactive ?? this.includeInactive,
      updatedAfter: updatedAfter ?? this.updatedAfter,
      updatedBefore: updatedBefore ?? this.updatedBefore,
      excludeIds: excludeIds ?? this.excludeIds,
      minVisitCount: minVisitCount ?? this.minVisitCount,
      minRating: minRating ?? this.minRating,
      prioritizeLiveDarshan:
          prioritizeLiveDarshan ?? this.prioritizeLiveDarshan,
      prioritizeNearby: prioritizeNearby ?? this.prioritizeNearby,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json.addAll({
      'includeInactive': includeInactive,
      if (updatedAfter != null) 'updatedAfter': updatedAfter!.toIso8601String(),
      if (updatedBefore != null)
        'updatedBefore': updatedBefore!.toIso8601String(),
      if (excludeIds != null) 'excludeIds': excludeIds,
      if (minVisitCount != null) 'minVisitCount': minVisitCount,
      if (minRating != null) 'minRating': minRating,
      'prioritizeLiveDarshan': prioritizeLiveDarshan,
      'prioritizeNearby': prioritizeNearby,
    });
    return json;
  }

  factory SearchFilters.fromJson(Map<String, dynamic> json) {
    return SearchFilters(
      searchQuery: json['searchQuery'] as String?,
      traditions: json['traditions'] != null
          ? List<String>.from(json['traditions'] as List)
          : null,
      features: json['features'] != null
          ? List<String>.from(json['features'] as List)
          : null,
      maxDistance: json['maxDistance'] as double?,
      userLocation: json['userLocation'] != null
          ? Location.fromJson(json['userLocation'] as Map<String, dynamic>)
          : null,
      hasLiveDarshan: json['hasLiveDarshan'] as bool?,
      isActive: json['isActive'] as bool? ?? true,
      cities: json['cities'] != null
          ? List<String>.from(json['cities'] as List)
          : null,
      states: json['states'] != null
          ? List<String>.from(json['states'] as List)
          : null,
      sortBy: SortOption.values.firstWhere(
        (e) => e.name == json['sortBy'],
        orElse: () => SortOption.name,
      ),
      ascending: json['ascending'] as bool? ?? true,
      includeInactive: json['includeInactive'] as bool? ?? false,
      updatedAfter: json['updatedAfter'] != null
          ? DateTime.parse(json['updatedAfter'] as String)
          : null,
      updatedBefore: json['updatedBefore'] != null
          ? DateTime.parse(json['updatedBefore'] as String)
          : null,
      excludeIds: json['excludeIds'] != null
          ? List<String>.from(json['excludeIds'] as List)
          : null,
      minVisitCount: json['minVisitCount'] as int?,
      minRating: json['minRating'] as double?,
      prioritizeLiveDarshan: json['prioritizeLiveDarshan'] as bool? ?? false,
      prioritizeNearby: json['prioritizeNearby'] as bool? ?? false,
    );
  }
}

/// Enhanced search results with metadata and performance information
class SearchResults {
  final List<Temple> temples;
  final int totalCount;
  final Map<String, int> filterCounts;
  final Duration searchTime;
  final bool fromCache;
  final String? nextPageToken;
  final Map<String, dynamic> metadata;
  final SearchFilters? appliedFilters;

  const SearchResults({
    required this.temples,
    required this.totalCount,
    this.filterCounts = const {},
    required this.searchTime,
    this.fromCache = false,
    this.nextPageToken,
    this.metadata = const {},
    this.appliedFilters,
  });

  /// Create a copy with updated fields
  SearchResults copyWith({
    List<Temple>? temples,
    int? totalCount,
    Map<String, int>? filterCounts,
    Duration? searchTime,
    bool? fromCache,
    String? nextPageToken,
    Map<String, dynamic>? metadata,
    SearchFilters? appliedFilters,
  }) {
    return SearchResults(
      temples: temples ?? this.temples,
      totalCount: totalCount ?? this.totalCount,
      filterCounts: filterCounts ?? this.filterCounts,
      searchTime: searchTime ?? this.searchTime,
      fromCache: fromCache ?? this.fromCache,
      nextPageToken: nextPageToken ?? this.nextPageToken,
      metadata: metadata ?? this.metadata,
      appliedFilters: appliedFilters ?? this.appliedFilters,
    );
  }

  /// Convert to JSON for caching
  Map<String, dynamic> toJson() {
    return {
      'temples': temples.map((temple) => temple.toCacheJson()).toList(),
      'totalCount': totalCount,
      'filterCounts': filterCounts,
      'searchTimeMs': searchTime.inMilliseconds,
      'fromCache': fromCache,
      if (nextPageToken != null) 'nextPageToken': nextPageToken,
      'metadata': metadata,
      if (appliedFilters != null) 'appliedFilters': appliedFilters!.toJson(),
    };
  }

  /// Create from JSON
  factory SearchResults.fromJson(Map<String, dynamic> json) {
    final templesData = json['temples'] as List<dynamic>;
    final temples = templesData
        .map(
          (templeJson) =>
              Temple.fromCacheJson(templeJson as Map<String, dynamic>),
        )
        .toList();

    return SearchResults(
      temples: temples,
      totalCount: json['totalCount'] as int,
      filterCounts: Map<String, int>.from(json['filterCounts'] as Map? ?? {}),
      searchTime: Duration(milliseconds: json['searchTimeMs'] as int),
      fromCache: json['fromCache'] as bool? ?? false,
      nextPageToken: json['nextPageToken'] as String?,
      metadata: Map<String, dynamic>.from(json['metadata'] as Map? ?? {}),
      appliedFilters: json['appliedFilters'] != null
          ? SearchFilters.fromJson(
              json['appliedFilters'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  /// Check if there are more results available
  bool get hasMoreResults => nextPageToken != null;

  /// Check if results are empty
  bool get isEmpty => temples.isEmpty;

  /// Check if results are not empty
  bool get isNotEmpty => temples.isNotEmpty;

  @override
  String toString() {
    return 'SearchResults(count: ${temples.length}/$totalCount, '
        'time: ${searchTime.inMilliseconds}ms, fromCache: $fromCache)';
  }
}

/// User search preferences for personalization
class SearchPreferences {
  final String userId;
  final List<String> recentSearches;
  final Map<String, int> searchFrequency;
  final List<String> favoriteFilters;
  final SortOption defaultSortBy;
  final bool defaultAscending;
  final double? defaultMaxDistance;
  final bool enableAutoComplete;
  final bool enableSearchHistory;
  final DateTime lastUpdated;

  const SearchPreferences({
    required this.userId,
    this.recentSearches = const [],
    this.searchFrequency = const {},
    this.favoriteFilters = const [],
    this.defaultSortBy = SortOption.name,
    this.defaultAscending = true,
    this.defaultMaxDistance,
    this.enableAutoComplete = true,
    this.enableSearchHistory = true,
    required this.lastUpdated,
  });

  /// Create a copy with updated fields
  SearchPreferences copyWith({
    String? userId,
    List<String>? recentSearches,
    Map<String, int>? searchFrequency,
    List<String>? favoriteFilters,
    SortOption? defaultSortBy,
    bool? defaultAscending,
    double? defaultMaxDistance,
    bool? enableAutoComplete,
    bool? enableSearchHistory,
    DateTime? lastUpdated,
  }) {
    return SearchPreferences(
      userId: userId ?? this.userId,
      recentSearches: recentSearches ?? this.recentSearches,
      searchFrequency: searchFrequency ?? this.searchFrequency,
      favoriteFilters: favoriteFilters ?? this.favoriteFilters,
      defaultSortBy: defaultSortBy ?? this.defaultSortBy,
      defaultAscending: defaultAscending ?? this.defaultAscending,
      defaultMaxDistance: defaultMaxDistance ?? this.defaultMaxDistance,
      enableAutoComplete: enableAutoComplete ?? this.enableAutoComplete,
      enableSearchHistory: enableSearchHistory ?? this.enableSearchHistory,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'recentSearches': recentSearches,
      'searchFrequency': searchFrequency,
      'favoriteFilters': favoriteFilters,
      'defaultSortBy': defaultSortBy.name,
      'defaultAscending': defaultAscending,
      if (defaultMaxDistance != null) 'defaultMaxDistance': defaultMaxDistance,
      'enableAutoComplete': enableAutoComplete,
      'enableSearchHistory': enableSearchHistory,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  /// Create from JSON
  factory SearchPreferences.fromJson(Map<String, dynamic> json) {
    return SearchPreferences(
      userId: json['userId'] as String,
      recentSearches: List<String>.from(json['recentSearches'] as List? ?? []),
      searchFrequency: Map<String, int>.from(
        json['searchFrequency'] as Map? ?? {},
      ),
      favoriteFilters: List<String>.from(
        json['favoriteFilters'] as List? ?? [],
      ),
      defaultSortBy: SortOption.values.firstWhere(
        (e) => e.name == json['defaultSortBy'],
        orElse: () => SortOption.name,
      ),
      defaultAscending: json['defaultAscending'] as bool? ?? true,
      defaultMaxDistance: json['defaultMaxDistance'] as double?,
      enableAutoComplete: json['enableAutoComplete'] as bool? ?? true,
      enableSearchHistory: json['enableSearchHistory'] as bool? ?? true,
      lastUpdated: DateTime.parse(json['lastUpdated'] as String),
    );
  }

  /// Add a search to recent searches
  SearchPreferences addRecentSearch(String query) {
    final updatedRecent = List<String>.from(recentSearches);
    updatedRecent.remove(query); // Remove if already exists
    updatedRecent.insert(0, query); // Add to beginning

    // Keep only last 20 searches
    if (updatedRecent.length > 20) {
      updatedRecent.removeRange(20, updatedRecent.length);
    }

    final updatedFrequency = Map<String, int>.from(searchFrequency);
    updatedFrequency[query] = (updatedFrequency[query] ?? 0) + 1;

    return copyWith(
      recentSearches: updatedRecent,
      searchFrequency: updatedFrequency,
      lastUpdated: DateTime.now(),
    );
  }

  /// Get popular searches based on frequency
  List<String> getPopularSearches({int limit = 10}) {
    final sortedEntries = searchFrequency.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedEntries.take(limit).map((entry) => entry.key).toList();
  }
}

/// Advanced search manager that coordinates search operations across multiple services
class SearchManager {
  static final SearchManager _instance = SearchManager._internal();
  factory SearchManager() => _instance;
  SearchManager._internal();

  // Service dependencies
  UserTempleService? _userTempleService;
  SearchCacheManager? _searchCache;
  OfflineManager? _offlineManager;

  // Caching for performance optimization
  final Map<String, List<String>> _locationSuggestionsCache = {};
  List<Temple> _allTemplesCache = [];
  DateTime? _cacheLastUpdated;
  DateTime? _allTemplesCacheUpdated;
  static const Duration _allTemplesCacheTTL = Duration(minutes: 30);

  // Lazy getters for services
  UserTempleService get userTempleService =>
      _userTempleService ??= UserTempleService();
  SearchCacheManager get searchCache => _searchCache ??= SearchCacheManager();
  OfflineManager get offlineManager => _offlineManager ??= OfflineManager();

  // Search preferences cache
  final Map<String, SearchPreferences> _preferencesCache = {};

  /// Initialize the search manager
  Future<void> initialize() async {
    await userTempleService.initialize();
    await searchCache.initialize();
    await offlineManager.initialize();

    // Clear cache if it's older than 1 hour
    if (_cacheLastUpdated != null &&
        DateTime.now().difference(_cacheLastUpdated!).inHours > 1) {
      _clearCache();
    }

    if (kDebugMode) {
      debugPrint('SearchManager: Initialized successfully');
    }
  }

  /// Clear internal caches
  void _clearCache() {
    _locationSuggestionsCache.clear();
    _allTemplesCache.clear();
    _cacheLastUpdated = null;
    _allTemplesCacheUpdated = null;
  }

  /// Perform advanced search with comprehensive filtering and caching
  Future<SearchResults> performAdvancedSearch({
    required String query,
    required SearchFilters filters,
    required SortOptions sortBy,
    bool useCache = true,
    int? limit,
    int? offset,
  }) async {
    final searchStartTime = DateTime.now();
    // Normalize query at method level so it's available throughout
    final normalizedQuery = query.trim().toLowerCase();

    try {
      // Merge sortBy into filters so the cache key is sort-aware
      final filtersWithSort = filters.copyWith(
        sortBy: sortBy.sortBy,
        ascending: sortBy.ascending,
      );

      // Check cache first if enabled
      if (useCache) {
        final cachedResults = await searchCache.getCachedSearchResults(
          normalizedQuery,
          filters: filtersWithSort,
        );

        if (cachedResults != null) {
          final searchTime = DateTime.now().difference(searchStartTime);
          return SearchResults(
            temples: cachedResults,
            totalCount: cachedResults.length,
            searchTime: searchTime,
            fromCache: true,
            appliedFilters: filtersWithSort,
            metadata: {
              'cacheHit': true,
              'searchTime': searchTime.inMilliseconds,
            },
          );
        }
      }

      // Convert SearchFilters to TempleFilters for UserTempleService
      final templeFilters = TempleFilters(
        searchQuery: normalizedQuery,
        traditions: filters.traditions,
        features: filters.features,
        maxDistance: filters.maxDistance,
        userLocation: filters.userLocation,
        hasLiveDarshan: filters.hasLiveDarshan,
        isActive: filters.includeInactive ? null : (filters.isActive ?? true),
        cities: filters.cities,
        states: filters.states,
        sortBy: filters.sortBy,
        ascending: filters.ascending,
      );

      // Perform comprehensive text search using enhanced UserTempleService
      List<Temple> temples = await _performComprehensiveTextSearch(
        normalizedQuery,
        templeFilters,
        limit: limit,
        offset: offset,
      );

      // Apply additional SearchFilters-specific filtering
      temples = _applyAdvancedFiltering(temples, filters);

      // Apply sorting first, then prioritization on top so live/nearby temples
      // always float to the front regardless of the chosen sort order.
      temples = _applySorting(temples, sortBy);
      temples = _applyPrioritizationIfNeeded(temples, filters);

      // Calculate filter counts for UI
      final filterCounts = _calculateFilterCounts(temples);

      // Calculate search time
      final searchTime = DateTime.now().difference(searchStartTime);

      // Create search results with enhanced metadata
      final results = SearchResults(
        temples: temples,
        totalCount: temples.length,
        filterCounts: filterCounts,
        searchTime: searchTime,
        fromCache: false,
        appliedFilters: filtersWithSort,
        metadata: {
          'cacheHit': false,
          'searchTime': searchTime.inMilliseconds,
          'originalQuery': query,
          'normalizedQuery': normalizedQuery,
          'filtersApplied': filters.hasFilters,
          'searchFields': _getSearchedFields(normalizedQuery),
          'resultCount': temples.length,
        },
      );

      // Cache results if enabled and not empty
      if (useCache && temples.isNotEmpty) {
        await searchCache.cacheSearchResults(
          normalizedQuery,
          temples,
          filters: filtersWithSort,
          metadata: results.metadata,
        );
      }

      if (kDebugMode) {
        debugPrint(
          'SearchManager: Search completed - ${temples.length} results in ${searchTime.inMilliseconds}ms',
        );
      }

      return results;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SearchManager: Error performing search - $e');
      }

      // Try to return cached results as fallback
      if (useCache) {
        try {
          final cachedResults = await searchCache.getCachedSearchResults(
            normalizedQuery,
            filters: filters,
          );

          if (cachedResults != null) {
            final searchTime = DateTime.now().difference(searchStartTime);
            return SearchResults(
              temples: cachedResults,
              totalCount: cachedResults.length,
              searchTime: searchTime,
              fromCache: true,
              appliedFilters: filters,
              metadata: {
                'cacheHit': true,
                'fallbackUsed': true,
                'originalError': e.toString(),
              },
            );
          }
        } catch (cacheError) {
          if (kDebugMode) {
            debugPrint(
              'SearchManager: Cache fallback also failed - $cacheError',
            );
          }
        }
      }

      // Return empty results with error information
      final searchTime = DateTime.now().difference(searchStartTime);
      return SearchResults(
        temples: [],
        totalCount: 0,
        searchTime: searchTime,
        fromCache: false,
        appliedFilters: filters,
        metadata: {
          'error': true,
          'errorMessage': e.toString(),
          'searchTime': searchTime.inMilliseconds,
        },
      );
    }
  }

  /// Perform comprehensive text search across temple fields
  /// Searches name, location, deity, and description fields as per requirements 1.1, 1.2
  Future<List<Temple>> _performComprehensiveTextSearch(
    String query,
    TempleFilters filters, {
    int? limit,
    int? offset,
  }) async {
    if (query.isEmpty) {
      // For empty queries, return all temples with applied filters
      return await userTempleService.searchTemples(
        '',
        filters: filters,
        useCache: false,
        limit: limit,
        offset: offset,
      );
    }

    // Get all temples first, then apply comprehensive text filtering
    List<Temple> allTemples = await userTempleService.searchTemples(
      '',
      filters: filters.copyWith(
        searchQuery: null,
      ), // Remove query to get all temples
      useCache: false,
    );

    // Apply comprehensive text search across multiple fields
    final searchTerms = query
        .toLowerCase()
        .split(' ')
        .where((term) => term.isNotEmpty)
        .toList();

    final filteredTemples = allTemples.where((temple) {
      return _matchesComprehensiveSearch(temple, searchTerms);
    }).toList();

    // Apply pagination
    if (offset != null && offset > 0) {
      if (offset >= filteredTemples.length) return [];
      filteredTemples.removeRange(0, offset);
    }

    if (limit != null && limit > 0 && filteredTemples.length > limit) {
      return filteredTemples.take(limit).toList();
    }

    return filteredTemples;
  }

  /// Check if temple matches comprehensive search across all relevant fields
  bool _matchesComprehensiveSearch(Temple temple, List<String> searchTerms) {
    // Build comprehensive searchable text from all relevant fields
    final searchableFields = [
      temple.name.toLowerCase(),
      temple.description.toLowerCase(),
      temple.location.address?.toLowerCase() ?? '',
      temple.location.city?.toLowerCase() ?? '',
      temple.location.state?.toLowerCase() ?? '',
      temple.location.country?.toLowerCase() ?? '',
      ...temple.traditions.map((t) => t.toLowerCase()),
      ...temple.features.map((f) => f.toLowerCase()),
      // Include contact information in search
      temple.contact.phone?.toLowerCase() ?? '',
      temple.contact.email?.toLowerCase() ?? '',
      temple.contact.website?.toLowerCase() ?? '',
    ];

    final searchableText = searchableFields.join(' ');

    // All search terms must be found in the searchable text
    return searchTerms.every((term) => searchableText.contains(term));
  }

  /// Apply sorting based on SortOptions
  List<Temple> _applySorting(List<Temple> temples, SortOptions sortBy) {
    temples.sort((a, b) {
      int comparison;

      switch (sortBy.sortBy) {
        case SortOption.name:
          comparison = a.name.compareTo(b.name);
          break;
        case SortOption.distance:
          final aDistance = a.distanceFromUser ?? double.infinity;
          final bDistance = b.distanceFromUser ?? double.infinity;
          comparison = aDistance.compareTo(bDistance);
          break;
        case SortOption.createdAt:
          comparison = a.createdAt.compareTo(b.createdAt);
          break;
        case SortOption.updatedAt:
          comparison = a.updatedAt.compareTo(b.updatedAt);
          break;
        case SortOption.visitCount:
          comparison = a.visitCount.compareTo(b.visitCount);
          break;
        case SortOption.tradition:
          final aTradition = a.traditions.isNotEmpty ? a.traditions.first : '';
          final bTradition = b.traditions.isNotEmpty ? b.traditions.first : '';
          comparison = aTradition.compareTo(bTradition);
          break;
        case SortOption.rating:
          comparison = a.averageRating.compareTo(b.averageRating);
          break;
        case SortOption.popularity:
          // Popularity based on combination of visit count and rating
          final aPopularity = (a.visitCount * 0.7) + (a.averageRating * 0.3);
          final bPopularity = (b.visitCount * 0.7) + (b.averageRating * 0.3);
          comparison = aPopularity.compareTo(bPopularity);
          break;
      }

      return sortBy.ascending ? comparison : -comparison;
    });

    return temples;
  }

  /// Get list of fields that were searched for metadata
  List<String> _getSearchedFields(String query) {
    if (query.isEmpty) return [];

    return [
      'name',
      'description',
      'location.address',
      'location.city',
      'location.state',
      'traditions',
      'features',
      'contact.phone',
      'contact.email',
      'contact.website',
    ];
  }

  /// Get search suggestions based on query and user preferences
  /// Implements suggestion engine based on temple names and locations
  /// Adds recent searches and popular temple suggestions as per requirements 1.4, 1.5, 6.3, 6.4
  Stream<List<String>> getSearchSuggestions(String query) async* {
    try {
      if (query.isEmpty) {
        // Return recent searches and popular temples for empty query
        final suggestions = await _getEmptyQuerySuggestions();
        yield suggestions;
        return;
      }

      // Get comprehensive suggestions for non-empty query
      final suggestions = await _getComprehensiveSuggestions(query);
      yield suggestions;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SearchManager: Error getting search suggestions - $e');
      }
      yield [];
    }
  }

  /// Get suggestions for empty query (recent searches and popular temples)
  Future<List<String>> _getEmptyQuerySuggestions() async {
    final suggestions = <String>[];

    // Get recent searches from cache (up to 5)
    final recentSearches = searchCache.getSearchSuggestions('', limit: 5);
    suggestions.addAll(recentSearches);

    // Get popular temple names (up to 5)
    final popularTemples = await _getPopularTempleSuggestions(5);
    suggestions.addAll(popularTemples);

    // Remove duplicates while preserving order
    final uniqueSuggestions = <String>[];
    final seen = <String>{};

    for (final suggestion in suggestions) {
      if (seen.add(suggestion.toLowerCase())) {
        uniqueSuggestions.add(suggestion);
      }
    }

    return uniqueSuggestions.take(10).toList();
  }

  /// Get comprehensive suggestions for non-empty query
  Future<List<String>> _getComprehensiveSuggestions(String query) async {
    final suggestions = <String>[];
    final normalizedQuery = query.toLowerCase().trim();

    // 1. Get cache suggestions (recent/popular searches matching query)
    final cacheSuggestions = searchCache.getSearchSuggestions(query, limit: 3);
    suggestions.addAll(cacheSuggestions);

    // 2. Get temple name suggestions
    final templeNameSuggestions = await _getTempleNameSuggestions(
      normalizedQuery,
      limit: 4,
    );
    suggestions.addAll(templeNameSuggestions);

    // 3. Get location suggestions (cities, states)
    final locationSuggestions = await _getLocationSuggestions(
      normalizedQuery,
      limit: 3,
    );
    suggestions.addAll(locationSuggestions);

    // Remove duplicates while preserving order and relevance.
    // Note: cache suggestions are already filtered to match the query, so we
    // only need to deduplicate — not re-filter — here.
    final uniqueSuggestions = <String>[];
    final seen = <String>{};

    for (final suggestion in suggestions) {
      final normalizedSuggestion = suggestion.toLowerCase();
      if (seen.add(normalizedSuggestion)) {
        uniqueSuggestions.add(suggestion);
      }
    }

    return uniqueSuggestions.take(10).toList();
  }

  /// Get temple name suggestions based on partial query
  Future<List<String>> _getTempleNameSuggestions(
    String query, {
    int limit = 5,
  }) async {
    try {
      // Search temples with the query to get matching temple names
      final results = await userTempleService.searchTemples(
        query,
        limit: limit * 2, // Get more results to filter better matches
        useCache: true,
      );

      final suggestions = <String>[];
      final queryLower = query.toLowerCase();

      for (final temple in results) {
        final templeName = temple.name;
        final templeNameLower = templeName.toLowerCase();

        // Prioritize temples whose names start with the query
        if (templeNameLower.startsWith(queryLower)) {
          suggestions.insert(0, templeName);
        } else if (templeNameLower.contains(queryLower)) {
          suggestions.add(templeName);
        }
      }

      // Remove duplicates and limit results
      return suggestions.toSet().take(limit).toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SearchManager: Error getting temple name suggestions - $e');
      }
      return [];
    }
  }

  /// Get location-based suggestions (cities, states) with caching
  Future<List<String>> _getLocationSuggestions(
    String query, {
    int limit = 5,
  }) async {
    try {
      // Use cached location data if available
      if (_locationSuggestionsCache.containsKey(query)) {
        return _locationSuggestionsCache[query]!.take(limit).toList();
      }

      // Get temples to extract location information (use cached results if possible)
      List<Temple> results;
      final cacheExpired =
          _allTemplesCacheUpdated == null ||
          DateTime.now().difference(_allTemplesCacheUpdated!) >
              _allTemplesCacheTTL;
      if (_allTemplesCache.isNotEmpty && !cacheExpired) {
        results = _allTemplesCache;
      } else {
        results = await userTempleService.searchTemples(
          '',
          limit: 200, // Reasonable limit for location extraction
          useCache: true,
        );
        _allTemplesCache = results; // Cache for future use
        _allTemplesCacheUpdated = DateTime.now();
      }

      final locationSuggestions = <String>{};
      final queryLower = query.toLowerCase();

      for (final temple in results) {
        final location = temple.location;

        // Add city suggestions
        if (location.city?.isNotEmpty == true &&
            location.city!.toLowerCase().contains(queryLower)) {
          locationSuggestions.add(location.city!);
        }

        // Add state suggestions
        if (location.state?.isNotEmpty == true &&
            location.state!.toLowerCase().contains(queryLower)) {
          locationSuggestions.add(location.state!);
        }

        // Add meaningful address parts
        if (location.address?.isNotEmpty == true &&
            location.address!.toLowerCase().contains(queryLower)) {
          final addressParts = location.address!.split(',');
          for (final part in addressParts) {
            final trimmedPart = part.trim();
            if (trimmedPart.length > 3 &&
                trimmedPart.toLowerCase().contains(queryLower) &&
                !trimmedPart.contains(RegExp(r'\d{5,}'))) {
              // Avoid postal codes
              locationSuggestions.add(trimmedPart);
            }
          }
        }
      }

      // Sort by relevance (starts with query first)
      final sortedSuggestions = locationSuggestions.toList();
      sortedSuggestions.sort((a, b) {
        final aStartsWith = a.toLowerCase().startsWith(queryLower);
        final bStartsWith = b.toLowerCase().startsWith(queryLower);

        if (aStartsWith && !bStartsWith) return -1;
        if (!aStartsWith && bStartsWith) return 1;
        return a.length.compareTo(b.length); // Prefer shorter names
      });

      final result = sortedSuggestions.take(limit).toList();

      // Cache the result
      _locationSuggestionsCache[query] = result;

      return result;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SearchManager: Error getting location suggestions - $e');
      }
      return [];
    }
  }

  /// Get popular temple suggestions based on visit count and ratings
  Future<List<String>> _getPopularTempleSuggestions(int limit) async {
    try {
      // Get temples sorted by popularity (visit count)
      final filters = TempleFilters(
        isActive: true,
        sortBy: SortOption.visitCount,
        ascending: false, // Most visited first
      );

      final results = await userTempleService.searchTemples(
        '',
        filters: filters,
        limit: limit * 2, // Get more to have variety
        useCache: true,
      );

      // Filter temples with good ratings and visit counts
      final popularTemples = results
          .where((temple) {
            return temple.visitCount > 0 || temple.averageRating >= 4.0;
          })
          .take(limit)
          .map((temple) => temple.name)
          .toList();

      return popularTemples;
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'SearchManager: Error getting popular temple suggestions - $e',
        );
      }
      return [];
    }
  }

  /// Save search preferences for a user
  Future<void> saveSearchPreferences(SearchPreferences preferences) async {
    _preferencesCache[preferences.userId] = preferences;

    // Persist to search cache for autocomplete functionality
    await _persistSearchPreferences(preferences);

    if (kDebugMode) {
      debugPrint(
        'SearchManager: Saved preferences for user ${preferences.userId}',
      );
    }
  }

  /// Persist search preferences to storage
  Future<void> _persistSearchPreferences(SearchPreferences preferences) async {
    // Intentionally a no-op: recent searches are already stored by
    // SearchPreferenceManager. Writing empty temple arrays into SearchCacheManager
    // would cause cache hits that return zero results for those queries.
    if (kDebugMode) {
      debugPrint(
        'SearchManager: Preferences persisted for user ${preferences.userId}',
      );
    }
  }

  /// Add search to user's recent searches and update preferences
  Future<void> addToRecentSearches(String userId, String query) async {
    if (query.trim().isEmpty) return;

    final currentPreferences = await getSearchPreferences(userId);
    if (currentPreferences != null) {
      final updatedPreferences = currentPreferences.addRecentSearch(
        query.trim(),
      );
      await saveSearchPreferences(updatedPreferences);
    }
  }

  /// Get search preferences for a user
  Future<SearchPreferences?> getSearchPreferences(String userId) async {
    // Check cache first
    if (_preferencesCache.containsKey(userId)) {
      return _preferencesCache[userId];
    }

    // In a real implementation, you would load from storage
    // For now, return default preferences
    final defaultPreferences = SearchPreferences(
      userId: userId,
      lastUpdated: DateTime.now(),
    );

    _preferencesCache[userId] = defaultPreferences;
    return defaultPreferences;
  }

  /// Apply advanced filtering specific to SearchFilters
  List<Temple> _applyAdvancedFiltering(
    List<Temple> temples,
    SearchFilters filters,
  ) {
    var filteredTemples = temples;

    // Filter by update date range
    if (filters.updatedAfter != null) {
      filteredTemples = filteredTemples
          .where((temple) => temple.updatedAt.isAfter(filters.updatedAfter!))
          .toList();
    }

    if (filters.updatedBefore != null) {
      filteredTemples = filteredTemples
          .where((temple) => temple.updatedAt.isBefore(filters.updatedBefore!))
          .toList();
    }

    // Exclude specific temple IDs
    if (filters.excludeIds?.isNotEmpty == true) {
      filteredTemples = filteredTemples
          .where((temple) => !filters.excludeIds!.contains(temple.id))
          .toList();
    }

    // Filter by minimum visit count
    if (filters.minVisitCount != null) {
      filteredTemples = filteredTemples
          .where((temple) => temple.visitCount >= filters.minVisitCount!)
          .toList();
    }

    // Filter by minimum rating
    if (filters.minRating != null) {
      filteredTemples = filteredTemples
          .where((temple) => temple.averageRating >= filters.minRating!)
          .toList();
    }

    return filteredTemples;
  }

  /// Apply prioritization after sorting so live/nearby temples always surface first.
  /// Called separately from _applyAdvancedFiltering so it runs after _applySorting.
  List<Temple> _applyPrioritizationIfNeeded(
    List<Temple> temples,
    SearchFilters filters,
  ) {
    if (!filters.prioritizeLiveDarshan && !filters.prioritizeNearby) {
      return temples;
    }
    return _applyPrioritization(temples, filters);
  }

  /// Apply prioritization to search results
  List<Temple> _applyPrioritization(
    List<Temple> temples,
    SearchFilters filters,
  ) {
    return temples.toList()..sort((a, b) {
      double scoreA = 0.0;
      double scoreB = 0.0;

      // Prioritize live darshan temples
      if (filters.prioritizeLiveDarshan) {
        if (a.liveDarshan?.isCurrentlyLive == true) scoreA += 10.0;
        if (b.liveDarshan?.isCurrentlyLive == true) scoreB += 10.0;
      }

      // Prioritize nearby temples
      if (filters.prioritizeNearby && filters.userLocation != null) {
        final distanceA = a.distanceFromUser ?? double.infinity;
        final distanceB = b.distanceFromUser ?? double.infinity;

        // Closer temples get higher scores
        scoreA += (100.0 - distanceA.clamp(0.0, 100.0));
        scoreB += (100.0 - distanceB.clamp(0.0, 100.0));
      }

      return scoreB.compareTo(scoreA); // Higher score first
    });
  }

  /// Calculate filter counts for UI display
  Map<String, int> _calculateFilterCounts(List<Temple> temples) {
    final counts = <String, int>{};

    // Count by traditions
    final traditionCounts = <String, int>{};
    for (final temple in temples) {
      for (final tradition in temple.traditions) {
        traditionCounts[tradition] = (traditionCounts[tradition] ?? 0) + 1;
      }
    }
    counts['traditions'] = traditionCounts.length;

    // Count by features
    final featureCounts = <String, int>{};
    for (final temple in temples) {
      for (final feature in temple.features) {
        featureCounts[feature] = (featureCounts[feature] ?? 0) + 1;
      }
    }
    counts['features'] = featureCounts.length;

    // Count temples with live darshan
    counts['liveDarshan'] = temples
        .where((temple) => temple.liveDarshan?.isConfiguredByAdmin == true)
        .length;

    // Count by states
    final stateCounts = <String, int>{};
    for (final temple in temples) {
      final state = temple.location.state;
      if (state != null) {
        stateCounts[state] = (stateCounts[state] ?? 0) + 1;
      }
    }
    counts['states'] = stateCounts.length;

    return counts;
  }

  /// Clear all search caches
  Future<void> clearSearchCache() async {
    await searchCache.clear();
    _preferencesCache.clear();

    if (kDebugMode) {
      debugPrint('SearchManager: Cleared all search caches');
    }
  }

  /// Get search statistics
  Map<String, dynamic> getSearchStatistics() {
    final cacheStats = searchCache.getStatistics();

    return {
      'cacheHitCount': cacheStats.hitCount,
      'cacheMissCount': cacheStats.missCount,
      'cacheSize': cacheStats.totalSize,
      'cachedPreferences': _preferencesCache.length,
    };
  }
}

/// Sort options for search results
class SortOptions {
  final SortOption sortBy;
  final bool ascending;

  const SortOptions({this.sortBy = SortOption.name, this.ascending = true});

  /// Create a copy with updated options
  SortOptions copyWith({SortOption? sortBy, bool? ascending}) {
    return SortOptions(
      sortBy: sortBy ?? this.sortBy,
      ascending: ascending ?? this.ascending,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SortOptions &&
        other.sortBy == sortBy &&
        other.ascending == ascending;
  }

  @override
  int get hashCode => Object.hash(sortBy, ascending);

  @override
  String toString() {
    return 'SortOptions(sortBy: ${sortBy.name}, ascending: $ascending)';
  }
}

/// Extension to add hasFilters property to SearchFilters
extension SearchFiltersExtension on SearchFilters {
  /// Check if any filters are applied
  bool get hasFilters {
    return traditions?.isNotEmpty == true ||
        features?.isNotEmpty == true ||
        maxDistance != null ||
        userLocation != null ||
        hasLiveDarshan != null ||
        cities?.isNotEmpty == true ||
        states?.isNotEmpty == true ||
        includeInactive != false ||
        updatedAfter != null ||
        updatedBefore != null ||
        excludeIds?.isNotEmpty == true ||
        minVisitCount != null ||
        minRating != null ||
        prioritizeLiveDarshan != false ||
        prioritizeNearby != false;
  }
}
