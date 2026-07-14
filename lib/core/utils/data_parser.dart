import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../shared/models/temple.dart';

/// Custom exception for temple parsing errors
class TempleParsingError implements Exception {
  final String templeId;
  final String field;
  final dynamic actualValue;
  final Type expectedType;
  final String? additionalInfo;

  TempleParsingError(
    this.templeId,
    this.field,
    this.actualValue,
    this.expectedType, [
    this.additionalInfo,
  ]);

  @override
  String toString() {
    final baseMessage =
        'TempleParsingError: Temple $templeId field "$field" '
        'expected $expectedType but got ${actualValue.runtimeType}: $actualValue';

    if (additionalInfo != null) {
      return '$baseMessage. Additional info: $additionalInfo';
    }

    return baseMessage;
  }
}

/// Utility class for safe data parsing with comprehensive error handling
class DataParser {
  /// Generic safe parsing method with type validation
  static T? safeParse<T>(
    dynamic value,
    T Function(dynamic) parser, {
    String? fieldName,
    String? templeId,
    T? fallback,
  }) {
    try {
      if (value == null) return fallback;
      return parser(value);
    } catch (e) {
      final error = TempleParsingError(
        templeId ?? 'unknown',
        fieldName ?? 'unknown_field',
        value,
        T,
        e.toString(),
      );

      debugPrint('DataParser.safeParse error: $error');
      return fallback;
    }
  }

  /// Safely parse a string value
  static String? parseString(
    dynamic value, {
    String? fieldName,
    String? templeId,
    String? fallback,
  }) {
    return safeParse<String>(
      value,
      (v) {
        if (v is String) return v;
        if (v is num) return v.toString();
        if (v is bool) return v.toString();
        return v.toString();
      },
      fieldName: fieldName,
      templeId: templeId,
      fallback: fallback,
    );
  }

  /// Safely parse a required string value (throws if null/empty)
  static String parseRequiredString(
    dynamic value, {
    String? fieldName,
    String? templeId,
    String fallback = '',
  }) {
    final result = parseString(
      value,
      fieldName: fieldName,
      templeId: templeId,
      fallback: fallback,
    );

    if (result == null || result.isEmpty) {
      if (fallback.isNotEmpty) return fallback;

      final error = TempleParsingError(
        templeId ?? 'unknown',
        fieldName ?? 'unknown_field',
        value,
        String,
        'Required string field is null or empty',
      );
      debugPrint('DataParser.parseRequiredString error: $error');
      return fallback;
    }

    return result;
  }

  /// Safely parse a double value
  static double? parseDouble(
    dynamic value, {
    String? fieldName,
    String? templeId,
    double? fallback,
  }) {
    return safeParse<double>(
      value,
      (v) {
        if (v is double) return v;
        if (v is int) return v.toDouble();
        if (v is num) return v.toDouble();
        if (v is String) {
          final parsed = double.tryParse(v);
          if (parsed != null) return parsed;
          throw Exception('Cannot parse string "$v" to double');
        }
        throw Exception('Cannot convert ${v.runtimeType} to double');
      },
      fieldName: fieldName,
      templeId: templeId,
      fallback: fallback,
    );
  }

  /// Safely parse an integer value
  static int? parseInt(
    dynamic value, {
    String? fieldName,
    String? templeId,
    int? fallback,
  }) {
    return safeParse<int>(
      value,
      (v) {
        if (v is int) return v;
        if (v is double) return v.toInt();
        if (v is num) return v.toInt();
        if (v is String) {
          final parsed = int.tryParse(v);
          if (parsed != null) return parsed;
          throw Exception('Cannot parse string "$v" to int');
        }
        throw Exception('Cannot convert ${v.runtimeType} to int');
      },
      fieldName: fieldName,
      templeId: templeId,
      fallback: fallback,
    );
  }

  /// Safely parse a boolean value
  static bool parseBool(
    dynamic value, {
    String? fieldName,
    String? templeId,
    bool fallback = false,
  }) {
    return safeParse<bool>(
          value,
          (v) {
            if (v is bool) return v;
            if (v is String) {
              final lower = v.toLowerCase();
              if (lower == 'true' || lower == '1' || lower == 'yes') {
                return true;
              }
              if (lower == 'false' || lower == '0' || lower == 'no') {
                return false;
              }
              throw Exception('Cannot parse string "$v" to bool');
            }
            if (v is int) return v != 0;
            if (v is double) return v != 0.0;
            throw Exception('Cannot convert ${v.runtimeType} to bool');
          },
          fieldName: fieldName,
          templeId: templeId,
          fallback: fallback,
        ) ??
        fallback;
  }

