import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../shared/models/temple.dart';
import '../../../shared/models/user_preferences.dart';
import 'search_manager.dart';
import 'search_preference_manager.dart';
import 'recommendation_manager.dart';
import 'live_darshan_service.dart';
import '../../user/services/user_preferences_service.dart';
import 'user_temple_service.dart';

/// Enhanced search manager that integrates recommendations with search and live darshan
class EnhancedSearchManager {
  static final EnhancedSearchManager _instance = EnhancedSearchManager._internal();
  factory EnhancedSearchManager() => _instance;
  EnhancedSearchManager._internal();

  // Base SearchManager instance
  final SearchManager _searchManager = SearchManager();

  // Additional service dependencies for integration
  RecommendationManager? _recommendationManager;
  LiveDarshanService? _liveDarshanService;
  UserPreferencesService? _preferencesService;
  UserTempleService? _userTempleService;
  SearchPreferenceManager? _searchPreferenceManager;

  // Lazy getters for additional services
  RecommendationManager get recommendationManager => 
      _recommendationManager ??= RecommendationManager();
  LiveDarshanService get liveDarshanService => 
      _liveDarshanService ??= LiveDarshanService();
  UserPreferencesService get preferencesService => 
      _preferencesService ??= UserPreferencesService();
  UserTempleService get userTempleService => 
      _userTempleService ??= UserTempleService();
  SearchPreferenceManager get searchPreferenceManager => 
      _searchPreferenceManager ??= SearchPreferenceManager();

  /// Initialize the enhanced search manager with all integrations
  Future<void> initialize() async {
    await _searchManager.initialize();
    await recommendationManager.initialize();
    await liveDarshanService.initialize();
    await preferencesService.initialize();
    await searchPreferenceManager.initialize();

    if (kDebugMode) {
      debugPrint('EnhancedSearchManager: Initialized with all integrations');
    }
  }

