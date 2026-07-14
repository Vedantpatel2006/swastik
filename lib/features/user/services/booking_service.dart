import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/models/booking.dart';
import '../../../shared/models/temple.dart';
import '../../../shared/models/payment_transaction.dart';
import '../../../shared/services/supabase_notification_service.dart';
import '../../../shared/models/notification.dart';
import '../../temple/services/stripe_payment_service.dart';
import '../../temple/services/user_temple_service.dart';

/// Service for managing temple bookings backed by Supabase Postgres.
///
/// All booking data is stored in the `public.bookings` table.
/// Reminders are stored in `public.booking_reminders`.
/// Availability checks and atomic creation go through Supabase Edge Functions.
class BookingService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final SupabaseNotificationService _notificationService =
      SupabaseNotificationService();
  final StripePaymentService _stripePayment = StripePaymentService.instance;
  final UserTempleService _templeService = UserTempleService();

  static const String _bookingsTable = 'bookings';
  static const String _remindersTable = 'booking_reminders';

  // ─── Read ────────────────────────────────────────────────────────────────

  /// All bookings for a user, newest first.
  Future<List<Booking>> getUserBookings(String userId) async {
    try {
      final rows = await _supabase
          .from(_bookingsTable)
          .select()
          .eq('user_id', userId)
          .order('booking_date', ascending: false);

      return rows.map((r) => Booking.fromSupabase(r)).toList();
    } catch (e) {
      throw Exception('Failed to fetch user bookings: $e');
    }
  }

  /// Upcoming (future, pending/confirmed) bookings for a user.
  Future<List<Booking>> getUpcomingBookings(String userId) async {
    try {
      final now = DateTime.now().toIso8601String();
      final rows = await _supabase
          .from(_bookingsTable)
          .select()
          .eq('user_id', userId)
          .gte('booking_date', now)
          .inFilter('status', ['pending', 'confirmed'])
          .order('booking_date');

      return rows
          .map((r) => Booking.fromSupabase(r))
          .where((b) => b.isFuture)
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch upcoming bookings: $e');
    }
  }

  /// Past bookings for a user.
  Future<List<Booking>> getPastBookings(String userId) async {
    try {
      final now = DateTime.now().toIso8601String();
      final rows = await _supabase
          .from(_bookingsTable)
          .select()
          .eq('user_id', userId)
          .lt('booking_date', now)
          .order('booking_date', ascending: false);

      return rows.map((r) => Booking.fromSupabase(r)).toList();
    } catch (e) {
      throw Exception('Failed to fetch past bookings: $e');
    }
  }

  /// Paginated bookings using range (offset-based).
  Future<List<Booking>> getUserBookingsPaginated(
    String userId, {
    required int pageSize,
    required int pageNumber,
  }) async {
    try {
      final from = pageNumber * pageSize;
      final to = from + pageSize - 1;

      final rows = await _supabase
          .from(_bookingsTable)
          .select()
          .eq('user_id', userId)
          .order('booking_date', ascending: false)
          .range(from, to);

      return rows.map((r) => Booking.fromSupabase(r)).toList();
    } catch (e) {
      throw Exception('Failed to fetch paginated bookings: $e');
    }
  }

  /// Real-time stream of all bookings for a user.
  Stream<List<Booking>> watchUserBookings(String userId) {
    return _supabase
        .from(_bookingsTable)
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('booking_date', ascending: false)
        .map((rows) => rows.map((r) => Booking.fromSupabase(r)).toList());
  }

  /// Real-time stream of paginated bookings.
  Stream<List<Booking>> watchUserBookingsPaginated(
    String userId, {
    required int pageSize,
  }) {
    return _supabase
        .from(_bookingsTable)
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('booking_date', ascending: false)
        .limit(pageSize)
        .map((rows) => rows.map((r) => Booking.fromSupabase(r)).toList());
  }

  /// Get a single booking by ID.
  Future<Booking?> getBookingById(String bookingId) async {
    try {
      final rows = await _supabase
          .from(_bookingsTable)
          .select()
          .eq('id', bookingId)
          .limit(1);

      if (rows.isEmpty) return null;
      return Booking.fromSupabase(rows.first);
    } catch (e) {
      throw Exception('Failed to get booking: $e');
    }
  }

  /// All bookings for a temple (admin use).
  Future<List<Booking>> getTempleBookings(String templeId) async {
    try {
      final rows = await _supabase
          .from(_bookingsTable)
          .select()
          .eq('temple_id', templeId)
          .order('booking_date', ascending: false);

      return rows.map((r) => Booking.fromSupabase(r)).toList();
    } catch (e) {
      throw Exception('Failed to fetch temple bookings: $e');
    }
  }

  // ─── Availability ────────────────────────────────────────────────────────

  /// Get available time slots for a temple on a given date.
  Future<List<TimeOfDay>> getAvailableSlots(
    String templeId,
    DateTime date,
    String bookingType,
  ) async {
    try {
      final temple = await _templeService.getTempleDetails(templeId);
      if (temple == null) throw Exception('Temple not found');

      final allSlots = _generateTimeSlots(temple, date, bookingType);
      if (allSlots.isEmpty) return [];

      // Fetch all booked slots for this temple/date in one query
      final startOfDay = DateFormat('yyyy-MM-dd').format(date);
      final endOfDay = DateFormat(
        'yyyy-MM-dd',
      ).format(date.add(const Duration(days: 1)));

      final rows = await _supabase
          .from(_bookingsTable)
          .select('booking_time')
          .eq('temple_id', templeId)
          .gte('booking_date', startOfDay)
          .lt('booking_date', endOfDay)
          .inFilter('status', ['pending', 'confirmed']);

      final bookedTimes = <String>{
        for (final r in rows) r['booking_time'] as String,
      };

      final available = allSlots
          .where((slot) => !bookedTimes.contains(_timeOfDayToString(slot)))
          .toList();

      if (kDebugMode) {
        debugPrint(
          '✅ ${available.length}/${allSlots.length} slots available for $templeId on $date',
        );
      }

      return available;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Failed to get available slots: $e');
      throw Exception('Failed to get available slots: $e');
    }
  }

  /// Real-time stream of available slots — updates when bookings change.
  Stream<List<TimeOfDay>> watchAvailableSlots({
    required String templeId,
    required DateTime date,
    required String bookingType,
  }) {
    final startOfDay = DateFormat('yyyy-MM-dd').format(date);
    final endOfDay = DateFormat(
      'yyyy-MM-dd',
    ).format(date.add(const Duration(days: 1)));

    return _supabase
        .from(_bookingsTable)
        .stream(primaryKey: ['id'])
        .eq('temple_id', templeId)
        .map((rows) {
          // Filter to this date and active statuses in Dart
          final bookedTimes = <String>{};
          for (final r in rows) {
            final bookingDate = r['booking_date'] as String? ?? '';
            final status = r['status'] as String? ?? '';
            if (bookingDate.compareTo(startOfDay) >= 0 &&
                bookingDate.compareTo(endOfDay) < 0 &&
                (status == 'pending' || status == 'confirmed')) {
              bookedTimes.add(r['booking_time'] as String? ?? '');
            }
          }
          return bookedTimes;
        })
        .asyncMap((bookedTimes) async {
          try {
            final temple = await _templeService.getTempleDetails(templeId);
            if (temple == null) return <TimeOfDay>[];
            final allSlots = _generateTimeSlots(temple, date, bookingType);
            return allSlots
                .where((s) => !bookedTimes.contains(_timeOfDayToString(s)))
                .toList()
              ..sort(
                (a, b) => a.hour != b.hour
                    ? a.hour.compareTo(b.hour)
                    : a.minute.compareTo(b.minute),
              );
          } catch (_) {
            return <TimeOfDay>[];
          }
        });
  }

  // ─── Write ───────────────────────────────────────────────────────────────

  /// Create a booking via the `create-booking` Edge Function.
  /// The function checks availability atomically and inserts the row.
  Future<Booking> createBooking(Booking booking) async {
    try {
      if (!booking.isValid()) throw ArgumentError('Invalid booking data');

      // Get Firebase ID token to authenticate with the Supabase Edge Function.
      // The Edge Function verifies this token against Firebase's public keys.
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');
      final idToken = await user.getIdToken();

      final response = await _supabase.functions.invoke(
        'create-booking',
        headers: {'Authorization': 'Bearer $idToken'},
        body: {
          'templeId': booking.templeId,
          'bookingDate': DateFormat('yyyy-MM-dd').format(booking.bookingDate),
          'bookingTime': _timeOfDayToString(booking.bookingTime),
          'numberOfPeople': booking.numberOfPeople,
          'bookingType': booking.bookingType,
          if (booking.specialRequests != null)
            'specialRequests': booking.specialRequests,
          if (booking.contactName != null) 'contactName': booking.contactName,
          if (booking.contactPhone != null)
            'contactPhone': booking.contactPhone,
          if (booking.contactEmail != null)
            'contactEmail': booking.contactEmail,
          if (booking.amount != null) 'amount': booking.amount,
          'currency': booking.currency ?? 'USD',
          if (booking.paymentStatus != null)
            'paymentStatus': booking.paymentStatus!.name,
          if (booking.paymentIntentId != null)
            'paymentIntentId': booking.paymentIntentId,
          if (booking.transactionId != null)
            'transactionId': booking.transactionId,
          if (booking.metadata != null) 'metadata': booking.metadata,
        },
      );

      if (response.status != 201) {
        final error = response.data?['error'] ?? 'Failed to create booking';
        throw Exception(error);
      }

      final createdBooking = Booking.fromSupabase(
        response.data['booking'] as Map<String, dynamic>,
      );

      // Send confirmation notification (non-blocking)
      _sendBookingConfirmation(
        createdBooking,
      ).catchError((e) => debugPrint('Notification error: $e'));

      if (kDebugMode) debugPrint('✅ Booking created: ${createdBooking.id}');
      return createdBooking;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Booking creation failed: $e');
      throw Exception('Failed to create booking: $e');
    }
  }

  /// Initialize booking payment with Stripe using a real booking ID.
  Future<PaymentTransaction> initializeBookingPayment({
    required Booking booking,
    required Map<String, dynamic> customerInfo,
  }) async {
    try {
      if (booking.amount == null || booking.amount! <= 0) {
        throw ArgumentError('Booking must have a valid amount for payment');
      }
      if (booking.id.isEmpty) {
        throw ArgumentError('Booking must have a valid ID before payment');
      }
      await _stripePayment.initialize();
      final transaction = await _stripePayment.processBookingPayment(
        booking: booking,
        customerInfo: customerInfo,
      );
      if (kDebugMode) {
        debugPrint('✅ Booking payment initialized: ${transaction.id}');
      }
      return transaction;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Failed to initialize booking payment: $e');
      throw Exception('Failed to initialize booking payment: $e');
    }
  }

  /// Create booking first (as pending), then process payment with the real ID.
  ///
  /// Order of operations:
  ///   1. Save booking to Supabase with status=pending, paymentStatus=pending
  ///   2. Present Stripe Payment Sheet using the real booking ID in metadata
  ///   3. On success → update booking to confirmed + paid
  ///   4. On failure → cancel the pending booking so the slot is freed
  Future<Booking> createBookingWithPayment({
    required Booking booking,
    required Map<String, dynamic> customerInfo,
  }) async {
    if (!booking.isValid()) throw ArgumentError('Invalid booking data');
    if (booking.amount == null || booking.amount! <= 0) {
      throw ArgumentError('Booking must have a valid amount for payment');
    }

    // Step 1: Create booking as pending so we have a real ID for the payment intent.
    final pendingBooking = await createBooking(
      booking.copyWith(
        status: BookingStatus.pending,
        paymentStatus: BookingPaymentStatus.pending,
      ),
    );

    if (kDebugMode)
      debugPrint('📋 Pending booking created: ${pendingBooking.id}');

    try {
      // Step 2: Process payment with the real booking ID in Stripe metadata.
      final transaction = await initializeBookingPayment(
        booking: pendingBooking,
        customerInfo: customerInfo,
      );

      if (!transaction.isSuccessful) {
        // Payment failed — cancel the pending booking to free the slot.
        await _cancelPendingBookingAfterPaymentFailure(pendingBooking.id);
        throw Exception('Payment failed: ${transaction.failureReason}');
      }

      // Step 3: Update booking to confirmed + paid.
      final confirmedBooking = pendingBooking.copyWith(
        paymentStatus: BookingPaymentStatus.paid,
        paymentIntentId: transaction.gatewayOrderId,
        transactionId: transaction.id,
        status: BookingStatus.confirmed,
        metadata: {
          ...?pendingBooking.metadata,
          'gateway': 'stripe',
          'payment_intent_id': transaction.gatewayOrderId,
          'paid_at': DateTime.now().toIso8601String(),
        },
      );

      await _supabase
          .from(_bookingsTable)
          .update({
            'status': BookingStatus.confirmed.name,
            'payment_status': BookingPaymentStatus.paid.name,
            'payment_intent_id': transaction.gatewayOrderId,
            'transaction_id': transaction.id,
            'metadata': confirmedBooking.metadata,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', pendingBooking.id);

      if (kDebugMode)
        debugPrint('✅ Booking confirmed after payment: ${pendingBooking.id}');
      return confirmedBooking;
    } catch (e) {
      // Cancel the pending booking to free the slot regardless of error type.
      await _cancelPendingBookingAfterPaymentFailure(pendingBooking.id);
      if (kDebugMode) debugPrint('❌ Failed to create booking with payment: $e');
      // Re-throw so the UI can handle cancellation vs real errors.
      rethrow;
    }
  }

  /// Cancel a pending booking when payment fails or is cancelled.
  Future<void> _cancelPendingBookingAfterPaymentFailure(
    String bookingId,
  ) async {
    try {
      await _supabase
          .from(_bookingsTable)
          .update({
            'status': BookingStatus.cancelled.name,
            'payment_status': BookingPaymentStatus.failed.name,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', bookingId);
      if (kDebugMode)
        debugPrint(
          '🗑️ Pending booking cancelled after payment failure: $bookingId',
        );
    } catch (e) {
      if (kDebugMode)
        debugPrint('⚠️ Could not cancel pending booking $bookingId: $e');
    }
  }

  /// Update booking status.
  Future<void> updateBookingStatus(
    String bookingId,
    BookingStatus status,
  ) async {
    try {
      await _supabase
          .from(_bookingsTable)
          .update({
        'status': status.name,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', bookingId);
    } catch (e) {
      throw Exception('Failed to update booking status: $e');
    }
  }

  /// Cancel a booking (requires 2-hour notice).
  Future<void> cancelBooking(String bookingId) async {
    try {
      final booking = await getBookingById(bookingId);
      if (booking == null) throw Exception('Booking not found');
      if (!booking.canBeCancelled) {
        throw Exception('Booking cannot be cancelled');
      }

      await updateBookingStatus(bookingId, BookingStatus.cancelled);
      await _cancelBookingReminders(bookingId);
      _sendBookingCancellation(
        booking,
      ).catchError((e) => debugPrint('Cancellation notification error: $e'));
    } catch (e) {
      throw Exception('Failed to cancel booking: $e');
    }
  }

  /// Modify an existing booking (requires 24-hour notice).
  Future<void> modifyBooking(String bookingId, Booking updatedBooking) async {
    try {
      final current = await getBookingById(bookingId);
      if (current == null) throw Exception('Booking not found');
      if (!current.canBeModified) throw Exception('Booking cannot be modified');
      if (!updatedBooking.isValid())
        throw ArgumentError('Invalid booking data');

      // If date/time changed, verify the new slot is available
      final dateChanged = current.bookingDate != updatedBooking.bookingDate;
      final timeChanged = current.bookingTime != updatedBooking.bookingTime;
      if (dateChanged || timeChanged) {
        final isAvailable = await _isTimeSlotAvailable(
          updatedBooking.templeId,
          updatedBooking.bookingDate,
          updatedBooking.bookingTime,
          excludeBookingId: bookingId,
        );
        if (!isAvailable) {
          throw Exception('The selected time slot is not available');
        }
      }

      await _supabase
          .from(_bookingsTable)
          .update(updatedBooking.toSupabaseJson())
          .eq('id', bookingId);

      if (dateChanged || timeChanged) {
        await _cancelBookingReminders(bookingId);
        await _scheduleReminders(updatedBooking.copyWith(id: bookingId));
      }
    } catch (e) {
      throw Exception('Failed to modify booking: $e');
    }
  }

  /// Confirm a booking.
  Future<void> confirmBooking(String bookingId) =>
      updateBookingStatus(bookingId, BookingStatus.confirmed);

  /// Mark booking as completed.
  Future<void> completeBooking(String bookingId) =>
      updateBookingStatus(bookingId, BookingStatus.completed);

  /// Mark booking as no-show.
  Future<void> markNoShow(String bookingId) =>
      updateBookingStatus(bookingId, BookingStatus.noShow);

  /// Delete a booking (admin only).
  Future<void> deleteBooking(String bookingId) async {
    try {
      await _supabase.from(_bookingsTable).delete().eq('id', bookingId);
    } catch (e) {
      throw Exception('Failed to delete booking: $e');
    }
  }

  // ─── Stats ───────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getUserBookingStats(String userId) async {
    try {
      final bookings = await getUserBookings(userId);
      final byType = <String, int>{};
      final byMonth = <String, int>{};

      for (final b in bookings) {
        byType[b.bookingType] = (byType[b.bookingType] ?? 0) + 1;
        final key =
            '${b.bookingDate.year}-${b.bookingDate.month.toString().padLeft(2, '0')}';
        byMonth[key] = (byMonth[key] ?? 0) + 1;
      }

      return {
        'totalBookings': bookings.length,
        'upcomingBookings': bookings
            .where(
              (b) =>
                  b.isFuture &&
                  (b.status == BookingStatus.pending ||
                      b.status == BookingStatus.confirmed),
            )
            .length,
        'completedBookings': bookings
            .where((b) => b.status == BookingStatus.completed)
            .length,
        'cancelledBookings': bookings
            .where((b) => b.status == BookingStatus.cancelled)
            .length,
        'bookingsByType': byType,
        'bookingsByMonth': byMonth,
      };
    } catch (e) {
      throw Exception('Failed to get booking statistics: $e');
    }
  }

  // ─── Reminders ───────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getBookingReminders(
    String bookingId,
  ) async {
    try {
      final rows = await _supabase
          .from(_remindersTable)
          .select()
          .eq('booking_id', bookingId)
          .order('reminder_time');
      return List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      throw Exception('Failed to get booking reminders: $e');
    }
  }

  // ─── Private helpers ─────────────────────────────────────────────────────

  Future<bool> _isTimeSlotAvailable(
    String templeId,
    DateTime date,
    TimeOfDay time, {
    String? excludeBookingId,
  }) async {
    final startOfDay = DateFormat('yyyy-MM-dd').format(date);
    final endOfDay = DateFormat(
      'yyyy-MM-dd',
    ).format(date.add(const Duration(days: 1)));
    final timeStr = _timeOfDayToString(time);

    var query = _supabase
        .from(_bookingsTable)
        .select('id')
        .eq('temple_id', templeId)
        .eq('booking_time', timeStr)
        .gte('booking_date', startOfDay)
        .lt('booking_date', endOfDay)
        .inFilter('status', ['pending', 'confirmed']);

    final rows = await query;

    final conflicts = excludeBookingId != null
        ? rows.where((r) => r['id'] != excludeBookingId).toList()
        : rows;

    return conflicts.isEmpty;
  }

  Future<void> _scheduleReminders(Booking booking) async {
    try {
      final bookingDT = booking.bookingDateTime;
      final now = DateTime.now();

      final reminders = [
        (
          time: bookingDT.subtract(const Duration(hours: 24)),
          type: '24_hour',
          msg: 'Your temple booking is tomorrow at ${booking.formattedTime}',
        ),
        (
          time: bookingDT.subtract(const Duration(hours: 1)),
          type: '1_hour',
          msg: 'Your temple booking is in 1 hour at ${booking.formattedTime}',
        ),
      ].where((r) => r.time.isAfter(now)).toList();

      if (reminders.isEmpty) return;

      await _supabase.from(_remindersTable).insert([
        for (final r in reminders)
          {
            'booking_id': booking.id,
            'user_id': booking.userId,
            'temple_id': booking.templeId,
            'reminder_time': r.time.toIso8601String(),
            'reminder_type': r.type,
            'title': 'Temple Booking Reminder',
            'message': r.msg,
            'is_processed': false,
            'metadata': {
              'booking_type': booking.bookingType,
              'number_of_people': booking.numberOfPeople,
              'booking_date_time': bookingDT.toIso8601String(),
            },
          },
      ]);
    } catch (e) {
      debugPrint('Failed to schedule booking reminders: $e');
    }
  }

  Future<void> _cancelBookingReminders(String bookingId) async {
    try {
      await _supabase
          .from(_remindersTable)
          .update({
            'is_processed': true,
            'cancelled_at': DateTime.now().toIso8601String(),
          })
          .eq('booking_id', bookingId)
          .eq('is_processed', false);
    } catch (e) {
      debugPrint('Failed to cancel booking reminders: $e');
    }
  }

  Future<void> _sendBookingConfirmation(Booking booking) async {
    try {
      String templeName = 'Unknown Temple';
      try {
        final temple = await _templeService.getTempleDetails(booking.templeId);
        if (temple != null) templeName = temple.name;
      } catch (_) {}

      await _notificationService.createNotification(
        userId: booking.userId,
        title: 'Booking Confirmed! ✅',
        message:
            'Your booking at $templeName has been confirmed for '
            '${booking.formattedDate} at ${booking.formattedTime}. '
            'Reference: ${booking.id.substring(0, 8)}',
        type: NotificationType.bookingConfirmation,
        priority: NotificationPriority.high,
        relatedId: booking.id,
        relatedType: 'booking',
        actionData: {
          'bookingId': booking.id,
          'templeId': booking.templeId,
          'templeName': templeName,
          'bookingDate': booking.bookingDate.toIso8601String(),
          'bookingTime': _timeOfDayToString(booking.bookingTime),
          'numberOfPeople': booking.numberOfPeople,
          'bookingType': booking.bookingType,
        },
      );
    } catch (e) {
      debugPrint('Failed to send booking confirmation notification: $e');
    }
  }

  Future<void> _sendBookingCancellation(Booking booking) async {
    try {
      String templeName = 'Unknown Temple';
      try {
        final temple = await _templeService.getTempleDetails(booking.templeId);
        if (temple != null) templeName = temple.name;
      } catch (_) {}

      await _notificationService.createNotification(
        userId: booking.userId,
        title: 'Booking Cancelled',
        message:
            'Your booking at $templeName for ${booking.formattedDate} '
            'has been cancelled.',
        type: NotificationType.bookingCancellation,
        priority: NotificationPriority.normal,
        relatedId: booking.id,
        relatedType: 'booking',
        actionData: {
          'bookingId': booking.id,
          'templeId': booking.templeId,
          'templeName': templeName,
          'bookingDate': booking.bookingDate.toIso8601String(),
          'bookingTime': _timeOfDayToString(booking.bookingTime),
        },
      );
    } catch (e) {
      debugPrint('Failed to send booking cancellation notification: $e');
    }
  }

  // ─── Time slot generation ─────────────────────────────────────────────────

  List<TimeOfDay> _generateTimeSlots(
    Temple temple,
    DateTime date,
    String bookingType,
  ) {
    final dayNames = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final dayName = dayNames[date.weekday - 1];

    String? timing = temple.timings[dayName];
    if (timing == null || timing.isEmpty) {
      timing = temple.timings['Daily'];
    }
    if (timing == null || timing.isEmpty)
      return _getDefaultSlots(date, bookingType);

    final parts = timing.split('-');
    if (parts.length != 2) return _getDefaultSlots(date, bookingType);

    final openTime = _parseTimeString(parts[0].trim());
    final closeTime = _parseTimeString(parts[1].trim());
    if (openTime == null || closeTime == null)
      return _getDefaultSlots(date, bookingType);

    final openDT = DateTime(
      date.year,
      date.month,
      date.day,
      openTime.hour,
      openTime.minute,
    );
    final closeDT = closeTime.hour < openTime.hour
        ? DateTime(
            date.year,
            date.month,
            date.day + 1,
            closeTime.hour,
            closeTime.minute,
          )
        : DateTime(
            date.year,
            date.month,
            date.day,
            closeTime.hour,
            closeTime.minute,
          );

    final slots = <TimeOfDay>[];
    var current = openDT;
    while (current.isBefore(closeDT)) {
      slots.add(TimeOfDay(hour: current.hour, minute: current.minute));
      // Slot interval depends on booking type:
      //   visit          → every 1 hour (standard)
      //   event          → every 2 hours (longer sessions)
      //   special_service → every 2 hours (puja / ceremony blocks)
      final intervalHours =
          (bookingType == 'event' || bookingType == 'special_service') ? 2 : 1;
      current = current.add(Duration(hours: intervalHours));
    }

    return _filterPastSlots(slots, date);
  }

  List<TimeOfDay> _getDefaultSlots(
    DateTime date, [
    String bookingType = 'visit',
  ]) {
    // visit: hourly morning + evening slots
    // event / special_service: fewer, wider blocks
    final defaults =
        (bookingType == 'event' || bookingType == 'special_service')
        ? [
            const TimeOfDay(hour: 6, minute: 0),
            const TimeOfDay(hour: 8, minute: 0),
            const TimeOfDay(hour: 10, minute: 0),
            const TimeOfDay(hour: 16, minute: 0),
            const TimeOfDay(hour: 18, minute: 0),
          ]
        : [
            const TimeOfDay(hour: 6, minute: 0),
            const TimeOfDay(hour: 7, minute: 0),
            const TimeOfDay(hour: 8, minute: 0),
            const TimeOfDay(hour: 9, minute: 0),
            const TimeOfDay(hour: 10, minute: 0),
            const TimeOfDay(hour: 11, minute: 0),
            const TimeOfDay(hour: 16, minute: 0),
            const TimeOfDay(hour: 17, minute: 0),
            const TimeOfDay(hour: 18, minute: 0),
            const TimeOfDay(hour: 19, minute: 0),
          ];
    return _filterPastSlots(defaults, date);
  }

  List<TimeOfDay> _filterPastSlots(List<TimeOfDay> slots, DateTime date) {
    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;
    if (!isToday) return slots;

    final current = TimeOfDay.fromDateTime(now);
    return slots
        .where(
          (s) =>
              s.hour > current.hour ||
              (s.hour == current.hour && s.minute > current.minute),
        )
        .toList();
  }

  TimeOfDay? _parseTimeString(String timeStr) {
    try {
      timeStr = timeStr.trim();
      if (timeStr.contains(':')) {
        final parts = timeStr.split(':');
        if (parts.length != 2) return null;
        var hour = int.tryParse(parts[0].trim());
        if (hour == null) return null;
        final minuteParts = parts[1].trim().split(' ');
        final minute = int.tryParse(minuteParts[0]);
        if (minute == null) return null;
        if (minuteParts.length > 1) {
          final period = minuteParts[1].toUpperCase();
          if (period == 'PM' && hour != 12) hour += 12;
          if (period == 'AM' && hour == 12) hour = 0;
        }
        return TimeOfDay(hour: hour, minute: minute);
      }
      final parts = timeStr.split(' ');
      var hour = int.tryParse(parts[0]);
      if (hour == null) return null;
      if (parts.length > 1) {
        final period = parts[1].toUpperCase();
        if (period == 'PM' && hour != 12) hour += 12;
        if (period == 'AM' && hour == 12) hour = 0;
      }
      return TimeOfDay(hour: hour, minute: 0);
    } catch (_) {
      return null;
    }
  }

  static String _timeOfDayToString(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
}
