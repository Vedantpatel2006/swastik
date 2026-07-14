import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Enum for different notification types
enum NotificationType {
  templeUpdate('temple_update'),
  eventReminder('event_reminder'),
  bookingConfirmation('booking_confirmation'),
  bookingReminder('booking_reminder'),
  bookingCancellation('booking_cancellation'),
  donationConfirmation('donation_confirmation'),
  liveStreamStarted('live_stream_started'),
  communityUpdate('community_update'),
  systemUpdate('system_update'),
  general('general');

  const NotificationType(this.value);
  final String value;

  static NotificationType fromString(String value) {
    return NotificationType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => NotificationType.general,
    );
  }

  static NotificationType fromValue(String value) {
    return fromString(value);
  }
}

/// Enum for festival notification types
enum FestivalNotificationType { upcoming, started, reminder }

/// Enum for emergency notification types
enum EmergencyNotificationType { templeClosure, scheduleChange, specialEvent }

/// Enum for notification priority levels
enum NotificationPriority {
  low('low'),
  normal('normal'),
  high('high'),
  urgent('urgent');

  const NotificationPriority(this.value);
  final String value;

  static NotificationPriority fromString(String value) {
    return NotificationPriority.values.firstWhere(
      (priority) => priority.value == value,
      orElse: () => NotificationPriority.normal,
    );
  }

  static NotificationPriority fromValue(String value) {
    return fromString(value);
  }
}

/// User notification model for the temple management app
class UserNotification {
  final String id;
  final String userId;
  final String title;
  final String message;
  final NotificationType type;
  final NotificationPriority priority;
  final String? relatedId; // temple, event, or booking ID
  final String? relatedType; // 'temple', 'event', 'booking', etc.
  final DateTime createdAt;
  final bool isRead;
  final DateTime? readAt;
  final Map<String, dynamic>? actionData; // Data for deep linking
  final String? imageUrl;
  final String? category; // For grouping notifications

  const UserNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    this.priority = NotificationPriority.normal,
    this.relatedId,
    this.relatedType,
    required this.createdAt,
    this.isRead = false,
    this.readAt,
    this.actionData,
    this.imageUrl,
    this.category,
  });

  /// Create UserNotification from Firestore document
  factory UserNotification.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    return UserNotification(
      id: doc.id,
      userId: data['userId'] as String,
      title: data['title'] as String,
      message: data['message'] as String,
      type: NotificationType.fromString(data['type'] as String? ?? 'general'),
      priority: NotificationPriority.fromString(
        data['priority'] as String? ?? 'normal',
      ),
      relatedId: data['relatedId'] as String?,
      relatedType: data['relatedType'] as String?,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      isRead: data['isRead'] as bool? ?? false,
      readAt: data['readAt'] != null
          ? (data['readAt'] as Timestamp).toDate()
          : null,
      actionData: data['actionData'] as Map<String, dynamic>?,
      imageUrl: data['imageUrl'] as String?,
      category: data['category'] as String?,
    );
  }

  /// Convert UserNotification to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'title': title,
      'message': message,
      'type': type.value,
      'priority': priority.value,
      'relatedId': relatedId,
      'relatedType': relatedType,
      'createdAt': Timestamp.fromDate(createdAt),
      'isRead': isRead,
      'readAt': readAt != null ? Timestamp.fromDate(readAt!) : null,
      'actionData': actionData,
      'imageUrl': imageUrl,
      'category': category,
    };
  }

  /// Create a copy with updated fields
  UserNotification copyWith({
    String? id,
    String? userId,
    String? title,
    String? message,
    NotificationType? type,
    NotificationPriority? priority,
    String? relatedId,
    String? relatedType,
    DateTime? createdAt,
    bool? isRead,
    DateTime? readAt,
    Map<String, dynamic>? actionData,
    String? imageUrl,
    String? category,
  }) {
    return UserNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      priority: priority ?? this.priority,
      relatedId: relatedId ?? this.relatedId,
      relatedType: relatedType ?? this.relatedType,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      actionData: actionData ?? this.actionData,
      imageUrl: imageUrl ?? this.imageUrl,
      category: category ?? this.category,
    );
  }

  /// Get notification icon based on type
  IconData get icon {
    switch (type) {
      case NotificationType.templeUpdate:
        return Icons.temple_hindu;
      case NotificationType.eventReminder:
        return Icons.event;
      case NotificationType.bookingConfirmation:
      case NotificationType.bookingReminder:
      case NotificationType.bookingCancellation:
        return Icons.book_online;
      case NotificationType.donationConfirmation:
        return Icons.volunteer_activism;
      case NotificationType.liveStreamStarted:
        return Icons.live_tv;
      case NotificationType.communityUpdate:
        return Icons.people;
      case NotificationType.systemUpdate:
        return Icons.system_update;
      case NotificationType.general:
        return Icons.notifications;
    }
  }

  /// Get notification color based on priority
  Color get priorityColor {
    switch (priority) {
      case NotificationPriority.urgent:
        return Colors.red;
      case NotificationPriority.high:
        return Colors.orange;
      case NotificationPriority.normal:
        return Colors.orange;
      case NotificationPriority.low:
        return Colors.grey;
    }
  }

  /// Get formatted time ago string
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  /// Check if notification is recent (within 24 hours)
  bool get isRecent {
    final now = DateTime.now();
    final difference = now.difference(createdAt);
    return difference.inHours < 24;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserNotification && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'UserNotification(id: $id, title: $title, type: $type, isRead: $isRead)';
  }
}

