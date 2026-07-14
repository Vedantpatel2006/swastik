import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a temple event with details like name, description, date, etc.
class Event {
  final String id;
  final String templeId;
  final String name;
  final String description;
  final DateTime startDate;
  final DateTime endDate;
  final String? imageUrl;
  final Map<String, dynamic>? additionalInfo;
  final bool isRecurring;
  final RecurrencePattern? recurrencePattern;

  const Event({
    required this.id,
    required this.templeId,
    required this.name,
    required this.description,
    required this.startDate,
    required this.endDate,
    this.imageUrl,
    this.additionalInfo,
    this.isRecurring = false,
    this.recurrencePattern,
  });

  /// Create Event from JSON
  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'] as String,
      templeId: json['templeId'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      startDate: (json['startDate'] as Timestamp).toDate(),
      endDate: (json['endDate'] as Timestamp).toDate(),
      imageUrl: json['imageUrl'] as String?,
      additionalInfo: json['additionalInfo'] as Map<String, dynamic>?,
      isRecurring: json['isRecurring'] as bool? ?? false,
      recurrencePattern: json['recurrencePattern'] != null
          ? RecurrencePattern.fromJson(
              json['recurrencePattern'] as Map<String, dynamic>)
          : null,
    );
  }

  /// Convert Event to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'templeId': templeId,
      'name': name,
      'description': description,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (additionalInfo != null) 'additionalInfo': additionalInfo,
      'isRecurring': isRecurring,
      if (recurrencePattern != null)
        'recurrencePattern': recurrencePattern!.toJson(),
    };
  }

  /// Create a copy of this Event with the given fields replaced with the new values
  Event copyWith({
    String? id,
    String? templeId,
    String? name,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    String? imageUrl,
    Map<String, dynamic>? additionalInfo,
    bool? isRecurring,
    RecurrencePattern? recurrencePattern,
  }) {
    return Event(
      id: id ?? this.id,
      templeId: templeId ?? this.templeId,
      name: name ?? this.name,
      description: description ?? this.description,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      imageUrl: imageUrl ?? this.imageUrl,
      additionalInfo: additionalInfo ?? this.additionalInfo,
      isRecurring: isRecurring ?? this.isRecurring,
      recurrencePattern: recurrencePattern ?? this.recurrencePattern,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Event &&
        other.id == id &&
        other.templeId == templeId &&
        other.name == name &&
        other.description == description &&
        other.startDate == startDate &&
        other.endDate == endDate &&
        other.imageUrl == imageUrl &&
        other.isRecurring == isRecurring &&
        other.recurrencePattern == recurrencePattern;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      templeId,
      name,
      description,
      startDate,
      endDate,
      imageUrl,
      isRecurring,
      recurrencePattern,
    );
  }

  /// ✅ NEW: Validate event data
  bool isValid() {
    // Check required fields
    if (id.isEmpty || templeId.isEmpty) return false;
    if (name.trim().isEmpty || description.trim().isEmpty) return false;

    // ✅ CRITICAL: End date must be after start date
    if (!endDate.isAfter(startDate)) {
      throw ArgumentError('Event end date must be after start date');
    }

    // Start date should be in the future
    if (startDate.isBefore(DateTime.now())) {
      throw ArgumentError('Event start date cannot be in the past');
    }

    // If recurring, validate recurrence pattern
    if (isRecurring && recurrencePattern == null) {
      throw ArgumentError('Recurring event must have a recurrence pattern');
    }

    return true;
  }
}

/// Defines the recurrence pattern for recurring events
class RecurrencePattern {
  final RecurrenceType type;
  final int interval;
  final List<int>? daysOfWeek; // 1-7 for Monday-Sunday
  final int? dayOfMonth;
  final DateTime? until;
  final int? count;

  const RecurrencePattern({
    required this.type,
    this.interval = 1,
    this.daysOfWeek,
    this.dayOfMonth,
    this.until,
    this.count,
  });

  /// Create RecurrencePattern from JSON
  factory RecurrencePattern.fromJson(Map<String, dynamic> json) {
    return RecurrencePattern(
      type: RecurrenceType.values[json['type'] as int],
      interval: json['interval'] as int? ?? 1,
      daysOfWeek: json['daysOfWeek'] != null
          ? List<int>.from(json['daysOfWeek'] as List)
          : null,
      dayOfMonth: json['dayOfMonth'] as int?,
      until: json['until'] != null
          ? (json['until'] as Timestamp).toDate()
          : null,
      count: json['count'] as int?,
    );
  }

  /// Convert RecurrencePattern to JSON
  Map<String, dynamic> toJson() {
    return {
      'type': type.index,
      'interval': interval,
      if (daysOfWeek != null) 'daysOfWeek': daysOfWeek,
      if (dayOfMonth != null) 'dayOfMonth': dayOfMonth,
      if (until != null) 'until': Timestamp.fromDate(until!),
      if (count != null) 'count': count,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RecurrencePattern &&
        other.type == type &&
        other.interval == interval &&
        other.dayOfMonth == dayOfMonth &&
        other.until == until &&
        other.count == count;
  }

  @override
  int get hashCode {
    return Object.hash(
      type,
      interval,
      dayOfMonth,
      until,
      count,
    );
  }
}

/// Types of recurrence patterns
enum RecurrenceType {
  daily,
  weekly,
  monthly,
  yearly,
}