import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/notification.dart';
import 'fcm_service.dart';

/// Supabase-based notification service (alternative to Firebase)
/// Stores notifications in Supabase Postgres database
/// Uses Supabase Edge Functions to send FCM push notifications
class SupabaseNotificationService {
  static final SupabaseNotificationService _instance =
      SupabaseNotificationService._internal();
  factory SupabaseNotificationService() => _instance;
  SupabaseNotificationService._internal();

  SupabaseClient? _supabase;

  /// Lazily get the Supabase client — safe to call before initialize()
  SupabaseClient get _client => _supabase ??= Supabase.instance.client;
  SharedPreferences? _prefs;
  String? _currentUserId;
  RealtimeChannel? _notificationChannel;

  // Table names
  static const String _notificationsTable = 'user_notifications';
  static const String _preferencesTable = 'notification_preferences';
  static const String _queuedNotificationsTable = 'queued_notifications';

  // Local storage keys
  static const String _badgeCountKey = 'notification_badge_count';

  /// Initialize the service
  Future<void> initialize({String? userId}) async {
    try {
      _supabase = Supabase.instance.client;
      _prefs = await SharedPreferences.getInstance();
      _currentUserId = userId ?? _supabase?.auth.currentUser?.id;

      if (_currentUserId != null) {
        await _initializeUserNotifications(_currentUserId!);
        _setupRealtimeSubscription(_currentUserId!);
      }

      if (kDebugMode) {
        debugPrint('SupabaseNotificationService: Initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SupabaseNotificationService: Error initializing - $e');
      }
    }
  }

