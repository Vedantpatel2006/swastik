import 'package:cloud_firestore/cloud_firestore.dart';

/// Payment transaction status enumeration
enum PaymentTransactionStatus {
  created,
  authorized,
  captured,
  failed,
  cancelled,
  refunded,
  partiallyRefunded,
}

/// Payment transaction type enumeration
enum PaymentTransactionType { payment, refund, adjustment }

/// Payment transaction model for secure payment processing
class PaymentTransaction {
  final String id;
  final String orderId;
  final String? paymentId;
  final String? refundId;
  final PaymentTransactionType type;
  final PaymentTransactionStatus status;
  final double amount;
  final String currency;
  final String? paymentMethod;
  final String? gatewayTransactionId;
  final String? gatewayOrderId;
  final String? signature;
  final String? failureReason;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? authorizedAt;
  final DateTime? capturedAt;
  final DateTime? failedAt;
  final Map<String, dynamic>? gatewayResponse;
  final Map<String, dynamic>? metadata;
  final bool isVerified;
  final double? processingFee;
  final double? gatewayFee;
  final double netAmount;

  const PaymentTransaction({
    required this.id,
    required this.orderId,
    this.paymentId,
    this.refundId,
    this.type = PaymentTransactionType.payment,
    this.status = PaymentTransactionStatus.created,
    required this.amount,
    this.currency = 'USD',
    this.paymentMethod,
    this.gatewayTransactionId,
    this.gatewayOrderId,
    this.signature,
    this.failureReason,
    required this.createdAt,
    required this.updatedAt,
    this.authorizedAt,
    this.capturedAt,
    this.failedAt,
    this.gatewayResponse,
    this.metadata,
    this.isVerified = false,
    this.processingFee,
    this.gatewayFee,
    required this.netAmount,
  });

