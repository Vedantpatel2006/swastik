import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:math';
import '../../../shared/models/donation.dart';
import '../../../shared/models/temple.dart';
import '../../../shared/models/payment_transaction.dart';
import '../../temple/models/donation.dart' as TempleDonation;
import '../../temple/services/receipt_service.dart';
import '../../temple/services/stripe_payment_service.dart';
import '../../../core/config/payment_config.dart';
import '../../../shared/services/user_stats_service.dart';
import '../../../shared/services/supabase_notification_service.dart';
import '../../../shared/models/notification.dart';

/// Service for managing temple donations and payments with Stripe integration
class DonationService {
  final FirebaseFirestore _firestore;
  final StripePaymentService _stripePayment;
  final UserStatsService _userStatsService;
  final SupabaseNotificationService _notificationService;

  DonationService({
    FirebaseFirestore? firestore,
    StripePaymentService? stripePayment,
    UserStatsService? userStatsService,
    SupabaseNotificationService? notificationService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _stripePayment = stripePayment ?? StripePaymentService.instance,
       _userStatsService = userStatsService ?? UserStatsService(),
       _notificationService =
           notificationService ?? SupabaseNotificationService();
  static const String _donationsCollection = 'donations';
  static const String _templesCollection = 'temples';
  static const String _transactionsCollection = 'payment_transactions';

  /// Get all donations for a specific user
  Future<List<Donation>> getUserDonations(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_donationsCollection)
          .where('userId', isEqualTo: userId)
          .orderBy('donationDate', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => Donation.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch user donations: $e');
    }
  }

  /// Get recent donations for a user (last 30 days)
  Future<List<Donation>> getRecentDonations(String userId) async {
    try {
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      final querySnapshot = await _firestore
          .collection(_donationsCollection)
          .where('userId', isEqualTo: userId)
          .where(
            'donationDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(thirtyDaysAgo),
          )
          .orderBy('donationDate', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => Donation.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch recent donations: $e');
    }
  }

  /// Get donations for a specific temple
  Future<List<Donation>> getTempleDonations(String templeId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_donationsCollection)
          .where('templeId', isEqualTo: templeId)
          .where('status', isEqualTo: DonationStatus.completed.name)
          .orderBy('donationDate', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => Donation.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch temple donations: $e');
    }
  }

  /// Get paginated user donations with lazy loading support
  /// Note: Firestore doesn't support offset directly, use cursor pagination instead
  Future<List<Donation>> getUserDonationsPaginated(
    String userId, {
    required int pageSize,
    DocumentSnapshot? lastDocument,
  }) async {
    try {
      Query query = _firestore
          .collection(_donationsCollection)
          .where('userId', isEqualTo: userId)
          .orderBy('donationDate', descending: true)
          .limit(pageSize);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final querySnapshot = await query.get();
      return querySnapshot.docs
          .map((doc) => Donation.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch paginated donations: $e');
    }
  }

  /// Watch paginated donations as a stream (for real-time updates)
  Stream<List<Donation>> watchUserDonationsPaginated(
    String userId, {
    required int pageSize,
    DocumentSnapshot? lastDocument,
  }) {
    try {
      Query query = _firestore
          .collection(_donationsCollection)
          .where('userId', isEqualTo: userId)
          .orderBy('donationDate', descending: true)
          .limit(pageSize);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      return query.snapshots().map((snapshot) => snapshot.docs
          .map((doc) => Donation.fromFirestore(doc))
          .toList());
    } catch (e) {
      throw Exception('Failed to watch paginated donations: $e');
    }
  }

  /// Initialize secure payment for donation with Stripe
  Future<PaymentTransaction> initializeDonationPayment({
    required Donation donation,
    required Map<String, dynamic> customerInfo,
  }) async {
    try {
      // Validate donation data
      if (!donation.isValid()) {
        throw ArgumentError('Invalid donation data: amount must be > 0 and <= 100,000');
      }

      // Validate customer information
      _validateCustomerInfo(customerInfo);

      // Initialize Stripe payment service
      await _stripePayment.initialize();

      // Process donation payment with Stripe
      final transaction = await _stripePayment.processDonationPayment(
        donation: donation,
        customerInfo: customerInfo,
      );

      // NOTE: Transaction will be saved by Cloud Function webhook
      // We don't save it here to avoid permission issues

      if (kDebugMode) {
        debugPrint(
          '✅ Stripe donation payment initialized: ${transaction.gatewayOrderId}',
        );
      }

      return transaction;
    } on StateError catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Payment service error: $e');
      }
      // Show user-friendly error
      _showUserError('Payment Service Error', e.message);
      rethrow;
    } on ArgumentError catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Invalid donation data: $e');
      }
      // Show user-friendly error
      _showUserError('Invalid Donation', 'Please check your donation details and try again.');
      rethrow;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Failed to initialize donation payment: $e');
      }
      // Log payment failure for security audit
      _logPaymentFailure('initializeDonationPayment', donation, e.toString());

      // Show user-friendly error
      _showUserError(
        'Payment Failed',
        'We couldn\'t process your donation. Please check your connection and try again.',
      );
      rethrow;
    }
  }

  // Helper method to show user-friendly error messages
  void _showUserError(String title, String message) {
    // This would be implemented with NotificationService in actual app
    debugPrint('⚠️ User Error: $title - $message');
  }

  // Helper method to log payment failures for security audit
  void _logPaymentFailure(String method, Donation donation, String error) {
    // This would be logged to security_logger in actual app
    debugPrint('🔐 Payment Failure Log: $method - Temple: ${donation.templeId}, Amount: ${donation.amount}, Error: $error');
  }

  /// Process donation with Stripe payment verification
  Future<Donation> processDonationWithPayment({
    required Donation donation,
    required Map<String, dynamic> customerInfo,
  }) async {
    try {
      // Validate donation data before touching payment
      if (!donation.isValid()) {
        throw ArgumentError('Invalid donation data');
      }

      // Initialize and process payment with Stripe
      final transaction = await initializeDonationPayment(
        donation: donation,
        customerInfo: customerInfo,
      );

      // Check if payment was successful
      if (!transaction.isSuccessful) {
        throw Exception('Payment failed: ${transaction.failureReason}');
      }

      // Update donation status
      final processedDonation = donation.copyWith(
        status: DonationStatus.completed,
        transactionId: transaction.gatewayOrderId,
        paymentMetadata: {
          'gateway': 'stripe',
          'payment_intent_id': transaction.gatewayOrderId,
          'captured_at': DateTime.now().toIso8601String(),
          'processing_fee': transaction.processingFee,
          'gateway_fee': transaction.gatewayFee,
          'net_amount': transaction.netAmount,
        },
      );

      // Save donation to Firestore
      final docRef = await _firestore
          .collection(_donationsCollection)
          .add(processedDonation.toJson());

      final savedDonation = processedDonation.copyWith(id: docRef.id);

      // Update user statistics and generate receipt if successful
      if (savedDonation.status == DonationStatus.completed) {
        await _updateUserDonationStats(savedDonation);

        // Receipt generation is non-fatal — don't let it block donation success
        try {
          await _generateSecureReceipt(
            savedDonation,
            transaction,
            customerInfo,
          );
        } catch (e) {
          if (kDebugMode) {
            debugPrint('⚠️ Receipt generation failed (non-fatal): $e');
          }
        }

        // Send donation confirmation notification
        await _sendDonationConfirmation(savedDonation);

        // Track donation activity
        await _trackDonationActivity(savedDonation);
      }

      if (kDebugMode) {
        debugPrint('✅ Donation processed successfully: ${savedDonation.id}');
      }

      return savedDonation;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Failed to process donation payment: $e');
      }
      throw Exception('Failed to process donation payment: $e');
    }
  }

  /// Process a donation (fallback to simulation for testing)
  Future<Donation> processDonation(Donation donation) async {
    try {
      // Validate donation data
      if (!donation.isValid()) {
        throw ArgumentError('Invalid donation data');
      }

      // Simulate payment processing for testing
      final processedDonation = await _simulatePaymentProcessing(donation);

      // Save donation to Firestore
      final docRef = await _firestore
          .collection(_donationsCollection)
          .add(processedDonation.toJson());

      final savedDonation = processedDonation.copyWith(id: docRef.id);

      // Update user statistics if donation is successful
      if (savedDonation.status == DonationStatus.completed) {
        await _updateUserDonationStats(savedDonation);
        // Simulation path has no customerInfo — receipt will show generic user data
        await _generateReceipt(savedDonation);

        // Send donation confirmation notification
        await _sendDonationConfirmation(savedDonation);

        // Track donation activity
        await _trackDonationActivity(savedDonation);
      }

      return savedDonation;
    } catch (e) {
      throw Exception('Failed to process donation: $e');
    }
  }

  /// Simulate payment processing (replace with actual payment gateway)
  Future<Donation> _simulatePaymentProcessing(Donation donation) async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 2));

    // Generate transaction ID
    final transactionId = _generateTransactionId();

    // Simulate payment success/failure (90% success rate)
    final random = Random();
    final isSuccess = random.nextDouble() > 0.1;

    if (isSuccess) {
      return donation.copyWith(
        status: DonationStatus.completed,
        transactionId: transactionId,
        paymentMetadata: {
          'gateway': 'simulated',
          'processedAt': DateTime.now().toIso8601String(),
          'gatewayTransactionId': transactionId,
        },
      );
    } else {
      return donation.copyWith(
        status: DonationStatus.failed,
        paymentMetadata: {
          'gateway': 'simulated',
          'processedAt': DateTime.now().toIso8601String(),
          'errorCode': 'PAYMENT_FAILED',
          'errorMessage': 'Payment processing failed',
        },
      );
    }
  }

  /// Generate a unique transaction ID
  String _generateTransactionId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(999999);
    final input = '$timestamp$random';
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return 'TXN_${digest.toString().substring(0, 16).toUpperCase()}';
  }

  /// Update user donation statistics using UserStatsService
  Future<void> _updateUserDonationStats(Donation donation) async {
    try {
      await _userStatsService.recordDonation(
        userId: donation.userId,
        amount: donation.amount,
      );

      if (kDebugMode) {
        debugPrint(
          'DonationService: Updated user stats for donation ${donation.id}',
        );
      }
    } catch (e) {
      // Don't fail the donation if stats update fails
      if (kDebugMode) {
        debugPrint('DonationService: Failed to update user donation stats: $e');
      }
    }
  }

  /// Generate receipt for completed donation
  Future<String> generateReceipt(
    String donationId, {
    String? userName,
    String? userEmail,
  }) async {
    try {
      final donationDoc = await _firestore
          .collection(_donationsCollection)
          .doc(donationId)
          .get();

      if (!donationDoc.exists) {
        throw Exception('Donation not found');
      }

      final donation = Donation.fromFirestore(donationDoc);
      return await _generateReceipt(
        donation,
        userName: userName,
        userEmail: userEmail,
      );
    } catch (e) {
      throw Exception('Failed to generate receipt: $e');
    }
  }

  /// Internal method to generate receipt using ReceiptService
  Future<String> _generateReceipt(
    Donation donation, {
    String? userName,
    String? userEmail,
  }) async {
    try {
      // Get temple information
      final templeDoc = await _firestore
          .collection(_templesCollection)
          .doc(donation.templeId)
          .get();

      final temple = templeDoc.exists ? Temple.fromFirestore(templeDoc) : null;

      // Map shared Donation purpose → temple DonationType
      TempleDonation.DonationType donationType;
      switch (donation.purpose) {
        case 'festival':
          donationType = TempleDonation.DonationType.festival;
          break;
        case 'maintenance':
          donationType = TempleDonation.DonationType.maintenance;
          break;
        case 'construction':
          donationType = TempleDonation.DonationType.construction;
          break;
        case 'food':
          donationType = TempleDonation.DonationType.food;
          break;
        default:
          donationType = TempleDonation.DonationType.general;
      }

      // Map shared Donation paymentMethod → temple PaymentMethod
      TempleDonation.PaymentMethod paymentMethod;
      switch (donation.paymentMethod.toLowerCase()) {
        case 'card':
          paymentMethod = TempleDonation.PaymentMethod.card;
          break;
        case 'netbanking':
          paymentMethod = TempleDonation.PaymentMethod.netBanking;
          break;
        case 'wallet':
          paymentMethod = TempleDonation.PaymentMethod.wallet;
          break;
        default:
          paymentMethod = TempleDonation.PaymentMethod.upi;
      }

      // Create receipt data - convert to temple donation format for receipt
      final templeDonation = TempleDonation.Donation(
        id: donation.id,
        templeId: donation.templeId,
        templeName: temple?.name ?? 'Temple',
        userId: donation.userId,
        userName: userName ?? 'User',
        userEmail: userEmail ?? '',
        amount: donation.amount,
        type: donationType,
        paymentMethod: paymentMethod,
        status: TempleDonation.DonationStatus.completed,
        createdAt: donation.createdAt,
      );

      final receiptData = TempleDonation.DonationReceipt(
        receiptNumber: _generateReceiptNumber(donation.id),
        donation: templeDonation,
        issuedAt: DateTime.now(),
        language: 'en', // Default to English, can be customized
        organizationName: temple?.name ?? 'Temple',
        organizationAddress: temple?.location.address ?? 'Temple Address',
        organizationPan: 'AAACT1234C', // Should come from temple configuration
        organizationRegistration:
            'REG123456789', // Should come from temple configuration
      );

      // Generate PDF receipt
      final receiptBytes = await ReceiptService.generateReceiptPDF(receiptData);

      // Upload receipt to Firebase Storage
      final receiptId =
          'RECEIPT_${donation.id}_${DateTime.now().millisecondsSinceEpoch}';
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('receipts')
          .child('$receiptId.pdf');

      final uploadTask = storageRef.putData(
        receiptBytes,
        SettableMetadata(
          contentType: 'application/pdf',
          customMetadata: {
            'donation_id': donation.id,
            'user_id': donation.userId,
            'temple_id': donation.templeId,
            'generated_at': DateTime.now().toIso8601String(),
          },
        ),
      );

      final snapshot = await uploadTask;
      final receiptUrl = await snapshot.ref.getDownloadURL();

      // Update donation with receipt URL
      await _firestore
          .collection(_donationsCollection)
          .doc(donation.id)
          .update({
            'receiptUrl': receiptUrl,
            'receiptNumber': receiptData.receiptNumber,
            'updatedAt': Timestamp.fromDate(DateTime.now()),
          });

      if (kDebugMode) {
        debugPrint(
          'DonationService: Generated receipt for donation ${donation.id}',
        );
      }

      return receiptUrl;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('DonationService: Failed to generate receipt: $e');
      }
      throw Exception('Failed to generate receipt: $e');
    }
  }

  /// Generate receipt number
  String _generateReceiptNumber(String donationId) {
    final timestamp = DateTime.now();
    final year = timestamp.year.toString().substring(2);
    final month = timestamp.month.toString().padLeft(2, '0');
    final day = timestamp.day.toString().padLeft(2, '0');
    final sequence = donationId.substring(0, 6).toUpperCase();

    return 'RCP$year$month$day$sequence';
  }

  /// Get available payment methods (Stripe only)
  Future<List<String>> getPaymentMethods() async {
    // Stripe supports all payment methods (cards, UPI, Google Pay, etc.)
    return ['stripe'];
  }

  /// Get total donations amount for a user
  Future<double> getTotalDonations(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_donationsCollection)
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: DonationStatus.completed.name)
          .get();

      double totalAmount = 0.0;
      for (final doc in querySnapshot.docs) {
        final donation = Donation.fromFirestore(doc);
        totalAmount += donation.amount;
      }

      return totalAmount;
    } catch (e) {
      throw Exception('Failed to get total donations: $e');
    }
  }

  /// Watch user donations stream
  Stream<List<Donation>> watchUserDonations(String userId) {
    return _firestore
        .collection(_donationsCollection)
        .where('userId', isEqualTo: userId)
        .orderBy('donationDate', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Donation.fromFirestore(doc)).toList(),
        );
  }

  /// Get donation by ID
  Future<Donation?> getDonationById(String donationId) async {
    try {
      final doc = await _firestore
          .collection(_donationsCollection)
          .doc(donationId)
          .get();

      if (!doc.exists) return null;

      return Donation.fromFirestore(doc);
    } catch (e) {
      throw Exception('Failed to get donation: $e');
    }
  }

  /// Refund a donation with Stripe payment gateway processing
  Future<void> refundDonation(String donationId, String reason) async {
    try {
      final donationDoc = await _firestore
          .collection(_donationsCollection)
          .doc(donationId)
          .get();

      if (!donationDoc.exists) {
        throw Exception('Donation not found');
      }

      final donation = Donation.fromFirestore(donationDoc);

      if (!donation.canBeRefunded) {
        throw Exception('Donation cannot be refunded');
      }

      // Process refund through Stripe if transaction ID exists
      if (donation.transactionId != null) {
        final refundData = await _stripePayment.refundPayment(
          paymentIntentId: donation.transactionId!,
          amount: donation.amount,
          reason: reason,
        );

        // Save refund transaction
        await _firestore.collection(_transactionsCollection).add({
          'type': 'refund',
          'donation_id': donationId,
          'amount': donation.amount,
          'currency': donation.currency,
          'reason': reason,
          'refund_id': refundData['id'],
          'status': refundData['status'],
          'created_at': Timestamp.fromDate(DateTime.now()),
        });
      }

      // Update donation status
      await _firestore.collection(_donationsCollection).doc(donationId).update({
        'status': DonationStatus.refunded.name,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
        'paymentMetadata': {
          ...?donation.paymentMetadata != null
              ? Map<String, dynamic>.from(donation.paymentMetadata!)
              : null,
          'refundReason': reason,
          'refundedAt': DateTime.now().toIso8601String(),
        },
      });

      // Update user statistics
      await _updateUserDonationStatsForRefund(donation);

      if (kDebugMode) {
        debugPrint('✅ Donation refunded successfully: $donationId');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Failed to refund donation: $e');
      }
      throw Exception('Failed to refund donation: $e');
    }
  }

  /// Update user stats when donation is refunded using UserStatsService
  Future<void> _updateUserDonationStatsForRefund(Donation donation) async {
    try {
      // Get current stats and manually adjust for refund
      final currentStats = await _userStatsService.getUserStats(
        donation.userId,
      );
      final updatedStats = currentStats.copyWith(
        totalDonations: (currentStats.totalDonations - 1)
            .clamp(0, double.infinity)
            .toInt(),
        totalDonationAmount:
            (currentStats.totalDonationAmount - donation.amount).clamp(
              0.0,
              double.infinity,
            ),
        updatedAt: DateTime.now(),
      );

      await _userStatsService.updateUserStats(donation.userId, updatedStats);

      if (kDebugMode) {
        debugPrint(
          'DonationService: Updated user stats for refund ${donation.id}',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'DonationService: Failed to update user stats for refund: $e',
        );
      }
    }
  }

  /// Get donation statistics for a user
  Future<Map<String, dynamic>> getUserDonationStats(String userId) async {
    try {
      final donations = await getUserDonations(userId);

      final stats = {
        'totalDonations': donations.length,
        'completedDonations': donations
            .where((d) => d.status == DonationStatus.completed)
            .length,
        'totalAmount': donations
            .where((d) => d.status == DonationStatus.completed)
            .fold(0.0, (total, d) => total + d.amount),
        'averageDonation': 0.0,
        'donationsByPurpose': <String, int>{},
        'donationsByMonth': <String, int>{},
        'donationsByPaymentMethod': <String, int>{},
        'largestDonation': 0.0,
        'mostRecentDonation': null,
      };

      final completedDonations = donations
          .where((d) => d.status == DonationStatus.completed)
          .toList();

      if (completedDonations.isNotEmpty) {
        stats['averageDonation'] =
            (stats['totalAmount'] as double) / completedDonations.length;
        stats['largestDonation'] = completedDonations
            .map((d) => d.amount)
            .reduce((a, b) => a > b ? a : b);
        stats['mostRecentDonation'] = completedDonations.first.formattedDate;
      }

      // Calculate donations by purpose
      final donationsByPurpose =
          stats['donationsByPurpose'] as Map<String, int>;
      final donationsByMonth = stats['donationsByMonth'] as Map<String, int>;
      final donationsByPaymentMethod =
          stats['donationsByPaymentMethod'] as Map<String, int>;

      for (final donation in completedDonations) {
        final purpose = donation.purpose ?? 'general';
        donationsByPurpose[purpose] = (donationsByPurpose[purpose] ?? 0) + 1;

        final monthKey =
            '${donation.donationDate.year}-${donation.donationDate.month.toString().padLeft(2, '0')}';
        donationsByMonth[monthKey] = (donationsByMonth[monthKey] ?? 0) + 1;

        final paymentMethod = donation.paymentMethod;
        donationsByPaymentMethod[paymentMethod] =
            (donationsByPaymentMethod[paymentMethod] ?? 0) + 1;
      }

      return stats;
    } catch (e) {
      throw Exception('Failed to get donation statistics: $e');
    }
  }

  /// Get temple donation statistics (admin use)
  Future<Map<String, dynamic>> getTempleDonationStats(String templeId) async {
    try {
      final donations = await getTempleDonations(templeId);

      final stats = {
        'totalDonations': donations.length,
        'totalAmount': donations.fold(0.0, (total, d) => total + d.amount),
        'averageDonation': 0.0,
        'donationsByPurpose': <String, int>{},
        'donationsByMonth': <String, int>{},
        'topDonors': <String, double>{},
        'largestDonation': 0.0,
      };

      if (donations.isNotEmpty) {
        stats['averageDonation'] =
            (stats['totalAmount'] as double) / donations.length;
        stats['largestDonation'] = donations
            .map((d) => d.amount)
            .reduce((a, b) => a > b ? a : b);
      }

      // Calculate various statistics
      final donationsByPurpose =
          stats['donationsByPurpose'] as Map<String, int>;
      final donationsByMonth = stats['donationsByMonth'] as Map<String, int>;
      final topDonors = stats['topDonors'] as Map<String, double>;

      for (final donation in donations) {
        final purpose = donation.purpose ?? 'general';
        donationsByPurpose[purpose] = (donationsByPurpose[purpose] ?? 0) + 1;

        final monthKey =
            '${donation.donationDate.year}-${donation.donationDate.month.toString().padLeft(2, '0')}';
        donationsByMonth[monthKey] = (donationsByMonth[monthKey] ?? 0) + 1;

        topDonors[donation.userId] =
            (topDonors[donation.userId] ?? 0.0) + donation.amount;
      }

      return stats;
    } catch (e) {
      throw Exception('Failed to get temple donation statistics: $e');
    }
  }

  /// Get donation purposes
  List<String> getDonationPurposes() {
    return [
      'general',
      'festival',
      'maintenance',
      'construction',
      'food',
      'education',
    ];
  }

  /// Validate payment method
  bool isValidPaymentMethod(String paymentMethod) {
    final validMethods = ['card', 'upi', 'netbanking', 'wallet', 'cash'];
    return validMethods.contains(paymentMethod);
  }

  /// Get donation amount suggestions
  List<double> getDonationAmountSuggestions() {
    return [51.0, 101.0, 251.0, 501.0, 1001.0, 2501.0];
  }

  /// Check if temple accepts donations
  Future<bool> templeAcceptsDonations(String templeId) async {
    try {
      final templeDoc = await _firestore
          .collection(_templesCollection)
          .doc(templeId)
          .get();

      if (!templeDoc.exists) return false;

      final temple = Temple.fromFirestore(templeDoc);
      // For now, assume all active temples accept donations
      return temple.isActive;
    } catch (e) {
      return false;
    }
  }

  /// Get available payment methods for donation (Stripe only)
  Future<List<Map<String, dynamic>>> getAvailablePaymentMethods({
    required double amount,
    required String currency,
  }) async {
    try {
      // Stripe card payment method
      return [
        {
          'id': 'stripe',
          'name': 'Secure Payment',
          'type': 'stripe',
          'isEnabled': true,
          'minAmount': PaymentConfig.minimumDonationAmount,
          'maxAmount': PaymentConfig.maximumDonationAmount,
          'supportedCurrencies': ['USD', 'EUR', 'GBP'],
          'description': 'Cards, UPI, Google Pay & more via Stripe',
        },
      ];
    } catch (e) {
      throw Exception('Failed to get payment methods: $e');
    }
  }

  /// Validate payment method for donation
  Future<bool> validatePaymentMethod({
    required String paymentMethodId,
    required Map<String, dynamic> paymentData,
  }) async {
    try {
      // For Stripe, we support all payment methods
      return paymentMethodId == 'stripe';
    } catch (e) {
      return false;
    }
  }

  /// Validate customer information
  void _validateCustomerInfo(Map<String, dynamic> customerInfo) {
    if (kDebugMode) {
      debugPrint(
        '🔍 Validating customer info keys: ${customerInfo.keys.toList()}',
      );
    }

    // Only name and email are required; contact/phone is optional
    final requiredFields = ['name', 'email'];

    for (final field in requiredFields) {
      if (!customerInfo.containsKey(field) ||
          customerInfo[field] == null ||
          customerInfo[field].toString().isEmpty) {
        throw ArgumentError('Missing required customer field: $field');
      }
    }

    // Validate email format
    final email = customerInfo['email'] as String;
    if (!RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,4}$').hasMatch(email)) {
      throw ArgumentError('Invalid email format');
    }

    // Validate contact format only if provided and non-empty
    final contact = customerInfo['contact']?.toString() ?? '';
    if (contact.isNotEmpty &&
        !RegExp(r'^\+?[1-9]\d{1,14}$').hasMatch(contact)) {
      throw ArgumentError('Invalid contact format');
    }
  }

  /// Generate secure receipt with Stripe payment gateway integration
  Future<String> _generateSecureReceipt(
    Donation donation,
    PaymentTransaction transaction,
    Map<String, dynamic> customerInfo,
  ) async {
    try {
      // Pass real user name and email from customerInfo to the receipt
      final receiptUrl = await _generateReceipt(
        donation,
        userName: customerInfo['name'] as String?,
        userEmail: customerInfo['email'] as String?,
      );

      // Update donation with receipt URL
      await _firestore.collection(_donationsCollection).doc(donation.id).update(
        {
          'receiptUrl': receiptUrl,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        },
      );

      if (kDebugMode) {
        debugPrint('✅ Generated secure receipt for donation: ${donation.id}');
      }

      return receiptUrl;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Failed to generate secure receipt: $e');
      }
      throw Exception('Failed to generate secure receipt: $e');
    }
  }

  /// Get payment analytics for temple (admin use)
  Future<Map<String, dynamic>> getPaymentAnalytics(String templeId) async {
    try {
      final donations = await getTempleDonations(templeId);
      final transactions = await _getTempleTransactions(templeId);

      final analytics = {
        'total_donations': donations.length,
        'total_amount': donations.fold(0.0, (total, d) => total + d.amount),
        'successful_payments': transactions.where((t) => t.isSuccessful).length,
        'failed_payments': transactions.where((t) => t.hasFailed).length,
        'refunded_payments': transactions
            .where((t) => t.status == PaymentTransactionStatus.refunded)
            .length,
        'total_processing_fees': transactions
            .where((t) => t.processingFee != null)
            .fold(0.0, (total, t) => total + (t.processingFee ?? 0.0)),
        'payment_methods': <String, int>{},
        'monthly_trends': <String, double>{},
        'success_rate': 0.0,
      };

      // Calculate payment method distribution
      final paymentMethods = analytics['payment_methods'] as Map<String, int>;
      for (final transaction in transactions) {
        if (transaction.paymentMethod != null) {
          paymentMethods[transaction.paymentMethod!] =
              (paymentMethods[transaction.paymentMethod!] ?? 0) + 1;
        }
      }

      // Calculate success rate
      final totalTransactions = transactions.length;
      final successfulTransactions = transactions
          .where((t) => t.isSuccessful)
          .length;
      analytics['success_rate'] = totalTransactions > 0
          ? (successfulTransactions / totalTransactions) * 100
          : 0.0;

      return analytics;
    } catch (e) {
      throw Exception('Failed to get payment analytics: $e');
    }
  }

  /// Get temple transactions
  Future<List<PaymentTransaction>> _getTempleTransactions(
    String templeId,
  ) async {
    try {
      final querySnapshot = await _firestore
          .collection(_transactionsCollection)
          .where('metadata.temple_id', isEqualTo: templeId)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => PaymentTransaction.fromFirestore(doc))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Validate payment configuration
  bool validatePaymentConfiguration() {
    return PaymentConfig.validateConfig();
  }

  /// Get payment security features
  List<String> getPaymentSecurityFeatures() {
    return [
      'PCI DSS Compliant',
      'SSL/TLS Encryption',
      'Secure Payment Gateway',
      'Fraud Detection',
      'Real-time Verification',
      'Secure Receipt Generation',
      'Audit Trail',
      'Refund Protection',
    ];
  }

  /// Track donation activity in Firebase
  Future<void> _trackDonationActivity(Donation donation) async {
    try {
      await _firestore.collection('user_activities').add({
        'userId': donation.userId,
        'type': 'donation',
        'data': {
          'donationId': donation.id,
          'templeId': donation.templeId,
          'amount': donation.amount,
          'currency': donation.currency,
          'purpose': donation.purpose ?? 'general',
          'paymentMethod': donation.paymentMethod,
        },
        'timestamp': Timestamp.fromDate(DateTime.now()),
        'createdAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      if (kDebugMode) {
        print('Failed to track donation activity: $e');
      }
      // Don't throw error for activity tracking failures
    }
  }

  /// Send donation confirmation notification
  Future<void> _sendDonationConfirmation(Donation donation) async {
    try {
      // Get temple information
      final templeDoc = await _firestore
          .collection(_templesCollection)
          .doc(donation.templeId)
          .get();

      String templeName = 'Unknown Temple';
      if (templeDoc.exists) {
        final data = templeDoc.data();
        if (data != null && data['name'] != null) {
          templeName = data['name'] as String;
        }
      }

      // Create confirmation notification
      await _notificationService.createNotification(
        userId: donation.userId,
        title: 'Donation Received! 🙏',
        message:
            'Thank you for your donation of ₹${donation.amount.toStringAsFixed(2)} to $templeName. Your receipt will be available shortly.',
        type: NotificationType.donationConfirmation,
        priority: NotificationPriority.high,
        relatedId: donation.id,
        relatedType: 'donation',
        actionData: {
          'donationId': donation.id,
          'templeId': donation.templeId,
          'templeName': templeName,
          'amount': donation.amount,
          'currency': donation.currency,
          'purpose': donation.purpose ?? 'general',
          'transactionId': donation.transactionId,
        },
      );

      if (kDebugMode) {
        debugPrint(
          'DonationService: Sent confirmation notification for donation ${donation.id}',
        );
      }
    } catch (e) {
      // Don't fail the donation if notification fails
      if (kDebugMode) {
        debugPrint(
          'DonationService: Failed to send donation confirmation notification: $e',
        );
      }
    }
  }
}
