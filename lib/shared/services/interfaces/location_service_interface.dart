import '../../models/temple.dart';

/// Location permission status
enum LocationPermissionStatus { granted, denied, deniedForever, notDetermined }

/// Location service status
enum LocationServiceStatus { enabled, disabled }

/// Interface for location service operations
abstract class LocationServiceInterface {
  /// Get current user location
  Future<Location?> getCurrentLocation();

  /// Get current location with timeout
  Future<Location?> getCurrentLocationWithTimeout(Duration timeout);

  /// Check location permission status
  Future<LocationPermissionStatus> getLocationPermissionStatus();

  /// Request location permission
  Future<LocationPermissionStatus> requestLocationPermission();

  /// Check if location services are enabled
  Future<LocationServiceStatus> getLocationServiceStatus();

  /// Open location settings
  Future<void> openLocationSettings();

  /// Calculate distance between two locations in kilometers
  Future<double> calculateDistance(Location from, Location to);

  /// Calculate distance between two locations with specific unit
  Future<double> calculateDistanceWithUnit(
    Location from,
    Location to,
    DistanceUnit unit,
  );

  /// Filter temples by distance from user location
  Future<List<Temple>> filterByDistance(
    List<Temple> temples,
    Location userLocation,
    double maxDistance,
  );

  /// Sort temples by distance from user location
  Future<List<Temple>> sortByDistance(
    List<Temple> temples,
    Location userLocation,
  );

  /// Get temples within radius of a location
  Future<List<Temple>> getTemplesWithinRadius(
    List<Temple> temples,
    Location center,
    double radius,
  );

  /// Watch location changes (continuous location updates)
  Stream<Location> watchLocation();

  /// Watch location changes with specific accuracy
  Stream<Location> watchLocationWithAccuracy(LocationAccuracy accuracy);

  /// Get location from address (geocoding)
  Future<Location?> getLocationFromAddress(String address);

  /// Get address from location (reverse geocoding)
  Future<String?> getAddressFromLocation(Location location);

  /// Get city from location
  Future<String?> getCityFromLocation(Location location);

  /// Get formatted address from location
  Future<String?> getFormattedAddress(Location location);

  /// Check if location is valid
  bool isValidLocation(Location location);

  /// Check if two locations are approximately equal
  bool areLocationsEqual(
    Location location1,
    Location location2, {
    double tolerance = 0.001,
  });

  /// Get distance display string
  String getDistanceDisplayString(double distanceKm);

  /// Get bearing between two locations
  double getBearing(Location from, Location to);

  /// Get midpoint between two locations
  Location getMidpoint(Location location1, Location location2);

  /// Check if location is within bounds
  bool isLocationWithinBounds(Location location, LocationBounds bounds);

  /// Stop location updates
  Future<void> stopLocationUpdates();

  /// Clear cached location data
  Future<void> clearCache();
}

/// Distance units for calculations
enum DistanceUnit { kilometers, miles, meters }

/// Location accuracy levels
enum LocationAccuracy { lowest, low, medium, high, best, bestForNavigation }

/// Location bounds for area checking
class LocationBounds {
  final Location northeast;
  final Location southwest;

  const LocationBounds({required this.northeast, required this.southwest});

  /// Check if location is within these bounds
  bool contains(Location location) {
    return location.latitude <= northeast.latitude &&
        location.latitude >= southwest.latitude &&
        location.longitude <= northeast.longitude &&
        location.longitude >= southwest.longitude;
  }

  /// Get center of bounds
  Location get center {
    final centerLat = (northeast.latitude + southwest.latitude) / 2;
    final centerLng = (northeast.longitude + southwest.longitude) / 2;
    return Location(latitude: centerLat, longitude: centerLng);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LocationBounds &&
        other.northeast == northeast &&
        other.southwest == southwest;
  }

  @override
  int get hashCode => Object.hash(northeast, southwest);

  @override
  String toString() {
    return 'LocationBounds(northeast: $northeast, southwest: $southwest)';
  }
}
