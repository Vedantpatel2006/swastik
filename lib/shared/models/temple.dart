import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Location data model for temple coordinates
class Location {
  final double latitude;
  final double longitude;
  final String? address;
  final String? city;
  final String? state;
  final String? country;
  final String? postalCode;

  const Location({
    required this.latitude,
    required this.longitude,
    this.address,
    this.city,
    this.state,
    this.country,
    this.postalCode,
  });

  /// Create Location from JSON
  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      address: json['address'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      country: json['country'] as String?,
      postalCode: json['postalCode'] as String?,
    );
  }

  /// Create Location from dynamic data with robust error handling
  /// Handles both String and Map formats with fallback to (0,0) for invalid data
  factory Location.fromDynamic(dynamic data, {String? templeId}) {
    if (data == null) {
      return const Location(latitude: 0.0, longitude: 0.0);
    }

    try {
      // Handle string format: "lat,lng" or address
      if (data is String) {
        return _parseLocationString(data, templeId: templeId);
      }

      // Handle Map format
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        return _parseLocationMap(map, templeId: templeId);
      }

      // Fallback for unexpected formats
      return const Location(latitude: 0.0, longitude: 0.0);
    } catch (e) {
      // Log error and return fallback location
      debugPrint('Location.fromDynamic error for temple $templeId: $e');
      return const Location(latitude: 0.0, longitude: 0.0);
    }
  }

  /// Parse location from string format
  static Location _parseLocationString(String locationStr, {String? templeId}) {
    try {
      // Parse various string formats
      final parts = locationStr.split(',');
      if (parts.length >= 2) {
        final lat = double.tryParse(parts[0].trim());
        final lng = double.tryParse(parts[1].trim());

        if (lat != null && lng != null && _isValidCoordinate(lat, lng)) {
          return Location(latitude: lat, longitude: lng);
        }
      }

      // If not coordinates, treat as address
      return Location(
        latitude: 0.0,
        longitude: 0.0,
        address: locationStr.trim(),
      );
    } catch (e) {
      debugPrint('Location._parseLocationString error: $e');
      return Location(latitude: 0.0, longitude: 0.0, address: locationStr);
    }
  }

  /// Parse location from Map format
  static Location _parseLocationMap(
    Map<String, dynamic> locationMap, {
    String? templeId,
  }) {
    try {
      // Try different field names for latitude
      final lat =
          _parseDouble(locationMap['latitude'] ?? locationMap['lat']) ?? 0.0;
      // Try different field names for longitude
      final lng =
          _parseDouble(locationMap['longitude'] ?? locationMap['lng']) ?? 0.0;

      // Validate coordinates and fallback to (0,0) if invalid
      final validLat = _isValidLatitude(lat) ? lat : 0.0;
      final validLng = _isValidLongitude(lng) ? lng : 0.0;

      if (lat != validLat || lng != validLng) {
        debugPrint(
          'Location: Invalid coordinates for temple $templeId: '
          'lat=$lat, lng=$lng. Using fallback: lat=$validLat, lng=$validLng',
        );
      }

      return Location(
        latitude: validLat,
        longitude: validLng,
        address: locationMap['address']?.toString(),
        city: locationMap['city']?.toString(),
        state: locationMap['state']?.toString(),
        country: locationMap['country']?.toString(),
        postalCode: locationMap['postalCode']?.toString(),
      );
    } catch (e) {
      debugPrint('Location._parseLocationMap error for temple $templeId: $e');
      return const Location(latitude: 0.0, longitude: 0.0);
    }
  }

  /// Safely parse double from dynamic value
  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }

  /// Validate latitude range (-90 to 90)
  static bool _isValidLatitude(double lat) {
    return lat >= -90.0 && lat <= 90.0;
  }

  /// Validate longitude range (-180 to 180)
  static bool _isValidLongitude(double lng) {
    return lng >= -180.0 && lng <= 180.0;
  }

  /// Validate coordinate pair
  static bool _isValidCoordinate(double lat, double lng) {
    return _isValidLatitude(lat) && _isValidLongitude(lng);
  }

  /// Convert Location to JSON
  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      if (address != null) 'address': address,
      if (city != null) 'city': city,
      if (state != null) 'state': state,
      if (country != null) 'country': country,
      if (postalCode != null) 'postalCode': postalCode,
    };
  }

  /// Validate location data
  /// ✅ IMPROVED: Now checks for (0,0) fallback coordinates
  bool isValid() {
    final hasValidCoordinates =
        latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
    
    // Check if this is a fallback (0,0) location
    final isFallbackLocation = latitude == 0.0 && longitude == 0.0;

    return hasValidCoordinates && !isFallbackLocation;
  }

  /// Check if location has meaningful address data
  bool hasAddress() {
    return address != null && address!.isNotEmpty;
  }

  /// Get Google Maps link for this location
  String get googleMapsLink =>
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';

  /// Get Apple Maps link for this location
  String get appleMapsLink => 'https://maps.apple.com/?q=$latitude,$longitude';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Location &&
        other.latitude == latitude &&
        other.longitude == longitude &&
        other.address == address &&
        other.city == city &&
        other.state == state &&
        other.country == country &&
        other.postalCode == postalCode;
  }

  @override
  int get hashCode {
    return Object.hash(
      latitude,
      longitude,
      address,
      city,
      state,
      country,
      postalCode,
    );
  }

  @override
  String toString() {
    return 'Location(lat: $latitude, lng: $longitude, address: $address)';
  }
}

/// Contact information for temples
class ContactInfo {
  final String? phone;
  final String? email;
  final String? website;
  final Map<String, String>? socialMedia;