  /// Create PaymentTransaction from Firestore document
  factory PaymentTransaction.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return PaymentTransaction.fromJson({...data, 'id': doc.id});
  }

  /// Create PaymentTransaction from JSON
  factory PaymentTransaction.fromJson(Map<String, dynamic> json) {
    return PaymentTransaction(
      id: json['id'] as String,
      orderId: json['orderId'] as String,
      paymentId: json['paymentId'] as String?,
      refundId: json['refundId'] as String?,
      type: PaymentTransactionType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => PaymentTransactionType.payment,
      ),
      status: PaymentTransactionStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => PaymentTransactionStatus.created,
      ),
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'USD',
      paymentMethod: json['paymentMethod'] as String?,
      gatewayTransactionId: json['gatewayTransactionId'] as String?,
      gatewayOrderId: json['gatewayOrderId'] as String?,
      signature: json['signature'] as String?,
      failureReason: json['failureReason'] as String?,
      createdAt: json['createdAt'] != null
          ? (json['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? (json['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
      authorizedAt: json['authorizedAt'] != null
          ? (json['authorizedAt'] as Timestamp).toDate()
          : null,
      capturedAt: json['capturedAt'] != null
          ? (json['capturedAt'] as Timestamp).toDate()
          : null,
      failedAt: json['failedAt'] != null
          ? (json['failedAt'] as Timestamp).toDate()
          : null,
      gatewayResponse: json['gatewayResponse'] != null
          ? Map<String, dynamic>.from(json['gatewayResponse'] as Map)
          : null,
      metadata: json['metadata'] != null
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : null,
      isVerified: json['isVerified'] as bool? ?? false,
      processingFee: json['processingFee'] != null
          ? (json['processingFee'] as num).toDouble()
          : null,
      gatewayFee: json['gatewayFee'] != null
          ? (json['gatewayFee'] as num).toDouble()
          : null,
      netAmount: (json['netAmount'] as num).toDouble(),
    );
  }

  /// Create PaymentTransaction from Stripe payment intent
  factory PaymentTransaction.fromStripePaymentIntent(
    Map<String, dynamic> paymentIntentData,
  ) {
    final amount =
        (paymentIntentData['amount'] as int) / 100.0; // Convert from cents
    final status = _mapStripeStatus(paymentIntentData['status'] as String);

    return PaymentTransaction(
      id: '', // Will be set when saved to Firestore/Supabase
      orderId: paymentIntentData['metadata']?['order_id'] as String? ?? '',
      paymentId: paymentIntentData['id'] as String,
      gatewayTransactionId: paymentIntentData['id'] as String,
      gatewayOrderId: paymentIntentData['id'] as String,
      type: PaymentTransactionType.payment,
      status: status,
      amount: amount,
      currency: (paymentIntentData['currency'] as String).toUpperCase(),
      paymentMethod:
          (paymentIntentData['payment_method_types'] as List?)?.first
              as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (paymentIntentData['created'] as int) * 1000,
      ),
      updatedAt: DateTime.now(),
      authorizedAt:
          status == PaymentTransactionStatus.authorized ||
              status == PaymentTransactionStatus.captured
          ? DateTime.fromMillisecondsSinceEpoch(
              (paymentIntentData['created'] as int) * 1000,
            )
          : null,
      capturedAt: status == PaymentTransactionStatus.captured
          ? DateTime.now()
          : null,
      failedAt: status == PaymentTransactionStatus.failed
          ? DateTime.now()
          : null,
      gatewayResponse: paymentIntentData,
      isVerified: paymentIntentData['status'] == 'succeeded',
      netAmount: amount,
      failureReason:
          paymentIntentData['last_payment_error']?['message'] as String?,
      metadata: paymentIntentData['metadata'] != null
          ? Map<String, dynamic>.from(paymentIntentData['metadata'] as Map)
          : null,
    );
  }

  /// Create PaymentTransaction from Stripe refund
  factory PaymentTransaction.fromStripeRefund(
    Map<String, dynamic> refundData,
  ) {
    final amount = (refundData['amount'] as int) / 100.0; // Convert from cents

    return PaymentTransaction(
      id: '', // Will be set when saved to Firestore/Supabase
      orderId: refundData['payment_intent'] as String,
      refundId: refundData['id'] as String,
      gatewayTransactionId: refundData['id'] as String,
      type: PaymentTransactionType.refund,
      status: PaymentTransactionStatus.refunded,
      amount: amount,
      currency: (refundData['currency'] as String).toUpperCase(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (refundData['created'] as int) * 1000,
      ),
      updatedAt: DateTime.now(),
      gatewayResponse: refundData,
      isVerified: true,
      netAmount: amount,
      metadata: refundData['metadata'] != null
          ? Map<String, dynamic>.from(refundData['metadata'] as Map)
          : null,
    );
  }

  /// Convert PaymentTransaction to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'orderId': orderId,
      if (paymentId != null) 'paymentId': paymentId,
      if (refundId != null) 'refundId': refundId,
      'type': type.name,
      'status': status.name,
      'amount': amount,
      'currency': currency,
      if (paymentMethod != null) 'paymentMethod': paymentMethod,
      if (gatewayTransactionId != null)
        'gatewayTransactionId': gatewayTransactionId,
      if (gatewayOrderId != null) 'gatewayOrderId': gatewayOrderId,
      if (signature != null) 'signature': signature,
      if (failureReason != null) 'failureReason': failureReason,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      if (authorizedAt != null)
        'authorizedAt': Timestamp.fromDate(authorizedAt!),
      if (capturedAt != null) 'capturedAt': Timestamp.fromDate(capturedAt!),
      if (failedAt != null) 'failedAt': Timestamp.fromDate(failedAt!),
      if (gatewayResponse != null) 'gatewayResponse': gatewayResponse,
      if (metadata != null) 'metadata': metadata,
      'isVerified': isVerified,
      if (processingFee != null) 'processingFee': processingFee,
      if (gatewayFee != null) 'gatewayFee': gatewayFee,
      'netAmount': netAmount,
    };
  }

  /// Create a copy of PaymentTransaction with updated fields
  PaymentTransaction copyWith({
    String? id,
    String? orderId,
    String? paymentId,
    String? refundId,
    PaymentTransactionType? type,
    PaymentTransactionStatus? status,
    double? amount,
    String? currency,
    String? paymentMethod,
    String? gatewayTransactionId,
    String? gatewayOrderId,
    String? signature,
    String? failureReason,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? authorizedAt,
    DateTime? capturedAt,
    DateTime? failedAt,
    Map<String, dynamic>? gatewayResponse,
    Map<String, dynamic>? metadata,
    bool? isVerified,
    double? processingFee,
    double? gatewayFee,
    double? netAmount,
  }) {
    return PaymentTransaction(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      paymentId: paymentId ?? this.paymentId,
      refundId: refundId ?? this.refundId,
      type: type ?? this.type,
      status: status ?? this.status,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      gatewayTransactionId: gatewayTransactionId ?? this.gatewayTransactionId,
      gatewayOrderId: gatewayOrderId ?? this.gatewayOrderId,
      signature: signature ?? this.signature,
      failureReason: failureReason ?? this.failureReason,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      authorizedAt: authorizedAt ?? this.authorizedAt,
      capturedAt: capturedAt ?? this.capturedAt,
      failedAt: failedAt ?? this.failedAt,
      gatewayResponse: gatewayResponse ?? this.gatewayResponse,
      metadata: metadata ?? this.metadata,
      isVerified: isVerified ?? this.isVerified,
      processingFee: processingFee ?? this.processingFee,
      gatewayFee: gatewayFee ?? this.gatewayFee,
      netAmount: netAmount ?? this.netAmount,
    );
  }

  /// Get status display name
  String get statusDisplayName {
    switch (status) {
      case PaymentTransactionStatus.created:
        return 'Created';
      case PaymentTransactionStatus.authorized:
        return 'Authorized';
      case PaymentTransactionStatus.captured:
        return 'Completed';
      case PaymentTransactionStatus.failed:
        return 'Failed';
      case PaymentTransactionStatus.cancelled:
        return 'Cancelled';
      case PaymentTransactionStatus.refunded:
        return 'Refunded';
      case PaymentTransactionStatus.partiallyRefunded:
        return 'Partially Refunded';
    }
  }

  /// Get type display name
  String get typeDisplayName {
    switch (type) {
      case PaymentTransactionType.payment:
        return 'Payment';
      case PaymentTransactionType.refund:
        return 'Refund';
      case PaymentTransactionType.adjustment:
        return 'Adjustment';
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

  /// Get formatted net amount with currency
  String get formattedNetAmount {
    switch (currency) {
      case 'INR':
        return '₹${netAmount.toStringAsFixed(2)}';
      case 'USD':
        return '\$${netAmount.toStringAsFixed(2)}';
      case 'EUR':
        return '€${netAmount.toStringAsFixed(2)}';
      default:
        return '$currency ${netAmount.toStringAsFixed(2)}';
    }
  }

  /// Get formatted processing fee
  String get formattedProcessingFee {
    if (processingFee == null) return 'N/A';
    switch (currency) {
      case 'INR':
        return '₹${processingFee!.toStringAsFixed(2)}';
      case 'USD':
        return '\$${processingFee!.toStringAsFixed(2)}';
      case 'EUR':
        return '€${processingFee!.toStringAsFixed(2)}';
      default:
        return '$currency ${processingFee!.toStringAsFixed(2)}';
    }
  }

  /// Get formatted date
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
    return '${createdAt.day} ${months[createdAt.month - 1]} ${createdAt.year}';
  }

  /// Get formatted date and time
  String get formattedDateTime {
    final time =
        '${createdAt.hour.toString().padLeft(2, '0')}:'
        '${createdAt.minute.toString().padLeft(2, '0')}';
    return '$formattedDate at $time';
  }

  /// Check if transaction is successful
  /// Authorized means payment was accepted by Stripe (webhook will capture it)
  bool get isSuccessful =>
      status == PaymentTransactionStatus.captured ||
      status == PaymentTransactionStatus.authorized;

  /// Check if transaction is pending
  bool get isPending =>
      status == PaymentTransactionStatus.created ||
      status == PaymentTransactionStatus.authorized;

  /// Check if transaction has failed
  bool get hasFailed =>
      status == PaymentTransactionStatus.failed ||
      status == PaymentTransactionStatus.cancelled;

  /// Check if transaction can be refunded
  bool get canBeRefunded =>
      status == PaymentTransactionStatus.captured &&
      type == PaymentTransactionType.payment &&
      createdAt.isAfter(DateTime.now().subtract(const Duration(days: 180)));

  /// Check if transaction has processing fee
  bool get hasProcessingFee => processingFee != null && processingFee! > 0;

  /// Get time since transaction
  Duration get timeSinceTransaction => DateTime.now().difference(createdAt);

  /// Get formatted time since transaction
  String get formattedTimeSinceTransaction {
    final duration = timeSinceTransaction;

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

  /// Map Stripe status to internal status
  static PaymentTransactionStatus _mapStripeStatus(String stripeStatus) {
    switch (stripeStatus.toLowerCase()) {
      case 'requires_payment_method':
      case 'requires_confirmation':
      case 'requires_action':
        return PaymentTransactionStatus.created;
      case 'processing':
        return PaymentTransactionStatus.authorized;
      case 'succeeded':
        return PaymentTransactionStatus.captured;
      case 'canceled':
        return PaymentTransactionStatus.cancelled;
      case 'requires_capture':
        return PaymentTransactionStatus.authorized;
      default:
        return PaymentTransactionStatus.created;
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PaymentTransaction &&
        other.id == id &&
        other.orderId == orderId &&
        other.paymentId == paymentId &&
        other.status == status &&
        other.amount == amount &&
        other.currency == currency;
  }

  @override
  int get hashCode {
    return Object.hash(id, orderId, paymentId, status, amount, currency);
  }

  @override
  String toString() {
    return 'PaymentTransaction(id: $id, orderId: $orderId, '
        'status: ${status.name}, amount: $formattedAmount)';
  }
}
