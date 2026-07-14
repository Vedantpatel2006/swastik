import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:math';
import '../../shared/models/donation.dart';
import 'user_stats_service.dart';
import 'supabase_notification_service.dart';
import 'service_container.dart';
import '../../shared/models/notification.dart';

/// Unified service for managing temple donations and payments
/// Consolidates both user and temple donation functionality
class UnifiedDonationService {
  static final UnifiedDonationService _instance =
      UnifiedDonationService._internal();
  factory UnifiedDonationService() => _instance;
  UnifiedDonationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final UserStatsService _userStatsService = UserStatsService();

  // Use centralized service container for NotificationService
  SupabaseNotificationService get _notificationService =>
      services.notificationService;

  // Collections
  static const String _donationsCollection = 'donations';
  static const String _templesCollection = 'temples';

  /// Initialize the service
  Future<void> initialize() async {
    // Stripe initialization is handled separately via StripePaymentService
  }

  String _generateTransactionId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(999999);
    final input = '$timestamp$random';
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return 'TXN_${digest.toString().substring(0, 16).toUpperCase()}';
  }

  String _generateReceiptNumber(String donationId) {
    final timestamp = DateTime.now();
    final year = timestamp.year.toString().substring(2);
    final month = timestamp.month.toString().padLeft(2, '0');
    final day = timestamp.day.toString().padLeft(2, '0');
    final sequence = donationId.substring(0, 6).toUpperCase();

    return 'RCP$year$month$day$sequence';
  }

  /// Helper methods
  void _validateDonationData({
    required double amount,
    required bool taxBenefitEligible,
    String? panNumber,
  }) {
    if (amount <= 0) {
      throw ArgumentError('Donation amount must be positive');
    }

    if (amount > 100000) {
      throw ArgumentError('Donation amount cannot exceed ₹1,00,000');
    }

    if (taxBenefitEligible && (panNumber == null || panNumber.isEmpty)) {
      throw ArgumentError('PAN number required for tax benefit');
    }

    if (panNumber != null && !_isValidPAN(panNumber)) {
      throw ArgumentError('Invalid PAN number format');
    }
  }

  bool _isValidPAN(String pan) {
    final panRegex = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]{1}$');
    return panRegex.hasMatch(pan);
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

  /// Create a new donation
  Future<Donation> createDonation({
    required String userId,
    required String templeId,
    required double amount,
    required String paymentMethod,
    String? purpose,
    String? notes,
    String currency = 'USD',
  }) async {
    try {
      // Validate donation data
      _validateDonationData(
        amount: amount,
        taxBenefitEligible: false,
        panNumber: null,
      );

      final donation = Donation(
        id: '', // Will be set by Firestore
        userId: userId,
        templeId: templeId,
        amount: amount,
        currency: currency,
        paymentMethod: paymentMethod,
        status: DonationStatus.pending,
        donationDate: DateTime.now(),
        purpose: purpose,
        notes: notes,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Save donation to Firestore
      final docRef = await _firestore
          .collection(_donationsCollection)
          .add(donation.toJson());

      final createdDonation = donation.copyWith(id: docRef.id);

      if (kDebugMode) {
        debugPrint('UnifiedDonationService: Created donation ${docRef.id}');
      }

      return createdDonation;
    } catch (e) {
      throw Exception('Failed to create donation: $e');
    }
  }

  /// Process donation with payment
  Future<Donation> processDonation({
    required Donation donation,
    required Map<String, dynamic> customerInfo,
    String? paymentId,
    String? signature,
  }) async {
    try {
      Donation processedDonation;

      if (paymentId != null && signature != null) {
        // Process with actual payment
        processedDonation = await _processWithPayment(
          donation,
          customerInfo,
          paymentId,
          signature,
        );
      } else {
        // Simulate payment for testing
        processedDonation = await _simulatePaymentProcessing(donation);
      }

      // Update donation in Firestore
      await _firestore
          .collection(_donationsCollection)
          .doc(processedDonation.id)
          .update(processedDonation.toJson());

      // Handle successful donation
      if (processedDonation.status == DonationStatus.completed) {
        await _handleSuccessfulDonation(processedDonation, customerInfo);
      }

      return processedDonation;
    } catch (e) {
      throw Exception('Failed to process donation: $e');
    }
  }

  /// Process donation with actual payment gateway
  Future<Donation> _processWithPayment(
    Donation donation,
    Map<String, dynamic> customerInfo,
    String paymentId,
    String signature,
  ) async {
    // Simulate payment processing for now
    await Future.delayed(const Duration(seconds: 1));

    return donation.copyWith(
      status: DonationStatus.completed,
      transactionId: paymentId,
      paymentMetadata: {
        'gateway': 'stripe',
        'payment_id': paymentId,
        'signature': signature,
        'captured_at': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Simulate payment processing for testing
  Future<Donation> _simulatePaymentProcessing(Donation donation) async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 2));

    // Generate transaction ID
    final transactionId = _generateTransactionId();

    // Simulate payment success (90% success rate)
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

  /// Handle successful donation
  Future<void> _handleSuccessfulDonation(
    Donation donation,
    Map<String, dynamic>? customerInfo,
  ) async {
    try {
      // Update user statistics
      await _userStatsService.recordDonation(
        userId: donation.userId,
        amount: donation.amount,
      );

      // Generate receipt
      await _generateReceipt(donation, customerInfo);

      // Send confirmation notification
      await _sendDonationConfirmation(donation);

      // Track donation activity
      await _trackDonationActivity(donation);

      if (kDebugMode) {
        debugPrint(
          'UnifiedDonationService: Handled successful donation ${donation.id}',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'UnifiedDonationService: Error handling successful donation: $e',
        );
      }
      // Don't fail the donation if post-processing fails
    }
  }

  /// Generate receipt for donation
  Future<String> _generateReceipt(
    Donation donation,
    Map<String, dynamic>? customerInfo,
  ) async {
    try {
      // Generate receipt number
      final receiptNumber = _generateReceiptNumber(donation.id);

      // In a real implementation, generate PDF receipt
      // For now, we'll simulate the receipt generation
      final receiptId =
          'RECEIPT_${donation.id}_${DateTime.now().millisecondsSinceEpoch}';
      final receiptUrl =
          'https://storage.googleapis.com/swastik-receipts/$receiptId.pdf';

      // Update donation with receipt URL
      await _firestore
          .collection(_donationsCollection)
          .doc(donation.id)
          .update({
            'receiptUrl': receiptUrl,
            'receiptNumber': receiptNumber,
            'updatedAt': Timestamp.fromDate(DateTime.now()),
          });

      if (kDebugMode) {
        debugPrint(
          'UnifiedDonationService: Generated receipt for donation ${donation.id}',
        );
      }

      return receiptUrl;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('UnifiedDonationService: Failed to generate receipt: $e');
      }
      throw Exception('Failed to generate receipt: $e');
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
        if (data != null && data['name'] != null && data['name'] is String) {
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
          'UnifiedDonationService: Sent confirmation notification for donation ${donation.id}',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'UnifiedDonationService: Failed to send donation confirmation notification: $e',
        );
      }
    }
  }

  /// Track donation activity
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
        debugPrint(
          'UnifiedDonationService: Failed to track donation activity: $e',
        );
      }
    }
  }

  /// Get donation statistics for a user
  Future<Map<String, dynamic>> getUserDonationStats(String userId) async {
    try {
      final donations = await getUserDonations(userId);

      final completedDonations = donations
          .where((d) => d.status == DonationStatus.completed)
          .toList();

      final stats = {
        'totalDonations': donations.length,
        'completedDonations': completedDonations.length,
        'totalAmount': completedDonations.fold(
          0.0,
          (total, d) => total + d.amount,
        ),
        'averageDonation': 0.0,
        'donationsByType': <String, int>{},
        'donationsByMonth': <String, int>{},
        'largestDonation': 0.0,
        'mostRecentDonation': null,
      };

      if (completedDonations.isNotEmpty) {
        stats['averageDonation'] =
            (stats['totalAmount'] as double) / completedDonations.length;
        stats['largestDonation'] = completedDonations
            .map((d) => d.amount)
            .reduce((a, b) => a > b ? a : b);
        stats['mostRecentDonation'] = completedDonations.first.donationDate
            .toIso8601String();
      }

      // Calculate donations by type and month
      final donationsByType = stats['donationsByType'] as Map<String, int>;
      final donationsByMonth = stats['donationsByMonth'] as Map<String, int>;

      for (final donation in completedDonations) {
        final type = donation.purpose ?? 'general';
        donationsByType[type] = (donationsByType[type] ?? 0) + 1;

        final monthKey =
            '${donation.donationDate.year}-${donation.donationDate.month.toString().padLeft(2, '0')}';
        donationsByMonth[monthKey] = (donationsByMonth[monthKey] ?? 0) + 1;
      }

      return stats;
    } catch (e) {
      throw Exception('Failed to get donation statistics: $e');
    }
  }
}