  const ContactInfo({this.phone, this.email, this.website, this.socialMedia});

  /// Create ContactInfo from JSON
  factory ContactInfo.fromJson(Map<String, dynamic> json) {
    return ContactInfo(
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      website: json['website'] as String?,
      socialMedia: json['socialMedia'] != null
          ? Map<String, String>.from(json['socialMedia'] as Map)
          : null,
    );
  }

  /// Convert ContactInfo to JSON
  Map<String, dynamic> toJson() {
    return {
      if (phone != null) 'phone': phone,
      if (email != null) 'email': email,
      if (website != null) 'website': website,
      if (socialMedia != null) 'socialMedia': socialMedia,
    };
  }

  /// Validate contact information
  bool isValid() {
    // At least one contact method should be provided
    return phone != null || email != null || website != null;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ContactInfo &&
        other.phone == phone &&
        other.email == email &&
        other.website == website &&
        _mapEquals(other.socialMedia, socialMedia);
  }

  @override
  int get hashCode {
    return Object.hash(phone, email, website, socialMedia);
  }

  bool _mapEquals(Map<String, String>? a, Map<String, String>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (a[key] != b[key]) return false;
    }
    return true;
  }
}

/// Live darshan schedule information
class DarshanSchedule {
  final String id;
  final String name;
  final String startTime; // Format: "HH:mm"
  final String endTime; // Format: "HH:mm"
  final List<String> daysOfWeek; // ["MON", "TUE", etc.]
  final bool isActive;
  final String? description;

  const DarshanSchedule({
    required this.id,
    required this.name,
    required this.startTime,
    required this.endTime,
    required this.daysOfWeek,
    this.isActive = true,
    this.description,
  });

  /// Create DarshanSchedule from JSON
  factory DarshanSchedule.fromJson(Map<String, dynamic> json) {
    return DarshanSchedule(
      id: json['id'] as String,
      name: json['name'] as String,
      startTime: json['startTime'] as String,
      endTime: json['endTime'] as String,
      daysOfWeek: List<String>.from(json['daysOfWeek'] as List),
      isActive: json['isActive'] as bool? ?? true,
      description: json['description'] as String?,
    );
  }

  /// Convert DarshanSchedule to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'startTime': startTime,
      'endTime': endTime,
      'daysOfWeek': daysOfWeek,
      'isActive': isActive,
      if (description != null) 'description': description,
    };
  }

  /// Validate schedule data
  bool isValid() {
    // Basic validation for time format and days
    final timeRegex = RegExp(r'^([01]?[0-9]|2[0-3]):[0-5][0-9]$');
    final validDays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

    return timeRegex.hasMatch(startTime) &&
        timeRegex.hasMatch(endTime) &&
        daysOfWeek.isNotEmpty &&
        daysOfWeek.every((day) => validDays.contains(day));
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DarshanSchedule &&
        other.id == id &&
        other.name == name &&
        other.startTime == startTime &&
        other.endTime == endTime &&
        _listEquals(other.daysOfWeek, daysOfWeek) &&
        other.isActive == isActive &&
        other.description == description;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      name,
      startTime,
      endTime,
      daysOfWeek,
      isActive,
      description,
    );
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Live darshan information for temples
class LiveDarshanInfo {
  final String? youtubeChannelUrl;
  final String? youtubeChannelId;
  final String? currentLiveVideoId;
  final bool isCurrentlyLive;
  final List<DarshanSchedule> schedule;
  final String? streamQuality;
  final DateTime? lastStreamDate;
  final Map<String, String>? streamMetadata;
  final bool isConfiguredByAdmin;
  final int? currentViewerCount;

  const LiveDarshanInfo({
    this.youtubeChannelUrl,
    this.youtubeChannelId,
    this.currentLiveVideoId,
    this.isCurrentlyLive = false,
    this.schedule = const [],
    this.streamQuality,
    this.lastStreamDate,
    this.streamMetadata,
    this.isConfiguredByAdmin = false,
    this.currentViewerCount,
  });

  /// Create LiveDarshanInfo from JSON
  factory LiveDarshanInfo.fromJson(Map<String, dynamic> json) {
    return LiveDarshanInfo(
      youtubeChannelUrl: json['youtubeChannelUrl'] as String?,
      youtubeChannelId: json['youtubeChannelId'] as String?,
      currentLiveVideoId: json['currentLiveVideoId'] as String?,
      isCurrentlyLive: json['isCurrentlyLive'] as bool? ?? false,
      schedule: json['schedule'] != null
          ? (json['schedule'] as List)
                .map(
                  (item) =>
                      DarshanSchedule.fromJson(item as Map<String, dynamic>),
                )
                .toList()
          : [],
      streamQuality: json['streamQuality'] as String?,
      lastStreamDate: json['lastStreamDate'] != null
          ? (json['lastStreamDate'] as Timestamp).toDate()
          : null,
      streamMetadata: json['streamMetadata'] != null
          ? Map<String, String>.from(json['streamMetadata'] as Map)
          : null,
      isConfiguredByAdmin: json['isConfiguredByAdmin'] as bool? ?? false,
      currentViewerCount: json['currentViewerCount'] as int?,
    );
  }

