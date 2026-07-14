import 'temple.dart';

/// Filters for temple search and discovery
class TempleFilters {
  final String? searchQuery;
  final List<String>? traditions;
  final List<String>? features;
  final double? maxDistance; // in kilometers
  final Location? userLocation;
  final bool? hasLiveDarshan;
  final bool? isActive;
  final List<String>? cities;
  final List<String>? states;
  final SortOption sortBy;
  final bool ascending;

  // Additional properties for pagination service
  final double? latitude;
  final double? longitude;
  final double? radiusKm;
  final String? category;
  final bool? isLiveStreamAvailable;
  final bool? hasEvents;
  final double? minRating;
  final String? favoriteUserId;
  final String? mainDeity;

  const TempleFilters({
    this.searchQuery,
    this.traditions,
    this.features,
    this.maxDistance,
    this.userLocation,
    this.hasLiveDarshan,
    this.isActive = true,
    this.cities,
    this.states,
    this.sortBy = SortOption.name,
    this.ascending = true,
    this.latitude,
    this.longitude,
    this.radiusKm,
    this.category,
    this.isLiveStreamAvailable,
    this.hasEvents,
    this.minRating,
    this.favoriteUserId,
    this.mainDeity,
  });

  /// Create a copy with updated filters
  TempleFilters copyWith({
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
  }) {
    return TempleFilters(
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
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radiusKm: radiusKm ?? this.radiusKm,
      category: category ?? this.category,
      isLiveStreamAvailable:
          isLiveStreamAvailable ?? this.isLiveStreamAvailable,
      hasEvents: hasEvents ?? this.hasEvents,
      minRating: minRating ?? this.minRating,
      favoriteUserId: favoriteUserId ?? this.favoriteUserId,
      mainDeity: mainDeity ?? this.mainDeity,
    );
  }

  /// Check if any filters are applied
  bool get hasFilters {
    return searchQuery?.isNotEmpty == true ||
        traditions?.isNotEmpty == true ||
        features?.isNotEmpty == true ||
        maxDistance != null ||
        hasLiveDarshan != null ||
        cities?.isNotEmpty == true ||
        states?.isNotEmpty == true;
  }

  /// Convert to JSON for caching
  Map<String, dynamic> toJson() {
    return {
      if (searchQuery != null) 'searchQuery': searchQuery,
      if (traditions != null) 'traditions': traditions,
      if (features != null) 'features': features,
      if (maxDistance != null) 'maxDistance': maxDistance,
      if (userLocation != null) 'userLocation': userLocation!.toJson(),
      if (hasLiveDarshan != null) 'hasLiveDarshan': hasLiveDarshan,
      if (isActive != null) 'isActive': isActive,
      if (cities != null) 'cities': cities,
      if (states != null) 'states': states,
      'sortBy': sortBy.name,
      'ascending': ascending,
    };
  }

  /// Create from JSON
  factory TempleFilters.fromJson(Map<String, dynamic> json) {
    return TempleFilters(
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
    );
  }

  /// Check if this filter is equivalent to another filter for caching purposes
  bool isEquivalentTo(TempleFilters other) {
    return searchQuery == other.searchQuery &&
        _listEquals(traditions, other.traditions) &&
        _listEquals(features, other.features) &&
        maxDistance == other.maxDistance &&
        _locationEquals(userLocation, other.userLocation) &&
        hasLiveDarshan == other.hasLiveDarshan &&
        isActive == other.isActive &&
        _listEquals(cities, other.cities) &&
        _listEquals(states, other.states) &&
        sortBy == other.sortBy &&
        ascending == other.ascending &&
        mainDeity == other.mainDeity;
  }

  /// Helper method to compare lists
  bool _listEquals(List<String>? a, List<String>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;

    final sortedA = List<String>.from(a)..sort();
    final sortedB = List<String>.from(b)..sort();

    for (int i = 0; i < sortedA.length; i++) {
      if (sortedA[i] != sortedB[i]) return false;
    }
    return true;
  }

  /// Helper method to compare locations
  bool _locationEquals(Location? a, Location? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;

    // Compare with small tolerance for floating point precision
    const tolerance = 0.0001;
    return (a.latitude - b.latitude).abs() < tolerance &&
        (a.longitude - b.longitude).abs() < tolerance;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TempleFilters && isEquivalentTo(other);
  }

  @override
  int get hashCode {
    return Object.hash(
      searchQuery,
      traditions?.join(','),
      features?.join(','),
      maxDistance,
      userLocation?.latitude,
      userLocation?.longitude,
      hasLiveDarshan,
      isActive,
      cities?.join(','),
      states?.join(','),
      sortBy,
      ascending,
      mainDeity,
    );
  }

  @override
  String toString() {
    return 'TempleFilters(query: $searchQuery, traditions: $traditions, '
        'maxDistance: $maxDistance, sortBy: ${sortBy.name})';
  }
}

/// Sort options for temple lists
enum SortOption {
  name,
  distance,
  createdAt,
  updatedAt,
  visitCount,
  tradition,
  rating,
  popularity,
}

/// Extension to get display names for sort options
extension SortOptionExtension on SortOption {
  String get displayName {
    switch (this) {
      case SortOption.name:
        return 'Name';
      case SortOption.distance:
        return 'Distance';
      case SortOption.createdAt:
        return 'Date Added';
      case SortOption.updatedAt:
        return 'Last Updated';
      case SortOption.visitCount:
        return 'Visit Count';
      case SortOption.tradition:
        return 'Tradition';
      case SortOption.rating:
        return 'Rating';
      case SortOption.popularity:
        return 'Popularity';
    }
  }
}
