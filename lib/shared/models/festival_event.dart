import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Festival event model for Gujarat temples
class FestivalEvent {
  final String id;
  final String templeId;
  final String name;
  final String nameGujarati;
  final String nameHindi;
  final String description;
  final String descriptionGujarati;
  final String descriptionHindi;
  final DateTime eventDate;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final String festivalType; // 'religious', 'cultural', 'seasonal'
  final bool acceptsBookings;
  final int maxCapacity;
  final int currentBookings;
  final double? bookingFee;
  final List<String> images;
  final Map<String, String> timings;
  final List<String> specialInstructions;
  final List<String> specialInstructionsGujarati;
  final List<String> specialInstructionsHindi;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic>? metadata;

  const FestivalEvent({
    required this.id,
    required this.templeId,
    required this.name,
    required this.nameGujarati,
    required this.nameHindi,
    required this.description,
    required this.descriptionGujarati,
    required this.descriptionHindi,
    required this.eventDate,
    required this.startTime,
    required this.endTime,
    required this.festivalType,
    this.acceptsBookings = true,
    this.maxCapacity = 100,
    this.currentBookings = 0,
    this.bookingFee,
    this.images = const [],
    this.timings = const {},
    this.specialInstructions = const [],
    this.specialInstructionsGujarati = const [],
    this.specialInstructionsHindi = const [],
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.metadata,
  });