  /// Create LiveDarshanInfo from cache-safe JSON (handles ISO date strings)
  factory LiveDarshanInfo.fromCacheJson(Map<String, dynamic> json) {
    return LiveDarshanInfo(
      youtubeChannelUrl: json['youtubeChannelUrl'] as String?,
      youtubeChannelId: json['youtubeChannelId'] as String?,
      currentLiveVideoId: json['currentLiveVideoId'] as String?,
      isCurrentlyLive: json['isCurrentlyLive'] as bool? ?? false,
      schedule: json['schedule'] != null
          ? (json['schedule'] as List)
                .map(
                  (item) =>
                      DarshanSchedule.fromJson(item as Map<String, dynamic>),
                )
                .toList()
          : [],
      streamQuality: json['streamQuality'] as String?,
      lastStreamDate: json['lastStreamDate'] != null
          ? DateTime.parse(json['lastStreamDate'] as String)
          : null,
      streamMetadata: json['streamMetadata'] != null
          ? Map<String, String>.from(json['streamMetadata'] as Map)
          : null,
      isConfiguredByAdmin: json['isConfiguredByAdmin'] as bool? ?? false,
      currentViewerCount: json['currentViewerCount'] as int?,
    );
  }

  /// Convert LiveDarshanInfo to JSON
  Map<String, dynamic> toJson() {
    return {
      if (youtubeChannelUrl != null) 'youtubeChannelUrl': youtubeChannelUrl,
      if (youtubeChannelId != null) 'youtubeChannelId': youtubeChannelId,
      if (currentLiveVideoId != null) 'currentLiveVideoId': currentLiveVideoId,
      'isCurrentlyLive': isCurrentlyLive,
      'schedule': schedule.map((item) => item.toJson()).toList(),
      if (streamQuality != null) 'streamQuality': streamQuality,
      if (lastStreamDate != null)
        'lastStreamDate': Timestamp.fromDate(lastStreamDate!),
      if (streamMetadata != null) 'streamMetadata': streamMetadata,
      'isConfiguredByAdmin': isConfiguredByAdmin,
      if (currentViewerCount != null) 'currentViewerCount': currentViewerCount,
    };
  }

  /// Convert LiveDarshanInfo to cache-safe JSON (without Firestore Timestamp objects)
  Map<String, dynamic> toCacheJson() {
    return {
      if (youtubeChannelUrl != null) 'youtubeChannelUrl': youtubeChannelUrl,
      if (youtubeChannelId != null) 'youtubeChannelId': youtubeChannelId,
      if (currentLiveVideoId != null) 'currentLiveVideoId': currentLiveVideoId,
      'isCurrentlyLive': isCurrentlyLive,
      'schedule': schedule.map((item) => item.toJson()).toList(),
      if (streamQuality != null) 'streamQuality': streamQuality,
      if (lastStreamDate != null)
        'lastStreamDate': lastStreamDate!.toIso8601String(),
      if (streamMetadata != null) 'streamMetadata': streamMetadata,
      'isConfiguredByAdmin': isConfiguredByAdmin,
      if (currentViewerCount != null) 'currentViewerCount': currentViewerCount,
    };
  }

  /// Validate live darshan configuration
  bool isValid() {
    if (!isConfiguredByAdmin) return true;

    // If configured by admin, should have at least YouTube channel URL
    return youtubeChannelUrl != null && youtubeChannelUrl!.isNotEmpty;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LiveDarshanInfo &&
        other.youtubeChannelUrl == youtubeChannelUrl &&
        other.youtubeChannelId == youtubeChannelId &&
        other.currentLiveVideoId == currentLiveVideoId &&
        other.isCurrentlyLive == isCurrentlyLive &&
        _listEquals(other.schedule, schedule) &&
        other.streamQuality == streamQuality &&
        other.lastStreamDate == lastStreamDate &&
        _mapEquals(other.streamMetadata, streamMetadata) &&
        other.isConfiguredByAdmin == isConfiguredByAdmin &&
        other.currentViewerCount == currentViewerCount;
  }

  @override
  int get hashCode {
    return Object.hash(
      youtubeChannelUrl,
      youtubeChannelId,
      currentLiveVideoId,
      isCurrentlyLive,
      schedule,
      streamQuality,
      lastStreamDate,
      streamMetadata,
      isConfiguredByAdmin,
      currentViewerCount,
    );
  }

  /// Create a copy with updated fields
  LiveDarshanInfo copyWith({
    String? youtubeChannelUrl,
    String? youtubeChannelId,
    String? currentLiveVideoId,
    bool? isCurrentlyLive,
    List<DarshanSchedule>? schedule,
    String? streamQuality,
    DateTime? lastStreamDate,
    Map<String, String>? streamMetadata,
    bool? isConfiguredByAdmin,
    int? currentViewerCount,
  }) {
    return LiveDarshanInfo(
      youtubeChannelUrl: youtubeChannelUrl ?? this.youtubeChannelUrl,
      youtubeChannelId: youtubeChannelId ?? this.youtubeChannelId,
      currentLiveVideoId: currentLiveVideoId ?? this.currentLiveVideoId,
      isCurrentlyLive: isCurrentlyLive ?? this.isCurrentlyLive,
      schedule: schedule ?? this.schedule,
      streamQuality: streamQuality ?? this.streamQuality,
      lastStreamDate: lastStreamDate ?? this.lastStreamDate,
      streamMetadata: streamMetadata ?? this.streamMetadata,
      isConfiguredByAdmin: isConfiguredByAdmin ?? this.isConfiguredByAdmin,
      currentViewerCount: currentViewerCount ?? this.currentViewerCount,
    );
  }

  bool _listEquals(List<DarshanSchedule> a, List<DarshanSchedule> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  bool _mapEquals(Map<String, String>? a, Map<String, String>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (a[key] != b[key]) return false;
    }
    return true;
  }
}

/// Enhanced Temple data model with user-specific fields
class Temple {
  final String id;
  final String name;
  final String description;
  final Location location;
  final List<String> images;
  final int primaryImageIndex; // ✅ NEW: Index of primary/cover image
  final String? history; // ✅ NEW: Temple history/background
  final List<String> traditions;
  final String? mainDeity;
  final Map<String, String> timings;
  final ContactInfo contact;
  final List<String> features;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Live Darshan fields
  final LiveDarshanInfo? liveDarshan;

