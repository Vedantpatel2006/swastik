import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'search_manager.dart' show SearchFilters, SearchPreferences;

/// Manager for search preference persistence and restoration
/// Implements requirements 6.1, 6.2, 6.5 for filter selections and search preferences
class SearchPreferenceManager {
  static final SearchPreferenceManager _instance = SearchPreferenceManager._internal();
  factory SearchPreferenceManager() => _instance;
  SearchPreferenceManager._internal();

  SharedPreferences? _prefs;
  final Map<String, SearchPreferences> _preferencesCache = {};
  final Map<String, List<String>> _searchHistoryCache = {};
  final Map<String, Map<String, int>> _locationFrequencyCache = {};

  // Storage keys
  static const String _searchPreferencesPrefix = 'search_preferences_';
  static const String _searchHistoryPrefix = 'search_history_';
  static const String _locationFrequencyPrefix = 'location_frequency_';
  static const String _filterSelectionPrefix = 'filter_selection_';

  /// Initialize the preference manager
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    
    if (kDebugMode) {
      debugPrint('SearchPreferenceManager: Initialized successfully');
    }
  }

  /// Store filter selections for a user
  /// Implements requirement 6.1: Store filter selections
  Future<void> storeFilterSelections({
    required String userId,
    required SearchFilters filters,
  }) async {
    if (_prefs == null) await initialize();
    
    try {
      final key = '$_filterSelectionPrefix$userId';
      final filterData = filters.toJson();
      
      await _prefs!.setString(key, jsonEncode(filterData));
      
      if (kDebugMode) {
        debugPrint('SearchPreferenceManager: Stored filter selections for user $userId');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SearchPreferenceManager: Error storing filter selections - $e');
      }
    }
  }

  /// Restore filter selections for a user
  /// Implements requirement 6.2: Restore previous settings on app return
  Future<SearchFilters?> restoreFilterSelections(String userId) async {
    if (_prefs == null) await initialize();
    
    try {
      final key = '$_filterSelectionPrefix$userId';
      final filterDataString = _prefs!.getString(key);
      
      if (filterDataString != null) {
        final filterData = jsonDecode(filterDataString) as Map<String, dynamic>;
        final filters = SearchFilters.fromJson(filterData);
        
        if (kDebugMode) {
          debugPrint('SearchPreferenceManager: Restored filter selections for user $userId');
        }
        
        return filters;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SearchPreferenceManager: Error restoring filter selections - $e');
      }
    }
    
    return null;
  }

  /// Store search preferences for a user
  /// Implements requirement 6.5: Sync changes across all user devices
  Future<void> storeSearchPreferences({
    required String userId,
    required SearchPreferences preferences,
  }) async {
    if (_prefs == null) await initialize();
    
    try {
      final key = '$_searchPreferencesPrefix$userId';
      final preferencesData = preferences.toJson();
      
      await _prefs!.setString(key, jsonEncode(preferencesData));
      
      // Update cache
      _preferencesCache[userId] = preferences;
      
      if (kDebugMode) {
        debugPrint('SearchPreferenceManager: Stored search preferences for user $userId');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SearchPreferenceManager: Error storing search preferences - $e');
      }
    }
  }

  /// Restore search preferences for a user
  /// Implements requirement 6.2: Restore previous settings on app return
  Future<SearchPreferences?> restoreSearchPreferences(String userId) async {
    if (_prefs == null) await initialize();
    
    // Check cache first
    if (_preferencesCache.containsKey(userId)) {
      return _preferencesCache[userId];
    }
    
    try {
      final key = '$_searchPreferencesPrefix$userId';
      final preferencesDataString = _prefs!.getString(key);
      
      if (preferencesDataString != null) {
        final preferencesData = jsonDecode(preferencesDataString) as Map<String, dynamic>;
        final preferences = SearchPreferences.fromJson(preferencesData);
        
        // Update cache
        _preferencesCache[userId] = preferences;
        
        if (kDebugMode) {
          debugPrint('SearchPreferenceManager: Restored search preferences for user $userId');
        }
        
        return preferences;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SearchPreferenceManager: Error restoring search preferences - $e');
      }
    }
    
    // Return default preferences if none found
    final defaultPreferences = SearchPreferences(
      userId: userId,
      lastUpdated: DateTime.now(),
    );
    
    // Store default preferences for future use
    await storeSearchPreferences(
      userId: userId,
      preferences: defaultPreferences,
    );
    
    return defaultPreferences;
  }

  /// Add search to history and update preferences
  /// Implements requirement 6.3: Provide recent searches for quick access
  Future<void> addToSearchHistory({
    required String userId,
    required String query,
  }) async {
    if (query.trim().isEmpty) return;
    
    final normalizedQuery = query.trim();
    
    // Update search history cache
    final currentHistory = _searchHistoryCache[userId] ?? [];
    currentHistory.remove(normalizedQuery); // Remove if already exists
    currentHistory.insert(0, normalizedQuery); // Add to beginning
    
    // Keep only last 20 searches
    if (currentHistory.length > 20) {
      currentHistory.removeRange(20, currentHistory.length);
    }
    
    _searchHistoryCache[userId] = currentHistory;
    
    // Store in SharedPreferences
    await _storeSearchHistory(userId, currentHistory);
    
    // Update search preferences
    final currentPreferences = await restoreSearchPreferences(userId);
    if (currentPreferences != null) {
      final updatedPreferences = currentPreferences.addRecentSearch(normalizedQuery);
      await storeSearchPreferences(
        userId: userId,
        preferences: updatedPreferences,
      );
    }
    
    if (kDebugMode) {
      debugPrint('SearchPreferenceManager: Added "$normalizedQuery" to search history for user $userId');
    }
  }

  /// Get recent searches for a user
  /// Implements requirement 6.3: Provide recent searches for quick access
  Future<List<String>> getRecentSearches(String userId, {int limit = 10}) async {
    if (_prefs == null) await initialize();
    
    // Check cache first
    if (_searchHistoryCache.containsKey(userId)) {
      return _searchHistoryCache[userId]!.take(limit).toList();
    }
    
    try {
      final key = '$_searchHistoryPrefix$userId';
      final historyDataString = _prefs!.getString(key);
      
      if (historyDataString != null) {
        final historyData = jsonDecode(historyDataString) as List<dynamic>;
        final history = historyData.cast<String>();
        
        // Update cache
        _searchHistoryCache[userId] = history;
        
        return history.take(limit).toList();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SearchPreferenceManager: Error getting recent searches - $e');
      }
    }
    
    return [];
  }

  /// Store location search frequency for autocomplete improvements
  /// Implements requirement 6.4: Suggest frequently searched locations in autocomplete
  Future<void> updateLocationFrequency({
    required String userId,
    required String location,
  }) async {
    if (location.trim().isEmpty) return;
    
    final normalizedLocation = location.trim();
    
    // Update location frequency cache
    final currentFrequency = _locationFrequencyCache[userId] ?? <String, int>{};
    currentFrequency[normalizedLocation] = (currentFrequency[normalizedLocation] ?? 0) + 1;
    _locationFrequencyCache[userId] = currentFrequency;
    
    // Store in SharedPreferences
    await _storeLocationFrequency(userId, currentFrequency);
    
    if (kDebugMode) {
      debugPrint('SearchPreferenceManager: Updated location frequency for "$normalizedLocation" (user: $userId)');
    }
  }

  /// Get frequently searched locations for autocomplete
  /// Implements requirement 6.4: Suggest frequently searched locations in autocomplete
  Future<List<String>> getFrequentLocations(String userId, {int limit = 5}) async {
    if (_prefs == null) await initialize();
    
    // Check cache first
    if (_locationFrequencyCache.containsKey(userId)) {
      final frequency = _locationFrequencyCache[userId]!;
      return _getSortedLocationsByFrequency(frequency, limit);
    }
    
    try {
      final key = '$_locationFrequencyPrefix$userId';
      final frequencyDataString = _prefs!.getString(key);
      
      if (frequencyDataString != null) {
        final frequencyData = jsonDecode(frequencyDataString) as Map<String, dynamic>;
        final frequency = frequencyData.cast<String, int>();
        
        // Update cache
        _locationFrequencyCache[userId] = frequency;
        
        return _getSortedLocationsByFrequency(frequency, limit);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SearchPreferenceManager: Error getting frequent locations - $e');
      }
    }
    
    return [];
  }

  /// Get location suggestions that match a query
  /// Implements requirement 6.4: Suggest frequently searched locations in autocomplete
  Future<List<String>> getLocationSuggestions({
    required String userId,
    required String query,
    int limit = 5,
  }) async {
    final frequentLocations = await getFrequentLocations(userId, limit: 20);
    final queryLower = query.toLowerCase();
    
    // Filter locations that match the query
    final matchingLocations = frequentLocations.where((location) {
      return location.toLowerCase().contains(queryLower);
    }).toList();
    
    // Sort by relevance (starts with query first, then contains)
    matchingLocations.sort((a, b) {
      final aStartsWith = a.toLowerCase().startsWith(queryLower);
      final bStartsWith = b.toLowerCase().startsWith(queryLower);
      
      if (aStartsWith && !bStartsWith) return -1;
      if (!aStartsWith && bStartsWith) return 1;
      return a.compareTo(b);
    });
    
    return matchingLocations.take(limit).toList();
  }

  /// Clear all stored preferences for a user
  Future<void> clearUserPreferences(String userId) async {
    if (_prefs == null) await initialize();
    
    try {
      // Remove from SharedPreferences
      await _prefs!.remove('$_searchPreferencesPrefix$userId');
      await _prefs!.remove('$_searchHistoryPrefix$userId');
      await _prefs!.remove('$_locationFrequencyPrefix$userId');
      await _prefs!.remove('$_filterSelectionPrefix$userId');
      
      // Remove from caches
      _preferencesCache.remove(userId);
      _searchHistoryCache.remove(userId);
      _locationFrequencyCache.remove(userId);
      
      if (kDebugMode) {
        debugPrint('SearchPreferenceManager: Cleared all preferences for user $userId');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SearchPreferenceManager: Error clearing user preferences - $e');
      }
    }
  }

  /// Get comprehensive search suggestions combining history and locations
  Future<List<String>> getComprehensiveSearchSuggestions({
    required String userId,
    required String query,
    int limit = 10,
  }) async {
    final suggestions = <String>[];
    
    if (query.isEmpty) {
      // For empty query, return recent searches
      final recentSearches = await getRecentSearches(userId, limit: limit);
      suggestions.addAll(recentSearches);
    } else {
      // For non-empty query, combine recent searches and location suggestions
      final recentSearches = await getRecentSearches(userId, limit: 5);
      final locationSuggestions = await getLocationSuggestions(
        userId: userId,
        query: query,
        limit: 5,
      );
      
      final queryLower = query.toLowerCase();
      
      // Add matching recent searches
      final matchingRecent = recentSearches.where((search) {
        return search.toLowerCase().contains(queryLower);
      }).toList();
      
      suggestions.addAll(matchingRecent);
      suggestions.addAll(locationSuggestions);
    }
    
    // Remove duplicates while preserving order
    final uniqueSuggestions = <String>[];
    final seen = <String>{};
    
    for (final suggestion in suggestions) {
      if (seen.add(suggestion.toLowerCase())) {
        uniqueSuggestions.add(suggestion);
      }
    }
    
    return uniqueSuggestions.take(limit).toList();
  }

  /// Store search history in SharedPreferences
  Future<void> _storeSearchHistory(String userId, List<String> history) async {
    try {
      final key = '$_searchHistoryPrefix$userId';
      await _prefs!.setString(key, jsonEncode(history));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SearchPreferenceManager: Error storing search history - $e');
      }
    }
  }

  /// Store location frequency in SharedPreferences
  Future<void> _storeLocationFrequency(String userId, Map<String, int> frequency) async {
    try {
      final key = '$_locationFrequencyPrefix$userId';
      await _prefs!.setString(key, jsonEncode(frequency));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SearchPreferenceManager: Error storing location frequency - $e');
      }
    }
  }

  /// Sort locations by frequency and return top results
  List<String> _getSortedLocationsByFrequency(Map<String, int> frequency, int limit) {
    final sortedEntries = frequency.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return sortedEntries
        .take(limit)
        .map((entry) => entry.key)
        .toList();
  }

  /// Get storage statistics
  Map<String, dynamic> getStorageStatistics() {
    return {
      'cachedPreferences': _preferencesCache.length,
      'cachedSearchHistory': _searchHistoryCache.length,
      'cachedLocationFrequency': _locationFrequencyCache.length,
      'totalCacheSize': _preferencesCache.length + 
                      _searchHistoryCache.length + 
                      _locationFrequencyCache.length,
    };
  }
}