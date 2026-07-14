import '../../models/temple.dart';
import '../../models/user_preferences.dart';

/// Filters for temple search and discovery
class TempleFilters {
  final List<String>? traditions;
  final double? maxDistance;
  final Location? userLocation;
  final bool? hasLiveDarshan;
  final bool? isActive;
  final List<String>? features;

  const TempleFilters({
    this.traditions,
    this.maxDistance,
    this.userLocation,
    this.hasLiveDarshan,
    this.isActive,
    this.features,
  });

  /// Create a copy with updated filters
  TempleFilters copyWith({
    List<String>? traditions,
    double? maxDistance,
    Location? userLocation,
    bool? hasLiveDarshan,
    bool? isActive,
    List<String>? features,
  }) {
    return TempleFilters(
      traditions: traditions ?? this.traditions,
      maxDistance: maxDistance ?? this.maxDistance,
      userLocation: userLocation ?? this.userLocation,
      hasLiveDarshan: hasLiveDarshan ?? this.hasLiveDarshan,
      isActive: isActive ?? this.isActive,
      features: features ?? this.features,
    );
  }

  /// Check if any filters are applied
  bool get hasFilters {
    return traditions != null ||
        maxDistance != null ||
        userLocation != null ||
        hasLiveDarshan != null ||
        isActive != null ||
        features != null;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TempleFilters &&
        _listEquals(other.traditions, traditions) &&
        other.maxDistance == maxDistance &&
        other.userLocation == userLocation &&
        other.hasLiveDarshan == hasLiveDarshan &&
        other.isActive == isActive &&
        _listEquals(other.features, features);
  }

  @override
  int get hashCode {
    return Object.hash(
      traditions,
      maxDistance,
      userLocation,
      hasLiveDarshan,
      isActive,
      features,
    );
  }

  bool _listEquals(List<String>? a, List<String>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Interface for user temple service operations
abstract class UserTempleServiceInterface {
  /// Search temples with optional query and filters
  Future<List<Temple>> searchTemples(String query, {TempleFilters? filters});

  /// Get temples near a specific location within radius
  Future<List<Temple>> getNearbyTemples(Location location, double radius);

  /// Get recommended temples based on user preferences
  Future<List<Temple>> getRecommendedTemples(UserPreferences preferences);

  /// Get detailed information for a specific temple
  Future<Temple> getTempleDetails(String templeId);

  /// Watch temples with real-time updates
  Stream<List<Temple>> watchTemples({TempleFilters? filters});

  /// Get temples that have live darshan configured
  Future<List<Temple>> getTemplesWithLiveDarshan();

  /// Check if a temple is currently live streaming
  Future<bool> isTempleLive(String templeId);

  /// Get all available traditions for filtering
  Future<List<String>> getAvailableTraditions();

  /// Get all available features for filtering
  Future<List<String>> getAvailableFeatures();

  /// Get popular temples based on user interactions
  Future<List<Temple>> getPopularTemples({int limit = 10});

  /// Get recently added temples
  Future<List<Temple>> getRecentlyAddedTemples({int limit = 10});

  /// Refresh temple data from server
  Future<void> refreshTempleData();

  /// Clear cached temple data
  Future<void> clearCache();
}
