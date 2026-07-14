import 'dart:async';
import 'dart:math' as math;
import '../../../shared/models/temple.dart';
import '../../../shared/models/temple_filters.dart';
import '../../../shared/services/location_service.dart';

/// Centralized service for temple filtering operations
/// Provides consistent filter logic across the application
class TempleFilterService {
  static final TempleFilterService _instance = TempleFilterService._internal();
  factory TempleFilterService() => _instance;
  TempleFilterService._internal();

  final LocationService _locationService = LocationService();

  /// Available filter options
  static const List<String> availableTraditions = [
    'Hinduism',
    'Buddhism',
    'Jainism',
    'Sikhism',
    'Christianity',
    'Islam',
    'Other',
  ];

  static const List<Map<String, dynamic>> availableFeatures = [
    {'name': 'Live Darshan', 'icon': 'videocam'},
    {'name': 'Parking', 'icon': 'local_parking'},
    {'name': 'Food Court', 'icon': 'restaurant'},
    {'name': 'Accommodation', 'icon': 'hotel'},
    {'name': 'Wheelchair Accessible', 'icon': 'accessible'},
    {'name': 'Library', 'icon': 'library_books'},
    {'name': 'Meditation Hall', 'icon': 'self_improvement'},
    {'name': 'Online Booking', 'icon': 'book_online'},
  ];

  static const List<Map<String, dynamic>> sortOptions = [
    {'name': 'Name', 'value': 'name', 'icon': 'sort_by_alpha'},
    {'name': 'Distance', 'value': 'distance', 'icon': 'near_me'},
    {'name': 'Rating', 'value': 'rating', 'icon': 'star'},
    {'name': 'Popular', 'value': 'popularity', 'icon': 'trending_up'},
  ];

  /// Initialize the service
  Future<void> initialize() async {
    await _locationService.initialize();
  }

  /// Apply filters to a list of temples
  List<Temple> applyFilters(List<Temple> temples, TempleFilters filters) {
    if (temples.isEmpty) return temples;

    List<Temple> filteredTemples = List.from(temples);

    // Apply text search filter
    if (filters.searchQuery?.isNotEmpty == true) {
      filteredTemples = _filterByText(filteredTemples, filters.searchQuery!);
    }

    // Apply tradition filter
    if (filters.traditions?.isNotEmpty == true) {
      filteredTemples = _filterByTraditions(filteredTemples, filters.traditions!);
    }

    // Apply features filter
    if (filters.features?.isNotEmpty == true) {
      filteredTemples = _filterByFeatures(filteredTemples, filters.features!);
    }

    // Apply distance filter
    if (filters.maxDistance != null && filters.userLocation != null) {
      filteredTemples = _filterByDistance(
        filteredTemples,
        filters.userLocation!,
        filters.maxDistance!,
      );
    }

    // Apply live darshan filter
    if (filters.hasLiveDarshan == true) {
      filteredTemples = _filterByLiveDarshan(filteredTemples);
    }

    // Apply active status filter
    if (filters.isActive != null) {
      filteredTemples = _filterByActiveStatus(filteredTemples, filters.isActive!);
    }

    // Apply city filter
    if (filters.cities?.isNotEmpty == true) {
      filteredTemples = _filterByCities(filteredTemples, filters.cities!);
    }

    // Apply state filter
    if (filters.states?.isNotEmpty == true) {
      filteredTemples = _filterByStates(filteredTemples, filters.states!);
    }

    // Apply mainDeity filter
    if (filters.mainDeity?.isNotEmpty == true) {
      filteredTemples = _filterByMainDeity(filteredTemples, filters.mainDeity!);
    }

    // Apply sorting
    filteredTemples = _sortTemples(filteredTemples, filters);

    return filteredTemples;
  }

  /// Filter temples by text search
  List<Temple> _filterByText(List<Temple> temples, String query) {
    final searchTerms = query.toLowerCase().split(' ').where((term) => term.isNotEmpty).toList();
    
    return temples.where((temple) {
      final searchableText = [
        temple.name,
        temple.description,
        temple.location.address ?? '',
        temple.location.city ?? '',
        temple.location.state ?? '',
        temple.traditions.join(' '),
        temple.features.join(' '),
      ].join(' ').toLowerCase();

      return searchTerms.every((term) => searchableText.contains(term));
    }).toList();
  }

  /// Filter temples by religious traditions
  List<Temple> _filterByTraditions(List<Temple> temples, List<String> traditions) {
    return temples.where((temple) {
      return temple.traditions.any((tradition) => traditions.contains(tradition));
    }).toList();
  }

  /// Filter temples by features
  List<Temple> _filterByFeatures(List<Temple> temples, List<String> features) {
    return temples.where((temple) {
      if (temple.features.isEmpty) return false;
      return features.every((feature) => temple.features.contains(feature));
    }).toList();
  }

  /// Filter temples by distance from user location
  List<Temple> _filterByDistance(List<Temple> temples, Location userLocation, double maxDistance) {
    return temples.where((temple) {
      if (temple.location.latitude == 0.0 && temple.location.longitude == 0.0) return false;
      
      final distance = _calculateDistance(userLocation, temple.location);
      return distance <= maxDistance;
    }).toList();
  }

  /// Filter temples by live darshan availability
  List<Temple> _filterByLiveDarshan(List<Temple> temples) {
    return temples.where((temple) {
      return temple.liveDarshan != null || 
             temple.features.contains('Live Darshan');
    }).toList();
  }

  /// Filter temples by active status
  List<Temple> _filterByActiveStatus(List<Temple> temples, bool isActive) {
    return temples.where((temple) => temple.isActive == isActive).toList();
  }