  // Booking availability
  final bool acceptsBookings;
  final List<String>
  availableBookingTypes; // ['visit', 'event', 'special_service']
  final Map<String, dynamic>? bookingSettings; // Booking configuration

  // Donation options
  final bool acceptsDonations;
  final List<String>
  donationPurposes; // ['general', 'festival', 'maintenance', etc.]
  final double? minimumDonationAmount;
  final double? suggestedDonationAmount;

  // Events
  final bool hasUpcomingEvents;
  final int upcomingEventsCount;
  final DateTime? nextEventDate;

  // Community features
  final bool allowsReviews;
  final double averageRating;
  final int totalReviews;
  final int totalPhotosShared;

  // User-specific fields (computed at runtime)
  final double? distanceFromUser;
  final bool isFavorite;
  final DateTime? lastVisited;
  final int visitCount;
  final bool hasUnreadNotifications;

  const Temple({
    required this.id,
    required this.name,
    required this.description,
    required this.location,
    this.images = const [],
    this.primaryImageIndex = 0, // ✅ NEW: Default to first image
    this.history, // ✅ NEW: Optional history field
    this.traditions = const [],
    this.mainDeity,
    this.timings = const {},
    required this.contact,
    this.features = const [],
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.liveDarshan,
    this.acceptsBookings = false,
    this.availableBookingTypes = const [],
    this.bookingSettings,
    this.acceptsDonations = false,
    this.donationPurposes = const [],
    this.minimumDonationAmount,
    this.suggestedDonationAmount,
    this.hasUpcomingEvents = false,
    this.upcomingEventsCount = 0,
    this.nextEventDate,
    this.allowsReviews = true,
    this.averageRating = 0.0,
    this.totalReviews = 0,
    this.totalPhotosShared = 0,
    this.distanceFromUser,
    this.isFavorite = false,
    this.lastVisited,
    this.visitCount = 0,
    this.hasUnreadNotifications = false,
  });

  /// ✅ NEW: Get primary/cover image URL
  String? get coverImage {
    if (images.isEmpty) return null;
    if (primaryImageIndex >= 0 && primaryImageIndex < images.length) {
      return images[primaryImageIndex];
    }
    return images.first; // Fallback to first image
  }

  /// ✅ NEW: Check if temple has valid images
  bool get hasImages => images.isNotEmpty;

  /// ✅ NEW: Validate temple data
  bool isValid() {
    // Basic required fields
    if (name.trim().isEmpty) return false;
    if (description.trim().isEmpty) return false;
    if (description.length < 50) return false; // ✅ Minimum description length

    // Location must be valid
    if (!location.isValid()) return false;

    // Main deity should be specified (warning level, but good practice)
    // if (mainDeity == null || mainDeity!.trim().isEmpty) return false;

    // At least one image recommended
    // if (images.isEmpty) return false;

    // Validate booking configuration
    if (acceptsBookings && availableBookingTypes.isEmpty) return false;

    // Validate donation amounts
    if (acceptsDonations) {
      if (minimumDonationAmount != null && minimumDonationAmount! <= 0) {
        return false;
      }
      if (suggestedDonationAmount != null && minimumDonationAmount != null) {
        if (suggestedDonationAmount! < minimumDonationAmount!) {
          return false; // ✅ Suggested must be >= minimum
        }
      }
    }

    // Validate live darshan if configured
    if (liveDarshan != null && liveDarshan!.isConfiguredByAdmin) {
      if (!liveDarshan!.isValid()) return false;
    }

    return true;
  }

  /// Create Temple from Firestore document with comprehensive error handling
  factory Temple.fromFirestore(DocumentSnapshot doc) {
    try {
      final data = doc.data();
      if (data == null) {
        debugPrint(
          'Temple.fromFirestore: Document data is null for temple ${doc.id}',
        );
        return _createFallbackTemple(doc);
      }

      // Handle different data types from Firestore
      Map<String, dynamic> jsonData;
      if (data is Map<String, dynamic>) {
        jsonData = data;
      } else if (data is Map) {
        // Convert Map to Map<String, dynamic>
        jsonData = Map<String, dynamic>.from(data);
      } else {
        debugPrint(
          'Temple.fromFirestore: Document data is not a Map for temple ${doc.id}: ${data.runtimeType}',
        );
        return _createFallbackTemple(doc);
      }

      return Temple._fromJsonSafe({...jsonData, 'id': doc.id});
    } catch (e) {
      // Log error and create fallback temple
      debugPrint('Temple.fromFirestore: Error parsing temple ${doc.id}: $e');
      return _createFallbackTemple(doc);
    }
  }

