import 'package:cloud_firestore/cloud_firestore.dart';

enum DonationStatus { pending, processing, completed, failed, refunded }

enum PaymentMethod { upi, card, netBanking, wallet }

enum DonationType {
  general,
  festival,
  construction,
  maintenance,
  food,
  special,
}

class Donation {
  final String id;
  final String templeId;
  final String templeName;
  final String userId;
  final String userName;
  final String userEmail;
  final double amount;
  final DonationType type;
  final PaymentMethod paymentMethod;
  final DonationStatus status;
  final String? transactionId;
  final String? paymentGatewayId;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? receiptNumber;
  final Map<String, dynamic>? metadata;
  final String? notes;
  final bool isAnonymous;
  final String? dedicatedTo;
  final bool taxBenefitEligible;
  final String? panNumber;

  const Donation({
    required this.id,
    required this.templeId,
    required this.templeName,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.amount,
    required this.type,
    required this.paymentMethod,
    required this.status,
    this.transactionId,
    this.paymentGatewayId,
    required this.createdAt,
    this.completedAt,
    this.receiptNumber,
    this.metadata,
    this.notes,
    this.isAnonymous = false,
    this.dedicatedTo,
    this.taxBenefitEligible = false,
    this.panNumber,
  });

  factory Donation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Donation(
      id: doc.id,
      templeId: data['templeId'] ?? '',
      templeName: data['templeName'] ?? '',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      userEmail: data['userEmail'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      type: DonationType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => DonationType.general,
      ),
      paymentMethod: PaymentMethod.values.firstWhere(
        (e) => e.name == data['paymentMethod'],
        orElse: () => PaymentMethod.upi,
      ),
      status: DonationStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => DonationStatus.pending,
      ),
      transactionId: data['transactionId'],
      paymentGatewayId: data['paymentGatewayId'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      completedAt: data['completedAt'] != null
          ? (data['completedAt'] as Timestamp).toDate()
          : null,
      receiptNumber: data['receiptNumber'],
      metadata: data['metadata'],
      notes: data['notes'],
      isAnonymous: data['isAnonymous'] ?? false,
      dedicatedTo: data['dedicatedTo'],
      taxBenefitEligible: data['taxBenefitEligible'] ?? false,
      panNumber: data['panNumber'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'templeId': templeId,
      'templeName': templeName,
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'amount': amount,
      'type': type.name,
      'paymentMethod': paymentMethod.name,
      'status': status.name,
      'transactionId': transactionId,
      'paymentGatewayId': paymentGatewayId,
      'createdAt': Timestamp.fromDate(createdAt),
      'completedAt': completedAt != null
          ? Timestamp.fromDate(completedAt!)
          : null,
      'receiptNumber': receiptNumber,
      'metadata': metadata,
      'notes': notes,
      'isAnonymous': isAnonymous,
      'dedicatedTo': dedicatedTo,
      'taxBenefitEligible': taxBenefitEligible,
      'panNumber': panNumber,
    };
  }

  Donation copyWith({
    String? id,
    String? templeId,
    String? templeName,
    String? userId,
    String? userName,
    String? userEmail,
    double? amount,
    DonationType? type,
    PaymentMethod? paymentMethod,
    DonationStatus? status,
    String? transactionId,
    String? paymentGatewayId,
    DateTime? createdAt,
    DateTime? completedAt,
    String? receiptNumber,
    Map<String, dynamic>? metadata,
    String? notes,
    bool? isAnonymous,
    String? dedicatedTo,
    bool? taxBenefitEligible,
    String? panNumber,
  }) {
    return Donation(
      id: id ?? this.id,
      templeId: templeId ?? this.templeId,
      templeName: templeName ?? this.templeName,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      status: status ?? this.status,
      transactionId: transactionId ?? this.transactionId,
      paymentGatewayId: paymentGatewayId ?? this.paymentGatewayId,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      receiptNumber: receiptNumber ?? this.receiptNumber,
      metadata: metadata ?? this.metadata,
      notes: notes ?? this.notes,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      dedicatedTo: dedicatedTo ?? this.dedicatedTo,
      taxBenefitEligible: taxBenefitEligible ?? this.taxBenefitEligible,
      panNumber: panNumber ?? this.panNumber,
    );
  }
}

class DonationReceipt {
  final String receiptNumber;
  final Donation donation;
  final String organizationName;
  final String organizationAddress;
  final String organizationPan;
  final String organizationRegistration;
  final DateTime issuedAt;
  final String language; // 'en', 'hi', 'gu'

  const DonationReceipt({
    required this.receiptNumber,
    required this.donation,
    required this.organizationName,
    required this.organizationAddress,
    required this.organizationPan,
    required this.organizationRegistration,
    required this.issuedAt,
    this.language = 'en',
  });

  Map<String, dynamic> toJson() {
    return {
      'receiptNumber': receiptNumber,
      'donation': donation.toFirestore(),
      'organizationName': organizationName,
      'organizationAddress': organizationAddress,
      'organizationPan': organizationPan,
      'organizationRegistration': organizationRegistration,
      'issuedAt': issuedAt.toIso8601String(),
      'language': language,
    };
  }
}

class DonationAnalytics {
  final String templeId;
  final double totalAmount;
  final int totalDonations;
  final Map<DonationType, double> amountByType;
  final Map<PaymentMethod, int> countByPaymentMethod;
  final Map<String, double> monthlyTrends;
  final double averageDonation;
  final DateTime periodStart;
  final DateTime periodEnd;

  const DonationAnalytics({
    required this.templeId,
    required this.totalAmount,
    required this.totalDonations,
    required this.amountByType,
    required this.countByPaymentMethod,
    required this.monthlyTrends,
    required this.averageDonation,
    required this.periodStart,
    required this.periodEnd,
  });

  factory DonationAnalytics.fromDonations(
    String templeId,
    List<Donation> donations,
    DateTime periodStart,
    DateTime periodEnd,
  ) {
    final totalAmount = donations.fold<double>(
      0.0,
      (sum, donation) => sum + donation.amount,
    );

    final amountByType = <DonationType, double>{};
    final countByPaymentMethod = <PaymentMethod, int>{};
    final monthlyTrends = <String, double>{};

    for (final donation in donations) {
      // Amount by type
      amountByType[donation.type] =
          (amountByType[donation.type] ?? 0) + donation.amount;

      // Count by payment method
      countByPaymentMethod[donation.paymentMethod] =
          (countByPaymentMethod[donation.paymentMethod] ?? 0) + 1;

      // Monthly trends
      final monthKey =
          '${donation.createdAt.year}-${donation.createdAt.month.toString().padLeft(2, '0')}';
      monthlyTrends[monthKey] =
          (monthlyTrends[monthKey] ?? 0) + donation.amount;
    }

    return DonationAnalytics(
      templeId: templeId,
      totalAmount: totalAmount,
      totalDonations: donations.length,
      amountByType: amountByType,
      countByPaymentMethod: countByPaymentMethod,
      monthlyTrends: monthlyTrends,
      averageDonation: donations.isNotEmpty
          ? totalAmount / donations.length
          : 0,
      periodStart: periodStart,
      periodEnd: periodEnd,
    );
  }
}
