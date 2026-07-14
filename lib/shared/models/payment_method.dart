/// Payment method type enumeration
/// All methods are handled through Stripe Payment Sheet interface
enum PaymentMethodType { card, upi, netbanking, wallet }

/// Payment method model for Stripe-supported payment options
/// All payment methods handled through Stripe Payment Sheet
class PaymentMethod {
  final String id;
  final String name;
  final PaymentMethodType type;
  final bool isEnabled;
  final double minAmount;
  final double maxAmount;
  final double processingFee;
  final String description;
  final List<String> supportedCurrencies;
  final String? iconUrl;
  final Map<String, dynamic>? configuration;
  final List<String>? supportedBanks;
  final List<String>? supportedWallets;
  final bool requiresVerification;
  final int? processingTimeMinutes;

  const PaymentMethod({
    required this.id,
    required this.name,
    required this.type,
    this.isEnabled = true,
    this.minAmount = 1.0,
    this.maxAmount = 1000000.0,
    this.processingFee = 0.0,
    this.description = '',
    this.supportedCurrencies = const ['USD', 'EUR', 'GBP'],
    this.iconUrl,
    this.configuration,
    this.supportedBanks,
    this.supportedWallets,
    this.requiresVerification = false,
    this.processingTimeMinutes,
  });

  /// Create PaymentMethod from JSON
  factory PaymentMethod.fromJson(Map<String, dynamic> json) {
    return PaymentMethod(
      id: json['id'] as String,
      name: json['name'] as String,
      type: PaymentMethodType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => PaymentMethodType.card,
      ),
      isEnabled: json['isEnabled'] as bool? ?? true,
      minAmount: (json['minAmount'] as num?)?.toDouble() ?? 1.0,
      maxAmount: (json['maxAmount'] as num?)?.toDouble() ?? 1000000.0,
      processingFee: (json['processingFee'] as num?)?.toDouble() ?? 0.0,
      description: json['description'] as String? ?? '',
      supportedCurrencies: json['supportedCurrencies'] != null
          ? List<String>.from(json['supportedCurrencies'] as List)
          : ['USD', 'EUR', 'GBP'],
      iconUrl: json['iconUrl'] as String?,
      configuration: json['configuration'] != null
          ? Map<String, dynamic>.from(json['configuration'] as Map)
          : null,
      supportedBanks: json['supportedBanks'] != null
          ? List<String>.from(json['supportedBanks'] as List)
          : null,
      supportedWallets: json['supportedWallets'] != null
          ? List<String>.from(json['supportedWallets'] as List)
          : null,
      requiresVerification: json['requiresVerification'] as bool? ?? false,
      processingTimeMinutes: json['processingTimeMinutes'] as int?,
    );
  }

  /// Convert PaymentMethod to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'isEnabled': isEnabled,
      'minAmount': minAmount,
      'maxAmount': maxAmount,
      'processingFee': processingFee,
      'description': description,
      'supportedCurrencies': supportedCurrencies,
      if (iconUrl != null) 'iconUrl': iconUrl,
      if (configuration != null) 'configuration': configuration,
      if (supportedBanks != null) 'supportedBanks': supportedBanks,
      if (supportedWallets != null) 'supportedWallets': supportedWallets,
      'requiresVerification': requiresVerification,
      if (processingTimeMinutes != null)
        'processingTimeMinutes': processingTimeMinutes,
    };
  }

  /// Create a copy of PaymentMethod with updated fields
  PaymentMethod copyWith({
    String? id,
    String? name,
    PaymentMethodType? type,
    bool? isEnabled,
    double? minAmount,
    double? maxAmount,
    double? processingFee,
    String? description,
    List<String>? supportedCurrencies,
    String? iconUrl,
    Map<String, dynamic>? configuration,
    List<String>? supportedBanks,
    List<String>? supportedWallets,
    bool? requiresVerification,
    int? processingTimeMinutes,
  }) {
    return PaymentMethod(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      isEnabled: isEnabled ?? this.isEnabled,
      minAmount: minAmount ?? this.minAmount,
      maxAmount: maxAmount ?? this.maxAmount,
      processingFee: processingFee ?? this.processingFee,
      description: description ?? this.description,
      supportedCurrencies: supportedCurrencies ?? this.supportedCurrencies,
      iconUrl: iconUrl ?? this.iconUrl,
      configuration: configuration ?? this.configuration,
      supportedBanks: supportedBanks ?? this.supportedBanks,
      supportedWallets: supportedWallets ?? this.supportedWallets,
      requiresVerification: requiresVerification ?? this.requiresVerification,
      processingTimeMinutes:
          processingTimeMinutes ?? this.processingTimeMinutes,
    );
  }

  /// Get type display name
  String get typeDisplayName {
    switch (type) {
      case PaymentMethodType.card:
        return 'Credit/Debit Card';
      case PaymentMethodType.upi:
        return 'UPI';
      case PaymentMethodType.netbanking:
        return 'Net Banking';
      case PaymentMethodType.wallet:
        return 'Digital Wallet';
    }
  }

  /// Get formatted processing fee
  String getFormattedProcessingFee(String currency) {
    if (processingFee == 0) return 'Free';

    switch (currency) {
      case 'INR':
        return '₹${processingFee.toStringAsFixed(2)}';
      case 'USD':
        return '\$${processingFee.toStringAsFixed(2)}';
      case 'EUR':
        return '€${processingFee.toStringAsFixed(2)}';
      case 'GBP':
        return '£${processingFee.toStringAsFixed(2)}';
      default:
        return '$currency ${processingFee.toStringAsFixed(2)}';
    }
  }

  /// Get formatted amount range
  String getFormattedAmountRange(String currency) {
    String formatAmount(double amount) {
      switch (currency) {
        case 'INR':
          return '₹${amount.toStringAsFixed(0)}';
        case 'USD':
          return '\$${amount.toStringAsFixed(0)}';
        case 'EUR':
          return '€${amount.toStringAsFixed(0)}';
        case 'GBP':
          return '£${amount.toStringAsFixed(0)}';
        default:
          return '$currency ${amount.toStringAsFixed(0)}';
      }
    }

    return '${formatAmount(minAmount)} - ${formatAmount(maxAmount)}';
  }

  /// Get formatted processing time
  String get formattedProcessingTime {
    if (processingTimeMinutes == null) return 'Instant';

    if (processingTimeMinutes! < 60) {
      return '${processingTimeMinutes!} minutes';
    } else if (processingTimeMinutes! < 1440) {
      final hours = (processingTimeMinutes! / 60).round();
      return '$hours ${hours == 1 ? 'hour' : 'hours'}';
    } else {
      final days = (processingTimeMinutes! / 1440).round();
      return '$days ${days == 1 ? 'day' : 'days'}';
    }
  }

  /// Check if payment method supports currency
  bool supportsCurrency(String currency) {
    return supportedCurrencies.contains(currency);
  }

  /// Check if amount is within limits
  bool isAmountValid(double amount) {
    return amount >= minAmount && amount <= maxAmount;
  }

  /// Check if payment method supports bank
  bool supportsBank(String bankCode) {
    return supportedBanks?.contains(bankCode) ?? false;
  }

  /// Check if payment method supports wallet
  bool supportsWallet(String walletType) {
    return supportedWallets?.contains(walletType) ?? false;
  }

  /// Get payment method icon based on type
  String get defaultIconPath {
    switch (type) {
      case PaymentMethodType.card:
        return 'assets/icons/payment/card.png';
      case PaymentMethodType.upi:
        return 'assets/icons/payment/upi.png';
      case PaymentMethodType.netbanking:
        return 'assets/icons/payment/netbanking.png';
      case PaymentMethodType.wallet:
        return 'assets/icons/payment/wallet.png';
    }
  }

  /// Get payment method color based on type
  int get defaultColor {
    switch (type) {
      case PaymentMethodType.card:
        return 0xFF2196F3; // Blue
      case PaymentMethodType.upi:
        return 0xFF4CAF50; // Green
      case PaymentMethodType.netbanking:
        return 0xFF9C27B0; // Purple
      case PaymentMethodType.wallet:
        return 0xFFFF9800; // Orange
    }
  }

  /// Get detailed description based on type
  String get detailedDescription {
    if (description.isNotEmpty) return description;

    switch (type) {
      case PaymentMethodType.card:
        return 'Pay securely using your credit or debit card. Stripe supports Visa, Mastercard, RuPay, and American Express.';
      case PaymentMethodType.upi:
        return 'Pay instantly using UPI apps like PhonePe, Google Pay, Paytm, or any UPI-enabled app. UPI payments are processed securely through Stripe.';
      case PaymentMethodType.netbanking:
        return 'Pay directly from your bank account using internet banking. All major banks are supported through Stripe.';
      case PaymentMethodType.wallet:
        return 'Pay using your digital wallet. Stripe supports Apple Pay, Google Pay, and other popular digital wallets.';
    }
  }

  /// Get security features based on type
  List<String> get securityFeatures {
    switch (type) {
      case PaymentMethodType.card:
        return [
          '3D Secure authentication',
          'PCI DSS Level 1 compliant',
          'SSL encrypted',
          'Advanced fraud detection',
        ];
      case PaymentMethodType.upi:
        return [
          'UPI PIN protection',
          'Bank-grade security',
          'Real-time verification',
          'Instant confirmation',
        ];
      case PaymentMethodType.netbanking:
        return [
          'Bank-level security',
          'OTP verification',
          'Session timeout protection',
          'Encrypted transactions',
        ];
      case PaymentMethodType.wallet:
        return [
          'Wallet PIN/biometric',
          'Transaction limits',
          'Real-time alerts',
          'Secure balance storage',
        ];
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PaymentMethod &&
        other.id == id &&
        other.name == name &&
        other.type == type &&
        other.isEnabled == isEnabled;
  }

  @override
  int get hashCode {
    return Object.hash(id, name, type, isEnabled);
  }

  @override
  String toString() {
    return 'PaymentMethod(id: $id, name: $name, type: ${type.name}, '
        'enabled: $isEnabled, range: ${getFormattedAmountRange('USD')})';
  }
}