  /// Filter temples by cities
  List<Temple> _filterByCities(List<Temple> temples, List<String> cities) {
    return temples.where((temple) {
      return temple.location.city != null && cities.contains(temple.location.city);
    }).toList();
  }

  /// Filter temples by states
  List<Temple> _filterByStates(List<Temple> temples, List<String> states) {
    return temples.where((temple) {
      return temple.location.state != null && states.contains(temple.location.state);
    }).toList();
  }

  /// Filter temples by main deity using substring matching so that values like
  /// "Lord Ganesha" and "Mata Durga" stored in Firestore are correctly matched
  /// against short filter names like "Ganesha" or "Durga".
  List<Temple> _filterByMainDeity(List<Temple> temples, String deity) {
    final keyword = deity.toLowerCase();
    return temples.where((temple) {
      if (temple.mainDeity == null || temple.mainDeity!.isEmpty) return false;
      return temple.mainDeity!.toLowerCase().contains(keyword);
    }).toList();
  }

  /// Sort temples based on the specified criteria
  List<Temple> _sortTemples(List<Temple> temples, TempleFilters filters) {
    final sortedTemples = List<Temple>.from(temples);

    switch (filters.sortBy) {
      case SortOption.name:
        sortedTemples.sort((a, b) => a.name.compareTo(b.name));
        break;
      case SortOption.distance:
        if (filters.userLocation != null) {
          sortedTemples.sort((a, b) {
            final distanceA = _getTempleDistance(a, filters.userLocation!);
            final distanceB = _getTempleDistance(b, filters.userLocation!);
            return distanceA.compareTo(distanceB);
          });
        }
        break;
      case SortOption.rating:
        sortedTemples.sort((a, b) => b.averageRating.compareTo(a.averageRating));
        break;
      case SortOption.popularity:
        sortedTemples.sort((a, b) => b.visitCount.compareTo(a.visitCount));
        break;
      case SortOption.createdAt:
        sortedTemples.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case SortOption.updatedAt:
        sortedTemples.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        break;
      case SortOption.visitCount:
        sortedTemples.sort((a, b) => b.visitCount.compareTo(a.visitCount));
        break;
      case SortOption.tradition:
        sortedTemples.sort((a, b) {
          final aTradition = a.traditions.isNotEmpty ? a.traditions.first : '';
          final bTradition = b.traditions.isNotEmpty ? b.traditions.first : '';
          return aTradition.compareTo(bTradition);
        });
        break;
    }

    if (!filters.ascending) {
      return sortedTemples.reversed.toList();
    }

    return sortedTemples;
  }

  /// Calculate distance between two locations in kilometers
  double _calculateDistance(Location location1, Location location2) {
    const double earthRadius = 6371; // Earth's radius in kilometers

    final double lat1Rad = location1.latitude * (math.pi / 180);
    final double lat2Rad = location2.latitude * (math.pi / 180);
    final double deltaLatRad = (location2.latitude - location1.latitude) * (math.pi / 180);
    final double deltaLonRad = (location2.longitude - location1.longitude) * (math.pi / 180);

    final double a = math.pow(math.sin(deltaLatRad / 2), 2) +
        math.cos(lat1Rad) * math.cos(lat2Rad) * math.pow(math.sin(deltaLonRad / 2), 2);
    final double c = 2 * math.asin(math.sqrt(a));

    return earthRadius * c;
  }

  /// Get distance from temple to user location
  double _getTempleDistance(Temple temple, Location userLocation) {
    if (temple.location.latitude == 0.0 && temple.location.longitude == 0.0) {
      return double.infinity;
    }

    return _calculateDistance(userLocation, temple.location);
  }

  /// Get filter statistics for display
  Map<String, int> getFilterCounts(List<Temple> temples) {
    final Map<String, int> counts = {};

    // Count traditions
    for (final tradition in availableTraditions) {
      counts['tradition_$tradition'] = temples
          .where((temple) => temple.traditions.contains(tradition))
          .length;
    }

    // Count features
    for (final feature in availableFeatures) {
      final featureName = feature['name'] as String;
      counts['feature_$featureName'] = temples
          .where((temple) => temple.features.contains(featureName))
          .length;
    }

    return counts;
  }

  /// Create a default filter set
  TempleFilters createDefaultFilters({Location? userLocation}) {
    return TempleFilters(
      maxDistance: 50.0,
      userLocation: userLocation,
      sortBy: SortOption.distance,
      ascending: true,
      isActive: true,
    );
  }

  /// Check if filters have any active criteria
  bool hasActiveFilters(TempleFilters filters) {
    return filters.searchQuery?.isNotEmpty == true ||
           filters.traditions?.isNotEmpty == true ||
           filters.features?.isNotEmpty == true ||
           filters.maxDistance != null ||
           filters.hasLiveDarshan != null ||
           filters.cities?.isNotEmpty == true ||
           filters.states?.isNotEmpty == true;
  }

  /// Clear all filters except location and basic settings
  TempleFilters clearFilters(TempleFilters currentFilters) {
    return TempleFilters(
      userLocation: currentFilters.userLocation,
      sortBy: SortOption.distance,
      ascending: true,
      isActive: true,
    );
  }

  /// Get available cities from temple list
  List<String> getAvailableCities(List<Temple> temples) {
    final cities = temples
        .where((temple) => temple.location.city != null && temple.location.city!.isNotEmpty)
        .map((temple) => temple.location.city!)
        .toSet()
        .toList();
    cities.sort();
    return cities;
  }

  /// Get available states from temple list
  List<String> getAvailableStates(List<Temple> temples) {
    final states = temples
        .where((temple) => temple.location.state != null && temple.location.state!.isNotEmpty)
        .map((temple) => temple.location.state!)
        .toSet()
        .toList();
    states.sort();
    return states;
  }
}