import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../temple/services/live_darshan_service.dart';

/// Service for managing admin notifications related to live streaming.
/// Live darshan status is read directly from Firestore.
class AdminNotificationService {
  static final AdminNotificationService _instance =
      AdminNotificationService._internal();
  factory AdminNotificationService() => _instance;
  AdminNotificationService._internal();

  FirebaseFirestore? _firestore;
  LiveDarshanService? _liveDarshanService;
  Timer? _monitoringTimer;

  // Notification types
  static const String streamingIssue = 'streaming_issue';
  static const String channelProblem = 'channel_problem';
  static const String configurationError = 'configuration_error';
  static const String liveStatusChange = 'live_status_change';

  Future<void> initialize({
    FirebaseFirestore? firestore,
    LiveDarshanService? liveDarshanService,
  }) async {
    _firestore = firestore ?? FirebaseFirestore.instance;
    _liveDarshanService = liveDarshanService ?? LiveDarshanService();
    await _liveDarshanService!.initialize();
    _startMonitoring();
    if (kDebugMode) debugPrint('AdminNotificationService: Initialized');
  }

  void _startMonitoring() {
    _monitoringTimer = Timer.periodic(const Duration(minutes: 30), (_) async {
      await _checkAllTemplesStreamingStatus();
    });
  }

  /// Check streaming status for all temples — reads from Firestore.
  Future<void> _checkAllTemplesStreamingStatus() async {
    try {
      final snapshot = await _firestore!
          .collection('temples')
          .where('liveDarshan.isConfiguredByAdmin', isEqualTo: true)
          .get();

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final templeName = data['name'] as String? ?? 'Unknown Temple';
        await _checkTempleStreamingStatus(doc.id, templeName, data);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AdminNotificationService: Error checking temples — $e');
      }
    }
  }

  Future<void> _checkTempleStreamingStatus(
    String templeId,
    String templeName,
    Map<String, dynamic> data,
  ) async {
    try {
      final liveDarshan = data['liveDarshan'] as Map<String, dynamic>?;
      final youtubeChannelId = liveDarshan?['youtubeChannelId'] as String?;

      if (youtubeChannelId == null) {
        await _createNotification(
          type: configurationError,
          title: 'Configuration Issue',
          message:
              'Temple "$templeName" has live darshan enabled but no YouTube channel ID',
          templeId: templeId,
          templeName: templeName,
        );
        return;
      }

      // Validate channel is reachable
      final channelUrl = liveDarshan?['youtubeChannelUrl'] as String? ?? '';
      final isChannelValid = await _liveDarshanService!.validateYouTubeChannel(
        channelUrl,
      );
      if (!isChannelValid) {
        await _createNotification(
          type: channelProblem,
          title: 'Channel Access Issue',
          message:
              'YouTube channel for "$templeName" is not accessible or may have been deleted',
          templeId: templeId,
          templeName: templeName,
        );
        return;
      }

      // Compare current vs stored live status (both from Firestore)
      final isCurrentlyLive = await _liveDarshanService!.isChannelLive(
        youtubeChannelId,
      );
      final wasLive = data['isCurrentlyLive'] as bool? ?? false;

      if (isCurrentlyLive != wasLive) {
        await _createNotification(
          type: liveStatusChange,
          title: isCurrentlyLive ? 'Temple Went Live' : 'Temple Went Offline',
          message: isCurrentlyLive
              ? '"$templeName" is now streaming live darshan'
              : '"$templeName" has stopped live streaming',
          templeId: templeId,
          templeName: templeName,
          priority: isCurrentlyLive ? 'high' : 'normal',
        );
      }

      // Check for long inactivity
      final lastCheck = data['lastLiveCheck'];
      if (lastCheck != null && !isCurrentlyLive) {
        DateTime? lastCheckDate;
        if (lastCheck is Timestamp) {
          lastCheckDate = lastCheck.toDate();
        } else if (lastCheck is String) {
          lastCheckDate = DateTime.tryParse(lastCheck);
        }
        if (lastCheckDate != null) {
          final daysSince = DateTime.now().difference(lastCheckDate).inDays;
          if (daysSince > 7) {
            await _createNotification(
              type: streamingIssue,
              title: 'Streaming Inactive',
              message: '"$templeName" has not streamed for $daysSince days',
              templeId: templeId,
              templeName: templeName,
              priority: 'low',
            );
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'AdminNotificationService: Error checking temple $templeId — $e',
        );
      }
    }
  }

  Future<void> _createNotification({
    required String type,
    required String title,
    required String message,
    required String templeId,
    required String templeName,
    String priority = 'normal',
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final existing = await _firestore!
          .collection('admin_notifications')
          .where('type', isEqualTo: type)
          .where('templeId', isEqualTo: templeId)
          .where('isRead', isEqualTo: false)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        await existing.docs.first.reference.update({
          'message': message,
          'updatedAt': FieldValue.serverTimestamp(),
          'count': FieldValue.increment(1),
        });
        return;
      }

      await _firestore!.collection('admin_notifications').add({
        'type': type,
        'title': title,
        'message': message,
        'templeId': templeId,
        'templeName': templeName,
        'priority': priority,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'count': 1,
        if (additionalData != null) ...additionalData,
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'AdminNotificationService: Error creating notification — $e',
        );
      }
    }
  }

  Stream<List<AdminNotification>> getNotifications() {
    return _firestore!
        .collection('admin_notifications')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (s) => s.docs.map(AdminNotification.fromFirestore).toList(),
        );
  }

  Stream<int> getUnreadCount() {
    return _firestore!
        .collection('admin_notifications')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((s) => s.docs.length);
  }

  Future<void> markAsRead(String notificationId) async {
    await _firestore!
        .collection('admin_notifications')
        .doc(notificationId)
        .update({'isRead': true, 'readAt': FieldValue.serverTimestamp()});
  }

  Future<void> markAllAsRead() async {
    final batch = _firestore!.batch();
    final unread = await _firestore!
        .collection('admin_notifications')
        .where('isRead', isEqualTo: false)
        .get();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  Future<void> deleteNotification(String notificationId) async {
    await _firestore!
        .collection('admin_notifications')
        .doc(notificationId)
        .delete();
  }

  Future<void> clearOldNotifications() async {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    final old = await _firestore!
        .collection('admin_notifications')
        .where('createdAt', isLessThan: Timestamp.fromDate(cutoff))
        .get();
    final batch = _firestore!.batch();
    for (final doc in old.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Future<void> checkTempleStatus(String templeId) async {
    try {
      final doc = await _firestore!.collection('temples').doc(templeId).get();
      if (!doc.exists) return;

      final data = doc.data()!;
      final templeName = data['name'] as String? ?? 'Unknown Temple';
      await _checkTempleStreamingStatus(templeId, templeName, data);
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'AdminNotificationService: Error checking temple $templeId — $e',
        );
      }
    }
  }

  void dispose() {
    _monitoringTimer?.cancel();
    _liveDarshanService?.dispose();
  }
}

