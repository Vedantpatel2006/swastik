import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/donation.dart';
import 'stripe_payment_service.dart';
import '../../../shared/models/payment_transaction.dart';
import '../../../shared/models/donation.dart' as shared_donation;

class DonationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final StripePaymentService _stripeService;

  DonationService({StripePaymentService? stripeService})
    : _stripeService = stripeService ?? StripePaymentService.instance;

  // Create a new donation
  Future<Donation> createDonation({
    required String templeId,
    required String templeName,
    required double amount,
    required DonationType type,
    required PaymentMethod paymentMethod,
    String? notes,
    bool isAnonymous = false,
    String? dedicatedTo,
    bool taxBenefitEligible = false,
    String? panNumber,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User must be logged in to make donations');
    }

    // Validate amount
    if (amount <= 0 || amount > 100000) {
      throw Exception('Invalid donation amount');
    }

    // Validate PAN if tax benefit is requested
    if (taxBenefitEligible && (panNumber == null || panNumber.length != 10)) {
      throw Exception('Valid PAN number required for tax benefit');
    }

    final donationId = _generateDonationId();
    final donation = Donation(
      id: donationId,
      templeId: templeId,
      templeName: templeName,
      userId: user.uid,
      userName: user.displayName ?? 'Anonymous',
      userEmail: user.email ?? '',
      amount: amount,
      type: type,
      paymentMethod: paymentMethod,
      status: DonationStatus.pending,
      createdAt: DateTime.now(),
      notes: notes,
      isAnonymous: isAnonymous,
      dedicatedTo: dedicatedTo,
      taxBenefitEligible: taxBenefitEligible,
      panNumber: panNumber,
    );

    // Save to Firestore
    await _firestore
        .collection('donations')
        .doc(donationId)
        .set(donation.toFirestore());

    return donation;
  }

  // Process payment for donation using Stripe
  Future<PaymentTransaction> processPayment({
    required Donation donation,
    required Map<String, dynamic> customerInfo,
  }) async {
    try {
      // Create shared donation model for Stripe service
      final sharedDonation = shared_donation.Donation(
        id: donation.id,
        templeId: donation.templeId,
        userId: donation.userId,
        amount: donation.amount,
        currency: 'USD',
        paymentMethod: 'stripe', // Always use Stripe for all payments
        status: shared_donation.DonationStatus.pending,
        donationDate: donation.createdAt,
        createdAt: donation.createdAt,
        updatedAt: DateTime.now(),
      );

      final transaction = await _stripeService.processDonationPayment(
        donation: sharedDonation,
        customerInfo: customerInfo,
      );

      // Update donation with payment details
      // Payment verification is handled by Stripe webhook, so mark as pending for verification
      await updateDonationStatus(
        donation.id,
        transaction.isSuccessful
            ? DonationStatus.processing
            : DonationStatus.failed,
        transactionId: transaction.gatewayTransactionId,
        paymentGatewayId: transaction.gatewayTransactionId,
      );

      return transaction;
    } catch (e) {
      throw Exception('Payment processing failed: $e');
    }
  }

  // Verify and complete payment
  Future<bool> verifyAndCompletePayment(String donationId) async {
    final donation = await getDonation(donationId);
    if (donation == null) return false;

    try {
      // Payment verification is handled by Stripe webhook
      // Mark as completed after verification
      final receiptNumber = _generateReceiptNumber();
      await updateDonationStatus(
        donationId,
        DonationStatus.completed,
        completedAt: DateTime.now(),
        receiptNumber: receiptNumber,
      );

      // Update temple donation statistics
      await _updateTempleStats(donation);

      return true;
    } catch (e) {
      await updateDonationStatus(donationId, DonationStatus.failed);
      return false;
    }
  }

  // Update donation status
  Future<void> updateDonationStatus(
    String donationId,
    DonationStatus status, {
    String? transactionId,
    String? paymentGatewayId,
    DateTime? completedAt,
    String? receiptNumber,
  }) async {
    final updateData = <String, dynamic>{'status': status.name};

    if (transactionId != null) updateData['transactionId'] = transactionId;
    if (paymentGatewayId != null)
      updateData['paymentGatewayId'] = paymentGatewayId;
    if (completedAt != null)
      updateData['completedAt'] = Timestamp.fromDate(completedAt);
    if (receiptNumber != null) updateData['receiptNumber'] = receiptNumber;

    await _firestore.collection('donations').doc(donationId).update(updateData);
  }

  // Get donation by ID
  Future<Donation?> getDonation(String donationId) async {
    final doc = await _firestore.collection('donations').doc(donationId).get();

    if (!doc.exists) return null;
    return Donation.fromFirestore(doc);
  }

  // Get user's donation history
  Future<List<Donation>> getUserDonations({
    String? userId,
    int limit = 50,
    DocumentSnapshot? startAfter,
  }) async {
    final uid = userId ?? _auth.currentUser?.uid;
    if (uid == null) return [];

    Query query = _firestore
        .collection('donations')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snapshot = await query.get();
    return snapshot.docs.map((doc) => Donation.fromFirestore(doc)).toList();
  }

  // Get temple donations
  Future<List<Donation>> getTempleDonations({
    required String templeId,
    int limit = 100,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    Query query = _firestore
        .collection('donations')
        .where('templeId', isEqualTo: templeId)
        .where('status', isEqualTo: DonationStatus.completed.name)
        .orderBy('completedAt', descending: true)
        .limit(limit);

    if (startDate != null) {
      query = query.where(
        'completedAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
      );
    }

    if (endDate != null) {
      query = query.where(
        'completedAt',
        isLessThanOrEqualTo: Timestamp.fromDate(endDate),
      );
    }

    final snapshot = await query.get();
    return snapshot.docs.map((doc) => Donation.fromFirestore(doc)).toList();
  }

  // Get donation analytics for temple
  Future<DonationAnalytics> getTempleAnalytics({
    required String templeId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final start =
        startDate ?? DateTime.now().subtract(const Duration(days: 365));
    final end = endDate ?? DateTime.now();

    final donations = await getTempleDonations(
      templeId: templeId,
      limit: 1000,
      startDate: start,
      endDate: end,
    );

    return DonationAnalytics.fromDonations(templeId, donations, start, end);
  }

  // Calculate tax benefits
  Map<String, dynamic> calculateTaxBenefits(List<Donation> donations) {
    final eligibleDonations = donations
        .where(
          (d) => d.taxBenefitEligible && d.status == DonationStatus.completed,
        )
        .toList();

    final totalEligibleAmount = eligibleDonations.fold<double>(
      0.0,
      (sum, donation) => sum + donation.amount,
    );

    // 80G deduction - 100% for religious donations
    final deduction80G = totalEligibleAmount;

    // Estimated tax savings (assuming 30% tax bracket)
    final estimatedSavings = deduction80G * 0.30;

    return {
      'totalEligibleAmount': totalEligibleAmount,
      'deduction80G': deduction80G,
      'estimatedTaxSavings': estimatedSavings,
      'eligibleDonationsCount': eligibleDonations.length,
      'donations': eligibleDonations,
    };
  }

  // Generate donation receipt
  Future<DonationReceipt> generateReceipt(
    String donationId, {
    String language = 'en',
  }) async {
    final donation = await getDonation(donationId);
    if (donation == null || donation.status != DonationStatus.completed) {
      throw Exception('Donation not found or not completed');
    }

    return DonationReceipt(
      receiptNumber: donation.receiptNumber ?? _generateReceiptNumber(),
      donation: donation,
      organizationName: 'Swastik Temple Foundation',
      organizationAddress: 'Gujarat, India',
      organizationPan: 'ABCDE1234F', // Replace with actual PAN
      organizationRegistration:
          '12A34567890', // Replace with actual registration
      issuedAt: DateTime.now(),
      language: language,
    );
  }

  // Refund donation via Stripe
  Future<bool> refundDonation(String donationId, String reason) async {
    final donation = await getDonation(donationId);
    if (donation == null || donation.status != DonationStatus.completed) {
      return false;
    }

    try {
      // Get payment intent ID from donation metadata
      final doc = await _firestore
          .collection('donations')
          .doc(donationId)
          .get();
      final data = doc.data() ?? {};
      final paymentIntentId = data['paymentIntentId'] as String?;

      if (paymentIntentId == null) {
        throw Exception('Payment intent ID not found for refund');
      }

      await _stripeService.refundPayment(
        paymentIntentId: paymentIntentId,
        amount: donation.amount,
        reason: reason,
      );

      await updateDonationStatus(donationId, DonationStatus.refunded);

      // Update temple statistics
      await _updateTempleStats(donation, isRefund: true);

      return true;
    } catch (e) {
      return false;
    }
  }

  // Private helper methods
  String _generateDonationId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(9999);
    return 'DON_${timestamp}_$random';
  }

  String _generateReceiptNumber() {
    final year = DateTime.now().year;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(999);
    return 'RCP_${year}_${timestamp}_$random';
  }

  Future<void> _updateTempleStats(
    Donation donation, {
    bool isRefund = false,
  }) async {
    final templeRef = _firestore.collection('temples').doc(donation.templeId);

    await _firestore.runTransaction((transaction) async {
      final templeDoc = await transaction.get(templeRef);

      if (templeDoc.exists) {
        final currentStats = templeDoc.data()?['donationStats'] ?? {};
        final totalAmount = (currentStats['totalAmount'] ?? 0.0) as double;
        final totalDonations = (currentStats['totalDonations'] ?? 0) as int;

        final newAmount = isRefund
            ? totalAmount - donation.amount
            : totalAmount + donation.amount;
        final newCount = isRefund ? totalDonations - 1 : totalDonations + 1;

        transaction.update(templeRef, {
          'donationStats': {
            'totalAmount': newAmount,
            'totalDonations': newCount,
            'lastUpdated': Timestamp.now(),
          },
        });
      }
    });
  }

  // Stream donations for real-time updates
  Stream<List<Donation>> streamUserDonations({String? userId}) {
    final uid = userId ?? _auth.currentUser?.uid;
    if (uid == null) return Stream.value([]);

    return _firestore
        .collection('donations')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Donation.fromFirestore(doc)).toList(),
        );
  }

  Stream<List<Donation>> streamTempleDonations(String templeId) {
    return _firestore
        .collection('donations')
        .where('templeId', isEqualTo: templeId)
        .where('status', isEqualTo: DonationStatus.completed.name)
        .orderBy('completedAt', descending: true)
        .limit(100)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Donation.fromFirestore(doc)).toList(),
        );
  }
}