/// Notification preferences model
class NotificationPreferences {
  final String userId;
  final bool enablePushNotifications;
  final bool enableTempleUpdates;
  final bool enableEventReminders;
  final bool enableBookingReminders;
  final bool enableDonationConfirmations;
  final bool enableLiveStreamNotifications;
  final bool enableCommunityUpdates;
  final bool enableSystemUpdates;
  final bool enableSoundNotifications;
  final bool enableVibrationNotifications;
  final String quietHoursStart; // Format: "22:00"
  final String quietHoursEnd; // Format: "08:00"
  final bool enableQuietHours;

  // Regional customization preferences
  final bool enableFestivalNotifications;
  final bool enableLocationNotifications;
  final bool enableEmergencyNotifications;
  final bool enableCulturalEventNotifications;
  final String preferredLanguage; // 'en', 'hi', 'gu'
  final List<String> interestedDistricts; // Gujarat districts
  final List<String> culturalEventCategories; // Festival types, etc.
  final double locationRadiusKm; // For location-based notifications
  final bool enableHolidayNotifications;

  final DateTime updatedAt;

  const NotificationPreferences({
    required this.userId,
    this.enablePushNotifications = true,
    this.enableTempleUpdates = true,
    this.enableEventReminders = true,
    this.enableBookingReminders = true,
    this.enableDonationConfirmations = true,
    this.enableLiveStreamNotifications = true,
    this.enableCommunityUpdates = true,
    this.enableSystemUpdates = true,
    this.enableSoundNotifications = true,
    this.enableVibrationNotifications = true,
    this.quietHoursStart = "22:00",
    this.quietHoursEnd = "08:00",
    this.enableQuietHours = false,

    // Regional customization defaults
    this.enableFestivalNotifications = true,
    this.enableLocationNotifications = true,
    this.enableEmergencyNotifications = true,
    this.enableCulturalEventNotifications = true,
    this.preferredLanguage = 'en',
    this.interestedDistricts = const [],
    this.culturalEventCategories = const [],
    this.locationRadiusKm = 10.0,
    this.enableHolidayNotifications = true,

    required this.updatedAt,
  });

