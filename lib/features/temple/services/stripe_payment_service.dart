import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/payment_config.dart';
import '../../../shared/models/donation.dart';
import '../../../shared/models/booking.dart';
import '../../../shared/models/payment_transaction.dart';

/// Service for handling Stripe payments with server-side security
/// Supports both donations and booking payments
class StripePaymentService {
  static StripePaymentService? _instance;
  static StripePaymentService get instance => _instance ??= StripePaymentService._();
  
  StripePaymentService._();

  bool _isInitialized = false;

  /// Initialize Stripe with publishable key
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      Stripe.publishableKey = PaymentConfig.stripePublishableKey;
      
      // Configure Stripe settings
      await Stripe.instance.applySettings();
      
      _isInitialized = true;
      
      if (kDebugMode) {
        debugPrint('✅ Stripe initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Failed to initialize Stripe: $e');
      }
      throw Exception('Failed to initialize Stripe: $e');
    }
  }

  /// Create payment intent via Supabase Edge Function
  /// NOTE: paymentMethod parameter is DEPRECATED - removed to use PaymentSheet for all methods
  Future<Map<String, dynamic>> createPaymentIntent({
    required double amount,
    required String currency,
    required Map<String, dynamic> metadata,
    String? customerId,
  }) async {
    if (kDebugMode) {
      debugPrint('🔍 Creating payment intent for amount: $amount $currency');
    }

    final response = await Supabase.instance.client.functions.invoke(
      'create-payment-intent',
      body: {
        'amount': amount,
        'currency': currency,
        'metadata': metadata,
        if (customerId != null) 'customer_id': customerId,
      },
    );

    if (response.data == null) {
      throw Exception('Empty response from payment service');
    }

    final data = Map<String, dynamic>.from(response.data as Map);

    if (data.containsKey('error')) {
      throw Exception(data['error'] as String);
    }

    if (kDebugMode) {
      debugPrint('✅ Created payment intent: ${data['id']}');
    }

    return data;
  }

  /// Process donation payment with server-side verification
  Future<PaymentTransaction> processDonationPayment({
    required Donation donation,
    required Map<String, dynamic> customerInfo,
  }) async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      // Step 1: Get or create a real Stripe customer + ephemeral key
      String? customerId;
      String? ephemeralKey;
      try {
        final customerData = await createCustomer(
          email: customerInfo['email'] as String? ?? '',
          name: customerInfo['name'] as String? ?? '',
          phone: customerInfo['phone'] as String?,
        );
        customerId = customerData['id'] as String?;
        ephemeralKey = customerData['ephemeral_key'] as String?;
      } catch (e) {
        // Non-fatal — Payment Sheet works without a customer, just no saved methods
        if (kDebugMode) debugPrint('⚠️ Could not create customer: $e');
      }

      // Step 2: Create payment intent server-side
      final paymentIntentData = await createPaymentIntent(
        amount: donation.amount,
        currency: donation.currency,
        metadata: {
          'donation_id': donation.id,
          'temple_id': donation.templeId,
          'user_id': donation.userId,
          'purpose': donation.purpose ?? 'general',
        },
        customerId: customerId,
      );

      // Step 3: Initialize payment sheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: paymentIntentData['client_secret'],
          merchantDisplayName: 'Swastik Temple App',
          style: ThemeMode.system,
          returnURL: 'com.swastik.stripe://return',
          // Attach customer + ephemeral key when available for saved methods
          customerId: customerId,
          customerEphemeralKeySecret: ephemeralKey,
          googlePay: PaymentSheetGooglePay(
            // US account — must use US as merchant country.
            // Change to 'IN' only after migrating to an Indian Stripe account.
            merchantCountryCode: 'US',
            currencyCode: donation.currency.toLowerCase(),
            testEnv: !PaymentConfig.isProduction,
          ),
          billingDetails: BillingDetails(
            name: customerInfo['name'],
            email: customerInfo['email'],
            phone: customerInfo['phone'],
          ),
        ),
      );

      // Present payment sheet
      await Stripe.instance.presentPaymentSheet();

      // SECURITY FIX: Payment success will be verified by webhook
      // Don't trust client-side success immediately
      final transaction = PaymentTransaction(
        id: '',
        orderId: donation.id,
        gatewayOrderId: paymentIntentData['id'],
        amount: donation.amount,
        currency: donation.currency,
        status: PaymentTransactionStatus.authorized,
        paymentMethod: 'stripe',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        netAmount: donation.amount,
        metadata: {
          'payment_intent_id': paymentIntentData['id'],
          'donation_id': donation.id,
          'temple_id': donation.templeId,
          'user_id': donation.userId,
          'requires_webhook_verification': true,
        },
      );

      if (kDebugMode) {
        debugPrint('✅ Stripe payment submitted, awaiting server verification');
      }

      return transaction;
    } on StripeException catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Stripe payment failed: ${e.error.localizedMessage}');
      }
      
      // Return failed transaction
      return PaymentTransaction(
        id: '',
        orderId: donation.id,
        amount: donation.amount,
        currency: donation.currency,
        status: PaymentTransactionStatus.failed,
        paymentMethod: 'stripe',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        netAmount: donation.amount,
        failureReason: e.error.localizedMessage,
        metadata: {
          'donation_id': donation.id,
          'temple_id': donation.templeId,
          'user_id': donation.userId,
          'error_type': e.error.type?.toString() ?? 'unknown',
        },
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Payment processing failed: $e');
      }
      
      // Return failed transaction
      return PaymentTransaction(
        id: '',
        orderId: donation.id,
        amount: donation.amount,
        currency: donation.currency,
        status: PaymentTransactionStatus.failed,
        paymentMethod: 'stripe',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        netAmount: donation.amount,
        failureReason: e.toString(),
        metadata: {
          'donation_id': donation.id,
          'temple_id': donation.templeId,
          'user_id': donation.userId,
        },
      );
    }
  }

  /// Create customer for recurring payments via Supabase Edge Function
  Future<Map<String, dynamic>> createCustomer({
    required String email,
    required String name,
    String? phone,
  }) async {
    if (kDebugMode) {
      debugPrint('🔍 Creating Stripe customer for: $email');
    }

    final response = await Supabase.instance.client.functions.invoke(
      'create-customer',
      body: {
        'email': email,
        'name': name,
        if (phone != null) 'phone': phone},
    );

    if (response.data == null) {
      throw Exception('Empty response from customer service');
    }

    final data = Map<String, dynamic>.from(response.data as Map);

    if (data.containsKey('error')) {
      throw Exception(data['error'] as String);
    }

    if (kDebugMode) {
      debugPrint('✅ Created Stripe customer: ${data['id']}');
    }

    return data;
  }

  /// Validate payment method (basic client-side format check)
  Future<bool> validatePaymentMethod(String paymentMethodId) async {
    return paymentMethodId.isNotEmpty && paymentMethodId.startsWith('pm_');
  }

  /// Get payment methods for customer via Supabase Edge Function
  Future<List<Map<String, dynamic>>> getPaymentMethods(
    String customerId,
  ) async {
    if (kDebugMode) {
      debugPrint('🔍 Fetching payment methods for customer: $customerId');
    }

    final response = await Supabase.instance.client.functions.invoke(
      'get-payment-methods',
      body: {'customer_id': customerId},
    );

    if (response.data == null) {
      throw Exception('Empty response from payment methods service');
    }

    final data = Map<String, dynamic>.from(response.data as Map);

    if (data.containsKey('error')) {
      throw Exception(data['error'] as String);
    }

    final methods = data['payment_methods'] as List<dynamic>? ?? [];
    return methods.map((m) => Map<String, dynamic>.from(m as Map)).toList();
  }

  /// Refund payment via Supabase Edge Function (calls Stripe server-side)
  Future<Map<String, dynamic>> refundPayment({
    required String paymentIntentId,
    required double amount,
    String? reason,
  }) async {
    if (kDebugMode) {
      debugPrint(
        '🔍 Creating refund for payment intent: $paymentIntentId, amount: $amount',
      );
    }

    final response = await Supabase.instance.client.functions.invoke(
      'create-refund',
      body: {
        'payment_intent_id': paymentIntentId,
        'amount': amount,
        if (reason != null) 'reason': reason,
      },
    );

    if (response.data == null) {
      throw Exception('Empty response from refund service');
    }

    final data = Map<String, dynamic>.from(response.data as Map);

    if (data.containsKey('error')) {
      throw Exception(data['error'] as String);
    }

    if (kDebugMode) {
      debugPrint('✅ Refund created: ${data['id']} status: ${data['status']}');
    }

    return data;
  }

  /// Check if Stripe is properly configured
  bool get isConfigured => PaymentConfig.isStripeConfigured;

  /// Get supported currencies (Stripe US account — INR not supported)
  List<String> get supportedCurrencies => ['usd', 'eur', 'gbp'];

  /// Get minimum charge amount for currency
  double getMinimumAmount(String currency) {
    switch (currency.toLowerCase()) {
      case 'usd':
      case 'eur':
      case 'gbp':
        return 0.50;
      case 'inr':
        return 50.0;
      default:
        return 1.0;
    }
  }

  /// Get maximum charge amount for currency
  double getMaximumAmount(String currency) {
    switch (currency.toLowerCase()) {
      case 'usd':
      case 'eur':
      case 'gbp':
        return 999999.99;
      case 'inr':
        return 1500000.0; // ~$18,000 USD
      default:
        return 999999.99;
    }
  }

  /// Format amount for display
  String formatAmount(double amount, String currency) {
    switch (currency.toLowerCase()) {
      case 'usd':
        return '\$${amount.toStringAsFixed(2)}';
      case 'eur':
        return '€${amount.toStringAsFixed(2)}';
      case 'gbp':
        return '£${amount.toStringAsFixed(2)}';
      case 'inr':
        return '₹${amount.toStringAsFixed(2)}';
      default:
        return '${amount.toStringAsFixed(2)} ${currency.toUpperCase()}';
    }
  }

  /// Process booking payment with server-side verification
  Future<PaymentTransaction> processBookingPayment({
    required Booking booking,
    required Map<String, dynamic> customerInfo,
  }) async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      // Validate booking has amount
      if (booking.amount == null || booking.amount! <= 0) {
        throw Exception('Invalid booking amount');
      }

      // Step 1: Get or create a real Stripe customer + ephemeral key
      String? customerId;
      String? ephemeralKey;
      try {
        final customerData = await createCustomer(
          email: customerInfo['email'] as String? ?? '',
          name: customerInfo['name'] as String? ?? '',
          phone: customerInfo['phone'] as String?,
        );
        customerId = customerData['id'] as String?;
        ephemeralKey = customerData['ephemeral_key'] as String?;
      } catch (e) {
        if (kDebugMode) debugPrint('⚠️ Could not create customer: $e');
      }

      // Step 2: Create payment intent server-side
      final paymentIntentData = await createPaymentIntent(
        amount: booking.amount!,
        currency: booking.currency ?? 'USD',
        metadata: {
          'booking_id': booking.id,
          'temple_id': booking.templeId,
          'user_id': booking.userId,
          'booking_type': booking.bookingType,
          'booking_date': booking.bookingDate.toIso8601String(),
          'number_of_people': booking.numberOfPeople.toString(),
        },
        customerId: customerId,
      );

      // Step 3: Initialize payment sheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: paymentIntentData['client_secret'],
          merchantDisplayName: 'Swastik Temple App',
          style: ThemeMode.system,
          returnURL: 'com.swastik.stripe://return',
          customerId: customerId,
          customerEphemeralKeySecret: ephemeralKey,
          googlePay: PaymentSheetGooglePay(
            merchantCountryCode: 'US',
            currencyCode: (booking.currency ?? 'USD').toLowerCase(),
            testEnv: !PaymentConfig.isProduction,
          ),
          billingDetails: BillingDetails(
            name: customerInfo['name'],
            email: customerInfo['email'],
            phone: customerInfo['phone'],
          ),
        ),
      );

      // Present payment sheet
      await Stripe.instance.presentPaymentSheet();

      // SECURITY FIX: Payment success will be verified by webhook
      final transaction = PaymentTransaction(
        id: '',
        orderId: booking.id,
        gatewayOrderId: paymentIntentData['id'],
        amount: booking.amount!,
        currency: booking.currency ?? 'USD',
        status: PaymentTransactionStatus.authorized,
        paymentMethod: 'stripe',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        netAmount: booking.amount!,
        metadata: {
          'payment_intent_id': paymentIntentData['id'],
          'booking_id': booking.id,
          'temple_id': booking.templeId,
          'user_id': booking.userId,
          'booking_type': booking.bookingType,
          'requires_webhook_verification': true,
        },
      );

      if (kDebugMode) {
        debugPrint(
          '✅ Stripe booking payment submitted, awaiting server verification',
        );
      }

      return transaction;
    } on StripeException catch (e) {
      if (kDebugMode) {
        debugPrint(
          '❌ Stripe booking payment failed: ${e.error.localizedMessage}',
        );
      }

      // Return failed transaction
      return PaymentTransaction(
        id: '',
        orderId: booking.id,
        amount: booking.amount ?? 0,
        currency: booking.currency ?? 'USD',
        status: PaymentTransactionStatus.failed,
        paymentMethod: 'stripe',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        netAmount: booking.amount ?? 0,
        failureReason: e.error.localizedMessage,
        metadata: {
          'booking_id': booking.id,
          'temple_id': booking.templeId,
          'user_id': booking.userId,
          'error_type': e.error.type?.toString() ?? 'unknown',
        },
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Booking payment processing failed: $e');
      }

      // Return failed transaction
      return PaymentTransaction(
        id: '',
        orderId: booking.id,
        amount: booking.amount ?? 0,
        currency: booking.currency ?? 'USD',
        status: PaymentTransactionStatus.failed,
        paymentMethod: 'stripe',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        netAmount: booking.amount ?? 0,
        failureReason: e.toString(),
        metadata: {
          'booking_id': booking.id,
          'temple_id': booking.templeId,
          'user_id': booking.userId,
        },
      );
    }
  }
}
