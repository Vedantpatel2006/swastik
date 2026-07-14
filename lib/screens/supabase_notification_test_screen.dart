import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swastik/shared/services/supabase_notification_service.dart';
import 'package:swastik/shared/models/notification.dart';

/// Test screen for Supabase notifications
/// Navigate to this screen from NotificationsScreen for testing
class SupabaseNotificationTestScreen extends StatefulWidget {
  const SupabaseNotificationTestScreen({super.key});

  @override
  State<SupabaseNotificationTestScreen> createState() =>
      _SupabaseNotificationTestScreenState();
}

class _SupabaseNotificationTestScreenState
    extends State<SupabaseNotificationTestScreen> {
  final SupabaseNotificationService _notificationService =
      SupabaseNotificationService();
  String _status = 'Ready to test';
  String? _userId;
  List<UserNotification> _notifications = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final user = FirebaseAuth.instance.currentUser;
    _userId = user?.uid;

    if (_userId != null) {
      await _notificationService.initialize(userId: _userId!);
      _loadNotifications();

      setState(() {
        _status = 'Connected to Supabase\nUser: $_userId';
      });
    } else {
      setState(() {
        _status = 'Error: No user logged in';
      });
    }
  }

  Future<void> _loadNotifications() async {
    if (_userId == null) return;

    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('user_notifications')
          .select()
          .eq('user_id', _userId!)
          .order('created_at', ascending: false)
          .limit(20);

      final notifications = (response as List)
          .map((json) => _mapToNotification(json as Map<String, dynamic>))
          .toList();

      setState(() {
        _notifications = notifications;
      });
    } catch (e) {
      setState(() {
        _status = 'Error loading notifications: $e';
      });
    }
  }

  Future<void> _createTestNotification() async {
    if (_userId == null) return;

    setState(() => _isLoading = true);

    try {
      final notificationId = await _notificationService.createNotification(
        userId: _userId!,
        title: '✅ Supabase Test Notification',
        message:
            'This notification is stored in Supabase!\nCreated at ${DateTime.now().toLocal()}',
        type: NotificationType.general,
        priority: NotificationPriority.normal,
        category: 'test',
      );

      setState(() {
        _status =
            'Success! Created notification:\n$notificationId\n\nRefresh to see it below.';
      });

      _loadNotifications();
    } catch (e) {
      setState(() {
        _status = 'Error creating notification:\n$e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createLiveDarshanNotification() async {
    if (_userId == null) return;

    setState(() => _isLoading = true);

    try {
      final notificationId = await _notificationService.createNotification(
        userId: _userId!,
        title: '🔴 Live Darshan Started',
        message: 'Shree Kashtabhanjan Dev Hanumanji Mandir is now live',
        type: NotificationType.liveStreamStarted,
        priority: NotificationPriority.high,
        relatedId: 'temple_fp1xhyty85PB98ghcM5k',
        relatedType: 'temple',
        actionData: {
          'templeId': 'fp1xhyty85PB98ghcM5k',
          'action': 'open_live_stream',
        },
      );

      setState(() {
        _status = 'Created live darshan notification:\n$notificationId';
      });

      _loadNotifications();
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      await _notificationService.markAsRead(notificationId);
      _loadNotifications();
    } catch (e) {
      setState(() => _status = 'Error marking as read: $e');
    }
  }

  Future<void> _deleteNotification(String notificationId) async {
    try {
      await _notificationService.deleteNotification(notificationId);
      _loadNotifications();
    } catch (e) {
      setState(() => _status = 'Error deleting: $e');
    }
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Supabase Notification Test')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Status:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(_status),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Test Buttons
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _createTestNotification,
              icon: const Icon(Icons.notification_add),
              label: const Text('Create Test Notification'),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _createLiveDarshanNotification,
              icon: const Icon(Icons.videocam),
              label: const Text('Create Live Darshan Notification'),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _loadNotifications,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
            const SizedBox(height: 20),

            // Instructions
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📝 Instructions:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text('1. Click "Create Test Notification"'),
                    Text('2. See notification created (status above)'),
                    Text('3. Click "Refresh" to see it appear below'),
                    Text('4. Tap notification to mark as read'),
                    Text('5. Slide to delete'),
                    SizedBox(height: 8),
                    Text(
                      '✅ If this works, Supabase notifications are working!',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Notifications List
            Text(
              'Recent Notifications (${_notifications.length}):',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            _notifications.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text('No notifications yet. Create one above!'),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _notifications.length,
                    itemBuilder: (context, index) {
                      final notification = _notifications[index];
                      return Card(
                        child: Dismissible(
                          key: Key(notification.id),
                          onDismissed: (_) =>
                              _deleteNotification(notification.id),
                          background: Container(
                            color: Colors.red,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 16),
                            child: const Icon(
                              Icons.delete,
                              color: Colors.white,
                            ),
                          ),
                          child: ListTile(
                            title: Text(notification.title),
                            subtitle: Text(notification.message),
                            trailing: Checkbox(
                              value: notification.isRead,
                              onChanged: (_) => _markAsRead(notification.id),
                            ),
                            dense: true,
                            tileColor: notification.isRead
                                ? Colors.grey[100]
                                : Colors.orange[50],
                          ),
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }
}