  /// Initialize notifications for a specific user
  Future<void> _initializeUserNotifications(String userId) async {
    try {
      // Check if preferences exist
      final prefs = await _client
          .from(_preferencesTable)
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (prefs == null) {
        // Create default preferences
        await _client.from(_preferencesTable).insert({
          'user_id': userId,
          'enable_all_notifications': true,
          'enable_push_notifications': true,
          'enable_temple_updates': true,
          'enable_event_reminders': true,
          'enable_booking_reminders': true,
          'enable_live_stream_notifications': true,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      }

      // Update badge count
      await _updateBadgeCount(userId);

      if (kDebugMode) {
        debugPrint('SupabaseNotificationService: Initialized for user $userId');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SupabaseNotificationService: Error initializing user - $e');
      }
    }
  }

  /// Setup real-time subscription for notifications
  void _setupRealtimeSubscription(String userId) {
    try {
      _notificationChannel = _client
          .channel('notifications:$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: _notificationsTable,
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: (payload) {
              if (kDebugMode) {
                debugPrint('New notification received: ${payload.newRecord}');
              }
              _updateBadgeCount(userId);
            },
          )
          .subscribe();

      if (kDebugMode) {
        debugPrint(
          'SupabaseNotificationService: Real-time subscription active',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'SupabaseNotificationService: Error setting up real-time - $e',
        );
      }
    }
  }

  /// Get user notifications stream
  Stream<List<UserNotification>> getUserNotifications(String userId) {
    return _client
        .from(_notificationsTable)
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(100)
        .map((data) => data.map((json) => _mapToNotification(json)).toList());
  }

  /// Get unread notifications count
  Stream<int> getUnreadCount(String userId) async* {
    await for (final notifications in getUserNotifications(userId)) {
      yield notifications.where((n) => !n.isRead).length;
    }
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
    try {
      // Check user preferences
      final prefs = await getNotificationPreferences(userId);
      if (!prefs.shouldSendNotification(type)) {
        if (kDebugMode) {
          debugPrint(
            'SupabaseNotificationService: Notification blocked by preferences',
          );
        }
        return '';
      }

      // Check quiet hours
      if (priority != NotificationPriority.urgent && prefs.isInQuietHours) {
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

      // Insert notification
      final response = await _client
          .from(_notificationsTable)
          .insert({
            'user_id': userId,
            'title': title,
            'message': message,
            'type': type.value,
            'priority': priority.value,
            'related_id': relatedId,
            'related_type': relatedType,
            'action_data': actionData,
            'image_url': imageUrl,
            'category': category,
            'is_read': false,
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      final notificationId = response['id'] as String;

      // Send push notification via Edge Function.
      // When the app is in the foreground, FCMService._handleForegroundMessage
      // will display a local notification automatically — so we must NOT also
      // call FCMService().showNotification() here, otherwise the user sees the
      // same notification twice (once from the local call, once from FCM).
      if (prefs.enablePushNotifications) {
        await _sendPushNotification(
          userId: userId,
          notificationId: notificationId,
          title: title,
          message: message,
          type: type.value,
          actionData: actionData,
        );
      } else {
        // Push is disabled — show a local-only notification so the user still
        // sees something while the app is open.
        unawaited(
          FCMService().showNotification(
            title: title,
            body: message,
            type: type.value,
            payload: notificationId,
          ),
        );
      }

      if (kDebugMode) {
        debugPrint(
          'SupabaseNotificationService: Created notification $notificationId',
        );
      }

      return notificationId;
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'SupabaseNotificationService: Error creating notification - $e',
        );
      }
      rethrow;
    }
  }

  /// Send push notification via Supabase Edge Function
  Future<void> _sendPushNotification({
    required String userId,
    required String notificationId,
    required String title,
    required String message,
    required String type,
    Map<String, dynamic>? actionData,
  }) async {
    try {
      // Call Supabase Edge Function
      final response = await _client.functions.invoke(
        'send-fcm-notification',
        body: {
          'userId': userId,
          'notificationId': notificationId,
          'title': title,
          'message': message,
          'type': type,
          'actionData': actionData,
        },
      );

      if (response.status == 200) {
        // Update notification with sent status
        await _client
            .from(_notificationsTable)
            .update({
              'push_sent': true,
              'push_sent_at': DateTime.now().toIso8601String(),
            })
            .eq('id', notificationId);

        if (kDebugMode) {
          debugPrint('SupabaseNotificationService: Push notification sent');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SupabaseNotificationService: Error sending push - $e');
      }
      // Don't rethrow - notification is still created in DB
    }
  }

  /// Queue notification for quiet hours
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
      final response = await _client
          .from(_queuedNotificationsTable)
          .insert({
            'user_id': userId,
            'title': title,
            'message': message,
            'type': type.value,
            'priority': priority.value,
            'related_id': relatedId,
            'related_type': relatedType,
            'action_data': actionData,
            'image_url': imageUrl,
            'category': category,
            'is_processed': false,
            'queued_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      final queuedId = response['id'] as String;

      if (kDebugMode) {
        debugPrint(
          'SupabaseNotificationService: Queued notification $queuedId',
        );
      }

      return queuedId;
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'SupabaseNotificationService: Error queueing notification - $e',
        );
      }
      rethrow;
    }
  }

  /// Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _client
          .from(_notificationsTable)
          .update({
            'is_read': true,
            'read_at': DateTime.now().toIso8601String(),
          })
          .eq('id', notificationId);

      if (_currentUserId != null) {
        await _updateBadgeCount(_currentUserId!);
      }

      if (kDebugMode) {
        debugPrint('SupabaseNotificationService: Marked notification as read');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SupabaseNotificationService: Error marking as read - $e');
      }
      rethrow;
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead(String userId) async {
    try {
      await _client
          .from(_notificationsTable)
          .update({
            'is_read': true,
            'read_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId)
          .eq('is_read', false);

      await _updateBadgeCount(userId);

      if (kDebugMode) {
        debugPrint('SupabaseNotificationService: Marked all as read');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'SupabaseNotificationService: Error marking all as read - $e',
        );
      }
      rethrow;
    }
  }

  /// Delete notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _client
          .from(_notificationsTable)
          .delete()
          .eq('id', notificationId);

      if (_currentUserId != null) {
        await _updateBadgeCount(_currentUserId!);
      }

      if (kDebugMode) {
        debugPrint('SupabaseNotificationService: Deleted notification');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SupabaseNotificationService: Error deleting - $e');
      }
      rethrow;
    }
  }

  /// Delete all notifications for a user
  Future<void> clearAllNotifications(String userId) async {
    try {
      await _client.from(_notificationsTable).delete().eq('user_id', userId);
      await _updateBadgeCount(userId);

      if (kDebugMode) {
        debugPrint('SupabaseNotificationService: Cleared all notifications');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'SupabaseNotificationService: Error clearing all notifications - $e',
        );
      }
      rethrow;
    }
  }

