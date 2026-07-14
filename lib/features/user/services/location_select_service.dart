import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../shared/models/temple.dart';
import '../../../shared/services/location_service.dart';
import '../../../shared/services/interfaces/location_service_interface.dart';
import 'user_preferences_service.dart';

/// Service for managing user location selection (GPS or manual)
class LocationSelectService {
  static final LocationSelectService _instance =
      LocationSelectService._internal();
  factory LocationSelectService() => _instance;
  LocationSelectService._internal();

  final LocationService _locationService = LocationService();
  final UserPreferencesService _preferencesService = UserPreferencesService();

  // Stream controller for location updates
  final StreamController<String> _locationStreamController =
      StreamController<String>.broadcast();

  // Current location state
  Location? _currentGpsLocation;
  String? _currentLocationString;
  bool _isUsingGps = false;
  bool _isInitialized = false;

  /// Stream of location changes
  Stream<String> get locationStream => _locationStreamController.stream;

  /// Get current location string
  String get currentLocation => _currentLocationString ?? 'Select Location';

  /// Check if currently using GPS
  bool get isUsingGps => _isUsingGps;

  /// Initialize the service
  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    try {
      await _preferencesService.initialize();

      // Load saved location preference
      final savedLocation = await _preferencesService.getUserLocation();
      _currentLocationString = savedLocation;

      if (kDebugMode) {
        debugPrint(
          'LocationSelectService: Initialized with location: $savedLocation',
        );
      }
      _isInitialized = true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('LocationSelectService: Error initializing: $e');
      }
      _currentLocationString = 'Select Location';
    }
  }

  /// Get current GPS location
  Future<Location?> getCurrentGpsLocation() async {
    try {
      // Check permission first
      final permissionStatus = await _locationService
          .getLocationPermissionStatus();

      if (permissionStatus != LocationPermissionStatus.granted) {
        if (kDebugMode) {
          debugPrint('LocationSelectService: Location permission not granted');
        }
        return null;
      }

      // Check if location services are enabled
      final serviceStatus = await _locationService.getLocationServiceStatus();
      if (serviceStatus != LocationServiceStatus.enabled) {
        if (kDebugMode) {
          debugPrint('LocationSelectService: Location services not enabled');
        }
        return null;
      }

      // Get current location
      final location = await _locationService.getCurrentLocation();

      if (location != null) {
        _currentGpsLocation = location;

        if (kDebugMode) {
          debugPrint(
            'LocationSelectService: Got GPS location: ${location.address}',
          );
        }
      }

      return location;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('LocationSelectService: Error getting GPS location: $e');
      }
      return null;
    }
  }

  /// Use current GPS location
  Future<bool> useCurrentGpsLocation() async {
    try {
      final location = await getCurrentGpsLocation();

      if (location == null) {
        return false;
      }

      // Format location string
      String locationString;
      if (location.address != null && location.address!.isNotEmpty) {
        locationString = location.address!;
      } else if (location.city != null && location.city!.isNotEmpty) {
        locationString = location.city!;
      } else {
        locationString = 'Current Location';
      }

      // Save to preferences
      await _preferencesService.setUserLocation(locationString);

      _currentLocationString = locationString;
      _isUsingGps = true;

      // Notify listeners
      if (!_locationStreamController.isClosed) {
        _locationStreamController.add(locationString);
      }

      if (kDebugMode) {
        debugPrint(
          'LocationSelectService: Using GPS location: $locationString',
        );
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('LocationSelectService: Error using GPS location: $e');
      }
      return false;
    }
  }

  /// Set manual location
  Future<bool> setManualLocation(String location) async {
    try {
      if (location.trim().isEmpty) {
        return false;
      }

      // Save to preferences
      await _preferencesService.setUserLocation(location);

      _currentLocationString = location;
      _isUsingGps = false;

      // Try to geocode the address to get coordinates
      if (kDebugMode) {
        debugPrint('LocationSelectService: Attempting to geocode: $location');
      }

      final geoLocation = await _locationService.getLocationFromAddress(
        location,
      );
      if (geoLocation != null) {
        _currentGpsLocation = geoLocation;
        if (kDebugMode) {
          debugPrint(
            'LocationSelectService: Geocoded successfully - '
            'Lat: ${geoLocation.latitude}, Lng: ${geoLocation.longitude}',
          );
        }
      } else {
        if (kDebugMode) {
          debugPrint(
            'LocationSelectService: Geocoding failed for: $location. '
            'Distance calculation will not be available.',
          );
        }
        // Clear the GPS location if geocoding fails
        _currentGpsLocation = null;
      }

      // Notify listeners
      if (!_locationStreamController.isClosed) {
        _locationStreamController.add(location);
      }

      if (kDebugMode) {
        debugPrint('LocationSelectService: Set manual location: $location');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('LocationSelectService: Error setting manual location: $e');
      }
      return false;
    }
  }

  /// Request location permission
  Future<LocationPermissionStatus> requestLocationPermission() async {
    return await _locationService.requestLocationPermission();
  }

  /// Check location permission status
  Future<LocationPermissionStatus> getLocationPermissionStatus() async {
    return await _locationService.getLocationPermissionStatus();
  }

  /// Open location settings
  Future<void> openLocationSettings() async {
    await _locationService.openLocationSettings();
  }

  /// Get saved location from preferences
  Future<String> getSavedLocation() async {
    try {
      final location = await _preferencesService.getUserLocation();
      _currentLocationString = location;
      return location;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('LocationSelectService: Error getting saved location: $e');
      }
      return 'Select Location';
    }
  }

  /// Clear location
  Future<void> clearLocation() async {
    try {
      await _preferencesService.setUserLocation('Select Location');
      _currentLocationString = 'Select Location';
      _currentGpsLocation = null;
      _isUsingGps = false;

      if (!_locationStreamController.isClosed) {
        _locationStreamController.add('Select Location');
      }

      if (kDebugMode) {
        debugPrint('LocationSelectService: Cleared location');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('LocationSelectService: Error clearing location: $e');
      }
    }
  }

  /// Get current location object (for distance calculations)
  Location? getCurrentLocationObject() {
    return _currentGpsLocation;
  }

  /// Dispose resources
  void dispose() {
    _locationStreamController.close();
  }
}