  /// Create FestivalEvent from Firestore document
  factory FestivalEvent.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return FestivalEvent.fromJson({...data, 'id': doc.id});
  }

  /// Create FestivalEvent from JSON
  factory FestivalEvent.fromJson(Map<String, dynamic> json) {
    return FestivalEvent(
      id: json['id'] as String,
      templeId: json['templeId'] as String,
      name: json['name'] as String,
      nameGujarati: json['nameGujarati'] as String? ?? '',
      nameHindi: json['nameHindi'] as String? ?? '',
      description: json['description'] as String,
      descriptionGujarati: json['descriptionGujarati'] as String? ?? '',
      descriptionHindi: json['descriptionHindi'] as String? ?? '',
      eventDate: json['eventDate'] != null
          ? (json['eventDate'] as Timestamp).toDate()
          : DateTime.now(),
      startTime: _timeOfDayFromString(json['startTime'] as String? ?? '09:00'),
      endTime: _timeOfDayFromString(json['endTime'] as String? ?? '18:00'),
      festivalType: json['festivalType'] as String? ?? 'religious',
      acceptsBookings: json['acceptsBookings'] as bool? ?? true,
      maxCapacity: json['maxCapacity'] as int? ?? 100,
      currentBookings: json['currentBookings'] as int? ?? 0,
      bookingFee: json['bookingFee'] != null
          ? (json['bookingFee'] as num).toDouble()
          : null,
      images: json['images'] != null
          ? List<String>.from(json['images'] as List)
          : [],
      timings: json['timings'] != null
          ? Map<String, String>.from(json['timings'] as Map)
          : {},
      specialInstructions: json['specialInstructions'] != null
          ? List<String>.from(json['specialInstructions'] as List)
          : [],
      specialInstructionsGujarati: json['specialInstructionsGujarati'] != null
          ? List<String>.from(json['specialInstructionsGujarati'] as List)
          : [],
      specialInstructionsHindi: json['specialInstructionsHindi'] != null
          ? List<String>.from(json['specialInstructionsHindi'] as List)
          : [],
      isActive: json['isActive'] as bool? ?? true,
      createdAt: json['createdAt'] != null
          ? (json['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? (json['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
      metadata: json['metadata'] != null
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : null,
    );
  }

  /// Convert FestivalEvent to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'templeId': templeId,
      'name': name,
      'nameGujarati': nameGujarati,
      'nameHindi': nameHindi,
      'description': description,
      'descriptionGujarati': descriptionGujarati,
      'descriptionHindi': descriptionHindi,
      'eventDate': Timestamp.fromDate(eventDate),
      'startTime': _timeOfDayToString(startTime),
      'endTime': _timeOfDayToString(endTime),
      'festivalType': festivalType,
      'acceptsBookings': acceptsBookings,
      'maxCapacity': maxCapacity,
      'currentBookings': currentBookings,
      if (bookingFee != null) 'bookingFee': bookingFee,
      'images': images,
      'timings': timings,
      'specialInstructions': specialInstructions,
      'specialInstructionsGujarati': specialInstructionsGujarati,
      'specialInstructionsHindi': specialInstructionsHindi,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      if (metadata != null) 'metadata': metadata,
    };
  }

  /// Helper method to convert TimeOfDay to string
  static String _timeOfDayToString(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  /// Helper method to convert string to TimeOfDay
  static TimeOfDay _timeOfDayFromString(String timeString) {
    final parts = timeString.split(':');
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 9,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
    );
  }

  /// Create a copy with updated fields
  FestivalEvent copyWith({
    String? id,
    String? templeId,
    String? name,
    String? nameGujarati,
    String? nameHindi,
    String? description,
    String? descriptionGujarati,
    String? descriptionHindi,
    DateTime? eventDate,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    String? festivalType,
    bool? acceptsBookings,
    int? maxCapacity,
    int? currentBookings,
    double? bookingFee,
    List<String>? images,
    Map<String, String>? timings,
    List<String>? specialInstructions,
    List<String>? specialInstructionsGujarati,
    List<String>? specialInstructionsHindi,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
  }) {
    return FestivalEvent(
      id: id ?? this.id,
      templeId: templeId ?? this.templeId,
      name: name ?? this.name,
      nameGujarati: nameGujarati ?? this.nameGujarati,
      nameHindi: nameHindi ?? this.nameHindi,
      description: description ?? this.description,
      descriptionGujarati: descriptionGujarati ?? this.descriptionGujarati,
      descriptionHindi: descriptionHindi ?? this.descriptionHindi,
      eventDate: eventDate ?? this.eventDate,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      festivalType: festivalType ?? this.festivalType,
      acceptsBookings: acceptsBookings ?? this.acceptsBookings,
      maxCapacity: maxCapacity ?? this.maxCapacity,
      currentBookings: currentBookings ?? this.currentBookings,
      bookingFee: bookingFee ?? this.bookingFee,
      images: images ?? this.images,
      timings: timings ?? this.timings,
      specialInstructions: specialInstructions ?? this.specialInstructions,
      specialInstructionsGujarati:
          specialInstructionsGujarati ?? this.specialInstructionsGujarati,
      specialInstructionsHindi:
          specialInstructionsHindi ?? this.specialInstructionsHindi,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      metadata: metadata ?? this.metadata,
    );
  }

  /// Get event date and time as DateTime
  DateTime get eventDateTime {
    return DateTime(
      eventDate.year,
      eventDate.month,
      eventDate.day,
      startTime.hour,
      startTime.minute,
    );
  }

  /// Get event end date and time as DateTime
  DateTime get eventEndDateTime {
    return DateTime(
      eventDate.year,
      eventDate.month,
      eventDate.day,
      endTime.hour,
      endTime.minute,
    );
  }

  /// Check if event is in the future
  bool get isFuture => eventDateTime.isAfter(DateTime.now());

  /// Check if event is in the past
  bool get isPast => eventEndDateTime.isBefore(DateTime.now());

  /// Check if event is currently happening
  bool get isHappening {
    final now = DateTime.now();
    return now.isAfter(eventDateTime) && now.isBefore(eventEndDateTime);
  }

  /// Check if event is today
  bool get isToday {
    final now = DateTime.now();
    return eventDate.year == now.year &&
        eventDate.month == now.month &&
        eventDate.day == now.day;
  }

  /// Check if event has available capacity
  bool get hasAvailableCapacity => currentBookings < maxCapacity;

  /// Get remaining capacity
  int get remainingCapacity => maxCapacity - currentBookings;

  /// Get capacity percentage
  double get capacityPercentage =>
      maxCapacity > 0 ? (currentBookings / maxCapacity) * 100 : 0;

  /// Check if event can be booked
  bool get canBeBooked =>
      acceptsBookings && isActive && isFuture && hasAvailableCapacity;

  /// Get festival type display name
  String get festivalTypeDisplayName {
    switch (festivalType) {
      case 'religious':
        return 'Religious Festival';
      case 'cultural':
        return 'Cultural Event';
      case 'seasonal':
        return 'Seasonal Celebration';
      default:
        return festivalType;
    }
  }

  /// Get formatted event time
  String get formattedTime {
    final startHour = startTime.hourOfPeriod;
    final startMinute = startTime.minute.toString().padLeft(2, '0');
    final startPeriod = startTime.period == DayPeriod.am ? 'AM' : 'PM';

    final endHour = endTime.hourOfPeriod;
    final endMinute = endTime.minute.toString().padLeft(2, '0');
    final endPeriod = endTime.period == DayPeriod.am ? 'AM' : 'PM';

    return '$startHour:$startMinute $startPeriod - $endHour:$endMinute $endPeriod';
  }

  /// Get formatted event date
  String get formattedDate {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${eventDate.day} ${months[eventDate.month - 1]} ${eventDate.year}';
  }

  /// Get formatted event date and time
  String get formattedDateTime {
    return '$formattedDate at $formattedTime';
  }

  /// Get time until event
  Duration? get timeUntilEvent {
    if (isPast) return null;
    return eventDateTime.difference(DateTime.now());
  }

  /// Get formatted time until event
  String? get formattedTimeUntilEvent {
    final duration = timeUntilEvent;
    if (duration == null) return null;

    if (duration.inDays > 0) {
      return '${duration.inDays} ${duration.inDays == 1 ? 'day' : 'days'}';
    } else if (duration.inHours > 0) {
      return '${duration.inHours} ${duration.inHours == 1 ? 'hour' : 'hours'}';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes} ${duration.inMinutes == 1 ? 'minute' : 'minutes'}';
    } else {
      return 'Starting soon';
    }
  }

  /// Validate festival event data
  bool isValid() {
    return id.isNotEmpty &&
        templeId.isNotEmpty &&
        name.isNotEmpty &&
        description.isNotEmpty &&
        maxCapacity > 0 &&
        currentBookings >= 0 &&
        currentBookings <= maxCapacity &&
        eventDate.isAfter(DateTime.now().subtract(const Duration(days: 1)));
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FestivalEvent &&
        other.id == id &&
        other.templeId == templeId &&
        other.name == name &&
        other.eventDate == eventDate &&
        other.startTime == startTime &&
        other.endTime == endTime;
  }

  @override
  int get hashCode {
    return Object.hash(id, templeId, name, eventDate, startTime, endTime);
  }

  @override
  String toString() {
    return 'FestivalEvent(id: $id, name: $name, date: $formattedDateTime, '
        'capacity: $currentBookings/$maxCapacity)';
  }
}
