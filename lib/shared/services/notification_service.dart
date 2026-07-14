import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/localization_service.dart';
import '../models/notification.dart';
import '../models/temple.dart';

/// Service for managing user notifications with Firebase Cloud Messaging integration
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  FirebaseFirestore? _firestore;
  FirebaseAuth? _auth;
  SharedPreferences? _prefs;
  StreamSubscription<User?>? _authSubscription;
  String? _currentUserId;

  // Collections
  static const String _notificationsCollection = 'user_notifications';
  static const String _preferencesCollection = 'notification_preferences';
  static const String _queuedNotificationsCollection = 'queued_notifications';

  // Local storage keys
  static const String _badgeCountKey = 'notification_badge_count';

  /// Check if the service is properly initialized
  bool get _isInitialized =>
      _firestore != null && _auth != null && _prefs != null;

  /// Ensure the service is initialized before use
  void _ensureInitialized() {
    if (!_isInitialized) {
      throw StateError(
        'NotificationService not initialized. Call initialize() first.',
      );
    }
  }

  /// Initialize the notification service
  Future<void> initialize({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    SharedPreferences? prefs,
  }) async {
    _firestore = firestore ?? FirebaseFirestore.instance;
    _auth = auth ?? FirebaseAuth.instance;
    _prefs = prefs ?? await SharedPreferences.getInstance();

    // Listen to auth state changes
    _authSubscription = _auth!.authStateChanges().listen((user) {
      _currentUserId = user?.uid;
      if (user != null && user.emailVerified) {
        _initializeUserNotifications(user.uid);
      } else if (user != null && !user.emailVerified) {
        if (kDebugMode) {
          debugPrint(
            'NotificationService: User not verified, skipping notification initialization',
          );
        }
      }
    });

    if (kDebugMode) {
      debugPrint('NotificationService: Initialized');
    }
  }

  /// Initialize notifications for a specific user
  Future<void> _initializeUserNotifications(String userId) async {
    try {
      // Only initialize if user is authenticated and email is verified
      final currentUser = _auth?.currentUser;
      if (currentUser == null || !currentUser.emailVerified) {
        if (kDebugMode) {
          debugPrint(
            'NotificationService: Skipping initialization - user not verified',
          );
        }
        return;
      }

      // Create default notification preferences if they don't exist
      final prefsDoc = await _firestore!
          .collection(_preferencesCollection)
          .doc(userId)
          .get();

      if (!prefsDoc.exists) {
        final defaultPrefs = NotificationPreferences(
          userId: userId,
          updatedAt: DateTime.now(),
        );
        await _firestore!
            .collection(_preferencesCollection)
            .doc(userId)
            .set(defaultPrefs.toFirestore());
      }

      // Update badge count
      await _updateBadgeCount(userId);

      if (kDebugMode) {
        debugPrint('NotificationService: Initialized for user $userId');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'NotificationService: Error initializing user notifications - $e',
        );
      }
    }
  }

  /// Get current user ID
  String? get currentUserId => _currentUserId;

  /// Get user notifications stream (simplified query to avoid index requirement)
  Stream<List<UserNotification>> getUserNotifications(String userId) {
    _ensureInitialized();
    return _firestore!
        .collection(_notificationsCollection)
        .where('userId', isEqualTo: userId)
        .limit(100) // Increased limit to show more notifications
        .snapshots()
        .map(
          (snapshot) {
          final notifications = snapshot.docs
              .map((doc) => UserNotification.fromFirestore(doc))
              .toList();

          // Sort in memory instead of using Firestore orderBy
          notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));

          return notifications;
        },
        );
  }

  /// Get unread notifications count stream
  Stream<int> getUnreadCount(String userId) {
    _ensureInitialized();
    return _firestore!
        .collection(_notificationsCollection)
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Get notifications by category
  Stream<List<UserNotification>> getNotificationsByCategory(
    String userId,
    String category,
  ) {
    return _firestore!
        .collection(_notificationsCollection)
        .where('userId', isEqualTo: userId)
        .where('category', isEqualTo: category)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => UserNotification.fromFirestore(doc))
              .toList(),
        );
  }

  /// Get notifications by type
  Stream<List<UserNotification>> getNotificationsByType(
    String userId,
    NotificationType type,
  ) {
    return _firestore!
        .collection(_notificationsCollection)
        .where('userId', isEqualTo: userId)
        .where('type', isEqualTo: type.value)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => UserNotification.fromFirestore(doc))
              .toList(),
        );
  }

  /// Create a new notification
  Future<String> createNotification({
    required String userId,
    required String title,
    required String message,
    required NotificationType type,
    NotificationPriority priority = NotificationPriority.normal,
    String? relatedId,
    String? relatedType,
    Map<String, dynamic>? actionData,
    String? imageUrl,
    String? category,
  }) async {
    _ensureInitialized();
    try {
      // Check user preferences before creating notification
      final preferences = await getNotificationPreferences(userId);
      if (!preferences.shouldSendNotification(type)) {
        if (kDebugMode) {
          debugPrint(
            'NotificationService: Notification blocked by user preferences',
          );
        }
        return '';
      }

      // Check quiet hours for non-urgent notifications
      if (priority != NotificationPriority.urgent &&
          preferences.isInQuietHours) {
        if (kDebugMode) {
          debugPrint(
            'NotificationService: Notification delayed due to quiet hours',
          );
        }
        // Queue notification for later delivery
        return await _queueNotificationForQuietHours(
          userId: userId,
          title: title,
          message: message,
          type: type,
          priority: priority,
          relatedId: relatedId,
          relatedType: relatedType,
          actionData: actionData,
          imageUrl: imageUrl,
          category: category,
        );
      }

      final notification = UserNotification(
        id: '', // Will be set by Firestore
        userId: userId,
        title: title,
        message: message,
        type: type,
        priority: priority,
        relatedId: relatedId,
        relatedType: relatedType,
        createdAt: DateTime.now(),
        actionData: actionData,
        imageUrl: imageUrl,
        category: category,
      );

      final docRef = await _firestore!
          .collection(_notificationsCollection)
          .add(notification.toFirestore());

      // Update badge count
      await _updateBadgeCount(userId);

      // Send push notification if enabled
      if (preferences.enablePushNotifications) {
        await _sendPushNotification(notification, preferences);
      }

      if (kDebugMode) {
        debugPrint('NotificationService: Created notification ${docRef.id}');
      }

      return docRef.id;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('NotificationService: Error creating notification - $e');
      }
      rethrow;
    }
  }

  /// Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore!
          .collection(_notificationsCollection)
          .doc(notificationId)
          .update({'isRead': true, 'readAt': FieldValue.serverTimestamp()});

      // Update badge count if current user
      if (_currentUserId != null) {
        await _updateBadgeCount(_currentUserId!);
      }

      if (kDebugMode) {
        debugPrint(
          'NotificationService: Marked notification $notificationId as read',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'NotificationService: Error marking notification as read - $e',
        );
      }
      rethrow;
    }
  }

  /// Mark multiple notifications as read
  Future<void> markMultipleAsRead(List<String> notificationIds) async {
    try {
      final batch = _firestore!.batch();

      for (final id in notificationIds) {
        final docRef = _firestore!.collection(_notificationsCollection).doc(id);
        batch.update(docRef, {
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      // Update badge count if current user
      if (_currentUserId != null) {
        await _updateBadgeCount(_currentUserId!);
      }

      if (kDebugMode) {
        debugPrint(
          'NotificationService: Marked ${notificationIds.length} notifications as read',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'NotificationService: Error marking notifications as read - $e',
        );
      }
      rethrow;
    }
  }

  /// Mark all notifications as read for a user
  Future<void> markAllAsRead(String userId) async {
    try {
      final unreadNotifications = await _firestore!
          .collection(_notificationsCollection)
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      if (unreadNotifications.docs.isEmpty) return;

      final batch = _firestore!.batch();
      for (final doc in unreadNotifications.docs) {
        batch.update(doc.reference, {
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      await _updateBadgeCount(userId);

      if (kDebugMode) {
        debugPrint(
          'NotificationService: Marked all notifications as read for user $userId',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'NotificationService: Error marking all notifications as read - $e',
        );
      }
      rethrow;
    }
  }

  /// Delete notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _firestore!
          .collection(_notificationsCollection)
          .doc(notificationId)
          .delete();

      // Update badge count if current user
      if (_currentUserId != null) {
        await _updateBadgeCount(_currentUserId!);
      }

      if (kDebugMode) {
        debugPrint('NotificationService: Deleted notification $notificationId');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('NotificationService: Error deleting notification - $e');
      }
      rethrow;
    }
  }

  /// Clear all notifications for a user
  Future<void> clearAllNotifications(String userId) async {
    try {
      final notifications = await _firestore!
          .collection(_notificationsCollection)
          .where('userId', isEqualTo: userId)
          .get();

      if (notifications.docs.isEmpty) return;

      final batch = _firestore!.batch();
      for (final doc in notifications.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      await _updateBadgeCount(userId);

      if (kDebugMode) {
        debugPrint(
          'NotificationService: Cleared all notifications for user $userId',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('NotificationService: Error clearing notifications - $e');
      }
      rethrow;
    }
  }

  /// Get notification preferences for a user
  Future<NotificationPreferences> getNotificationPreferences(
    String userId,
  ) async {
    // Guard: return defaults if service hasn't been initialized yet
    if (_firestore == null) {
      return NotificationPreferences(userId: userId, updatedAt: DateTime.now());
    }
    try {
      final doc = await _firestore!
          .collection(_preferencesCollection)
          .doc(userId)
          .get();

      if (doc.exists) {
        return NotificationPreferences.fromFirestore(doc);
      } else {
        // Return default preferences
        return NotificationPreferences(
          userId: userId,
          updatedAt: DateTime.now(),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('NotificationService: Error getting preferences - $e');
      }
      // Return default preferences on error
      return NotificationPreferences(userId: userId, updatedAt: DateTime.now());
    }
  }

  /// Update notification preferences
  Future<void> updateNotificationPreferences(
    NotificationPreferences preferences,
  ) async {
    try {
      await _firestore!
          .collection(_preferencesCollection)
          .doc(preferences.userId)
          .set(preferences.toFirestore(), SetOptions(merge: true));

      if (kDebugMode) {
        debugPrint(
          'NotificationService: Updated preferences for user ${preferences.userId}',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('NotificationService: Error updating preferences - $e');
      }
      rethrow;
    }
  }

  /// Get notification preferences stream
  Stream<NotificationPreferences> watchNotificationPreferences(String userId) {
    return _firestore!
        .collection(_preferencesCollection)
        .doc(userId)
        .snapshots()
        .map((doc) {
          if (doc.exists) {
            return NotificationPreferences.fromFirestore(doc);
          } else {
            return NotificationPreferences(
              userId: userId,
              updatedAt: DateTime.now(),
            );
          }
        });
  }

  /// Schedule a reminder notification
  Future<String> scheduleReminder({
    required String userId,
    required String title,
    required String message,
    required DateTime scheduledTime,
    NotificationType type = NotificationType.general,
    String? relatedId,
    String? relatedType,
    Map<String, dynamic>? actionData,
  }) async {
    try {
      // For now, we'll create the notification immediately
      // In a production app, you'd use a cloud function or background service
      // to schedule notifications

      final notification = UserNotification(
        id: '', // Will be set by Firestore
        userId: userId,
        title: title,
        message: message,
        type: type,
        priority: NotificationPriority.normal,
        relatedId: relatedId,
        relatedType: relatedType,
        createdAt: scheduledTime,
        actionData: {
          ...?actionData,
          'isScheduled': true,
          'scheduledFor': scheduledTime.toIso8601String(),
        },
      );

      final docRef = await _firestore!
          .collection(_notificationsCollection)
          .add(notification.toFirestore());

      if (kDebugMode) {
        debugPrint(
          'NotificationService: Scheduled reminder ${docRef.id} for $scheduledTime',
        );
      }

      return docRef.id;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('NotificationService: Error scheduling reminder - $e');
      }
      rethrow;
    }
  }

  /// Update badge count
  Future<void> _updateBadgeCount(String userId) async {
    try {
      final unreadCount = await _firestore!
          .collection(_notificationsCollection)
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get()
          .then((snapshot) => snapshot.docs.length);

      await _prefs!.setInt(_badgeCountKey, unreadCount);

      if (kDebugMode) {
        debugPrint('NotificationService: Updated badge count to $unreadCount');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('NotificationService: Error updating badge count - $e');
      }
    }
  }

  /// Get current badge count
  int getBadgeCount() {
    return _prefs?.getInt(_badgeCountKey) ?? 0;
  }

  /// Send push notification via Firebase Cloud Messaging
  /// DEPRECATED: Push notifications now handled by Supabase Edge Functions
  /// Use SupabaseNotificationService instead
  Future<void> _sendPushNotification(
    UserNotification notification,
    NotificationPreferences preferences,
  ) async {
    try {
      if (kDebugMode) {
        debugPrint(
          'NotificationService: Deprecated Firebase service - use SupabaseNotificationService',
        );
      }
      // Push notifications are now handled by Supabase
      return;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('NotificationService: Error in deprecated service - $e');
      }
    }
  }

  /// Handle notification tap (deep linking)
  Future<void> handleNotificationTap(UserNotification notification) async {
    try {
      // Mark as read
      await markAsRead(notification.id);

      // Handle deep linking based on notification type and action data
      if (notification.actionData != null) {
        final actionData = notification.actionData!;

        // This would integrate with your navigation system
        if (kDebugMode) {
          debugPrint('NotificationService: Handling notification tap:');
          debugPrint('  Type: ${notification.type.value}');
          debugPrint('  Related ID: ${notification.relatedId}');
          debugPrint('  Action Data: $actionData');
        }

        // Example deep linking logic:
        switch (notification.type) {
          case NotificationType.templeUpdate:
            // Navigate to temple detail screen
            break;
          case NotificationType.eventReminder:
            // Navigate to event detail screen
            break;
          case NotificationType.bookingConfirmation:
          case NotificationType.bookingReminder:
            // Navigate to booking detail screen
            break;
          case NotificationType.liveStreamStarted:
            // Navigate to live darshan screen
            break;
          default:
            // Handle general navigation
            break;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('NotificationService: Error handling notification tap - $e');
      }
    }
  }

  /// Clean up old notifications (older than 30 days)
  Future<void> cleanupOldNotifications(String userId) async {
    try {
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      final oldNotifications = await _firestore!
          .collection(_notificationsCollection)
          .where('userId', isEqualTo: userId)
          .where('createdAt', isLessThan: Timestamp.fromDate(thirtyDaysAgo))
          .get();

      if (oldNotifications.docs.isEmpty) return;

      final batch = _firestore!.batch();
      for (final doc in oldNotifications.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();

      if (kDebugMode) {
        debugPrint(
          'NotificationService: Cleaned up ${oldNotifications.docs.length} old notifications',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'NotificationService: Error cleaning up old notifications - $e',
        );
      }
    }
  }

  // Regional Customization Methods

  /// Create localized notification with Hindi/Gujarati support
  Future<String> createLocalizedNotification({
    required String userId,
    required String titleKey,
    required String messageKey,
    required NotificationType type,
    Map<String, String>? titleParams,
    Map<String, String>? messageParams,
    NotificationPriority priority = NotificationPriority.normal,
    String? relatedId,
    String? relatedType,
    Map<String, dynamic>? actionData,
    String? imageUrl,
    String? category,
    String? preferredLanguage,
  }) async {
    try {
      // Get user's preferred language or use current language
      final language = preferredLanguage ?? LocalizationService.currentLanguage;

      // Get localized title and message
      String title = LocalizationService.getLocalizedText(titleKey);
      String message = LocalizationService.getLocalizedText(messageKey);

      // Apply parameters if provided
      if (titleParams != null) {
        title = LocalizationService.getLocalizedTextWithParams(
          titleKey,
          titleParams,
        );
      }
      if (messageParams != null) {
        message = LocalizationService.getLocalizedTextWithParams(
          messageKey,
          messageParams,
        );
      }

      // Create notification with localized content
      return await createNotification(
        userId: userId,
        title: title,
        message: message,
        type: type,
        priority: priority,
        relatedId: relatedId,
        relatedType: relatedType,
        actionData: {
          ...?actionData,
          'language': language,
          'titleKey': titleKey,
          'messageKey': messageKey,
        },
        imageUrl: imageUrl,
        category: category,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'NotificationService: Error creating localized notification - $e',
        );
      }
      rethrow;
    }
  }

  // Festival notification functionality removed - Gujarat-specific features disabled
  // Future<String> createFestivalNotification(...) - REMOVED

  /// Create location-based notification for nearby temple events
  Future<String> createLocationBasedNotification({
    required String userId,
    required String templeId,
    required String templeName,
    required String eventTitle,
    required DateTime eventTime,
    required double distanceKm,
    String? eventType,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final titleKey = 'notification.location.nearby_event.title';
      final messageKey = 'notification.location.nearby_event.message';

      final titleParams = {'templeName': templeName};
      final messageParams = {
        'eventTitle': eventTitle,
        'templeName': templeName,
        'distance': LocalizationService.formatNumber(distanceKm),
        'time': LocalizationService.formatTime(eventTime),
      };

      return await createLocalizedNotification(
        userId: userId,
        titleKey: titleKey,
        messageKey: messageKey,
        titleParams: titleParams,
        messageParams: messageParams,
        type: NotificationType.eventReminder,
        priority: NotificationPriority.normal,
        relatedId: templeId,
        relatedType: 'temple_event',
        actionData: {
          'templeId': templeId,
          'eventType': eventType ?? 'general',
          'distanceKm': distanceKm,
          'eventTime': eventTime.toIso8601String(),
          ...?additionalData,
        },
        category: 'location_based',
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'NotificationService: Error creating location-based notification - $e',
        );
      }
      rethrow;
    }
  }

  /// Create emergency notification for temple closures or special events
  Future<String> createEmergencyNotification({
    required String userId,
    required String templeId,
    required String templeName,
    required EmergencyNotificationType emergencyType,
    String? reason,
    DateTime? affectedDate,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      String titleKey;
      String messageKey;
      Map<String, String> titleParams = {};
      Map<String, String> messageParams = {};

      switch (emergencyType) {
        case EmergencyNotificationType.templeClosure:
          titleKey = 'notification.emergency.temple_closure.title';
          messageKey = 'notification.emergency.temple_closure.message';
          titleParams = {'templeName': templeName};
          messageParams = {
            'templeName': templeName,
            if (reason != null) 'reason': reason,
            if (affectedDate != null)
              'date': LocalizationService.formatGujaratiDate(affectedDate),
          };
          break;
        case EmergencyNotificationType.scheduleChange:
          titleKey = 'notification.emergency.schedule_change.title';
          messageKey = 'notification.emergency.schedule_change.message';
          titleParams = {'templeName': templeName};
          messageParams = {
            'templeName': templeName,
            if (reason != null) 'reason': reason,
          };
          break;
        case EmergencyNotificationType.specialEvent:
          titleKey = 'notification.emergency.special_event.title';
          messageKey = 'notification.emergency.special_event.message';
          titleParams = {'templeName': templeName};
          messageParams = {
            'templeName': templeName,
            if (affectedDate != null)
              'date': LocalizationService.formatGujaratiDate(affectedDate),
          };
          break;
      }

      return await createLocalizedNotification(
        userId: userId,
        titleKey: titleKey,
        messageKey: messageKey,
        titleParams: titleParams,
        messageParams: messageParams,
        type: NotificationType.systemUpdate,
        priority: NotificationPriority.urgent,
        relatedId: templeId,
        relatedType: 'temple_emergency',
        actionData: {
          'templeId': templeId,
          'emergencyType': emergencyType.name,
          if (reason != null) 'reason': reason,
          if (affectedDate != null)
            'affectedDate': affectedDate.toIso8601String(),
          ...?additionalData,
        },
        category: 'emergency',
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'NotificationService: Error creating emergency notification - $e',
        );
      }
      rethrow;
    }
  }

  // Festival scheduling functionality removed - Gujarat-specific features disabled
  // Future<List<String>> scheduleFestivalNotifications(...) - REMOVED

  /// Check and send location-based notifications for nearby temple events
  Future<void> checkLocationBasedNotifications({
    required String userId,
    required double userLatitude,
    required double userLongitude,
    double radiusKm = 10.0,
  }) async {
    try {
      // Validate input parameters
      if (userId.isEmpty) {
        if (kDebugMode) {
          debugPrint(
            'NotificationService: Invalid userId provided for location-based notifications',
          );
        }
        return;
      }

      if (userLatitude < -90 || userLatitude > 90) {
        if (kDebugMode) {
          debugPrint(
            'NotificationService: Invalid latitude $userLatitude (must be between -90 and 90)',
          );
        }
        return;
      }

      if (userLongitude < -180 || userLongitude > 180) {
        if (kDebugMode) {
          debugPrint(
            'NotificationService: Invalid longitude $userLongitude (must be between -180 and 180)',
          );
        }
        return;
      }

      if (radiusKm <= 0) {
        if (kDebugMode) {
          debugPrint(
            'NotificationService: Invalid radius $radiusKm (must be positive)',
          );
        }
        return;
      }

      // Get user preferences to check if location notifications are enabled
      final preferences = await getNotificationPreferences(userId);
      if (!preferences.enableLocationNotifications) {
        if (kDebugMode) {
          debugPrint(
            'NotificationService: Location notifications disabled for user $userId',
          );
        }
        return;
      }

      // Query nearby temples using latitude bounds
      // Approximate: 1 degree of latitude ≈ 111 km
      final latDelta = radiusKm / 111.0;

      if (kDebugMode) {
        debugPrint(
          'NotificationService: Checking location-based notifications for user $userId at ($userLatitude, $userLongitude) within ${radiusKm}km',
        );
      }

      // Query temples within latitude bounds
      final nearbyTemples = await _firestore!
          .collection('temples')
          .where('location.latitude', isGreaterThan: userLatitude - latDelta)
          .where('location.latitude', isLessThan: userLatitude + latDelta)
          .get();

      if (kDebugMode) {
        debugPrint(
          'NotificationService: Found ${nearbyTemples.docs.length} temples within latitude bounds',
        );
      }

      if (nearbyTemples.docs.isEmpty) {
        if (kDebugMode) {
          debugPrint(
            'NotificationService: No temples found within ${radiusKm}km radius',
          );
        }
        return;
      }

      int processedCount = 0;
      int errorCount = 0;

      // Filter by actual distance and check for events
      for (final doc in nearbyTemples.docs) {
        try {
          final temple = Temple.fromFirestore(doc);

          // Validate temple has location data
          if (temple.location.latitude == 0.0 &&
              temple.location.longitude == 0.0) {
            if (kDebugMode) {
              debugPrint(
                'NotificationService: Temple ${temple.name} (${doc.id}) has invalid location data, skipping',
              );
            }
            continue;
          }

          // Calculate actual distance using Haversine formula
          final distance = _calculateDistance(
            userLatitude,
            userLongitude,
            temple.location.latitude,
            temple.location.longitude,
          );

          if (kDebugMode) {
            debugPrint(
              'NotificationService: Temple ${temple.name} is ${distance.toStringAsFixed(2)}km away',
            );
          }

          // Only process temples within the specified radius
          if (distance <= radiusKm) {
            await _checkTempleEvents(userId, temple, distance);
            processedCount++;
          }
        } catch (e, stackTrace) {
          errorCount++;
          if (kDebugMode) {
            debugPrint(
              'NotificationService: Error processing temple ${doc.id} - $e',
            );
            debugPrint('Stack trace: $stackTrace');
          }
          // Continue with next temple even if one fails
          continue;
        }
      }

      if (kDebugMode) {
        debugPrint(
          'NotificationService: Completed location-based notification check - processed $processedCount temples, $errorCount errors',
        );
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          'NotificationService: Error checking location-based notifications - $e',
        );
        debugPrint('Stack trace: $stackTrace');
      }
    }
  }

  /// Check for upcoming events at a temple and create notifications
  Future<void> _checkTempleEvents(
    String userId,
    Temple temple,
    double distance,
  ) async {
    try {
      // Validate temple ID
      if (temple.id.isEmpty) {
        if (kDebugMode) {
          debugPrint(
            'NotificationService: Temple has empty ID, skipping event check',
          );
        }
        return;
      }

      // Query upcoming events for this temple
      // Events starting within the next 7 days
      final now = DateTime.now();
      final weekFromNow = now.add(const Duration(days: 7));

      final eventsSnapshot = await _firestore!
          .collection('events')
          .where('templeId', isEqualTo: temple.id)
          .where('startDate', isGreaterThan: Timestamp.fromDate(now))
          .where('startDate', isLessThan: Timestamp.fromDate(weekFromNow))
          .get();

      if (kDebugMode) {
        debugPrint(
          'NotificationService: Found ${eventsSnapshot.docs.length} upcoming events at ${temple.name}',
        );
      }

      if (eventsSnapshot.docs.isEmpty) {
        if (kDebugMode) {
          debugPrint(
            'NotificationService: No upcoming events at ${temple.name}',
          );
        }
        return;
      }

      int notificationsCreated = 0;
      int notificationsSkipped = 0;
      int errorCount = 0;

      // Create notifications for each event
      for (final eventDoc in eventsSnapshot.docs) {
        try {
          final eventData = eventDoc.data();

          // Validate event data
          if (eventData['name'] == null || eventData['startDate'] == null) {
            if (kDebugMode) {
              debugPrint(
                'NotificationService: Event ${eventDoc.id} has missing required fields, skipping',
              );
            }
            errorCount++;
            continue;
          }

          final eventName = eventData['name'];
          final eventStartDate = eventData['startDate'];

          if (eventName == null || eventName is! String) {
            if (kDebugMode) {
              debugPrint(
                'NotificationService: Invalid event name for event ${eventDoc.id}',
              );
            }
            errorCount++;
            continue;
          }

          if (eventStartDate == null || eventStartDate is! Timestamp) {
            if (kDebugMode) {
              debugPrint(
                'NotificationService: Invalid event start date for event ${eventDoc.id}',
              );
            }
            errorCount++;
            continue;
          }

          final eventStartDateTime = eventStartDate.toDate();

          // Check if notification already exists for this event
          final existingNotification = await _firestore!
              .collection(_notificationsCollection)
              .where('userId', isEqualTo: userId)
              .where('relatedId', isEqualTo: eventDoc.id)
              .where('relatedType', isEqualTo: 'event')
              .limit(1)
              .get();

          // Skip if notification already exists
          if (existingNotification.docs.isNotEmpty) {
            if (kDebugMode) {
              debugPrint(
                'NotificationService: Notification already exists for event $eventName (${eventDoc.id})',
              );
            }
            notificationsSkipped++;
            continue;
          }

          // Create notification for the event
          final daysUntilEvent = eventStartDateTime.difference(now).inDays;
          final timeDescription = daysUntilEvent == 0
              ? 'today'
              : daysUntilEvent == 1
              ? 'tomorrow'
              : 'in $daysUntilEvent days';

          await createNotification(
            userId: userId,
            title: 'Upcoming Event at ${temple.name}',
            message:
                '$eventName is happening $timeDescription at ${temple.name}, ${distance.toStringAsFixed(1)}km away',
            type: NotificationType.eventReminder,
            priority: daysUntilEvent <= 1
                ? NotificationPriority.high
                : NotificationPriority.normal,
            relatedId: eventDoc.id,
            relatedType: 'event',
            actionData: {
              'templeId': temple.id,
              'templeName': temple.name,
              'eventId': eventDoc.id,
              'eventName': eventName,
              'distance': distance,
            },
            imageUrl: temple.images.isNotEmpty ? temple.images.first : null,
            category: 'location_event',
          );

          notificationsCreated++;

          if (kDebugMode) {
            debugPrint(
              'NotificationService: Created notification for event $eventName at ${temple.name}',
            );
          }
        } catch (e, stackTrace) {
          errorCount++;
          if (kDebugMode) {
            debugPrint(
              'NotificationService: Error creating notification for event ${eventDoc.id} - $e',
            );
            debugPrint('Stack trace: $stackTrace');
          }
          // Continue with next event even if one fails
          continue;
        }
      }

      if (kDebugMode) {
        debugPrint(
          'NotificationService: Event check complete for ${temple.name} - created $notificationsCreated, skipped $notificationsSkipped, errors $errorCount',
        );
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          'NotificationService: Error checking events for temple ${temple.id} (${temple.name}) - $e',
        );
        debugPrint('Stack trace: $stackTrace');
      }
    }
  }

  /// Calculate distance between two geographic coordinates using Haversine formula
  /// Returns distance in kilometers
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    // Earth's radius in kilometers
    const double earthRadiusKm = 6371.0;

    // Convert degrees to radians
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);

    final lat1Rad = _degreesToRadians(lat1);
    final lat2Rad = _degreesToRadians(lat2);

    // Haversine formula
    final a =
        (sin(dLat / 2) * sin(dLat / 2)) +
        (sin(dLon / 2) * sin(dLon / 2) * cos(lat1Rad) * cos(lat2Rad));
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadiusKm * c;
  }

  /// Convert degrees to radians
  double _degreesToRadians(double degrees) {
    return degrees * pi / 180.0;
  }

  /// Dispose the service
  void dispose() {
    _authSubscription?.cancel();
  }

  /// Queue notification for delivery after quiet hours
  Future<String> _queueNotificationForQuietHours({
    required String userId,
    required String title,
    required String message,
    required NotificationType type,
    NotificationPriority priority = NotificationPriority.normal,
    String? relatedId,
    String? relatedType,
    Map<String, dynamic>? actionData,
    String? imageUrl,
    String? category,
  }) async {
    try {
      final queuedNotification = {
        'userId': userId,
        'title': title,
        'message': message,
        'type': type.value,
        'priority': priority.value,
        'relatedId': relatedId,
        'relatedType': relatedType,
        'actionData': actionData,
        'imageUrl': imageUrl,
        'category': category,
        'queuedAt': FieldValue.serverTimestamp(),
        'isProcessed': false,
      };

      final docRef = await _firestore!
          .collection(_queuedNotificationsCollection)
          .add(queuedNotification);

      if (kDebugMode) {
        debugPrint('NotificationService: Queued notification ${docRef.id} for quiet hours');
      }

      return docRef.id;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('NotificationService: Error queueing notification - $e');
      }
      rethrow;
    }
  }

  /// Process queued notifications for users whose quiet hours have ended
  Future<void> processQueuedNotifications(String userId) async {
    try {
      final preferences = await getNotificationPreferences(userId);
      
      // Only process if not in quiet hours
      if (preferences.isInQuietHours) {
        if (kDebugMode) {
          debugPrint('NotificationService: Still in quiet hours for user $userId');
        }
        return;
      }

      // Get queued notifications for this user
      final queuedNotifications = await _firestore!
          .collection(_queuedNotificationsCollection)
          .where('userId', isEqualTo: userId)
          .where('isProcessed', isEqualTo: false)
          .orderBy('queuedAt')
          .get();

      if (queuedNotifications.docs.isEmpty) {
        return;
      }

      if (kDebugMode) {
        debugPrint('NotificationService: Processing ${queuedNotifications.docs.length} queued notifications for user $userId');
      }

      final batch = _firestore!.batch();
      
      for (final doc in queuedNotifications.docs) {
        final data = doc.data();
        
        try {
          // Create the actual notification
          await createNotification(
            userId: data['userId'],
            title: data['title'],
            message: data['message'],
            type: NotificationType.fromValue(data['type']),
            priority: NotificationPriority.fromValue(data['priority']),
            relatedId: data['relatedId'],
            relatedType: data['relatedType'],
            actionData: data['actionData'] != null 
                ? Map<String, dynamic>.from(data['actionData'])
                : null,
            imageUrl: data['imageUrl'],
            category: data['category'],
          );

          // Mark as processed
          batch.update(doc.reference, {
            'isProcessed': true,
            'processedAt': FieldValue.serverTimestamp(),
          });
        } catch (e) {
          if (kDebugMode) {
            debugPrint('NotificationService: Error processing queued notification ${doc.id} - $e');
          }
          
          // Mark as processed with error
          batch.update(doc.reference, {
            'isProcessed': true,
            'processedAt': FieldValue.serverTimestamp(),
            'error': e.toString(),
          });
        }
      }

      await batch.commit();

      if (kDebugMode) {
        debugPrint('NotificationService: Processed ${queuedNotifications.docs.length} queued notifications');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('NotificationService: Error processing queued notifications - $e');
      }
    }
  }

  /// Get count of queued notifications for a user
  Future<int> getQueuedNotificationsCount(String userId) async {
    try {
      final snapshot = await _firestore!
          .collection(_queuedNotificationsCollection)
          .where('userId', isEqualTo: userId)
          .where('isProcessed', isEqualTo: false)
          .get();

      return snapshot.docs.length;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('NotificationService: Error getting queued notifications count - $e');
      }
      return 0;
    }
  }
}