  /// Create NotificationPreferences from Firestore document
  factory NotificationPreferences.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    return NotificationPreferences(
      userId: data['userId'] as String,
      enablePushNotifications: data['enablePushNotifications'] as bool? ?? true,
      enableTempleUpdates: data['enableTempleUpdates'] as bool? ?? true,
      enableEventReminders: data['enableEventReminders'] as bool? ?? true,
      enableBookingReminders: data['enableBookingReminders'] as bool? ?? true,
      enableDonationConfirmations:
          data['enableDonationConfirmations'] as bool? ?? true,
      enableLiveStreamNotifications:
          data['enableLiveStreamNotifications'] as bool? ?? true,
      enableCommunityUpdates: data['enableCommunityUpdates'] as bool? ?? true,
      enableSystemUpdates: data['enableSystemUpdates'] as bool? ?? true,
      enableSoundNotifications:
          data['enableSoundNotifications'] as bool? ?? true,
      enableVibrationNotifications:
          data['enableVibrationNotifications'] as bool? ?? true,
      quietHoursStart: data['quietHoursStart'] as String? ?? "22:00",
      quietHoursEnd: data['quietHoursEnd'] as String? ?? "08:00",
      enableQuietHours: data['enableQuietHours'] as bool? ?? false,

      // Regional customization fields
      enableFestivalNotifications:
          data['enableFestivalNotifications'] as bool? ?? true,
      enableLocationNotifications:
          data['enableLocationNotifications'] as bool? ?? true,
      enableEmergencyNotifications:
          data['enableEmergencyNotifications'] as bool? ?? true,
      enableCulturalEventNotifications:
          data['enableCulturalEventNotifications'] as bool? ?? true,
      preferredLanguage: data['preferredLanguage'] as String? ?? 'en',
      interestedDistricts: data['interestedDistricts'] != null
          ? List<String>.from(data['interestedDistricts'] as List)
          : [],
      culturalEventCategories: data['culturalEventCategories'] != null
          ? List<String>.from(data['culturalEventCategories'] as List)
          : [],
      locationRadiusKm: (data['locationRadiusKm'] as num?)?.toDouble() ?? 10.0,
      enableHolidayNotifications:
          data['enableHolidayNotifications'] as bool? ?? true,

      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  /// Convert NotificationPreferences to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'enablePushNotifications': enablePushNotifications,
      'enableTempleUpdates': enableTempleUpdates,
      'enableEventReminders': enableEventReminders,
      'enableBookingReminders': enableBookingReminders,
      'enableDonationConfirmations': enableDonationConfirmations,
      'enableLiveStreamNotifications': enableLiveStreamNotifications,
      'enableCommunityUpdates': enableCommunityUpdates,
      'enableSystemUpdates': enableSystemUpdates,
      'enableSoundNotifications': enableSoundNotifications,
      'enableVibrationNotifications': enableVibrationNotifications,
      'quietHoursStart': quietHoursStart,
      'quietHoursEnd': quietHoursEnd,
      'enableQuietHours': enableQuietHours,

      // Regional customization fields
      'enableFestivalNotifications': enableFestivalNotifications,
      'enableLocationNotifications': enableLocationNotifications,
      'enableEmergencyNotifications': enableEmergencyNotifications,
      'enableCulturalEventNotifications': enableCulturalEventNotifications,
      'preferredLanguage': preferredLanguage,
      'interestedDistricts': interestedDistricts,
      'culturalEventCategories': culturalEventCategories,
      'locationRadiusKm': locationRadiusKm,
      'enableHolidayNotifications': enableHolidayNotifications,

      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Create a copy with updated fields
  NotificationPreferences copyWith({
    String? userId,
    bool? enablePushNotifications,
    bool? enableTempleUpdates,
    bool? enableEventReminders,
    bool? enableBookingReminders,
    bool? enableDonationConfirmations,
    bool? enableLiveStreamNotifications,
    bool? enableCommunityUpdates,
    bool? enableSystemUpdates,
    bool? enableSoundNotifications,
    bool? enableVibrationNotifications,
    String? quietHoursStart,
    String? quietHoursEnd,
    bool? enableQuietHours,

    // Regional customization parameters
    bool? enableFestivalNotifications,
    bool? enableLocationNotifications,
    bool? enableEmergencyNotifications,
    bool? enableCulturalEventNotifications,
    String? preferredLanguage,
    List<String>? interestedDistricts,
    List<String>? culturalEventCategories,
    double? locationRadiusKm,
    bool? enableHolidayNotifications,

    DateTime? updatedAt,
  }) {
    return NotificationPreferences(
      userId: userId ?? this.userId,
      enablePushNotifications:
          enablePushNotifications ?? this.enablePushNotifications,
      enableTempleUpdates: enableTempleUpdates ?? this.enableTempleUpdates,
      enableEventReminders: enableEventReminders ?? this.enableEventReminders,
      enableBookingReminders:
          enableBookingReminders ?? this.enableBookingReminders,
      enableDonationConfirmations:
          enableDonationConfirmations ?? this.enableDonationConfirmations,
      enableLiveStreamNotifications:
          enableLiveStreamNotifications ?? this.enableLiveStreamNotifications,
      enableCommunityUpdates:
          enableCommunityUpdates ?? this.enableCommunityUpdates,
      enableSystemUpdates: enableSystemUpdates ?? this.enableSystemUpdates,
      enableSoundNotifications:
          enableSoundNotifications ?? this.enableSoundNotifications,
      enableVibrationNotifications:
          enableVibrationNotifications ?? this.enableVibrationNotifications,
      quietHoursStart: quietHoursStart ?? this.quietHoursStart,
      quietHoursEnd: quietHoursEnd ?? this.quietHoursEnd,
      enableQuietHours: enableQuietHours ?? this.enableQuietHours,

      // Regional customization fields
      enableFestivalNotifications:
          enableFestivalNotifications ?? this.enableFestivalNotifications,
      enableLocationNotifications:
          enableLocationNotifications ?? this.enableLocationNotifications,
      enableEmergencyNotifications:
          enableEmergencyNotifications ?? this.enableEmergencyNotifications,
      enableCulturalEventNotifications:
          enableCulturalEventNotifications ??
          this.enableCulturalEventNotifications,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      interestedDistricts: interestedDistricts ?? this.interestedDistricts,
      culturalEventCategories:
          culturalEventCategories ?? this.culturalEventCategories,
      locationRadiusKm: locationRadiusKm ?? this.locationRadiusKm,
      enableHolidayNotifications:
          enableHolidayNotifications ?? this.enableHolidayNotifications,

      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Check if notifications should be sent based on preferences and type
  bool shouldSendNotification(NotificationType type) {
    if (!enablePushNotifications) return false;

    switch (type) {
      case NotificationType.templeUpdate:
        return enableTempleUpdates;
      case NotificationType.eventReminder:
        return enableEventReminders;
      case NotificationType.bookingConfirmation:
      case NotificationType.bookingReminder:
      case NotificationType.bookingCancellation:
        return enableBookingReminders;
      case NotificationType.donationConfirmation:
        return enableDonationConfirmations;
      case NotificationType.liveStreamStarted:
        return enableLiveStreamNotifications;
      case NotificationType.communityUpdate:
        return enableCommunityUpdates;
      case NotificationType.systemUpdate:
        return enableSystemUpdates;
      case NotificationType.general:
        return true; // General notifications are always sent if push is enabled
    }
  }

  /// Check if festival notifications should be sent
  bool get shouldSendFestivalNotifications =>
      enablePushNotifications && enableFestivalNotifications;

  /// Check if location-based notifications should be sent
  bool get shouldSendLocationNotifications =>
      enablePushNotifications && enableLocationNotifications;

  /// Check if emergency notifications should be sent
  bool get shouldSendEmergencyNotifications =>
      enablePushNotifications && enableEmergencyNotifications;

  /// Check if cultural event notifications should be sent
  bool get shouldSendCulturalEventNotifications =>
      enablePushNotifications && enableCulturalEventNotifications;

  /// Check if holiday notifications should be sent
  bool get shouldSendHolidayNotifications =>
      enablePushNotifications && enableHolidayNotifications;

  /// Check if current time is within quiet hours
  bool get isInQuietHours {
    if (!enableQuietHours) return false;

    final now = DateTime.now();
    final currentTime =
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

    // Handle quiet hours that span midnight
    if (quietHoursStart.compareTo(quietHoursEnd) > 0) {
      return currentTime.compareTo(quietHoursStart) >= 0 ||
          currentTime.compareTo(quietHoursEnd) <= 0;
    } else {
      return currentTime.compareTo(quietHoursStart) >= 0 &&
          currentTime.compareTo(quietHoursEnd) <= 0;
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NotificationPreferences && other.userId == userId;
  }

  @override
  int get hashCode => userId.hashCode;

  @override
  String toString() {
    return 'NotificationPreferences(userId: $userId, enablePushNotifications: $enablePushNotifications)';
  }
}
