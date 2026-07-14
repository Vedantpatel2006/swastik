import 'package:cloud_firestore/cloud_firestore.dart';

/// Service for searching and filtering temples
class TempleSearchService {
  final Map<String, List<Map<String, dynamic>>> _cache = {};
  static const int _maxCacheSize = 20;

  /// Search temples with filtering and sorting
  List<Map<String, dynamic>> search({
    required List<Map<String, dynamic>> temples,
    required String query,
    String? filterStatus,
    String? sortBy,
  }) {
    final cacheKey = '$query-$filterStatus-$sortBy';

    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    var results = _filterTemples(temples, query, filterStatus);
    results = _sortTemples(results, sortBy);

    _cache[cacheKey] = results;
    _limitCacheSize();

    return results;
  }

  List<Map<String, dynamic>> _filterTemples(
    List<Map<String, dynamic>> temples,
    String query,
    String? status,
  ) {
    var filtered = temples;

    if (query.isNotEmpty) {
      final lowercaseQuery = query.toLowerCase();
      filtered = filtered.where((temple) {
        final name = (temple['name'] ?? '').toString().toLowerCase();
        final location = (temple['location'] ?? '').toString().toLowerCase();
        final description =
            (temple['aboutTemple'] ?? temple['description'] ?? '')
                .toString()
                .toLowerCase();
        final city = (temple['city'] ?? '').toString().toLowerCase();
        final state = (temple['state'] ?? '').toString().toLowerCase();

        return name.contains(lowercaseQuery) ||
            location.contains(lowercaseQuery) ||
            description.contains(lowercaseQuery) ||
            city.contains(lowercaseQuery) ||
            state.contains(lowercaseQuery);
      }).toList();
    }

    if (status != null && status != 'all') {
      filtered = filtered.where((temple) {
        switch (status) {
          case 'active':
            return temple['isActive'] ?? true;
          case 'inactive':
            return !(temple['isActive'] ?? true);
          case 'live_streaming':
            final liveDarshan = temple['liveDarshan'];
            return liveDarshan != null &&
                liveDarshan['isConfiguredByAdmin'] == true;
          case 'currently_live':
            final liveDarshan = temple['liveDarshan'];
            return liveDarshan != null && liveDarshan['isCurrentlyLive'] == true;
          default:
            return true;
        }
      }).toList();
    }

    return filtered;
  }

  List<Map<String, dynamic>> _sortTemples(
    List<Map<String, dynamic>> temples,
    String? sortBy,
  ) {
    final sorted = List<Map<String, dynamic>>.from(temples);

    switch (sortBy) {
      case 'newest':
        sorted.sort((a, b) {
          final aTime = a['createdAt'] as Timestamp?;
          final bTime = b['createdAt'] as Timestamp?;
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime);
        });
        break;
      case 'oldest':
        sorted.sort((a, b) {
          final aTime = a['createdAt'] as Timestamp?;
          final bTime = b['createdAt'] as Timestamp?;
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return aTime.compareTo(bTime);
        });
        break;
      case 'name':
        sorted.sort((a, b) {
          final aName = (a['name'] ?? '').toString();
          final bName = (b['name'] ?? '').toString();
          return aName.compareTo(bName);
        });
        break;
      case 'location':
        sorted.sort((a, b) {
          final aLocation = (a['location'] ?? '').toString();
          final bLocation = (b['location'] ?? '').toString();
          return aLocation.compareTo(bLocation);
        });
        break;
      case 'rating':
        sorted.sort((a, b) {
          final aRating = (a['averageRating'] ?? 0.0) as num;
          final bRating = (b['averageRating'] ?? 0.0) as num;
          return bRating.compareTo(aRating);
        });
        break;
      default:
        sorted.sort((a, b) {
          final aTime = a['createdAt'] as Timestamp?;
          final bTime = b['createdAt'] as Timestamp?;
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime);
        });
    }

    return sorted;
  }

  Map<String, String> parseSmartQuery(String query) {
    final result = <String, String>{};
    final queryLower = query.toLowerCase();
    String remainingQuery = query;

    final statusPatterns = {
      'active': RegExp(r'active only|status:active', caseSensitive: false),
      'inactive': RegExp(r'inactive only|status:inactive', caseSensitive: false),
      'live_streaming':
          RegExp(r'live streaming|status:live', caseSensitive: false),
      'currently_live':
          RegExp(r'currently live|status:current', caseSensitive: false),
    };

    for (final entry in statusPatterns.entries) {
      if (entry.value.hasMatch(queryLower)) {
        result['status'] = entry.key;
        remainingQuery = remainingQuery.replaceAll(entry.value, '').trim();
        break;
      }
    }

    final sortPatterns = {
      'newest': RegExp(r'sort:newest|newest first', caseSensitive: false),
      'oldest': RegExp(r'sort:oldest|oldest first', caseSensitive: false),
      'name': RegExp(r'sort:name|sort by name', caseSensitive: false),
      'location':
          RegExp(r'sort:location|sort by location', caseSensitive: false),
      'rating': RegExp(r'sort:rating|sort by rating', caseSensitive: false),
    };

    for (final entry in sortPatterns.entries) {
      if (entry.value.hasMatch(queryLower)) {
        result['sort'] = entry.key;
        remainingQuery = remainingQuery.replaceAll(entry.value, '').trim();
        break;
      }
    }

    result['text'] = remainingQuery.trim();
    return result;
  }

  List<String> generateSuggestions({
    required String query,
    required List<Map<String, dynamic>> temples,
  }) {
    if (query.isEmpty) return [];

    final suggestions = <String>[];
    final queryLower = query.toLowerCase();

    final statusFilters = [
      'active only',
      'inactive only',
      'live streaming',
      'currently live',
    ];

    for (final filter in statusFilters) {
      if (filter.contains(queryLower) && !queryLower.contains(filter)) {
        suggestions.add(filter);
      }
    }

    final sortOptions = [
      'newest first',
      'oldest first',
      'sort by name',
      'sort by location',
      'sort by rating',
    ];

    for (final sort in sortOptions) {
      if (sort.contains(queryLower) && !queryLower.contains(sort)) {
        suggestions.add(sort);
      }
    }

    for (final temple in temples.take(3)) {
      final name = (temple['name'] ?? '').toString();
      if (name.toLowerCase().contains(queryLower) && suggestions.length < 6) {
        suggestions.add(name);
      }
    }

    if (suggestions.length < 6) {
      final uniqueLocations = <String>{};
      for (final temple in temples) {
        final city = (temple['city'] ?? temple['location'] ?? '').toString();
        if (city.isNotEmpty && city.toLowerCase().contains(queryLower)) {
          uniqueLocations.add(city);
        }
      }

      for (final location in uniqueLocations.take(2)) {
        if (suggestions.length < 6) {
          suggestions.add(location);
        }
      }
    }

    return suggestions.take(6).toList();
  }

  void clearCache() {
    _cache.clear();
  }

  void _limitCacheSize() {
    if (_cache.length > _maxCacheSize) {
      final firstKey = _cache.keys.first;
      _cache.remove(firstKey);
    }
  }
}