  /// Get notification preferences
  Future<NotificationPreferences> getNotificationPreferences(
    String userId,
  ) async {
    try {
      final data = await _client
          .from(_preferencesTable)
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (data != null) {
        return _mapToPreferences(data, userId);
      } else {
        // Return default preferences
        return NotificationPreferences(
          userId: userId,
          updatedAt: DateTime.now(),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'SupabaseNotificationService: Error getting preferences - $e',
        );
      }
      return NotificationPreferences(userId: userId, updatedAt: DateTime.now());
    }
  }

  /// Update badge count
  Future<void> _updateBadgeCount(String userId) async {
    try {
      final unreadNotifications = await _client
          .from(_notificationsTable)
          .select('id')
          .eq('user_id', userId)
          .eq('is_read', false);

      final unreadCount = unreadNotifications.length;
      await _prefs!.setInt(_badgeCountKey, unreadCount);

      if (kDebugMode) {
        debugPrint('SupabaseNotificationService: Badge count: $unreadCount');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SupabaseNotificationService: Error updating badge - $e');
      }
    }
  }

  /// Get current badge count
  int getBadgeCount() {
    return _prefs?.getInt(_badgeCountKey) ?? 0;
  }

  /// Map Supabase JSON to UserNotification
  UserNotification _mapToNotification(Map<String, dynamic> json) {
    return UserNotification(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      message: json['message'] as String,
      type: NotificationType.fromValue(json['type'] as String),
      priority: NotificationPriority.fromValue(
        json['priority'] as String? ?? 'normal',
      ),
      relatedId: json['related_id'] as String?,
      relatedType: json['related_type'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      isRead: json['is_read'] as bool? ?? false,
      readAt: json['read_at'] != null
          ? DateTime.parse(json['read_at'] as String)
          : null,
      actionData: json['action_data'] as Map<String, dynamic>?,
      imageUrl: json['image_url'] as String?,
      category: json['category'] as String?,
    );
  }

  /// Map Supabase JSON to NotificationPreferences
  NotificationPreferences _mapToPreferences(
    Map<String, dynamic> json,
    String userId,
  ) {
    return NotificationPreferences(
      userId: userId,
      enablePushNotifications:
          json['enable_push_notifications'] as bool? ?? true,
      enableTempleUpdates: json['enable_temple_updates'] as bool? ?? true,
      enableEventReminders: json['enable_event_reminders'] as bool? ?? true,
      enableBookingReminders: json['enable_booking_reminders'] as bool? ?? true,
      enableDonationConfirmations:
          json['enable_donation_confirmations'] as bool? ?? true,
      enableLiveStreamNotifications:
          json['enable_live_stream_notifications'] as bool? ?? true,
      enableCommunityUpdates: json['enable_community_updates'] as bool? ?? true,
      enableSystemUpdates: json['enable_system_updates'] as bool? ?? true,
      enableSoundNotifications:
          json['enable_sound_notifications'] as bool? ?? true,
      enableVibrationNotifications:
          json['enable_vibration_notifications'] as bool? ?? true,
      quietHoursStart: json['quiet_hours_start'] as String? ?? '22:00',
      quietHoursEnd: json['quiet_hours_end'] as String? ?? '08:00',
      enableQuietHours: json['enable_quiet_hours'] as bool? ?? false,
      enableFestivalNotifications:
          json['enable_festival_notifications'] as bool? ?? true,
      enableLocationNotifications:
          json['enable_location_notifications'] as bool? ?? true,
      enableEmergencyNotifications:
          json['enable_emergency_notifications'] as bool? ?? true,
      enableCulturalEventNotifications:
          json['enable_cultural_event_notifications'] as bool? ?? true,
      preferredLanguage: json['preferred_language'] as String? ?? 'en',
      interestedDistricts: json['interested_districts'] != null
          ? List<String>.from(json['interested_districts'] as List)
          : const [],
      culturalEventCategories: json['cultural_event_categories'] != null
          ? List<String>.from(json['cultural_event_categories'] as List)
          : const [],
      locationRadiusKm:
          (json['location_radius_km'] as num?)?.toDouble() ?? 10.0,
      enableHolidayNotifications:
          json['enable_holiday_notifications'] as bool? ?? true,
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Dispose resources
  void dispose() {
    _notificationChannel?.unsubscribe();
  }
}