  /// Create Temple from JSON with safe parsing
  factory Temple._fromJsonSafe(Map<String, dynamic> json) {
    final templeId = json['id'] as String? ?? 'unknown';

    try {
      return Temple(
        id: templeId,
        name: _parseString(json['name'], 'name', templeId) ?? 'Unknown Temple',
        description:
            _parseString(json['description'], 'description', templeId) ?? '',
        location: _parseLocation(json['location'], templeId: templeId),
        images: _parseStringList(json['images'], 'images', templeId),
        primaryImageIndex:
            _parseInt(
              json['primaryImageIndex'],
              'primaryImageIndex',
              templeId,
            ) ??
            0, // ✅ NEW
        history: _parseString(json['history'], 'history', templeId), // ✅ NEW
        traditions: _parseStringList(
          json['traditions'],
          'traditions',
          templeId,
        ),
        mainDeity: _parseString(json['mainDeity'], 'mainDeity', templeId),
        timings: _buildTimings(json, templeId),
        contact: _parseContactInfo(json['contact'], templeId),
        features: _parseStringList(json['features'], 'features', templeId),
        isActive: _parseBool(json['isActive'], 'isActive', templeId, true),
        createdAt:
            _parseDateTime(json['createdAt'], 'createdAt', templeId) ??
            DateTime.now(),
        updatedAt:
            _parseDateTime(json['updatedAt'], 'updatedAt', templeId) ??
            DateTime.now(),
        liveDarshan: _parseLiveDarshanInfoWithFallback(
          json['liveDarshan'],
          templeId,
          topLevelIsLive: json['isCurrentlyLive'] as bool?,
          topLevelVideoId: json['currentLiveVideoId'] as String?,
        ),
        acceptsBookings: _parseBool(
          json['acceptsBookings'],
          'acceptsBookings',
          templeId,
          false,
        ),
        availableBookingTypes: _parseStringList(
          json['availableBookingTypes'],
          'availableBookingTypes',
          templeId,
        ),
        bookingSettings: json['bookingSettings'] as Map<String, dynamic>?,
        acceptsDonations: _parseBool(
          json['acceptsDonations'],
          'acceptsDonations',
          templeId,
          false,
        ),
        donationPurposes: _parseStringList(
          json['donationPurposes'],
          'donationPurposes',
          templeId,
        ),
        minimumDonationAmount: _parseDouble(
          json['minimumDonationAmount'],
          'minimumDonationAmount',
          templeId,
        ),
        suggestedDonationAmount: _parseDouble(
          json['suggestedDonationAmount'],
          'suggestedDonationAmount',
          templeId,
        ),
        hasUpcomingEvents: _parseBool(
          json['hasUpcomingEvents'],
          'hasUpcomingEvents',
          templeId,
          false,
        ),
        upcomingEventsCount:
            _parseInt(
              json['upcomingEventsCount'],
              'upcomingEventsCount',
              templeId,
            ) ??
            0,
        nextEventDate: _parseDateTime(
          json['nextEventDate'],
          'nextEventDate',
          templeId,
        ),
        allowsReviews: _parseBool(
          json['allowsReviews'],
          'allowsReviews',
          templeId,
          true,
        ),
        averageRating:
            _parseDouble(json['averageRating'], 'averageRating', templeId) ??
            0.0,
        totalReviews:
            _parseInt(json['totalReviews'], 'totalReviews', templeId) ?? 0,
        totalPhotosShared:
            _parseInt(
              json['totalPhotosShared'],
              'totalPhotosShared',
              templeId,
            ) ??
            0,
        distanceFromUser: _parseDouble(
          json['distanceFromUser'],
          'distanceFromUser',
          templeId,
        ),
        isFavorite: _parseBool(
          json['isFavorite'],
          'isFavorite',
          templeId,
          false,
        ),
        lastVisited: _parseDateTime(
          json['lastVisited'],
          'lastVisited',
          templeId,
        ),
        visitCount: _parseInt(json['visitCount'], 'visitCount', templeId) ?? 0,
        hasUnreadNotifications: _parseBool(
          json['hasUnreadNotifications'],
          'hasUnreadNotifications',
          templeId,
          false,
        ),
      );
    } catch (e) {
      debugPrint('Temple._fromJsonSafe: Error parsing temple $templeId: $e');
      return _createFallbackTempleFromData(templeId, json);
    }
  }

  /// Create a fallback temple when parsing fails
  static Temple _createFallbackTemple(DocumentSnapshot doc) {
    final data = doc.data();
    final templeId = doc.id;

    // Try to extract basic information if possible
    String name = 'Unknown Temple';
    String description = 'Temple data could not be loaded properly';

    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      name = _parseString(map['name'], 'name', templeId) ?? name;
      description =
          _parseString(map['description'], 'description', templeId) ??
          description;
    }