  /// Safely parse a DateTime from Timestamp or other formats
  static DateTime? parseDateTime(
    dynamic value, {
    String? fieldName,
    String? templeId,
    DateTime? fallback,
  }) {
    return safeParse<DateTime>(
      value,
      (v) {
        if (v is Timestamp) return v.toDate();
        if (v is DateTime) return v;
        if (v is String) {
          final parsed = DateTime.tryParse(v);
          if (parsed != null) return parsed;
          throw Exception('Cannot parse string "$v" to DateTime');
        }
        if (v is int) {
          // Assume milliseconds since epoch
          return DateTime.fromMillisecondsSinceEpoch(v);
        }
        throw Exception('Cannot convert ${v.runtimeType} to DateTime');
      },
      fieldName: fieldName,
      templeId: templeId,
      fallback: fallback,
    );
  }

  /// Safely ensure a value is a Map of String to dynamic
  static Map<String, dynamic> ensureMap(
    dynamic value, {
    String? fieldName,
    String? templeId,
    Map<String, dynamic>? fallback,
  }) {
    final result = safeParse<Map<String, dynamic>>(
      value,
      (v) {
        if (v is Map<String, dynamic>) return v;
        if (v is Map) return Map<String, dynamic>.from(v);
        throw Exception(
          'Cannot convert ${v.runtimeType} to Map<String, dynamic>',
        );
      },
      fieldName: fieldName,
      templeId: templeId,
      fallback: fallback ?? <String, dynamic>{},
    );

    return result ?? <String, dynamic>{};
  }

  /// Safely ensure a value is a List of String
  static List<String> ensureStringList(
    dynamic value, {
    String? fieldName,
    String? templeId,
    List<String>? fallback,
  }) {
    final result = safeParse<List<String>>(
      value,
      (v) {
        if (v is List<String>) return v;
        if (v is List) {
          return v.map((item) => item.toString()).toList();
        }
        if (v is String) {
          // Handle comma-separated strings
          return v
              .split(',')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList();
        }
        throw Exception('Cannot convert ${v.runtimeType} to List<String>');
      },
      fieldName: fieldName,
      templeId: templeId,
      fallback: fallback ?? <String>[],
    );

    return result ?? <String>[];
  }

  /// Safely parse Location data from various formats
  static Location parseLocation(
    dynamic locationData, {
    String? templeId,
    Location? fallback,
  }) {
    if (locationData == null) {
      debugPrint(
        'DataParser.parseLocation: Location data is null for temple $templeId',
      );
      return fallback ?? const Location(latitude: 0.0, longitude: 0.0);
    }

    try {
      // Handle string format (coordinates or address)
      if (locationData is String) {
        return _parseLocationString(locationData, templeId: templeId);
      }

      // Handle Map format
      if (locationData is Map) {
        final locationMap = ensureMap(
          locationData,
          fieldName: 'location',
          templeId: templeId,
        );
        return _parseLocationMap(locationMap, templeId: templeId);
      }

      throw TempleParsingError(
        templeId ?? 'unknown',
        'location',
        locationData,
        Location,
        'Unsupported location data type: ${locationData.runtimeType}',
      );
    } catch (e) {
      debugPrint('DataParser.parseLocation error for temple $templeId: $e');
      return fallback ?? const Location(latitude: 0.0, longitude: 0.0);
    }
  }

