import 'package:cloud_firestore/cloud_firestore.dart';

/// Enum for different types of notifications
enum NotificationType { festival, event, emergency, location, general }

/// Enum for notification priority levels
enum NotificationPriority { low, normal, high, urgent }

/// Enum for cultural event categories
enum CulturalEventCategory {
  festival,
  puja,
  aarti,
  bhajan,
  katha,
  yatra,
  donation,
  special,
  event,
  general,
}

/// Model for notification data
class NotificationData {
  final String id;
  final String title;
  final String message;
  final NotificationType type;
  final NotificationPriority priority;
  final CulturalEventCategory? category;
  final Map<String, dynamic> data;
  final DateTime scheduledTime;
  final DateTime? sentTime;
  final List<String> targetLanguages;
  final List<String> targetDistricts;
  final String? templeId;
  final String? templeName;
  final bool isLocationBased;
  final double? latitude;
  final double? longitude;
  final double? radiusKm;
  final bool isSent;
  final DateTime createdAt;
  final DateTime updatedAt;

  const NotificationData({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    this.priority = NotificationPriority.normal,
    this.category,
    this.data = const {},
    required this.scheduledTime,
    this.sentTime,
    this.targetLanguages = const ['en', 'hi', 'gu'],
    this.targetDistricts = const [],
    this.templeId,
    this.templeName,
    this.isLocationBased = false,
    this.latitude,
    this.longitude,
    this.radiusKm,
    this.isSent = false,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create from Firestore document
  factory NotificationData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return NotificationData(
      id: doc.id,
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      type: NotificationType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => NotificationType.general,
      ),
      priority: NotificationPriority.values.firstWhere(
        (e) => e.name == data['priority'],
        orElse: () => NotificationPriority.normal,
      ),
      category: data['category'] != null
          ? CulturalEventCategory.values.firstWhere(
              (e) => e.name == data['category'],
              orElse: () => CulturalEventCategory.general,
            )
          : null,
      data: Map<String, dynamic>.from(data['data'] ?? {}),
      scheduledTime: (data['scheduledTime'] as Timestamp).toDate(),
      sentTime: data['sentTime'] != null
          ? (data['sentTime'] as Timestamp).toDate()
          : null,
      targetLanguages: List<String>.from(data['targetLanguages'] ?? ['en']),
      targetDistricts: List<String>.from(data['targetDistricts'] ?? []),
      templeId: data['templeId'],
      templeName: data['templeName'],
      isLocationBased: data['isLocationBased'] ?? false,
      latitude: data['latitude']?.toDouble(),
      longitude: data['longitude']?.toDouble(),
      radiusKm: data['radiusKm']?.toDouble(),
      isSent: data['isSent'] ?? false,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'message': message,
      'type': type.name,
      'priority': priority.name,
      'category': category?.name,
      'data': data,
      'scheduledTime': Timestamp.fromDate(scheduledTime),
      'sentTime': sentTime != null ? Timestamp.fromDate(sentTime!) : null,
      'targetLanguages': targetLanguages,
      'targetDistricts': targetDistricts,
      'templeId': templeId,
      'templeName': templeName,
      'isLocationBased': isLocationBased,
      'latitude': latitude,
      'longitude': longitude,
      'radiusKm': radiusKm,
      'isSent': isSent,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Create a copy with updated fields
  NotificationData copyWith({
    String? title,
    String? message,
    NotificationType? type,
    NotificationPriority? priority,
    CulturalEventCategory? category,
    Map<String, dynamic>? data,
    DateTime? scheduledTime,
    DateTime? sentTime,
    List<String>? targetLanguages,
    List<String>? targetDistricts,
    String? templeId,
    String? templeName,
    bool? isLocationBased,
    double? latitude,
    double? longitude,
    double? radiusKm,
    bool? isSent,
    DateTime? updatedAt,
  }) {
    return NotificationData(
      id: id,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      priority: priority ?? this.priority,
      category: category ?? this.category,
      data: data ?? this.data,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      sentTime: sentTime ?? this.sentTime,
      targetLanguages: targetLanguages ?? this.targetLanguages,
      targetDistricts: targetDistricts ?? this.targetDistricts,
      templeId: templeId ?? this.templeId,
      templeName: templeName ?? this.templeName,
      isLocationBased: isLocationBased ?? this.isLocationBased,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radiusKm: radiusKm ?? this.radiusKm,
      isSent: isSent ?? this.isSent,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}

/// Model for user notification preferences
class NotificationPreferences {
  final String userId;
  final bool enableNotifications;
  final bool enableFestivalNotifications;
  final bool enableEventNotifications;
  final bool enableEmergencyNotifications;
  final bool enableLocationNotifications;
  final List<CulturalEventCategory> enabledCategories;
  final List<String> preferredLanguages;
  final List<String> preferredDistricts;
  final double locationRadiusKm;
  final bool enableSound;
  final bool enableVibration;
  final String quietHoursStart;
  final String quietHoursEnd;
  final DateTime createdAt;
  final DateTime updatedAt;

  const NotificationPreferences({
    required this.userId,
    this.enableNotifications = true,
    this.enableFestivalNotifications = true,
    this.enableEventNotifications = true,
    this.enableEmergencyNotifications = true,
    this.enableLocationNotifications = true,
    this.enabledCategories = const [],
    this.preferredLanguages = const ['en'],
    this.preferredDistricts = const [],
    this.locationRadiusKm = 10.0,
    this.enableSound = true,
    this.enableVibration = true,
    this.quietHoursStart = '22:00',
    this.quietHoursEnd = '07:00',
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create from Firestore document
  factory NotificationPreferences.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return NotificationPreferences(
      userId: doc.id,
      enableNotifications: data['enableNotifications'] ?? true,
      enableFestivalNotifications: data['enableFestivalNotifications'] ?? true,
      enableEventNotifications: data['enableEventNotifications'] ?? true,
      enableEmergencyNotifications:
          data['enableEmergencyNotifications'] ?? true,
      enableLocationNotifications: data['enableLocationNotifications'] ?? true,
      enabledCategories:
          (data['enabledCategories'] as List<dynamic>?)
              ?.map(
                (e) => CulturalEventCategory.values.firstWhere(
                  (cat) => cat.name == e,
                  orElse: () => CulturalEventCategory.general,
                ),
              )
              .toList() ??
          [],
      preferredLanguages: List<String>.from(
        data['preferredLanguages'] ?? ['en'],
      ),
      preferredDistricts: List<String>.from(data['preferredDistricts'] ?? []),
      locationRadiusKm: (data['locationRadiusKm'] ?? 10.0).toDouble(),
      enableSound: data['enableSound'] ?? true,
      enableVibration: data['enableVibration'] ?? true,
      quietHoursStart: data['quietHoursStart'] ?? '22:00',
      quietHoursEnd: data['quietHoursEnd'] ?? '07:00',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'enableNotifications': enableNotifications,
      'enableFestivalNotifications': enableFestivalNotifications,
      'enableEventNotifications': enableEventNotifications,
      'enableEmergencyNotifications': enableEmergencyNotifications,
      'enableLocationNotifications': enableLocationNotifications,
      'enabledCategories': enabledCategories.map((e) => e.name).toList(),
      'preferredLanguages': preferredLanguages,
      'preferredDistricts': preferredDistricts,
      'locationRadiusKm': locationRadiusKm,
      'enableSound': enableSound,
      'enableVibration': enableVibration,
      'quietHoursStart': quietHoursStart,
      'quietHoursEnd': quietHoursEnd,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Create a copy with updated fields
  NotificationPreferences copyWith({
    bool? enableNotifications,
    bool? enableFestivalNotifications,
    bool? enableEventNotifications,
    bool? enableEmergencyNotifications,
    bool? enableLocationNotifications,
    List<CulturalEventCategory>? enabledCategories,
    List<String>? preferredLanguages,
    List<String>? preferredDistricts,
    double? locationRadiusKm,
    bool? enableSound,
    bool? enableVibration,
    String? quietHoursStart,
    String? quietHoursEnd,
    DateTime? updatedAt,
  }) {
    return NotificationPreferences(
      userId: userId,
      enableNotifications: enableNotifications ?? this.enableNotifications,
      enableFestivalNotifications:
          enableFestivalNotifications ?? this.enableFestivalNotifications,
      enableEventNotifications:
          enableEventNotifications ?? this.enableEventNotifications,
      enableEmergencyNotifications:
          enableEmergencyNotifications ?? this.enableEmergencyNotifications,
      enableLocationNotifications:
          enableLocationNotifications ?? this.enableLocationNotifications,
      enabledCategories: enabledCategories ?? this.enabledCategories,
      preferredLanguages: preferredLanguages ?? this.preferredLanguages,
      preferredDistricts: preferredDistricts ?? this.preferredDistricts,
      locationRadiusKm: locationRadiusKm ?? this.locationRadiusKm,
      enableSound: enableSound ?? this.enableSound,
      enableVibration: enableVibration ?? this.enableVibration,
      quietHoursStart: quietHoursStart ?? this.quietHoursStart,
      quietHoursEnd: quietHoursStart ?? this.quietHoursEnd,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}

/// Model for Gujarat festival calendar
class GujaratFestival {
  final String id;
  final String name;
  final String nameGujarati;
  final String nameHindi;
  final String description;
  final DateTime date;
  final int durationDays;
  final CulturalEventCategory category;
  final List<String> associatedTemples;
  final Map<String, dynamic> customData;
  final bool isRecurring;
  final String? recurrencePattern;

  const GujaratFestival({
    required this.id,
    required this.name,
    required this.nameGujarati,
    required this.nameHindi,
    required this.description,
    required this.date,
    this.durationDays = 1,
    this.category = CulturalEventCategory.festival,
    this.associatedTemples = const [],
    this.customData = const {},
    this.isRecurring = false,
    this.recurrencePattern,
  });

  /// Create from Firestore document
  factory GujaratFestival.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return GujaratFestival(
      id: doc.id,
      name: data['name'] ?? '',
      nameGujarati: data['nameGujarati'] ?? '',
      nameHindi: data['nameHindi'] ?? '',
      description: data['description'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      durationDays: data['durationDays'] ?? 1,
      category: CulturalEventCategory.values.firstWhere(
        (e) => e.name == data['category'],
        orElse: () => CulturalEventCategory.festival,
      ),
      associatedTemples: List<String>.from(data['associatedTemples'] ?? []),
      customData: Map<String, dynamic>.from(data['customData'] ?? {}),
      isRecurring: data['isRecurring'] ?? false,
      recurrencePattern: data['recurrencePattern'],
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'nameGujarati': nameGujarati,
      'nameHindi': nameHindi,
      'description': description,
      'date': Timestamp.fromDate(date),
      'durationDays': durationDays,
      'category': category.name,
      'associatedTemples': associatedTemples,
      'customData': customData,
      'isRecurring': isRecurring,
      'recurrencePattern': recurrencePattern,
    };
  }
}