  /// Perform search with recommendation integration and live darshan prioritization
  /// Implements requirements 12.1, 12.2, 12.3, 12.4, 12.5
  Future<SearchResults> performEnhancedSearch({
    required String query,
    required SearchFilters filters,
    required SortOptions sortBy,
    String? userId,
    bool useCache = true,
    bool includeRecommendations = true,
    bool prioritizeLiveDarshan = true,
    int? limit,
    int? offset,
  }) async {
    try {
      // Get user preferences if userId is provided
      UserPreferences? userPreferences;
      if (userId != null) {
        userPreferences = await preferencesService.getUserPreferencesById(
          userId,
        );
      }

      // Create enhanced filters with live darshan prioritization
      final enhancedFilters = filters.copyWith(
        prioritizeLiveDarshan: prioritizeLiveDarshan || filters.prioritizeLiveDarshan,
      );

      // Perform base search
      final baseResults = await _searchManager.performAdvancedSearch(
        query: query,
        filters: enhancedFilters,
        sortBy: sortBy,
        useCache: useCache,
        limit: limit,
        offset: offset,
      );

      // Enhance results with live darshan integration
      final enhancedTemples = await _enhanceWithLiveDarshanIntegration(
        baseResults.temples,
        prioritizeLiveDarshan,
      );

      // Integrate recommendations if enabled and user is provided
      List<Temple> finalTemples = enhancedTemples;
      if (includeRecommendations && userId != null && userPreferences != null) {
        finalTemples = await _integrateRecommendations(
          enhancedTemples,
          userPreferences,
          query,
          filters,
        );
      }

      // Track user search interaction for ML learning and preferences
      if (userId != null) {
        try {
          await _trackSearchInteraction(
            userId,
            query,
            filters,
            finalTemples.length,
          );

          // Store filter selections and add to search history
          await searchPreferenceManager.storeFilterSelections(
            userId: userId,
            filters: filters,
          );

          if (query.isNotEmpty) {
            await searchPreferenceManager.addToSearchHistory(
              userId: userId,
              query: query,
            );
          }

          // Update location frequency if location-based search
          if (filters.userLocation != null) {
            final locationString =
                '${filters.userLocation!.latitude},${filters.userLocation!.longitude}';
            await searchPreferenceManager.updateLocationFrequency(
              userId: userId,
              location: locationString,
            );
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint(
              'EnhancedSearchManager: Error tracking search interaction - $e',
            );
          }
          // Continue without tracking - don't fail the search
        }
      }

      // Create enhanced search results
      final enhancedResults = baseResults.copyWith(
        temples: finalTemples,
        totalCount: finalTemples.length,
        metadata: {
          ...baseResults.metadata,
          'liveDarshanIntegrated': true,
          'recommendationsIntegrated': includeRecommendations && userId != null,
          'liveDarshanCount': finalTemples.where((t) => t.liveDarshan?.isCurrentlyLive == true).length,
          'recommendedCount': includeRecommendations && userId != null 
              ? finalTemples.where((t) => t.visitCount > 0).length // Simplified metric
              : 0,
        },
      );

      if (kDebugMode) {
        debugPrint(
          'EnhancedSearchManager: Enhanced search completed - ${finalTemples.length} results '
          'with ${enhancedResults.metadata['liveDarshanCount']} live temples',
        );
      }

      return enhancedResults;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('EnhancedSearchManager: Error performing enhanced search - $e');
      }
      
      // Fallback to base search
      return await _searchManager.performAdvancedSearch(
        query: query,
        filters: filters,
        sortBy: sortBy,
        useCache: useCache,
        limit: limit,
        offset: offset,
      );
    }
  }

  /// Enhance temples with live darshan integration
  /// Prioritizes live darshan temples in search results (requirement 12.1)
  Future<List<Temple>> _enhanceWithLiveDarshanIntegration(
    List<Temple> temples,
    bool prioritizeLiveDarshan,
  ) async {
    if (!prioritizeLiveDarshan) return temples;

    try {
      // Update live darshan status for temples that have it configured
      final enhancedTemples = <Temple>[];
      
      for (final temple in temples) {
        if (temple.liveDarshan?.isConfiguredByAdmin == true) {
          // Get current live darshan info
          final liveDarshanInfo = await liveDarshanService.getLiveDarshanInfo(temple.id);
          
          if (liveDarshanInfo != null) {
            // Update temple with current live darshan status
            final updatedLiveDarshan = temple.liveDarshan!.copyWith(
              isCurrentlyLive: liveDarshanInfo.isCurrentlyLive,
              currentLiveVideoId: liveDarshanInfo.currentLiveVideoId,
            );

            final updatedTemple = temple.copyWith(liveDarshan: updatedLiveDarshan);
            enhancedTemples.add(updatedTemple);
          } else {
            enhancedTemples.add(temple);
          }
        } else {
          enhancedTemples.add(temple);
        }
      }

      // Partition: live temples first, then non-live — preserving relative order within each group
      final liveTemples = enhancedTemples
          .where((t) => t.liveDarshan?.isCurrentlyLive == true)
          .toList();
      final nonLiveTemples = enhancedTemples
          .where((t) => t.liveDarshan?.isCurrentlyLive != true)
          .toList();
      return [...liveTemples, ...nonLiveTemples];
    } catch (e) {
      if (kDebugMode) {
        debugPrint('EnhancedSearchManager: Error enhancing with live darshan - $e');
      }
      return temples;
    }
  }

  /// Integrate personalized recommendations with search results
  /// Boosts live darshan temples in recommendations (requirement 12.2)
  Future<List<Temple>> _integrateRecommendations(
    List<Temple> searchResults,
    UserPreferences userPreferences,
    String query,
    SearchFilters filters,
  ) async {
    try {
      // Get personalized recommendations
      final recommendations = await recommendationManager.getPersonalizedRecommendations(
        preferences: userPreferences,
        userLocation: filters.userLocation,
        limit: 10,
        includeExplanations: false,
      );

      if (recommendations.isEmpty) return searchResults;

      // Create a set of search result IDs for quick lookup
      final searchResultIds = searchResults.map((t) => t.id).toSet();

      // Separate recommended temples into those already in search results and new ones
      final recommendedInResults = <String, RecommendedTemple>{};
      final newRecommendations = <RecommendedTemple>[];

      for (final recommendation in recommendations) {
        if (searchResultIds.contains(recommendation.temple.id)) {
          recommendedInResults[recommendation.temple.id] = recommendation;
        } else {
          newRecommendations.add(recommendation);
        }
      }

      // Boost temples that are both in search results and recommendations
      // by moving them earlier in the list rather than mutating their data.
      final boostedIds = recommendedInResults.keys.toSet();
      final boostedResults = [
        // Recommended temples first (preserving their relative search order)
        ...searchResults.where((t) => boostedIds.contains(t.id)),
        // Then the rest
        ...searchResults.where((t) => !boostedIds.contains(t.id)),
      ];

      // Add new recommendations at the beginning if they match search criteria
      final filteredNewRecommendations = _filterRecommendationsBySearch(
        newRecommendations,
        query,
        filters,
      );

      // Combine results: filtered new recommendations first, then boosted search results
      final integratedResults = <Temple>[];
      integratedResults.addAll(filteredNewRecommendations.map((r) => r.temple));
      integratedResults.addAll(boostedResults);

      // Remove duplicates while preserving order
      final uniqueResults = <Temple>[];
      final seenIds = <String>{};
      
      for (final temple in integratedResults) {
        if (seenIds.add(temple.id)) {
          uniqueResults.add(temple);
        }
      }

      return uniqueResults;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('EnhancedSearchManager: Error integrating recommendations - $e');
      }
      return searchResults;
    }
  }

  /// Filter recommendations based on search criteria
  List<RecommendedTemple> _filterRecommendationsBySearch(
    List<RecommendedTemple> recommendations,
    String query,
    SearchFilters filters,
  ) {
    if (recommendations.isEmpty) return [];

    return recommendations.where((recommendation) {
      final temple = recommendation.temple;
      
      // Check if temple matches search query
      if (query.isNotEmpty) {
        final queryLower = query.toLowerCase();
        final matchesQuery =
            temple.name.toLowerCase().contains(queryLower) ||
            temple.description.toLowerCase().contains(queryLower) ||
            temple.location.address?.toLowerCase().contains(queryLower) ==
                true ||
            temple.location.city?.toLowerCase().contains(queryLower) == true ||
            temple.traditions.any((t) => t.toLowerCase().contains(queryLower));
        
        if (!matchesQuery) return false;
      }
      
      // Check if temple matches filters
      if (filters.traditions?.isNotEmpty == true) {
        final hasMatchingTradition = temple.traditions.any(
          (tradition) => filters.traditions!.contains(tradition),
        );
        if (!hasMatchingTradition) return false;
      }
      
      if (filters.features?.isNotEmpty == true) {
        final hasMatchingFeature = temple.features.any(
          (feature) => filters.features!.contains(feature),
        );
        if (!hasMatchingFeature) return false;
      }
      
      if (filters.hasLiveDarshan == true) {
        if (temple.liveDarshan?.isConfiguredByAdmin != true) return false;
      }
      
      return true;
    }).toList();
  }

  /// Track user search interaction for ML learning
  Future<void> _trackSearchInteraction(
    String userId,
    String query,
    SearchFilters filters,
    int resultCount,
  ) async {
    try {
      // Store search analytics data
      final searchData = {
        'userId': userId,
        'query': query,
        'filters': filters.toJson(),
        'resultCount': resultCount,
        'timestamp': DateTime.now().toIso8601String(),
        'hasLocation': filters.userLocation != null,
        'hasFilters': filters.hasFilters,
      };
      
      // In a real implementation, this would send to analytics service
      if (kDebugMode) {
        debugPrint(
          'EnhancedSearchManager: Tracking search interaction - $searchData',
        );
      }
      
      // Could store in local database for offline analytics
      // await _analyticsService.trackSearchInteraction(searchData);
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'EnhancedSearchManager: Error tracking search interaction - $e',
        );
      }
    }
  }

  /// Get recent searches for a user
  Future<List<String>> getRecentSearches(String userId, {int limit = 10}) async {
    try {
      return await searchPreferenceManager.getRecentSearches(userId, limit: limit);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('EnhancedSearchManager: Error getting recent searches - $e');
      }
      return [];
    }
  }

  /// Get location suggestions for autocomplete
  Future<List<String>> getLocationSuggestions({
    required String userId,
    required String query,
    int limit = 5,
  }) async {
    try {
      return await searchPreferenceManager.getLocationSuggestions(
        userId: userId,
        query: query,
        limit: limit,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('EnhancedSearchManager: Error getting location suggestions - $e');
      }
      return [];
    }
  }

  /// Get search suggestions with enhanced features
  Stream<List<String>> getSearchSuggestions(
    String query, {
    String? userId,
  }) async* {
    try {
      // Combine base search suggestions with enhanced features
      await for (final baseSuggestions in _searchManager.getSearchSuggestions(
        query,
      )) {
        final enhancedSuggestions = <String>[];

        // Add base suggestions
        enhancedSuggestions.addAll(baseSuggestions);

        // Add user-specific suggestions if userId provided
        if (userId != null) {
          final recentSearches = await getRecentSearches(userId, limit: 3);
          final locationSuggestions = await getLocationSuggestions(
            userId: userId,
            query: query,
            limit: 2,
          );

          // Filter and add recent searches that match query
          final matchingRecent = recentSearches
              .where(
                (search) => search.toLowerCase().contains(query.toLowerCase()),
              )
              .take(2);
          enhancedSuggestions.addAll(matchingRecent);

          // Add location suggestions
          enhancedSuggestions.addAll(locationSuggestions);
        }
        
        // Remove duplicates and limit results
        final uniqueSuggestions = enhancedSuggestions.toSet().take(10).toList();
        yield uniqueSuggestions;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'EnhancedSearchManager: Error getting enhanced search suggestions - $e',
        );
      }
      yield [];
    }
  }
}