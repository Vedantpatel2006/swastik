import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/booking.dart';
import '../models/notification.dart';
import 'supabase_notification_service.dart';
import 'service_container.dart';

/// Service for processing booking reminders backed by Supabase.
///
/// Reads from `public.booking_reminders` and `public.bookings` tables.
/// Reminders are created by the `create-booking` Edge Function.
class BookingReminderService {
  static final BookingReminderService _instance =
      BookingReminderService._internal();
  factory BookingReminderService() => _instance;
  BookingReminderService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  // Use centralized service container for NotificationService
  SupabaseNotificationService get _notificationService =>
      services.notificationService;

  Timer? _reminderTimer;
  bool _isProcessing = false;

  static const String _remindersTable = 'booking_reminders';
  static const String _bookingsTable = 'bookings';
  static const String _templesTable = 'temples';

  /// Initialize the reminder processing service
  Future<void> initialize() async {
    // Start processing reminders every 5 minutes
    _reminderTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _processReminders(),
    );

    if (kDebugMode) {
      debugPrint(
        'BookingReminderService: Initialized with 5-minute processing interval',
      );
    }
  }

  /// Process pending booking reminders
  Future<void> _processReminders() async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      final now = DateTime.now().toUtc();

      // Only process reminders for the currently signed-in user
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        if (kDebugMode) {
          debugPrint('BookingReminderService: No signed-in user, skipping');
        }
        return;
      }

      // Query due, unprocessed reminders for this user from Supabase
      final rows = await _supabase
          .from(_remindersTable)
          .select()
          .eq('user_id', currentUser.uid)
          .eq('is_processed', false)
          .lte('reminder_time', now.toIso8601String())
          .limit(50);

      if (rows.isEmpty) {
        if (kDebugMode) {
          debugPrint('BookingReminderService: No pending reminders found');
        }
        return;
      }

      if (kDebugMode) {
        debugPrint(
          'BookingReminderService: Processing ${rows.length} reminders',
        );
      }

      int processedCount = 0;
      final processedIds = <String>[];
      final errorIds = <Map<String, String>>[];

      for (final reminderRow in rows) {
        final reminderId = reminderRow['id'] as String;
        try {
          final bookingId = reminderRow['booking_id'] as String?;
          if (bookingId == null) {
            errorIds.add({'id': reminderId, 'error': 'missing booking_id'});
            continue;
          }

          final reminderType =
              reminderRow['reminder_type'] as String? ?? 'booking_reminder';

          // Fetch booking from Supabase
          final bookingRows = await _supabase
              .from(_bookingsTable)
              .select()
              .eq('id', bookingId)
              .limit(1);

          if (bookingRows.isEmpty) {
            if (kDebugMode) {
              debugPrint(
                'BookingReminderService: Booking $bookingId not found, skipping reminder',
              );
            }
            processedIds.add(reminderId);
            continue;
          }

          final booking = Booking.fromSupabase(bookingRows.first);

          // Fetch temple name from Supabase
          final templeName = await _getTempleName(booking.templeId);

          // Create notification
          await _createReminderNotification(booking, templeName, reminderType);

          processedIds.add(reminderId);
          processedCount++;
        } catch (e) {
          if (kDebugMode) {
            debugPrint(
              'BookingReminderService: Error processing reminder $reminderId: $e',
            );
          }
          errorIds.add({'id': reminderId, 'error': e.toString()});
        }
      }

      // Batch-mark processed reminders
      if (processedIds.isNotEmpty) {
        await _supabase
            .from(_remindersTable)
            .update({'is_processed': true})
            .inFilter('id', processedIds);
      }

      // Mark errored reminders as processed to avoid infinite retries
      for (final entry in errorIds) {
        final id = entry['id'];
        if (id == null) continue;
        await _supabase
            .from(_remindersTable)
            .update({
              'is_processed': true,
              'metadata': {'error': entry['error']},
            })
            .eq('id', id);
      }

      if (kDebugMode) {
        debugPrint(
          'BookingReminderService: Successfully processed $processedCount reminders',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('BookingReminderService: Error processing reminders: $e');
      }
    } finally {
      _isProcessing = false;
    }
  }

  /// Get temple name from Supabase temples table
  Future<String> _getTempleName(String templeId) async {
    try {
      final rows = await _supabase
          .from(_templesTable)
          .select('name')
          .eq('id', templeId)
          .limit(1);

      if (rows.isNotEmpty) {
        return rows.first['name'] as String? ?? 'Unknown Temple';
      }
      return 'Unknown Temple';
    } catch (e) {
      if (kDebugMode) {
        debugPrint('BookingReminderService: Error getting temple name: $e');
      }
      return 'Unknown Temple';
    }
  }

  /// Create notification for booking reminder
  Future<void> _createReminderNotification(
    Booking booking,
    String templeName,
    String reminderType,
  ) async {
    try {
      String title;
      String message;
      NotificationPriority priority = NotificationPriority.high;

      switch (reminderType) {
        case '24_hour':
        case 'booking_reminder_24h':
          title = 'Booking Reminder - Tomorrow';
          message =
              'Your booking at $templeName is tomorrow at ${_formatTime(booking.bookingDateTime)}';
          break;
        case '1_hour':
        case 'booking_reminder_2h':
          title = 'Booking Reminder - 1 Hour';
          message =
              'Your booking at $templeName is in 1 hour at ${_formatTime(booking.bookingDateTime)}';
          priority = NotificationPriority.urgent;
          break;
        case 'booking_reminder_30m':
          title = 'Booking Reminder - 30 Minutes';
          message =
              'Your booking at $templeName starts in 30 minutes. Please arrive on time.';
          priority = NotificationPriority.urgent;
          break;
        default:
          title = 'Booking Reminder';
          message = 'You have an upcoming booking at $templeName';
      }

      await _notificationService.createNotification(
        userId: booking.userId,
        title: title,
        message: message,
        type: NotificationType.bookingReminder,
        priority: priority,
        relatedId: booking.id,
        relatedType: 'booking',
        actionData: {
          'bookingId': booking.id,
          'templeId': booking.templeId,
          'templeName': templeName,
          'bookingTime': booking.bookingDateTime.toIso8601String(),
          'reminderType': reminderType,
        },
      );

      if (kDebugMode) {
        debugPrint(
          'BookingReminderService: Created $reminderType notification for booking ${booking.id}',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'BookingReminderService: Error creating reminder notification: $e',
        );
      }
      rethrow;
    }
  }

  /// Format time for display
  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }

  /// Manually process reminders (for testing or immediate processing)
  Future<void> processRemindersNow() async {
    if (kDebugMode) {
      debugPrint(
        'BookingReminderService: Manual reminder processing triggered',
      );
    }
    await _processReminders();
  }

  /// Get count of pending unprocessed reminders for the current user
  Future<int> getPendingRemindersCount() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return 0;

      final rows = await _supabase
          .from(_remindersTable)
          .select('id')
          .eq('user_id', currentUser.uid)
          .eq('is_processed', false);

      return rows.length;
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'BookingReminderService: Error getting pending reminders count: $e',
        );
      }
      return 0;
    }
  }

  /// Get processed reminders for a specific booking
  Future<List<Map<String, dynamic>>> getProcessedReminders(
    String bookingId,
  ) async {
    try {
      final rows = await _supabase
          .from(_remindersTable)
          .select()
          .eq('booking_id', bookingId)
          .eq('is_processed', true)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'BookingReminderService: Error getting processed reminders: $e',
        );
      }
      return [];
    }
  }

  /// Dispose resources
  void dispose() {
    _reminderTimer?.cancel();
    _reminderTimer = null;
  }
}