    return Temple(
      id: templeId,
      name: name,
      description: description,
      location: const Location(latitude: 0.0, longitude: 0.0),
      contact: const ContactInfo(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// Create a fallback temple from partial JSON data
  static Temple _createFallbackTempleFromData(
    String templeId,
    Map<String, dynamic> json,
  ) {
    return Temple(
      id: templeId,
      name: _parseString(json['name'], 'name', templeId) ?? 'Unknown Temple',
      description:
          _parseString(json['description'], 'description', templeId) ??
          'Temple data partially corrupted',
      location: const Location(latitude: 0.0, longitude: 0.0),
      contact: const ContactInfo(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  // Safe parsing helper methods
  static String? _parseString(
    dynamic value,
    String fieldName,
    String templeId,
  ) {
    try {
      if (value == null) return null;
      if (value is String) return value;
      return value.toString();
    } catch (e) {
      debugPrint(
        'Temple._parseString: Error parsing $fieldName for temple $templeId: $e',
      );
      return null;
    }
  }

  static List<String> _parseStringList(
    dynamic value,
    String fieldName,
    String templeId,
  ) {
    try {
      if (value == null) return [];
      if (value is List<String>) return value;
      if (value is List) return value.map((item) => item.toString()).toList();
      return [];
    } catch (e) {
      debugPrint(
        'Temple._parseStringList: Error parsing $fieldName for temple $templeId: $e',
      );
      return [];
    }
  }

  static Map<String, String> _buildTimings(
    Map<String, dynamic> json,
    String templeId,
  ) {
    final parsed = _parseStringMap(json['timings'], 'timings', templeId);
    if (parsed.isNotEmpty) return parsed;

    // Fall back to legacy openingTime/closingTime fields
    final opening = json['openingTime'] as String?;
    final closing = json['closingTime'] as String?;
    if (opening == null || closing == null) return {};

    final range = '$opening - $closing';
    final closedDay = json['weeklyClosedDay'] as String?;
    if (closedDay == null || closedDay == 'None') {
      return {'Daily': range};
    }
    const days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday',
    ];
    return {for (final d in days) if (d != closedDay) d: range};
  }

  static Map<String, String> _parseStringMap(
    dynamic value,
    String fieldName,
    String templeId,
  ) {
    try {
      if (value == null) return {};
      if (value is Map<String, String>) return value;
      if (value is Map) {
        return value.map(
          (key, val) => MapEntry(key.toString(), val.toString()),
        );
      }
      return {};
    } catch (e) {
      debugPrint(
        'Temple._parseStringMap: Error parsing $fieldName for temple $templeId: $e',
      );
      return {};
    }
  }

  static bool _parseBool(
    dynamic value,
    String fieldName,
    String templeId,
    bool fallback,
  ) {
    try {
      if (value == null) return fallback;
      if (value is bool) return value;
      if (value is String) {
        final lower = value.toLowerCase();
        return lower == 'true' || lower == '1' || lower == 'yes';
      }
      if (value is int) return value != 0;
      return fallback;
    } catch (e) {
      debugPrint(
        'Temple._parseBool: Error parsing $fieldName for temple $templeId: $e',
      );
      return fallback;
    }
  }

  static double? _parseDouble(
    dynamic value,
    String fieldName,
    String templeId,
  ) {
    try {
      if (value == null) return null;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    } catch (e) {
      debugPrint(
        'Temple._parseDouble: Error parsing $fieldName for temple $templeId: $e',
      );
      return null;
    }
  }

  static int? _parseInt(dynamic value, String fieldName, String templeId) {
    try {
      if (value == null) return null;
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value);
      return null;
    } catch (e) {
      debugPrint(
        'Temple._parseInt: Error parsing $fieldName for temple $templeId: $e',
      );
      return null;
    }
  }

  static DateTime? _parseDateTime(
    dynamic value,
    String fieldName,
    String templeId,
  ) {
    try {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value);
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
      return null;
    } catch (e) {
      debugPrint(
        'Temple._parseDateTime: Error parsing $fieldName for temple $templeId: $e',
      );
      return null;
    }
  }

  static ContactInfo _parseContactInfo(dynamic value, String templeId) {
    try {
      if (value == null) return const ContactInfo();
      if (value is Map) {
        final map = Map<String, dynamic>.from(value);
        return ContactInfo(
          phone: _parseString(map['phone'], 'contact.phone', templeId),
          email: _parseString(map['email'], 'contact.email', templeId),
          website: _parseString(map['website'], 'contact.website', templeId),
          socialMedia: map['socialMedia'] != null
              ? Map<String, String>.from(map['socialMedia'] as Map)
              : null,
        );
      }
      return const ContactInfo();
    } catch (e) {
      debugPrint(
        'Temple._parseContactInfo: Error parsing contact for temple $templeId: $e',
      );
      return const ContactInfo();
    }
  }

  /// Like [_parseLiveDarshanInfoWithFallback] but merges top-level `isCurrentlyLive` /
  /// `currentLiveVideoId` fields as a fallback when the nested map is stale.
  /// The Cloud Function historically wrote to top-level fields; this ensures
  /// the app shows the correct live status even for documents not yet migrated.
  static LiveDarshanInfo? _parseLiveDarshanInfoWithFallback(
    dynamic value,
    String templeId, {
    bool? topLevelIsLive,
    String? topLevelVideoId,
  }) {
    try {
      LiveDarshanInfo? info;
      if (value != null && value is Map) {
        final map = Map<String, dynamic>.from(value);
        info = LiveDarshanInfo.fromJson(map);
      }

      // If the nested map has no live status but the top-level field says live,
      // use the top-level value (written by the Cloud Function before the fix).
      if (topLevelIsLive == true && (info == null || !info.isCurrentlyLive)) {
        if (info != null) {
          return info.copyWith(
            isCurrentlyLive: true,
            currentLiveVideoId: topLevelVideoId ?? info.currentLiveVideoId,
          );
        }
        // No nested map at all — create a minimal info from top-level fields
        return LiveDarshanInfo(
          isCurrentlyLive: true,
          currentLiveVideoId: topLevelVideoId,
          isConfiguredByAdmin: false,
        );
      }

      return info;
    } catch (e) {
      debugPrint(
        'Temple._parseLiveDarshanInfoWithFallback: Error for temple $templeId: $e',
      );
      return null;
    }
  }

  static LiveDarshanInfo? _parseLiveDarshanInfoFromCache(
    dynamic value,
    String templeId,
  ) {
    try {
      if (value == null) return null;
      if (value is Map) {
        final map = Map<String, dynamic>.from(value);
        return LiveDarshanInfo.fromCacheJson(map);
      }
      return null;
    } catch (e) {
      debugPrint(
        'Temple._parseLiveDarshanInfoFromCache: Error parsing liveDarshan for temple $templeId: $e',
      );
      return null;
    }
  }

  static DateTime? _parseDateTimeFromString(
    dynamic value,
    String fieldName,
    String templeId,
  ) {
    try {
      if (value == null) return null;
      if (value is String) return DateTime.parse(value);
      if (value is DateTime) return value;
      return null;
    } catch (e) {
      debugPrint(
        'Temple._parseDateTimeFromString: Error parsing $fieldName for temple $templeId: $e',
      );
      return null;
    }
  }

  /// Create Temple from JSON (public interface - uses safe parsing internally)
  factory Temple.fromJson(Map<String, dynamic> json) {
    return Temple._fromJsonSafe(json);
  }

  /// Create Temple from cache-safe JSON (handles ISO date strings)
  factory Temple.fromCacheJson(Map<String, dynamic> json) {
    final templeId = json['id'] as String? ?? 'unknown';

    try {
      return Temple(
        id: templeId,
        name: _parseString(json['name'], 'name', templeId) ?? 'Unknown Temple',
        description:
            _parseString(json['description'], 'description', templeId) ?? '',
        location: _parseLocation(json['location'], templeId: templeId),
        images: _parseStringList(json['images'], 'images', templeId),
        traditions: _parseStringList(
          json['traditions'],
          'traditions',
          templeId,
        ),
        mainDeity: _parseString(json['mainDeity'], 'mainDeity', templeId),
        timings: _buildTimings(json, templeId),
        contact: _parseContactInfo(json['contact'], templeId),
        features: _parseStringList(json['features'], 'features', templeId),
        isActive: _parseBool(json['isActive'], 'isActive', templeId, true),
        createdAt:
            _parseDateTimeFromString(
              json['createdAt'],
              'createdAt',
              templeId,
            ) ??
            DateTime.now(),
        updatedAt:
            _parseDateTimeFromString(
              json['updatedAt'],
              'updatedAt',
              templeId,
            ) ??
            DateTime.now(),
        liveDarshan: _parseLiveDarshanInfoFromCache(
          json['liveDarshan'],
          templeId,
        ),
        acceptsBookings: _parseBool(
          json['acceptsBookings'],
          'acceptsBookings',
          templeId,
          false,
        ),
        availableBookingTypes: _parseStringList(
          json['availableBookingTypes'],
          'availableBookingTypes',
          templeId,
        ),
        bookingSettings: json['bookingSettings'] as Map<String, dynamic>?,
        acceptsDonations: _parseBool(
          json['acceptsDonations'],
          'acceptsDonations',
          templeId,
          false,
        ),
        donationPurposes: _parseStringList(
          json['donationPurposes'],
          'donationPurposes',
          templeId,
        ),
        minimumDonationAmount: _parseDouble(
          json['minimumDonationAmount'],
          'minimumDonationAmount',
          templeId,
        ),
        suggestedDonationAmount: _parseDouble(
          json['suggestedDonationAmount'],
          'suggestedDonationAmount',
          templeId,
        ),
        hasUpcomingEvents: _parseBool(
          json['hasUpcomingEvents'],
          'hasUpcomingEvents',
          templeId,
          false,
        ),
        upcomingEventsCount:
            _parseInt(
              json['upcomingEventsCount'],
              'upcomingEventsCount',
              templeId,
            ) ??
            0,
        nextEventDate: _parseDateTimeFromString(
          json['nextEventDate'],
          'nextEventDate',
          templeId,
        ),
        allowsReviews: _parseBool(
          json['allowsReviews'],
          'allowsReviews',
          templeId,
          true,
        ),
        averageRating:
            _parseDouble(json['averageRating'], 'averageRating', templeId) ??
            0.0,
        totalReviews:
            _parseInt(json['totalReviews'], 'totalReviews', templeId) ?? 0,
        totalPhotosShared:
            _parseInt(
              json['totalPhotosShared'],
              'totalPhotosShared',
              templeId,
            ) ??
            0,
        distanceFromUser: _parseDouble(
          json['distanceFromUser'],
          'distanceFromUser',
          templeId,
        ),
        isFavorite: _parseBool(
          json['isFavorite'],
          'isFavorite',
          templeId,
          false,
        ),
        lastVisited: _parseDateTimeFromString(
          json['lastVisited'],
          'lastVisited',
          templeId,
        ),
        visitCount: _parseInt(json['visitCount'], 'visitCount', templeId) ?? 0,
        hasUnreadNotifications: _parseBool(
          json['hasUnreadNotifications'],
          'hasUnreadNotifications',
          templeId,
          false,
        ),
      );
    } catch (e) {
      debugPrint('Temple.fromCacheJson: Error parsing temple $templeId: $e');
      return _createFallbackTempleFromData(templeId, json);
    }
  }

  static Location _parseLocation(dynamic value, {String? templeId}) {
    try {
      if (value == null) return const Location(latitude: 0.0, longitude: 0.0);
      return Location.fromDynamic(value, templeId: templeId);
    } catch (e) {
      debugPrint(
        'Temple._parseLocation: Error parsing location for temple $templeId: $e',
      );
      return const Location(latitude: 0.0, longitude: 0.0);
    }
  }

  /// Convert Temple to JSON for Firestore
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'location': location.toJson(),
      'images': images,
      'primaryImageIndex': primaryImageIndex, // ✅ NEW
      if (history != null) 'history': history, // ✅ NEW
      'traditions': traditions,
      'timings': timings,
      'contact': contact.toJson(),
      'features': features,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      if (liveDarshan != null) 'liveDarshan': liveDarshan!.toJson(),
      'acceptsBookings': acceptsBookings,
      'availableBookingTypes': availableBookingTypes,
      if (bookingSettings != null) 'bookingSettings': bookingSettings,
      'acceptsDonations': acceptsDonations,
      'donationPurposes': donationPurposes,
      if (minimumDonationAmount != null)
        'minimumDonationAmount': minimumDonationAmount,
      if (suggestedDonationAmount != null)
        'suggestedDonationAmount': suggestedDonationAmount,
      'hasUpcomingEvents': hasUpcomingEvents,
      'upcomingEventsCount': upcomingEventsCount,
      if (nextEventDate != null)
        'nextEventDate': Timestamp.fromDate(nextEventDate!),
      'allowsReviews': allowsReviews,
      'averageRating': averageRating,
      'totalReviews': totalReviews,
      'totalPhotosShared': totalPhotosShared,
      if (distanceFromUser != null) 'distanceFromUser': distanceFromUser,
      'isFavorite': isFavorite,
      if (lastVisited != null) 'lastVisited': Timestamp.fromDate(lastVisited!),
      'visitCount': visitCount,
      'hasUnreadNotifications': hasUnreadNotifications,
    };
  }

