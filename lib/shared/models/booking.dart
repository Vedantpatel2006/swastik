import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Booking status enumeration
enum BookingStatus { pending, confirmed, cancelled, completed, noShow }

/// Payment status enumeration for bookings
enum BookingPaymentStatus { pending, paid, failed, refunded }

/// Booking model for temple visit and event reservations with Stripe payment.
/// All data is stored in and read from Supabase (`public.bookings`).
class Booking {
  final String id;
  final String templeId;
  final String userId;
  final String bookingType; // visit, event, special_service
  final DateTime bookingDate;
  final TimeOfDay bookingTime;
  final int numberOfPeople;
  final BookingStatus status;
  final String? specialRequests;
  final String? contactName;
  final String? contactPhone;
  final String? contactEmail;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic>? metadata;

  // Payment fields
  final double? amount;
  final String? currency;
  final BookingPaymentStatus? paymentStatus;
  final String? paymentIntentId;
  final String? transactionId;
  final Map<String, dynamic>? paymentMetadata;

  const Booking({
    required this.id,
    required this.templeId,
    required this.userId,
    required this.bookingType,
    required this.bookingDate,
    required this.bookingTime,
    this.numberOfPeople = 1,
    this.status = BookingStatus.pending,
    this.specialRequests,
    this.contactName,
    this.contactPhone,
    this.contactEmail,
    required this.createdAt,
    required this.updatedAt,
    this.metadata,
    this.amount,
    this.currency = 'USD',
    this.paymentStatus,
    this.paymentIntentId,
    this.transactionId,
    this.paymentMetadata,
  });

  // ─── Supabase serialization ───────────────────────────────────────────────

  /// Create Booking from a Supabase row (snake_case keys)
  factory Booking.fromSupabase(Map<String, dynamic> row) {
    return Booking(
      id: row['id'] as String,
      templeId: row['temple_id'] as String,
      userId: row['user_id'] as String,
      bookingType: row['booking_type'] as String,
      bookingDate: DateTime.parse(row['booking_date'] as String),
      bookingTime: _timeOfDayFromString(
        row['booking_time'] as String? ?? '09:00',
      ),
      numberOfPeople: row['number_of_people'] as int? ?? 1,
      status: BookingStatus.values.firstWhere(
        (e) => e.name == row['status'],
        orElse: () => BookingStatus.pending,
      ),
      specialRequests: row['special_requests'] as String?,
      contactName: row['contact_name'] as String?,
      contactPhone: row['contact_phone'] as String?,
      contactEmail: row['contact_email'] as String?,
      createdAt: row['created_at'] != null
          ? DateTime.parse(row['created_at'] as String)
          : DateTime.now(),
      updatedAt: row['updated_at'] != null
          ? DateTime.parse(row['updated_at'] as String)
          : DateTime.now(),
      metadata: row['metadata'] != null
          ? Map<String, dynamic>.from(row['metadata'] as Map)
          : null,
      amount: row['amount'] != null ? (row['amount'] as num).toDouble() : null,
      currency: row['currency'] as String? ?? 'USD',
      paymentStatus: row['payment_status'] != null
          ? BookingPaymentStatus.values.firstWhere(
              (e) => e.name == row['payment_status'],
              orElse: () => BookingPaymentStatus.pending,
            )
          : null,
      paymentIntentId: row['payment_intent_id'] as String?,
      transactionId: row['transaction_id'] as String?,
    );
  }

