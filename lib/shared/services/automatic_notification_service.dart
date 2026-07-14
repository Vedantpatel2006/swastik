import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/temple.dart';
import '../models/notification.dart';
import 'supabase_notification_service.dart';
import 'location_service.dart';
import 'service_container.dart';

/// Service that automatically creates notifications for real events
class AutomaticNotificationService {
  static final AutomaticNotificationService _instance =
      AutomaticNotificationService._internal();
  factory AutomaticNotificationService() => _instance;
  AutomaticNotificationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Use centralized service container for both services
  SupabaseNotificationService get _notificationService =>
      services.notificationService;
  LocationService get _locationService => services.locationService;

  final List<StreamSubscription> _subscriptions = [];
  bool _isInitialized = false;

  /// Initialize automatic notification monitoring
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Both services are now initialized by ServiceContainer

      // Start monitoring for automatic notifications
      _startTempleMonitoring();
      _startLiveDarshanMonitoring();
      _startEventMonitoring();

      _isInitialized = true;
      if (kDebugMode) {
        debugPrint('✅ AutomaticNotificationService initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Failed to initialize AutomaticNotificationService: $e');
      }
    }
  }

  /// Monitor for new temples being added
  void _startTempleMonitoring() {
    bool isFirstSnapshot = true;

    final templeStream = _firestore
        .collection('temples')
        .where('isActive', isEqualTo: true)
        .snapshots();

    final subscription = templeStream.listen((snapshot) {
      // Skip the initial load — only react to genuinely new documents
      if (isFirstSnapshot) {
        isFirstSnapshot = false;
        return;
      }
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          _handleNewTemple(change.doc);
        }
      }
    });

    _subscriptions.add(subscription);
  }

  /// Monitor live darshan status changes via Firestore snapshots.
  void _startLiveDarshanMonitoring() {
    final Set<String> _knownLiveTemples = {};
    // Tracks when we last sent a live notification per temple, to prevent
    // duplicate notifications caused by cron updates or snapshot races.
    final Map<String, DateTime> _lastNotifiedAt = {};
    const Duration notificationCooldown = Duration(hours: 1);
    bool _seeded = false;

    // Seed the known-live set from current Firestore state BEFORE
    // starting the listener, so we never notify for already-live temples.
    _firestore
        .collection('temples')
        .where('isCurrentlyLive', isEqualTo: true)
        .get()
        .then((snap) {
          for (final doc in snap.docs) {
            _knownLiveTemples.add(doc.id);
          }
          _seeded = true;
        });

    // Listen for any temple live status change
    final sub = _firestore.collection('temples').snapshots().listen((
      snapshot,
    ) async {
      // Wait until the seed query has completed so _knownLiveTemples is
      // fully populated before we start reacting to changes.
      if (!_seeded) return;

      for (final change in snapshot.docChanges) {
        if (change.type != DocumentChangeType.modified) continue;

        final templeId = change.doc.id;
        final data = change.doc.data() as Map<String, dynamic>? ?? {};
        final isLive = data['isCurrentlyLive'] as bool? ?? false;
        final wasLive = _knownLiveTemples.contains(templeId);

        if (isLive && !wasLive) {
          // Check cooldown — don't re-notify if we already sent one recently.
          final lastNotified = _lastNotifiedAt[templeId];
          final cooldownPassed =
              lastNotified == null ||
              DateTime.now().difference(lastNotified) > notificationCooldown;

          _knownLiveTemples.add(templeId);

          if (cooldownPassed) {
            _lastNotifiedAt[templeId] = DateTime.now();
            await _handleLiveDarshanStartedFromDoc(templeId, data);
          } else if (kDebugMode) {
            debugPrint(
              '🔕 Skipping duplicate live notification for $templeId '
              '(cooldown: ${notificationCooldown.inMinutes}min)',
            );
          }
        } else if (!isLive && wasLive) {
          _knownLiveTemples.remove(templeId);
          // Reset cooldown when temple goes offline so next live event notifies.
          _lastNotifiedAt.remove(templeId);
        }
      }
    });

    _subscriptions.add(sub);
  }

  /// Handle live darshan started — data comes from Firestore document.
  Future<void> _handleLiveDarshanStartedFromDoc(
    String templeId,
    Map<String, dynamic> data,
  ) async {
    try {
      final templeName = data['name'] as String? ?? 'Temple';
      final videoId = data['currentLiveVideoId'] as String?;

      final users = await _getUsersInterestedInTempleId(templeId);

      for (final userId in users) {
        await _notificationService.createNotification(
          userId: userId,
          title: 'Live Darshan Started! 🔴',
          message: '$templeName is now streaming live darshan. Join now!',
          type: NotificationType.liveStreamStarted,
          priority: NotificationPriority.high,
          relatedId: templeId,
          relatedType: 'live_darshan',
          actionData: {
            'templeId': templeId,
            'templeName': templeName,
            'action': 'watch_live',
            if (videoId != null) 'streamUrl': videoId,
          },
          category: 'live_darshan',
        );
      }

      if (kDebugMode) {
        debugPrint('📢 Sent live darshan notifications for: $templeName');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error handling live darshan (Firestore): $e');
      }
    }
  }

  Future<List<String>> _getUsersInterestedInTempleId(String templeId) async {
    try {
      final interestedUsers = <String>{};

      // Users who favorited this temple
      final favSnap = await _firestore
          .collection('user_favorites')
          .where('templeIds', arrayContains: templeId)
          .get();
      for (final doc in favSnap.docs) {
        interestedUsers.add(doc.id);
      }

      return interestedUsers.toList();
    } catch (e) {
      if (kDebugMode) debugPrint('❌ _getUsersInterestedInTempleId: $e');
      return [];
    }
  }

  /// Monitor for temple events
  void _startEventMonitoring() {
    bool isFirstSnapshot = true;

    final eventStream = _firestore
        .collection('events')
        .where('isActive', isEqualTo: true)
        .where('startDate', isGreaterThan: Timestamp.now())
        .snapshots();

    final subscription = eventStream.listen((snapshot) {
      if (isFirstSnapshot) {
        isFirstSnapshot = false;
        return;
      }
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          _handleNewEvent(change.doc);
        }
      }
    });

    _subscriptions.add(subscription);
  }

  /// Handle new temple added
  Future<void> _handleNewTemple(DocumentSnapshot doc) async {
    try {
      final temple = Temple.fromFirestore(doc);

      // Get all users to notify about new temple
      final users = await _getActiveUsers();

      for (final userId in users) {
        // Check if temple is near user's location
        final isNearby = await _isTempleNearUser(temple, userId);

        if (isNearby) {
          await _notificationService.createNotification(
            userId: userId,
            title: 'New Temple Discovered! 🏛️',
            message:
                '${temple.name} has been added near your location. Explore now!',
            type: NotificationType.templeUpdate,
            priority: NotificationPriority.normal,
            relatedId: temple.id,
            relatedType: 'temple',
            actionData: {
              'templeId': temple.id,
              'templeName': temple.name,
              'action': 'view_temple',
            },
            category: 'new_temple',
          );
        }
      }

      if (kDebugMode) {
        debugPrint('📢 Sent new temple notifications for: ${temple.name}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error handling new temple: $e');
      }
    }
  }

  /// Handle new event added
  Future<void> _handleNewEvent(DocumentSnapshot doc) async {
    try {
      final eventData = doc.data() as Map<String, dynamic>? ?? {};
      final eventName = eventData['name'] as String? ?? 'Temple Event';
      final templeId = eventData['templeId'] as String?;
      final startDate = (eventData['startDate'] as Timestamp?)?.toDate();

      if (templeId == null) return;

      // Get temple details
      final templeDoc = await _firestore
          .collection('temples')
          .doc(templeId)
          .get();
      if (!templeDoc.exists) return;

      final temple = Temple.fromFirestore(templeDoc);

      // Get users interested in this temple
      final users = await _getUsersInterestedInTemple(temple);

      for (final userId in users) {
        await _notificationService.createNotification(
          userId: userId,
          title: 'New Temple Event! 📅',
          message:
              '$eventName at ${temple.name}${startDate != null ? ' on ${_formatDate(startDate)}' : ''}',
          type: NotificationType.eventReminder,
          priority: NotificationPriority.normal,
          relatedId: templeId,
          relatedType: 'temple_event',
          actionData: {
            'templeId': templeId,
            'templeName': temple.name,
            'eventId': doc.id,
            'eventName': eventName,
            'action': 'view_event',
          },
          category: 'events',
        );
      }

      if (kDebugMode) {
        debugPrint(
          '📢 Sent event notifications for: $eventName at ${temple.name}',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error handling new event: $e');
      }
    }
  }

  /// Get all active users - OPTIMIZED VERSION
  Future<List<String>> _getActiveUsers() async {
    try {
      // Use user_preferences collection as it's more accessible
      final querySnapshot = await _firestore
          .collection('user_preferences')
          .limit(1000) // Limit to prevent excessive reads
          .get();

      final activeUserIds = querySnapshot.docs.map((doc) => doc.id).toList();

      if (kDebugMode) {
        debugPrint(
          'AutomaticNotificationService: Found ${activeUserIds.length} active users from preferences',
        );
      }

      return activeUserIds;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error getting active users: $e');
      }
      return [];
    }
  }

  /// Check if temple is near user's location
  Future<bool> _isTempleNearUser(Temple temple, String userId) async {
    try {
      // Get user's location preferences
      final userPrefsDoc = await _firestore
          .collection('user_preferences')
          .doc(userId)
          .get();

      if (!userPrefsDoc.exists) return false;

      final userPrefs = userPrefsDoc.data() ?? {};
      final userLat = userPrefs['lastKnownLatitude'] as double?;
      final userLng = userPrefs['lastKnownLongitude'] as double?;
      final maxDistance =
          userPrefs['locationRadius'] as double? ?? 50.0; // Default 50km

      if (userLat == null || userLng == null) return false;

      final userLocation = Location(latitude: userLat, longitude: userLng);
      final distance = await _locationService.calculateDistance(
        userLocation,
        temple.location,
      );

      return distance <= maxDistance;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error checking temple proximity: $e');
      }
      return false;
    }
  }

  /// Get users interested in a specific temple (favorites + nearby)
  Future<List<String>> _getUsersInterestedInTemple(Temple temple) async {
    try {
      final interestedUsers = <String>{};

      // Get users who have this temple in favorites
      final favoritesSnapshot = await _firestore
          .collection('user_favorites')
          .where('templeIds', arrayContains: temple.id)
          .get();

      for (final doc in favoritesSnapshot.docs) {
        interestedUsers.add(doc.id);
      }

      // Get users who are nearby (within 25km for live darshan)
      final allUsers = await _getActiveUsers();
      for (final userId in allUsers) {
        final isNearby = await _isTempleNearUser(temple, userId);
        if (isNearby) {
          interestedUsers.add(userId);
        }
      }

      return interestedUsers.toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error getting interested users: $e');
      }
      return [];
    }
  }

  /// Format date for display
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDate = DateTime(date.year, date.month, date.day);

    if (eventDate == today) {
      return 'today';
    } else if (eventDate == today.add(const Duration(days: 1))) {
      return 'tomorrow';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  /// Send system update notification to all users
  Future<void> sendSystemUpdateNotification({
    required String title,
    required String message,
    NotificationPriority priority = NotificationPriority.normal,
    Map<String, dynamic>? actionData,
  }) async {
    try {
      final users = await _getActiveUsers();

      for (final userId in users) {
        await _notificationService.createNotification(
          userId: userId,
          title: title,
          message: message,
          type: NotificationType.systemUpdate,
          priority: priority,
          actionData: actionData,
          category: 'system',
        );
      }

      if (kDebugMode) {
        debugPrint('📢 Sent system update to ${users.length} users: $title');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error sending system update: $e');
      }
    }
  }

  /// Send location-based notification for nearby events
  Future<void> sendLocationBasedNotification({
    required String userId,
    required String title,
    required String message,
    required String templeId,
    String? eventId,
    Map<String, dynamic>? actionData,
  }) async {
    try {
      await _notificationService.createNotification(
        userId: userId,
        title: title,
        message: message,
        type: NotificationType.eventReminder,
        priority: NotificationPriority.normal,
        relatedId: templeId,
        relatedType: eventId != null ? 'temple_event' : 'temple',
        actionData: {
          'templeId': templeId,
          if (eventId != null) 'eventId': eventId,
          'action': 'view_nearby',
          ...?actionData,
        },
        category: 'location_based',
      );

      if (kDebugMode) {
        debugPrint('📢 Sent location-based notification to user $userId');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error sending location-based notification: $e');
      }
    }
  }

  /// Dispose resources
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
    _isInitialized = false;
  }
}
