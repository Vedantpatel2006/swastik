import 'package:cloud_firestore/cloud_firestore.dart';

/// Extension methods for Map to safely extract typed values
extension MapExtensions on Map<String, dynamic> {
  /// Safely get a String value
  String? getString(String key) => this[key]?.toString();

  /// Safely get an int value with type conversion
  int? getInt(String key) {
    final value = this[key];
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// Safely get a double value with type conversion
  double? getDouble(String key) {
    final value = this[key];
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  /// Safely get a bool value
  bool? getBool(String key) {
    final value = this[key];
    if (value is bool) return value;
    if (value is String) {
      final lower = value.toLowerCase();
      if (lower == 'true') return true;
      if (lower == 'false') return false;
    }
    return null;
  }

  /// Safely get a DateTime value from Timestamp or String
  DateTime? getDateTime(String key) {
    final value = this[key];
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  /// Safely get a List<String> value
  List<String> getStringList(String key) {
    final value = this[key];
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return [];
  }

  /// Safely get a Map<String, String> value
  Map<String, String> getStringMap(String key) {
    final value = this[key];
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v.toString()));
    }
    return {};
  }

  /// Safely get a nested Map
  Map<String, dynamic>? getMap(String key) {
    final value = this[key];
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }
}