  /// Parse location from string format
  static Location _parseLocationString(String locationStr, {String? templeId}) {
    try {
      // Try to parse as coordinates: "lat,lng"
      final parts = locationStr.split(',');
      if (parts.length >= 2) {
        final lat = parseDouble(
          parts[0].trim(),
          fieldName: 'location.latitude',
          templeId: templeId,
        );
        final lng = parseDouble(
          parts[1].trim(),
          fieldName: 'location.longitude',
          templeId: templeId,
        );

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
      debugPrint('DataParser._parseLocationString error: $e');
      return Location(latitude: 0.0, longitude: 0.0, address: locationStr);
    }
  }

  /// Parse location from Map format
  static Location _parseLocationMap(
    Map<String, dynamic> locationMap, {
    String? templeId,
  }) {
    final lat =
        parseDouble(
          locationMap['latitude'] ?? locationMap['lat'],
          fieldName: 'location.latitude',
          templeId: templeId,
          fallback: 0.0,
        ) ??
        0.0;

    final lng =
        parseDouble(
          locationMap['longitude'] ?? locationMap['lng'],
          fieldName: 'location.longitude',
          templeId: templeId,
          fallback: 0.0,
        ) ??
        0.0;

    // Validate coordinates and fallback to (0,0) if invalid
    final validLat = _isValidLatitude(lat) ? lat : 0.0;
    final validLng = _isValidLongitude(lng) ? lng : 0.0;

    if (lat != validLat || lng != validLng) {
      debugPrint(
        'DataParser: Invalid coordinates for temple $templeId: '
        'lat=$lat, lng=$lng. Using fallback: lat=$validLat, lng=$validLng',
      );
    }

    return Location(
      latitude: validLat,
      longitude: validLng,
      address: parseString(
        locationMap['address'],
        fieldName: 'location.address',
        templeId: templeId,
      ),
      city: parseString(
        locationMap['city'],
        fieldName: 'location.city',
        templeId: templeId,
      ),
      state: parseString(
        locationMap['state'],
        fieldName: 'location.state',
        templeId: templeId,
      ),
      country: parseString(
        locationMap['country'],
        fieldName: 'location.country',
        templeId: templeId,
      ),
      postalCode: parseString(
        locationMap['postalCode'],
        fieldName: 'location.postalCode',
        templeId: templeId,
      ),
    );
  }

  /// Safely parse ContactInfo data
  static ContactInfo parseContactInfo(
    dynamic contactData, {
    String? templeId,
    ContactInfo? fallback,
  }) {
    if (contactData == null) {
      return fallback ?? const ContactInfo();
    }

    try {
      final contactMap = ensureMap(
        contactData,
        fieldName: 'contact',
        templeId: templeId,
      );

      final socialMediaData = contactMap['socialMedia'];
      Map<String, String>? socialMedia;

      if (socialMediaData != null) {
        final socialMap = ensureMap(
          socialMediaData,
          fieldName: 'contact.socialMedia',
          templeId: templeId,
        );
        socialMedia = socialMap.map(
          (key, value) => MapEntry(key, value.toString()),
        );
      }

      return ContactInfo(
        phone: parseString(
          contactMap['phone'],
          fieldName: 'contact.phone',
          templeId: templeId,
        ),
        email: parseString(
          contactMap['email'],
          fieldName: 'contact.email',
          templeId: templeId,
        ),
        website: parseString(
          contactMap['website'],
          fieldName: 'contact.website',
          templeId: templeId,
        ),
        socialMedia: socialMedia,
      );
    } catch (e) {
      debugPrint('DataParser.parseContactInfo error for temple $templeId: $e');
      return fallback ?? const ContactInfo();
    }
  }

  /// Safely parse timing data
  static Map<String, String> parseTimings(
    dynamic timingsData, {
    String? templeId,
    Map<String, String>? fallback,
  }) {
    if (timingsData == null) {
      return fallback ?? <String, String>{};
    }

    try {
      final timingsMap = ensureMap(
        timingsData,
        fieldName: 'timings',
        templeId: templeId,
      );

      // Convert all values to strings
      return timingsMap.map((key, value) => MapEntry(key, value.toString()));
    } catch (e) {
      debugPrint('DataParser.parseTimings error for temple $templeId: $e');
      return fallback ?? <String, String>{};
    }
  }

  /// Validate latitude range
  static bool _isValidLatitude(double lat) {
    return lat >= -90.0 && lat <= 90.0;
  }

  /// Validate longitude range
  static bool _isValidLongitude(double lng) {
    return lng >= -180.0 && lng <= 180.0;
  }

  /// Validate coordinate pair
  static bool _isValidCoordinate(double lat, double lng) {
    return _isValidLatitude(lat) && _isValidLongitude(lng);
  }

  /// Log detailed parsing error information
  static void logParsingError(
    String templeId,
    String operation,
    dynamic data,
    Exception error,
  ) {
    debugPrint('=== Temple Parsing Error ===');
    debugPrint('Temple ID: $templeId');
    debugPrint('Operation: $operation');
    debugPrint('Data Type: ${data.runtimeType}');
    debugPrint('Data Value: $data');
    debugPrint('Error: $error');
    debugPrint('========================');
  }
}
