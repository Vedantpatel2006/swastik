import 'dart:async';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'supabase_device_token_service.dart';

/// Background message handler — must be a top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase is already initialized by the time this runs
  if (kDebugMode) {
    debugPrint('📬 FCM background message: ${message.messageId}');
  }
}

/// FCM Service — handles device token, foreground/background push notifications,
/// and local notification display.
class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  String? _deviceToken;
  bool _initialized = false;
  GlobalKey<NavigatorState>? _navigatorKey;

  // Current signed-in user ID — set after login so token refreshes are saved.
  String? _currentUserId;

  // Notification channel IDs
  static const String _defaultChannelId = 'swastik_notifications';
  static const String _urgentChannelId = 'swastik_urgent';
  static const String _liveChannelId = 'swastik_live';

  String? get deviceToken => _deviceToken;

  void setNavigatorKey(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
  }

  /// Register the signed-in user so token refreshes are persisted to Supabase.
  /// Call this after every successful login (already done via
  /// initializeNotificationServicesForUser in main.dart).
  void setCurrentUserId(String? userId) {
    _currentUserId = userId;
  }

  /// Initialize FCM — request permission, get token, set up listeners
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Register background handler
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );

      // Request notification permission
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (kDebugMode) {
        debugPrint('🔔 FCM permission: ${settings.authorizationStatus.name}');
      }

      // Initialize local notifications (for foreground display)
      await _initializeLocalNotifications();

      // Get and cache device token
      _deviceToken = await _messaging.getToken();
      if (kDebugMode) {
        debugPrint('📱 FCM token: $_deviceToken');
      }

      // Listen for token refresh — save the new token to Supabase immediately
      // so the Edge Function always has a valid token to send pushes to.
      _messaging.onTokenRefresh.listen((newToken) {
        _deviceToken = newToken;
        if (kDebugMode) {
          debugPrint('🔄 FCM token refreshed: $newToken');
        }
        // Persist the refreshed token if a user is signed in.
        if (_currentUserId != null) {
          SupabaseDeviceTokenService().saveDeviceToken(_currentUserId!);
        }
      });

      // Handle foreground messages — show local notification
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle notification tap when app is in background (not terminated)
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // Handle notification tap when app was terminated
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        // Delay to let the navigator settle
        Future.delayed(const Duration(seconds: 1), () {
          _handleNotificationTap(initialMessage);
        });
      }

      _initialized = true;
      if (kDebugMode) {
        debugPrint('✅ FCMService initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ FCMService init error: $e');
      }
    }
  }

  /// Get FCM token (initializes if needed)
  Future<String?> getToken() async {
    if (!_initialized) await initialize();
    _deviceToken ??= await _messaging.getToken();
    return _deviceToken;
  }

  /// Handle a message received while app is in foreground
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    if (kDebugMode) {
      debugPrint('📬 FCM foreground message: ${message.notification?.title}');
    }

    final notification = message.notification;
    if (notification == null) return;

    final type = message.data['type'] as String? ?? 'general';
    final channelId = _getChannelForType(type);

    await _showLocalNotification(
      id: message.hashCode,
      title: notification.title ?? 'Swastik',
      body: notification.body ?? '',
      channelId: channelId,
      payload: jsonEncode(message.data),
    );
  }

  /// Handle notification tap (navigate to relevant screen)
  void _handleNotificationTap(RemoteMessage message) {
    if (kDebugMode) {
      debugPrint('👆 FCM notification tapped: ${message.data}');
    }

    final navigator = _navigatorKey?.currentState;
    if (navigator == null) return;

    final type = message.data['type'] as String? ?? 'general';
    final templeId = message.data['templeId'] as String?;

    switch (type) {
      case 'live_stream_started':
        navigator.pushNamed('/home');
        break;
      case 'temple_update':
        if (templeId != null) {
          navigator.pushNamed('/temple_search');
        } else {
          navigator.pushNamed('/home');
        }
        break;
      case 'event_reminder':
        navigator.pushNamed('/home');
        break;
      case 'booking_confirmation':
      case 'booking_reminder':
      case 'booking_cancellation':
        navigator.pushNamed('/my_bookings');
        break;
      case 'donation_confirmation':
        navigator.pushNamed('/donations');
        break;
      default:
        navigator.pushNamed('/notifications');
    }
  }

  /// Show a local notification
  Future<void> _showLocalNotification({
    required int id,
    required String title,
    required String body,
    required String channelId,
    String? payload,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      channelId,
      _getChannelName(channelId),
      importance: channelId == _urgentChannelId || channelId == _liveChannelId
          ? Importance.max
          : Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    final details = NotificationDetails(android: androidDetails);
    await _localNotifications.show(id, title, body, details, payload: payload);
  }

  /// Show a local notification directly (called by app code)
  Future<void> showNotification({
    required String title,
    required String body,
    String type = 'general',
    String? payload,
  }) async {
    await _showLocalNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      channelId: _getChannelForType(type),
      payload: payload,
    );
  }

  String _getChannelForType(String type) {
    switch (type) {
      case 'live_stream_started':
        return _liveChannelId;
      case 'system_update':
        return _urgentChannelId;
      default:
        return _defaultChannelId;
    }
  }

  String _getChannelName(String channelId) {
    switch (channelId) {
      case _urgentChannelId:
        return 'Urgent Notifications';
      case _liveChannelId:
        return 'Live Darshan';
      default:
        return 'Swastik Notifications';
    }
  }

  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _localNotifications.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: (response) {
        if (kDebugMode) {
          debugPrint('🔔 Local notification tapped: ${response.payload}');
        }
        if (response.payload != null) {
          try {
            final data = jsonDecode(response.payload!) as Map<String, dynamic>;
            final type = data['type'] as String? ?? 'general';
            final navigator = _navigatorKey?.currentState;
            if (navigator != null) {
              switch (type) {
                case 'booking_confirmation':
                case 'booking_reminder':
                case 'booking_cancellation':
                  navigator.pushNamed('/my_bookings');
                  break;
                case 'donation_confirmation':
                  navigator.pushNamed('/donations');
                  break;
                default:
                  navigator.pushNamed('/notifications');
              }
            }
          } catch (_) {}
        }
      },
    );

    // Create Android notification channels
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _defaultChannelId,
        'Swastik Notifications',
        description: 'Temple updates, events, and reminders',
        importance: Importance.high,
        playSound: true,
      ),
    );

    await androidPlugin?.createNotificationChannel(
      AndroidNotificationChannel(
        _urgentChannelId,
        'Urgent Notifications',
        description: 'Urgent alerts from Swastik',
        importance: Importance.max,
        playSound: true,
        vibrationPattern: Int64List.fromList([0, 250, 250, 250]),
      ),
    );

    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _liveChannelId,
        'Live Darshan',
        description: 'Alerts when a temple goes live',
        importance: Importance.max,
        playSound: true,
      ),
    );
  }

  void dispose() {
    _initialized = false;
  }
}