  /// Convert Booking to a Supabase insert/update map (snake_case keys)
  Map<String, dynamic> toSupabaseJson() {
    return {
      'user_id': userId,
      'temple_id': templeId,
      'booking_date': DateFormat('yyyy-MM-dd').format(bookingDate),
      'booking_time': _timeOfDayToString(bookingTime),
      'number_of_people': numberOfPeople,
      'booking_type': bookingType,
      'status': status.name,
      if (specialRequests != null) 'special_requests': specialRequests,
      if (contactName != null) 'contact_name': contactName,
      if (contactPhone != null) 'contact_phone': contactPhone,
      if (contactEmail != null) 'contact_email': contactEmail,
      if (amount != null) 'amount': amount,
      if (currency != null) 'currency': currency,
      if (paymentStatus != null) 'payment_status': paymentStatus!.name,
      if (paymentIntentId != null) 'payment_intent_id': paymentIntentId,
      if (transactionId != null) 'transaction_id': transactionId,
      if (metadata != null) 'metadata': metadata,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  static String _timeOfDayToString(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  static TimeOfDay _timeOfDayFromString(String timeString) {
    final parts = timeString.split(':');
    if (parts.length < 2) return const TimeOfDay(hour: 9, minute: 0);
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 9,
      minute: int.tryParse(parts[1]) ?? 0,
    );
  }

  // ─── Validation ───────────────────────────────────────────────────────────

  bool isValid() {
    const validBookingTypes = ['visit', 'event', 'special_service'];
    return templeId.isNotEmpty &&
        userId.isNotEmpty &&
        validBookingTypes.contains(bookingType) &&
        numberOfPeople > 0 &&
        numberOfPeople <= 50 &&
        bookingDate.isAfter(DateTime.now().subtract(const Duration(days: 1)));
  }

  // ─── CopyWith ─────────────────────────────────────────────────────────────

  Booking copyWith({
    String? id,
    String? templeId,
    String? userId,
    String? bookingType,
    DateTime? bookingDate,
    TimeOfDay? bookingTime,
    int? numberOfPeople,
    BookingStatus? status,
    String? specialRequests,
    String? contactName,
    String? contactPhone,
    String? contactEmail,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
    double? amount,
    String? currency,
    BookingPaymentStatus? paymentStatus,
    String? paymentIntentId,
    String? transactionId,
    Map<String, dynamic>? paymentMetadata,
  }) {
    return Booking(
      id: id ?? this.id,
      templeId: templeId ?? this.templeId,
      userId: userId ?? this.userId,
      bookingType: bookingType ?? this.bookingType,
      bookingDate: bookingDate ?? this.bookingDate,
      bookingTime: bookingTime ?? this.bookingTime,
      numberOfPeople: numberOfPeople ?? this.numberOfPeople,
      status: status ?? this.status,
      specialRequests: specialRequests ?? this.specialRequests,
      contactName: contactName ?? this.contactName,
      contactPhone: contactPhone ?? this.contactPhone,
      contactEmail: contactEmail ?? this.contactEmail,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      metadata: metadata ?? this.metadata,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentIntentId: paymentIntentId ?? this.paymentIntentId,
      transactionId: transactionId ?? this.transactionId,
      paymentMetadata: paymentMetadata ?? this.paymentMetadata,
    );
  }

  // ─── Computed properties ──────────────────────────────────────────────────

  DateTime get bookingDateTime => DateTime(
    bookingDate.year,
    bookingDate.month,
    bookingDate.day,
    bookingTime.hour,
    bookingTime.minute,
  );

  bool get isFuture => bookingDateTime.isAfter(DateTime.now());
  bool get isPast => bookingDateTime.isBefore(DateTime.now());

  bool get isToday {
    final now = DateTime.now();
    return bookingDate.year == now.year &&
        bookingDate.month == now.month &&
        bookingDate.day == now.day;
  }

  bool get canBeCancelled =>
      (status == BookingStatus.pending || status == BookingStatus.confirmed) &&
      isFuture &&
      bookingDateTime.difference(DateTime.now()).inHours >= 2;

  bool get canBeModified =>
      (status == BookingStatus.pending || status == BookingStatus.confirmed) &&
      isFuture &&
      bookingDateTime.difference(DateTime.now()).inHours >= 24;

  String get statusDisplayName {
    switch (status) {
      case BookingStatus.pending:
        return 'Pending';
      case BookingStatus.confirmed:
        return 'Confirmed';
      case BookingStatus.cancelled:
        return 'Cancelled';
      case BookingStatus.completed:
        return 'Completed';
      case BookingStatus.noShow:
        return 'No Show';
    }
  }

  String get bookingTypeDisplayName {
    switch (bookingType) {
      case 'visit':
        return 'Temple Visit';
      case 'event':
        return 'Event';
      case 'special_service':
        return 'Special Service';
      default:
        return bookingType;
    }
  }

  String get formattedTime {
    final hour = bookingTime.hourOfPeriod == 0 ? 12 : bookingTime.hourOfPeriod;
    final minute = bookingTime.minute.toString().padLeft(2, '0');
    final period = bookingTime.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  String get formattedDate {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${bookingDate.day} ${months[bookingDate.month - 1]} ${bookingDate.year}';
  }

  String get formattedDateTime => '$formattedDate at $formattedTime';

  bool get hasSpecialRequests =>
      specialRequests != null && specialRequests!.isNotEmpty;

  bool get hasContactInfo => contactPhone != null || contactEmail != null;

  Duration? get timeUntilBooking {
    if (isPast) return null;
    return bookingDateTime.difference(DateTime.now());
  }

  String? get formattedTimeUntilBooking {
    final duration = timeUntilBooking;
    if (duration == null) return null;
    if (duration.inDays > 0) {
      return '${duration.inDays} ${duration.inDays == 1 ? 'day' : 'days'}';
    } else if (duration.inHours > 0) {
      return '${duration.inHours} ${duration.inHours == 1 ? 'hour' : 'hours'}';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes} ${duration.inMinutes == 1 ? 'minute' : 'minutes'}';
    } else {
      return 'Now';
    }
  }

  bool get requiresPayment => amount != null && amount! > 0;
  bool get isPaymentCompleted => paymentStatus == BookingPaymentStatus.paid;
  bool get isPaymentPending => paymentStatus == BookingPaymentStatus.pending;
  bool get isPaymentFailed => paymentStatus == BookingPaymentStatus.failed;

  String get formattedAmount {
    if (amount == null) return 'Free';
    final symbol = _getCurrencySymbol(currency ?? 'USD');
    return '$symbol${amount!.toStringAsFixed(2)}';
  }

  String _getCurrencySymbol(String currencyCode) {
    switch (currencyCode.toUpperCase()) {
      case 'INR':
        return '₹';
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      default:
        return currencyCode;
    }
  }

  String get paymentStatusDisplayName {
    if (paymentStatus == null) return 'No Payment';
    switch (paymentStatus!) {
      case BookingPaymentStatus.pending:
        return 'Payment Pending';
      case BookingPaymentStatus.paid:
        return 'Paid';
      case BookingPaymentStatus.failed:
        return 'Payment Failed';
      case BookingPaymentStatus.refunded:
        return 'Refunded';
    }
  }

  // ─── Equality ─────────────────────────────────────────────────────────────

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Booking &&
        other.id == id &&
        other.templeId == templeId &&
        other.userId == userId &&
        other.bookingType == bookingType &&
        other.bookingDate == bookingDate &&
        other.bookingTime == bookingTime &&
        other.numberOfPeople == numberOfPeople &&
        other.status == status &&
        other.specialRequests == specialRequests &&
        other.contactPhone == contactPhone &&
        other.contactEmail == contactEmail &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        _mapEquals(other.metadata, metadata);
  }

  @override
  int get hashCode => Object.hash(
    id,
    templeId,
    userId,
    bookingType,
    bookingDate,
    bookingTime,
    numberOfPeople,
    status,
    specialRequests,
    contactPhone,
    contactEmail,
    createdAt,
    updatedAt,
    metadata,
  );

  @override
  String toString() =>
      'Booking(id: $id, templeId: $templeId, userId: $userId, '
      'type: $bookingType, date: $formattedDateTime, status: ${status.name})';

  bool _mapEquals(Map<String, dynamic>? a, Map<String, dynamic>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (a[key] != b[key]) return false;
    }
    return true;
  }
}
