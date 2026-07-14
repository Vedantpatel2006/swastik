import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Payment configuration constants with production security
/// ONLY STRIPE PAYMENT GATEWAY - All other gateways removed
///
/// ARCHITECTURE NOTE:
/// - Publishable key (pk_*) lives here — safe for frontend
/// - Secret key (sk_*) and webhook secret MUST live on backend only
/// - PaymentIntent creation and webhook verification must be done server-side
class PaymentConfig {
  // SECURITY: Environment-based configuration
  // isProduction can still be set via --dart-define=PRODUCTION=true at build time
  static const bool isProduction = bool.fromEnvironment(
    'PRODUCTION',
    defaultValue: false,
  );

  /// Stripe publishable key — read from .env at runtime (safe for frontend).
  /// Uses a single STRIPE_PUBLISHABLE_KEY entry; swap the value for live key
  /// when building for production.
  static String get stripePublishableKey =>
      dotenv.env['STRIPE_PUBLISHABLE_KEY'] ?? '';

  // Human-readable environment label for debug UI / logging
  static String get environmentName => isProduction ? 'PRODUCTION' : 'TEST';

  // Stripe US account supported currencies (INR/UPI not supported)
  static const Map<String, String> supportedCurrencies = {
    'USD': 'US Dollar',
    'EUR': 'Euro',
    'GBP': 'British Pound',
  };

  // SECURITY: Enforce minimum amounts to prevent micro-transaction abuse
  static const double minimumDonationAmount = 1.0;
  static const double maximumDonationAmount = 100000.0;
  static const double minimumBookingAmount = 10.0;
  static const double maximumBookingAmount = 50000.0;

  static const String receiptPrefix = 'SWASTIK';
  static const int receiptNumberLength = 16;
  static const Duration disputeTimeout = Duration(days: 180);

  // ⚠️  WEBHOOK SECRET REMOVED FROM FRONTEND
  // The webhook secret (STRIPE_WEBHOOK_SECRET) must only exist on your
  // backend server (Firebase Functions / Node.js). It is used to verify
  // Stripe event signatures and must never be shipped in a Flutter app.

  /// Validates that a valid publishable key is present.
  static bool validateConfig() {
    final key = stripePublishableKey;
    return key.length > 20 &&
        (key.startsWith('pk_test_') || key.startsWith('pk_live_')) &&
        receiptPrefix.isNotEmpty &&
        receiptNumberLength > 0;
  }

  /// Returns true only when a valid publishable key is present.
  static bool get isStripeConfigured {
    final key = stripePublishableKey;
    return key.length > 20 &&
        (key.startsWith('pk_test_') || key.startsWith('pk_live_'));
  }

  /// Returns true when [amount] is within the allowed donation range.
  static bool isValidDonationAmount(double amount) {
    return amount >= minimumDonationAmount && amount <= maximumDonationAmount;
  }

  /// Returns true when [amount] is within the allowed booking range.
  static bool isValidBookingAmount(double amount) {
    return amount >= minimumBookingAmount && amount <= maximumBookingAmount;
  }

  /// Returns true when [currency] is in the supported currencies map.
  static bool isCurrencySupported(String currency) {
    return supportedCurrencies.containsKey(currency.toUpperCase());
  }

  /// Get current payment gateway (Stripe only)
  static String get primaryPaymentGateway => 'stripe';

  /// Safe environment info for debugging — no secrets included.
  static Map<String, dynamic> get environmentInfo => {
    'environment': environmentName,
    'paymentGateway': primaryPaymentGateway,
    'stripeConfigured': isStripeConfigured,
  };
}