  /// Convert Temple to cache-safe JSON (without Firestore Timestamp objects)
  Map<String, dynamic> toCacheJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'location': location.toJson(),
      'images': images,
      'traditions': traditions,
      'timings': timings,
      'contact': contact.toJson(),
      'features': features,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      if (liveDarshan != null) 'liveDarshan': liveDarshan!.toCacheJson(),
      'acceptsBookings': acceptsBookings,
      'availableBookingTypes': availableBookingTypes,
      if (bookingSettings != null) 'bookingSettings': bookingSettings,
      'acceptsDonations': acceptsDonations,
      'donationPurposes': donationPurposes,
      if (minimumDonationAmount != null)
        'minimumDonationAmount': minimumDonationAmount,
      if (suggestedDonationAmount != null)
        'suggestedDonationAmount': suggestedDonationAmount,
      'hasUpcomingEvents': hasUpcomingEvents,
      'upcomingEventsCount': upcomingEventsCount,
      if (nextEventDate != null)
        'nextEventDate': nextEventDate!.toIso8601String(),
      'allowsReviews': allowsReviews,
      'averageRating': averageRating,
      'totalReviews': totalReviews,
      'totalPhotosShared': totalPhotosShared,
      if (distanceFromUser != null) 'distanceFromUser': distanceFromUser,
      'isFavorite': isFavorite,
      if (lastVisited != null) 'lastVisited': lastVisited!.toIso8601String(),
      'visitCount': visitCount,
      'hasUnreadNotifications': hasUnreadNotifications,
    };
  }

  /// Create a copy of this temple with updated fields
  Temple copyWith({
    String? id,
    String? name,
    String? description,
    Location? location,
    List<String>? images,
    List<String>? traditions,
    String? mainDeity,
    Map<String, String>? timings,
    ContactInfo? contact,
    List<String>? features,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    LiveDarshanInfo? liveDarshan,
    bool? acceptsBookings,
    List<String>? availableBookingTypes,
    Map<String, dynamic>? bookingSettings,
    bool? acceptsDonations,
    List<String>? donationPurposes,
    double? minimumDonationAmount,
    double? suggestedDonationAmount,
    bool? hasUpcomingEvents,
    int? upcomingEventsCount,
    DateTime? nextEventDate,
    bool? allowsReviews,
    double? averageRating,
    int? totalReviews,
    int? totalPhotosShared,
    double? distanceFromUser,
    bool? isFavorite,
    DateTime? lastVisited,
    int? visitCount,
    bool? hasUnreadNotifications,
  }) {
    return Temple(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      location: location ?? this.location,
      images: images ?? this.images,
      traditions: traditions ?? this.traditions,
      mainDeity: mainDeity ?? this.mainDeity,
      timings: timings ?? this.timings,
      contact: contact ?? this.contact,
      features: features ?? this.features,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      liveDarshan: liveDarshan ?? this.liveDarshan,
      acceptsBookings: acceptsBookings ?? this.acceptsBookings,
      availableBookingTypes:
          availableBookingTypes ?? this.availableBookingTypes,
      bookingSettings: bookingSettings ?? this.bookingSettings,
      acceptsDonations: acceptsDonations ?? this.acceptsDonations,
      donationPurposes: donationPurposes ?? this.donationPurposes,
      minimumDonationAmount:
          minimumDonationAmount ?? this.minimumDonationAmount,
      suggestedDonationAmount:
          suggestedDonationAmount ?? this.suggestedDonationAmount,
      hasUpcomingEvents: hasUpcomingEvents ?? this.hasUpcomingEvents,
      upcomingEventsCount: upcomingEventsCount ?? this.upcomingEventsCount,
      nextEventDate: nextEventDate ?? this.nextEventDate,
      allowsReviews: allowsReviews ?? this.allowsReviews,
      averageRating: averageRating ?? this.averageRating,
      totalReviews: totalReviews ?? this.totalReviews,
      totalPhotosShared: totalPhotosShared ?? this.totalPhotosShared,
      distanceFromUser: distanceFromUser ?? this.distanceFromUser,
      isFavorite: isFavorite ?? this.isFavorite,
      lastVisited: lastVisited ?? this.lastVisited,
      visitCount: visitCount ?? this.visitCount,
      hasUnreadNotifications:
          hasUnreadNotifications ?? this.hasUnreadNotifications,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Temple &&
        other.id == id &&
        other.name == name &&
        other.description == description &&
        other.location == location &&
        _listEquals(other.images, images) &&
        _listEquals(other.traditions, traditions) &&
        _mapEquals(other.timings, timings) &&
        other.contact == contact &&
        _listEquals(other.features, features) &&
        other.isActive == isActive &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      name,
      description,
      location,
      images,
      traditions,
      timings,
      contact,
      features,
      isActive,
      createdAt,
      updatedAt,
    );
  }

  @override
  String toString() {
    return 'Temple(id: $id, name: $name, location: $location)';
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  bool _mapEquals(Map<String, String> a, Map<String, String> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (a[key] != b[key]) return false;
    }
    return true;
  }
}
