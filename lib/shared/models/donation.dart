import 'package:cloud_firestore/cloud_firestore.dart';

/// Donation status enumeration
enum DonationStatus { pending, completed, failed, refunded }

/// Donation model for temple contributions
class Donation {
  final String id;
  final String templeId;
  final String userId;
  final double amount;
  final String currency;
  final String paymentMethod;
  final String? transactionId;
  final DonationStatus status;
  final String? purpose; // general, festival, maintenance, etc.
  final DateTime donationDate;
  final String? receiptUrl;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic>? paymentMetadata;

  const Donation({
    required this.id,
    required this.templeId,
    required this.userId,
    required this.amount,
    this.currency = 'USD',
    required this.paymentMethod,
    this.transactionId,
    this.status = DonationStatus.pending,
    this.purpose,
    required this.donationDate,
    this.receiptUrl,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.paymentMetadata,
  });

  /// Create Donation from Firestore document
  factory Donation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Donation.fromJson({...data, 'id': doc.id});
  }

  /// Create Donation from JSON
  factory Donation.fromJson(Map<String, dynamic> json) {
    return Donation(
      id: json['id'] as String,
      templeId: json['templeId'] as String,
      userId: json['userId'] as String,
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'USD',
      paymentMethod: json['paymentMethod'] as String,
      transactionId: json['transactionId'] as String?,
      status: DonationStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => DonationStatus.pending,
      ),
      purpose: json['purpose'] as String?,
      donationDate: json['donationDate'] != null
          ? (json['donationDate'] as Timestamp).toDate()
          : DateTime.now(),
      receiptUrl: json['receiptUrl'] as String?,
      notes: json['notes'] as String?,
      createdAt: json['createdAt'] != null
          ? (json['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? (json['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
      paymentMetadata: json['paymentMetadata'] != null
          ? Map<String, dynamic>.from(json['paymentMetadata'] as Map)
          : null,
    );
  }

  /// Convert Donation to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'templeId': templeId,
      'userId': userId,
      'amount': amount,
      'currency': currency,
      'paymentMethod': paymentMethod,
      if (transactionId != null) 'transactionId': transactionId,
      'status': status.name,
      if (purpose != null) 'purpose': purpose,
      'donationDate': Timestamp.fromDate(donationDate),
      if (receiptUrl != null) 'receiptUrl': receiptUrl,
      if (notes != null) 'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      if (paymentMetadata != null) 'paymentMetadata': paymentMetadata,
    };
  }

  /// Validate donation data
  bool isValid() {
    final validPaymentMethods = ['stripe', 'card', 'upi', 'netbanking', 'wallet', 'cash'];
    final validCurrencies = ['USD', 'EUR', 'GBP'];

    // Note: id can be empty for new donations (will be set by Firestore)
    return templeId.isNotEmpty &&
        userId.isNotEmpty &&
        amount > 0 &&
        amount <= 100000 && // Reasonable limit
        validCurrencies.contains(currency) &&
        validPaymentMethods.contains(paymentMethod);
  }

  /// Create a copy of Donation with updated fields
  Donation copyWith({
    String? id,
    String? templeId,
    String? userId,
    double? amount,
    String? currency,
    String? paymentMethod,
    String? transactionId,
    DonationStatus? status,
    String? purpose,
    DateTime? donationDate,
    String? receiptUrl,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? paymentMetadata,
  }) {
    return Donation(
      id: id ?? this.id,
      templeId: templeId ?? this.templeId,
      userId: userId ?? this.userId,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      transactionId: transactionId ?? this.transactionId,
      status: status ?? this.status,
      purpose: purpose ?? this.purpose,
      donationDate: donationDate ?? this.donationDate,
      receiptUrl: receiptUrl ?? this.receiptUrl,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      paymentMetadata: paymentMetadata ?? this.paymentMetadata,
    );
  }

  /// Get status display name
  String get statusDisplayName {
    switch (status) {
      case DonationStatus.pending:
        return 'Pending';
      case DonationStatus.completed:
        return 'Completed';
      case DonationStatus.failed:
        return 'Failed';
      case DonationStatus.refunded:
        return 'Refunded';
    }
  }

  /// Get purpose display name
  String get purposeDisplayName {
    switch (purpose) {
      case 'general':
        return 'General Donation';
      case 'festival':
        return 'Festival Celebration';
      case 'maintenance':
        return 'Temple Maintenance';
      case 'construction':
        return 'Construction';
      case 'food':
        return 'Food Service';
      case 'education':
        return 'Education';
      default:
        return purpose ?? 'General Donation';
    }
  }

  /// Get formatted amount with currency
  String get formattedAmount {
    switch (currency) {
      case 'INR':
        return '₹${amount.toStringAsFixed(2)}';
      case 'USD':
        return '\$${amount.toStringAsFixed(2)}';
      case 'EUR':
        return '€${amount.toStringAsFixed(2)}';
      default:
        return '$currency ${amount.toStringAsFixed(2)}';
    }
  }

  /// Get formatted donation date
  String get formattedDate {
    final months = [
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
    return '${donationDate.day} ${months[donationDate.month - 1]} ${donationDate.year}';
  }

  /// Get formatted donation date and time
  String get formattedDateTime {
    final time =
        '${donationDate.hour.toString().padLeft(2, '0')}:${donationDate.minute.toString().padLeft(2, '0')}';
    return '$formattedDate at $time';
  }

  /// Get payment method display name
  String get paymentMethodDisplayName {
    switch (paymentMethod) {
      case 'card':
        return 'Credit/Debit Card';
      case 'upi':
        return 'UPI';
      case 'netbanking':
        return 'Net Banking';
      case 'wallet':
        return 'Digital Wallet';
      case 'cash':
        return 'Cash';
      default:
        return paymentMethod;
    }
  }

  /// Check if donation can be refunded
  bool get canBeRefunded {
    return status == DonationStatus.completed &&
        donationDate.isAfter(
          DateTime.now().subtract(const Duration(days: 30)),
        ) &&
        paymentMethod != 'cash';
  }

  /// Check if donation has receipt
  bool get hasReceipt => receiptUrl != null && receiptUrl!.isNotEmpty;

  /// Check if donation has notes
  bool get hasNotes => notes != null && notes!.isNotEmpty;

  /// Get time since donation
  Duration get timeSinceDonation => DateTime.now().difference(donationDate);

  /// Get formatted time since donation
  String get formattedTimeSinceDonation {
    final duration = timeSinceDonation;

    if (duration.inDays > 0) {
      return '${duration.inDays} ${duration.inDays == 1 ? 'day' : 'days'} ago';
    } else if (duration.inHours > 0) {
      return '${duration.inHours} ${duration.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes} ${duration.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else {
      return 'Just now';
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Donation &&
        other.id == id &&
        other.templeId == templeId &&
        other.userId == userId &&
        other.amount == amount &&
        other.currency == currency &&
        other.paymentMethod == paymentMethod &&
        other.transactionId == transactionId &&
        other.status == status &&
        other.purpose == purpose &&
        other.donationDate == donationDate &&
        other.receiptUrl == receiptUrl &&
        other.notes == notes &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        _mapEquals(other.paymentMetadata, paymentMetadata);
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      templeId,
      userId,
      amount,
      currency,
      paymentMethod,
      transactionId,
      status,
      purpose,
      donationDate,
      receiptUrl,
      notes,
      createdAt,
      updatedAt,
      paymentMetadata,
    );
  }

  @override
  String toString() {
    return 'Donation(id: $id, templeId: $templeId, userId: $userId, '
        'amount: $formattedAmount, status: ${status.name})';
  }

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
