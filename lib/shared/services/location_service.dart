import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart' as geolocator;
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:permission_handler/permission_handler.dart';
import '../models/temple.dart';
import 'interfaces/location_service_interface.dart';

/// Implementation of location service for GPS and manual location support
class LocationService implements LocationServiceInterface {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  StreamController<Location>? _locationStreamController;
  StreamSubscription<geolocator.Position>? _positionStreamSubscription;
  Location? _lastKnownLocation;
  DateTime? _lastLocationUpdate;

  static const Duration _locationCacheTimeout = Duration(minutes: 5);
  static const Duration _defaultTimeout = Duration(seconds: 30);

  /// Initialize the location service
  Future<void> initialize() async {
    if (kDebugMode) {
      debugPrint('LocationService: Initializing location service');
    }
  }

  @override
  Future<Location?> getCurrentLocation() async {
    return await getCurrentLocationWithTimeout(_defaultTimeout);
  }

  @override
  Future<Location?> getCurrentLocationWithTimeout(Duration timeout) async {
    try {
      // Check if we have a recent cached location
      if (_lastKnownLocation != null &&
          _lastLocationUpdate != null &&
          DateTime.now().difference(_lastLocationUpdate!) <
              _locationCacheTimeout) {
        if (kDebugMode) {
          debugPrint('LocationService: Returning cached location');
        }
        return _lastKnownLocation;
      }

      // Check location permission
      final permissionStatus = await getLocationPermissionStatus();
      if (permissionStatus != LocationPermissionStatus.granted) {
        if (kDebugMode) {
          debugPrint(
            'LocationService: Location permission not granted: $permissionStatus',
          );
        }
        return null;
      }

      // Check if location services are enabled
      final serviceStatus = await getLocationServiceStatus();
      if (serviceStatus != LocationServiceStatus.enabled) {
        if (kDebugMode) {
          debugPrint('LocationService: Location services not enabled');
        }
        // Return null instead of a default location with "Unknown" values
        return null;
      }

      // Get current position with highest accuracy for detailed location
      final position = await geolocator.Geolocator.getCurrentPosition(
        desiredAccuracy: geolocator.LocationAccuracy.bestForNavigation,
        timeLimit: timeout,
      );

      if (kDebugMode) {
        debugPrint(
          'LocationService: Got position: ${position.latitude}, ${position.longitude}',
        );
      }

      // Convert to our Location model
      final location = Location(
        latitude: position.latitude,
        longitude: position.longitude,
      );

      // Try to get address information with retry logic
      try {
        final placemarks = await geocoding.placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (kDebugMode) {
          debugPrint('LocationService: Got ${placemarks.length} placemarks');
          if (placemarks.isNotEmpty) {
            final p = placemarks.first;
            debugPrint('LocationService: === DETAILED PLACEMARK INFO ===');
            debugPrint('LocationService: name: "${p.name}"');
            debugPrint('LocationService: street/thoroughfare: "${p.thoroughfare}"');
            debugPrint('LocationService: subThoroughfare: "${p.subThoroughfare}"');
            debugPrint('LocationService: locality: "${p.locality}"');
            debugPrint('LocationService: subLocality: "${p.subLocality}"');
            debugPrint('LocationService: administrativeArea: "${p.administrativeArea}"');
            debugPrint('LocationService: subAdministrativeArea: "${p.subAdministrativeArea}"');
            debugPrint('LocationService: postalCode: "${p.postalCode}"');
            debugPrint('LocationService: country: "${p.country}"');
            debugPrint('LocationService: isoCountryCode: "${p.isoCountryCode}"');
            debugPrint('LocationService: === END PLACEMARK INFO ===');
          }
        }

        if (placemarks.isNotEmpty) {
          final placemark = placemarks.first;
          
          // Create a more comprehensive address
          final locationWithAddress = Location(
            latitude: position.latitude,
            longitude: position.longitude,
            address: _formatBetterAddress(placemark),
            city: _getBestCity(placemark),
            state: _getBestState(placemark),
            country: placemark.country ?? 'India',
            postalCode: placemark.postalCode,
          );

          // Cache the location
          _lastKnownLocation = locationWithAddress;
          _lastLocationUpdate = DateTime.now();

          if (kDebugMode) {
            debugPrint(
              'LocationService: Created location with address: "${locationWithAddress.address}"',
            );
            debugPrint(
              'LocationService: City: "${locationWithAddress.city}", State: "${locationWithAddress.state}"',
            );
          }

          return locationWithAddress;
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('LocationService: Failed to get address for location: $e');
        }
        
        // Try a fallback approach with a delay and retry
        try {
          await Future.delayed(const Duration(milliseconds: 500));
          final retryPlacemarks = await geocoding.placemarkFromCoordinates(
            position.latitude,
            position.longitude,
          );

          if (retryPlacemarks.isNotEmpty) {
            final placemark = retryPlacemarks.first;
            final locationWithAddress = Location(
              latitude: position.latitude,
              longitude: position.longitude,
              address: _formatBetterAddress(placemark),
              city: _getBestCity(placemark),
              state: _getBestState(placemark),
              country: placemark.country ?? 'India',
              postalCode: placemark.postalCode,
            );

            _lastKnownLocation = locationWithAddress;
            _lastLocationUpdate = DateTime.now();

            if (kDebugMode) {
              debugPrint(
                'LocationService: Retry successful - got address: ${locationWithAddress.address}',
              );
            }

            return locationWithAddress;
          }
        } catch (retryError) {
          if (kDebugMode) {
            debugPrint('LocationService: Retry also failed: $retryError');
          }
        }
      }

      // Cache the basic location
      _lastKnownLocation = location;
      _lastLocationUpdate = DateTime.now();

      if (kDebugMode) {
        debugPrint('LocationService: Got basic location: $location');
      }

      return location;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('LocationService: Error getting current location: $e');
      }

      // Return cached location if available
      if (_lastKnownLocation != null) {
        if (kDebugMode) {
          debugPrint('LocationService: Returning cached location due to error');
        }
        return _lastKnownLocation;
      }

      return null;
    }
  }

  @override
  Future<LocationPermissionStatus> getLocationPermissionStatus() async {
    try {
      final permission = await Permission.location.status;

      switch (permission) {
        case PermissionStatus.granted:
          return LocationPermissionStatus.granted;
        case PermissionStatus.denied:
          return LocationPermissionStatus.denied;
        case PermissionStatus.permanentlyDenied:
          return LocationPermissionStatus.deniedForever;
        case PermissionStatus.restricted:
          return LocationPermissionStatus.denied;
        case PermissionStatus.limited:
          return LocationPermissionStatus.granted;
        case PermissionStatus.provisional:
          return LocationPermissionStatus.granted;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('LocationService: Error checking permission status: $e');
      }
      return LocationPermissionStatus.notDetermined;
    }
  }

  @override
  Future<LocationPermissionStatus> requestLocationPermission() async {
    try {
      final permission = await Permission.location.request();

      switch (permission) {
        case PermissionStatus.granted:
          if (kDebugMode) {
            debugPrint('LocationService: Location permission granted');
          }
          return LocationPermissionStatus.granted;
        case PermissionStatus.denied:
          if (kDebugMode) {
            debugPrint('LocationService: Location permission denied');
          }
          return LocationPermissionStatus.denied;
        case PermissionStatus.permanentlyDenied:
          if (kDebugMode) {
            debugPrint(
              'LocationService: Location permission permanently denied',
            );
          }
          return LocationPermissionStatus.deniedForever;
        case PermissionStatus.restricted:
          return LocationPermissionStatus.denied;
        case PermissionStatus.limited:
          return LocationPermissionStatus.granted;
        case PermissionStatus.provisional:
          return LocationPermissionStatus.granted;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('LocationService: Error requesting location permission: $e');
      }
      return LocationPermissionStatus.denied;
    }
  }

  @override
  Future<LocationServiceStatus> getLocationServiceStatus() async {
    try {
      final isEnabled = await geolocator.Geolocator.isLocationServiceEnabled();
      return isEnabled
          ? LocationServiceStatus.enabled
          : LocationServiceStatus.disabled;
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'LocationService: Error checking location service status: $e',
        );
      }
      return LocationServiceStatus.disabled;
    }
  }

  @override
  Future<void> openLocationSettings() async {
    try {
      await geolocator.Geolocator.openLocationSettings();
      if (kDebugMode) {
        debugPrint('LocationService: Opened location settings');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('LocationService: Error opening location settings: $e');
      }
      // Fallback to app settings
      await openAppSettings();
    }
  }

  @override
  Future<double> calculateDistance(Location from, Location to) async {
    return calculateDistanceWithUnit(from, to, DistanceUnit.kilometers);
  }

  @override
  Future<double> calculateDistanceWithUnit(
    Location from,
    Location to,
    DistanceUnit unit,
  ) async {
    try {
      final distanceInMeters = geolocator.Geolocator.distanceBetween(
        from.latitude,
        from.longitude,
        to.latitude,
        to.longitude,
      );

      switch (unit) {
        case DistanceUnit.meters:
          return distanceInMeters;
        case DistanceUnit.kilometers:
          return distanceInMeters / 1000;
        case DistanceUnit.miles:
          return distanceInMeters / 1609.344;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('LocationService: Error calculating distance: $e');
      }
      // Fallback to Haversine formula
      return _calculateDistanceHaversine(from, to, unit);
    }
  }

  @override
  Future<List<Temple>> filterByDistance(
    List<Temple> temples,
    Location userLocation,
    double maxDistance,
  ) async {
    try {
      final filteredTemples = <Temple>[];

      for (final temple in temples) {
        final distance = await calculateDistance(userLocation, temple.location);
        if (distance <= maxDistance) {
          filteredTemples.add(temple.copyWith(distanceFromUser: distance));
        }
      }

      if (kDebugMode) {
        debugPrint(
          'LocationService: Filtered ${filteredTemples.length} temples within ${maxDistance}km',
        );
      }

      return filteredTemples;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('LocationService: Error filtering temples by distance: $e');
      }
      return temples;
    }
  }

  @override
  Future<List<Temple>> sortByDistance(
    List<Temple> temples,
    Location userLocation,
  ) async {
    try {
      // Calculate distances for all temples
      final templesWithDistance = <Temple>[];

      for (final temple in temples) {
        final distance = await calculateDistance(userLocation, temple.location);
        templesWithDistance.add(temple.copyWith(distanceFromUser: distance));
      }

      // Sort by distance
      templesWithDistance.sort((a, b) {
        final aDistance = a.distanceFromUser ?? double.infinity;
        final bDistance = b.distanceFromUser ?? double.infinity;
        return aDistance.compareTo(bDistance);
      });

      if (kDebugMode) {
        debugPrint(
          'LocationService: Sorted ${templesWithDistance.length} temples by distance',
        );
      }

      return templesWithDistance;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('LocationService: Error sorting temples by distance: $e');
      }
      return temples;
    }
  }

  @override
  Future<List<Temple>> getTemplesWithinRadius(
    List<Temple> temples,
    Location center,
    double radius,
  ) async {
    return await filterByDistance(temples, center, radius);
  }

  @override
  Stream<Location> watchLocation() {
    return watchLocationWithAccuracy(LocationAccuracy.high);
  }

  @override
  Stream<Location> watchLocationWithAccuracy(LocationAccuracy accuracy) {
    // Close existing stream if any
    _locationStreamController?.close();
    _positionStreamSubscription?.cancel();

    _locationStreamController = StreamController<Location>.broadcast();

    // Convert our accuracy enum to Geolocator accuracy
    final geolocatorAccuracy = _convertLocationAccuracy(accuracy);

    final locationSettings = geolocator.LocationSettings(
      accuracy: geolocatorAccuracy,
      distanceFilter: 10, // Update every 10 meters
    );

    _positionStreamSubscription =
        geolocator.Geolocator.getPositionStream(
          locationSettings: locationSettings,
        ).listen(
          (position) async {
            try {
              final location = Location(
                latitude: position.latitude,
                longitude: position.longitude,
              );

              // Try to get address information for significant location changes
              if (_lastKnownLocation == null ||
                  await calculateDistance(_lastKnownLocation!, location) >
                      0.1) {
                try {
                  final placemarks = await geocoding.placemarkFromCoordinates(
                    position.latitude,
                    position.longitude,
                  );

                  if (placemarks.isNotEmpty) {
                    final placemark = placemarks.first;
                    final locationWithAddress = Location(
                      latitude: position.latitude,
                      longitude: position.longitude,
                      address: _formatAddress(placemark),
                      city: placemark.locality,
                      state: placemark.administrativeArea,
                      country: placemark.country,
                      postalCode: placemark.postalCode,
                    );

                    _lastKnownLocation = locationWithAddress;
                    _lastLocationUpdate = DateTime.now();
                    _locationStreamController?.add(locationWithAddress);
                    return;
                  }
                } catch (e) {
                  if (kDebugMode) {
                    debugPrint(
                      'LocationService: Failed to get address for streaming location: $e',
                    );
                  }
                }
              }

              _lastKnownLocation = location;
              _lastLocationUpdate = DateTime.now();
              _locationStreamController?.add(location);
            } catch (e) {
              if (kDebugMode) {
                debugPrint(
                  'LocationService: Error processing location update: $e',
                );
              }
            }
          },
          onError: (error) {
            if (kDebugMode) {
              debugPrint('LocationService: Location stream error: $error');
            }
            _locationStreamController?.addError(error);
          },
        );

    return _locationStreamController!.stream;
  }

  @override
  Future<Location?> getLocationFromAddress(String address) async {
    try {
      if (address.trim().isEmpty) {
        return null;
      }

      final locations = await geocoding.locationFromAddress(address);
      if (locations.isNotEmpty) {
        final geoLocation = locations.first;

        // Try to get detailed address information
        try {
          final placemarks = await geocoding.placemarkFromCoordinates(
            geoLocation.latitude,
            geoLocation.longitude,
          );

          if (placemarks.isNotEmpty) {
            final placemark = placemarks.first;
            return Location(
              latitude: geoLocation.latitude,
              longitude: geoLocation.longitude,
              address: _formatAddress(placemark),
              city: placemark.locality,
              state: placemark.administrativeArea,
              country: placemark.country,
              postalCode: placemark.postalCode,
            );
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint(
              'LocationService: Failed to get detailed address info: $e',
            );
          }
        }

        return Location(
          latitude: geoLocation.latitude,
          longitude: geoLocation.longitude,
          address: address,
        );
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('LocationService: Error getting location from address: $e');
      }
      return null;
    }
  }

  @override
  Future<String?> getAddressFromLocation(Location location) async {
    try {
      final placemarks = await geocoding.placemarkFromCoordinates(
        location.latitude,
        location.longitude,
      );

      if (placemarks.isNotEmpty) {
        return _formatAddress(placemarks.first);
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('LocationService: Error getting address from location: $e');
      }
      return null;
    }
  }

  @override
  Future<String?> getCityFromLocation(Location location) async {
    try {
      final placemarks = await geocoding.placemarkFromCoordinates(
        location.latitude,
        location.longitude,
      );

      if (placemarks.isNotEmpty) {
        return placemarks.first.locality;
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('LocationService: Error getting city from location: $e');
      }
      return null;
    }
  }

  @override
  Future<String?> getFormattedAddress(Location location) async {
    try {
      final placemarks = await geocoding.placemarkFromCoordinates(
        location.latitude,
        location.longitude,
      );

      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        return _formatFullAddress(placemark);
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('LocationService: Error getting formatted address: $e');
      }
      return null;
    }
  }

  @override
  bool isValidLocation(Location location) {
    return location.latitude >= -90 &&
        location.latitude <= 90 &&
        location.longitude >= -180 &&
        location.longitude <= 180;
  }

  @override
  bool areLocationsEqual(
    Location location1,
    Location location2, {
    double tolerance = 0.001,
  }) {
    return (location1.latitude - location2.latitude).abs() <= tolerance &&
        (location1.longitude - location2.longitude).abs() <= tolerance;
  }

  @override
  String getDistanceDisplayString(double distanceKm) {
    if (distanceKm < 1) {
      return '${(distanceKm * 1000).round()}m';
    } else if (distanceKm < 10) {
      return '${distanceKm.toStringAsFixed(1)}km';
    } else {
      return '${distanceKm.round()}km';
    }
  }

  @override
  double getBearing(Location from, Location to) {
    final lat1Rad = from.latitude * (math.pi / 180);
    final lat2Rad = to.latitude * (math.pi / 180);
    final deltaLonRad = (to.longitude - from.longitude) * (math.pi / 180);

    final y = math.sin(deltaLonRad) * math.cos(lat2Rad);
    final x =
        math.cos(lat1Rad) * math.sin(lat2Rad) -
        math.sin(lat1Rad) * math.cos(lat2Rad) * math.cos(deltaLonRad);

    final bearingRad = math.atan2(y, x);
    final bearingDeg = bearingRad * (180 / math.pi);

    return (bearingDeg + 360) % 360;
  }

  @override
  Location getMidpoint(Location location1, Location location2) {
    final lat1Rad = location1.latitude * (math.pi / 180);
    final lat2Rad = location2.latitude * (math.pi / 180);
    final deltaLonRad =
        (location2.longitude - location1.longitude) * (math.pi / 180);

    final bx = math.cos(lat2Rad) * math.cos(deltaLonRad);
    final by = math.cos(lat2Rad) * math.sin(deltaLonRad);

    final lat3Rad = math.atan2(
      math.sin(lat1Rad) + math.sin(lat2Rad),
      math.sqrt((math.cos(lat1Rad) + bx) * (math.cos(lat1Rad) + bx) + by * by),
    );

    final lon3Rad =
        (location1.longitude * (math.pi / 180)) +
        math.atan2(by, math.cos(lat1Rad) + bx);

    return Location(
      latitude: lat3Rad * (180 / math.pi),
      longitude: lon3Rad * (180 / math.pi),
    );
  }

  @override
  bool isLocationWithinBounds(Location location, LocationBounds bounds) {
    return bounds.contains(location);
  }

  @override
  Future<void> stopLocationUpdates() async {
    await _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;

    await _locationStreamController?.close();
    _locationStreamController = null;

    if (kDebugMode) {
      debugPrint('LocationService: Stopped location updates');
    }
  }

  @override
  Future<void> clearCache() async {
    _lastKnownLocation = null;
    _lastLocationUpdate = null;

    if (kDebugMode) {
      debugPrint('LocationService: Cleared location cache');
    }
  }

  // Private helper methods

  /// Convert our LocationAccuracy enum to Geolocator's LocationAccuracy
  geolocator.LocationAccuracy _convertLocationAccuracy(
    LocationAccuracy accuracy,
  ) {
    switch (accuracy) {
      case LocationAccuracy.lowest:
        return geolocator.LocationAccuracy.lowest;
      case LocationAccuracy.low:
        return geolocator.LocationAccuracy.low;
      case LocationAccuracy.medium:
        return geolocator.LocationAccuracy.medium;
      case LocationAccuracy.high:
        return geolocator.LocationAccuracy.high;
      case LocationAccuracy.best:
        return geolocator.LocationAccuracy.best;
      case LocationAccuracy.bestForNavigation:
        return geolocator.LocationAccuracy.bestForNavigation;
    }
  }

  /// Calculate distance using Haversine formula as fallback
  double _calculateDistanceHaversine(
    Location from,
    Location to,
    DistanceUnit unit,
  ) {
    const double earthRadius = 6371; // Earth's radius in kilometers

    final double dLat = _degreesToRadians(to.latitude - from.latitude);
    final double dLon = _degreesToRadians(to.longitude - from.longitude);

    final double a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(from.latitude)) *
            math.cos(_degreesToRadians(to.latitude)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    final double distanceKm = earthRadius * c;

    switch (unit) {
      case DistanceUnit.kilometers:
        return distanceKm;
      case DistanceUnit.miles:
        return distanceKm * 0.621371;
      case DistanceUnit.meters:
        return distanceKm * 1000;
    }
  }

  /// Convert degrees to radians
  double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
  }

  /// Format address from placemark
  String _formatAddress(geocoding.Placemark placemark) {
    final parts = <String>[];

    if (placemark.name?.isNotEmpty == true) {
      parts.add(placemark.name!);
    }
    if (placemark.street?.isNotEmpty == true &&
        placemark.street != placemark.name) {
      parts.add(placemark.street!);
    }
    if (placemark.locality?.isNotEmpty == true) {
      parts.add(placemark.locality!);
    }

    return parts.join(', ');
  }

  /// Format better address with priority for detailed location
  String _formatBetterAddress(geocoding.Placemark placemark) {
    final parts = <String>[];

    // First priority: specific place name or establishment
    if (placemark.name?.isNotEmpty == true && 
        placemark.name != placemark.locality &&
        placemark.name != placemark.administrativeArea &&
        placemark.name!.length > 3) {
      parts.add(placemark.name!);
    }

    // Second priority: street or thoroughfare for detailed location
    if (placemark.thoroughfare?.isNotEmpty == true &&
        placemark.thoroughfare != placemark.name &&
        placemark.thoroughfare!.length > 3) {
      parts.add(placemark.thoroughfare!);
    }

    // Third priority: sub-locality for area/neighborhood
    if (placemark.subLocality?.isNotEmpty == true &&
        !parts.contains(placemark.subLocality!) &&
        placemark.subLocality!.length > 2) {
      parts.add(placemark.subLocality!);
    }

    // Fourth priority: locality/city
    if (placemark.locality?.isNotEmpty == true &&
        !parts.contains(placemark.locality!)) {
      parts.add(placemark.locality!);
    } else if (placemark.subAdministrativeArea?.isNotEmpty == true &&
        !parts.contains(placemark.subAdministrativeArea!)) {
      parts.add(placemark.subAdministrativeArea!);
    }

    // If we still don't have enough detail, try other fields
    if (parts.isEmpty || parts.length == 1) {
      // Try premise or sub-premise for building/establishment names
      if (placemark.subThoroughfare?.isNotEmpty == true &&
          placemark.subThoroughfare!.length > 2) {
        parts.insert(0, placemark.subThoroughfare!);
      }
      
      // Add administrative area (state) only if we have specific location
      if (parts.isNotEmpty && placemark.administrativeArea?.isNotEmpty == true) {
        parts.add(placemark.administrativeArea!);
      }
    }

    final result = parts.join(', ');
    
    // If we still don't have detailed location, return what we have
    if (result.isEmpty) {
      // Last resort: try any available location info
      if (placemark.locality?.isNotEmpty == true) {
        return placemark.locality!;
      }
      if (placemark.administrativeArea?.isNotEmpty == true) {
        return placemark.administrativeArea!;
      }
      return 'Current Location';
    }
    
    return result;
  }

  /// Get the best city name from placemark
  String? _getBestCity(geocoding.Placemark placemark) {
    if (placemark.locality?.isNotEmpty == true) {
      return placemark.locality;
    }
    if (placemark.subAdministrativeArea?.isNotEmpty == true) {
      return placemark.subAdministrativeArea;
    }
    if (placemark.administrativeArea?.isNotEmpty == true) {
      return placemark.administrativeArea;
    }
    return null;
  }

  /// Get the best state name from placemark
  String? _getBestState(geocoding.Placemark placemark) {
    if (placemark.administrativeArea?.isNotEmpty == true) {
      return placemark.administrativeArea;
    }
    return null;
  }

  /// Format full address from placemark
  String _formatFullAddress(geocoding.Placemark placemark) {
    final parts = <String>[];

    if (placemark.name?.isNotEmpty == true) {
      parts.add(placemark.name!);
    }
    if (placemark.street?.isNotEmpty == true &&
        placemark.street != placemark.name) {
      parts.add(placemark.street!);
    }
    if (placemark.locality?.isNotEmpty == true) {
      parts.add(placemark.locality!);
    }
    if (placemark.administrativeArea?.isNotEmpty == true) {
      parts.add(placemark.administrativeArea!);
    }
    if (placemark.postalCode?.isNotEmpty == true) {
      parts.add(placemark.postalCode!);
    }
    if (placemark.country?.isNotEmpty == true) {
      parts.add(placemark.country!);
    }

    return parts.join(', ');
  }

  /// Dispose resources
  void dispose() {
    // stopLocationUpdates is async but dispose() must be sync.
    // Cancel subscriptions immediately and let the stream close asynchronously.
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    _locationStreamController?.close();
    _locationStreamController = null;
    _lastKnownLocation = null;
    _lastLocationUpdate = null;

    if (kDebugMode) {
      debugPrint('LocationService: Disposed');
    }
  }
}