class AdminNotification {
  final String id;
  final String type;
  final String title;
  final String message;
  final String templeId;
  final String templeName;
  final String priority;
  final bool isRead;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? readAt;
  final int count;
  final Map<String, dynamic>? additionalData;

  const AdminNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.templeId,
    required this.templeName,
    required this.priority,
    required this.isRead,
    required this.createdAt,
    required this.updatedAt,
    this.readAt,
    required this.count,
    this.additionalData,
  });

  factory AdminNotification.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return AdminNotification(
      id: doc.id,
      type: data['type'] as String,
      title: data['title'] as String,
      message: data['message'] as String,
      templeId: data['templeId'] as String,
      templeName: data['templeName'] as String,
      priority: data['priority'] as String? ?? 'normal',
      isRead: data['isRead'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      readAt: data['readAt'] != null
          ? (data['readAt'] as Timestamp).toDate()
          : null,
      count: data['count'] as int? ?? 1,
      additionalData: data['additionalData'] as Map<String, dynamic>?,
    );
  }

  IconData get icon {
    switch (type) {
      case AdminNotificationService.streamingIssue:
        return Icons.warning;
      case AdminNotificationService.channelProblem:
        return Icons.error;
      case AdminNotificationService.configurationError:
        return Icons.settings_input_antenna;
      case AdminNotificationService.liveStatusChange:
        return Icons.live_tv;
      default:
        return Icons.notifications;
    }
  }

  Color get color {
    switch (priority) {
      case 'high':
        return Colors.red;
      case 'low':
        return Colors.orange;
      default:
        return Colors.orange;
    }
  }
}
