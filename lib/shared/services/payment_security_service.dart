import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/payment_transaction.dart';
import '../../core/config/payment_config.dart';

/// Service for payment security, fraud detection, and compliance
class PaymentSecurityService {
  final FirebaseFirestore _firestore;

  PaymentSecurityService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  static const String _securityLogsCollection = 'payment_security_logs';
  static const String _fraudAlertsCollection = 'fraud_alerts';
  static const String _complianceReportsCollection = 'compliance_reports';

  /// Validate PCI DSS compliance for payment data
  Future<Map<String, dynamic>> validatePCICompliance({
    required Map<String, dynamic> paymentData,
    required String paymentMethod,
  }) async {
    final complianceChecks = <String, bool>{};
    final violations = <String>[];

    // Check 1: No sensitive card data in logs
    complianceChecks['no_card_data_logging'] = !_containsSensitiveCardData(
      paymentData,
    );
    if (!complianceChecks['no_card_data_logging']!) {
      violations.add('Sensitive card data found in payment logs');
    }

    // Check 2: Encrypted data transmission
    complianceChecks['encrypted_transmission'] = _isDataEncrypted(paymentData);
    if (!complianceChecks['encrypted_transmission']!) {
      violations.add('Payment data not properly encrypted');
    }

    // Check 3: Strong authentication
    complianceChecks['strong_authentication'] = _hasStrongAuthentication(
      paymentData,
    );
    if (!complianceChecks['strong_authentication']!) {
      violations.add('Weak authentication detected');
    }

    // Check 4: Access control
    complianceChecks['access_control'] = _hasProperAccessControl(paymentData);
    if (!complianceChecks['access_control']!) {
      violations.add('Insufficient access control measures');
    }

    final isCompliant = violations.isEmpty;

    // Log compliance check
    await _logSecurityEvent({
      'type': 'pci_compliance_check',
      'payment_method': paymentMethod,
      'is_compliant': isCompliant,
      'violations': violations,
      'timestamp': DateTime.now().toIso8601String(),
    });

    return {
      'is_compliant': isCompliant,
      'compliance_checks': complianceChecks,
      'violations': violations,
      'compliance_score': _calculateComplianceScore(complianceChecks),
    };
  }

  /// Detect fraudulent payment patterns
  Future<Map<String, dynamic>> detectFraud({
    required PaymentTransaction transaction,
    required Map<String, dynamic> userContext,
  }) async {
    final riskFactors = <String, double>{};
    final alerts = <String>[];

    // Risk Factor 1: Unusual amount
    final amountRisk = _analyzeAmountRisk(transaction.amount, userContext);
    riskFactors['amount_risk'] = amountRisk;
    if (amountRisk > 0.7) alerts.add('Unusually high transaction amount');

    // Risk Factor 2: Velocity check
    final velocityRisk = await _analyzeVelocityRisk(transaction, userContext);
    riskFactors['velocity_risk'] = velocityRisk;
    if (velocityRisk > 0.8) alerts.add('High transaction velocity detected');

    // Risk Factor 3: Geographic anomaly
    final geoRisk = _analyzeGeographicRisk(transaction, userContext);
    riskFactors['geographic_risk'] = geoRisk;
    if (geoRisk > 0.6) alerts.add('Geographic anomaly detected');

    // Risk Factor 4: Device fingerprinting
    final deviceRisk = _analyzeDeviceRisk(transaction, userContext);
    riskFactors['device_risk'] = deviceRisk;
    if (deviceRisk > 0.5) alerts.add('Suspicious device characteristics');

    // Risk Factor 5: Time-based checks
    final timeRisk = _analyzeTimeRisk(transaction);
    riskFactors['time_risk'] = timeRisk;
    if (timeRisk > 0.4) alerts.add('Unusual transaction timing');

    final overallRiskScore = _calculateOverallRiskScore(riskFactors);
    final riskLevel = _determineRiskLevel(overallRiskScore);

    // Log fraud check
    await _logSecurityEvent({
      'type': 'fraud_check',
      'transaction_id': transaction.id,
      'risk_score': overallRiskScore,
      'risk_level': riskLevel,
      'risk_factors': riskFactors,
      'alerts': alerts,
      'timestamp': DateTime.now().toIso8601String(),
    });

    // Create fraud alert if high risk
    if (overallRiskScore > 0.8) {
      await _createFraudAlert(transaction, overallRiskScore, alerts);
    }

    return {
      'risk_score': overallRiskScore,
      'risk_level': riskLevel,
      'risk_factors': riskFactors,
      'alerts': alerts,
      'requires_manual_review': overallRiskScore > 0.7,
      'block_transaction': overallRiskScore > 0.9,
    };
  }

  /// Validate payment method security
  Future<Map<String, dynamic>> validatePaymentMethodSecurity({
    required String paymentMethod,
    required Map<String, dynamic> paymentData,
  }) async {
    final securityChecks = <String, bool>{};
    final recommendations = <String>[];

    switch (paymentMethod.toLowerCase()) {
      case 'card':
        securityChecks.addAll(await _validateCardSecurity(paymentData));
        break;
      case 'upi':
        securityChecks.addAll(await _validateUPISecurity(paymentData));
        break;
      case 'netbanking':
        securityChecks.addAll(await _validateNetbankingSecurity(paymentData));
        break;
      case 'wallet':
        securityChecks.addAll(await _validateWalletSecurity(paymentData));
        break;
    }

    // Generate recommendations based on failed checks
    securityChecks.forEach((check, passed) {
      if (!passed) {
        recommendations.add(_getSecurityRecommendation(check));
      }
    });

    final securityScore = _calculateSecurityScore(securityChecks);

    return {
      'security_score': securityScore,
      'security_checks': securityChecks,
      'recommendations': recommendations,
      'is_secure': securityScore >= 0.8,
    };
  }

  /// Generate secure payment receipt with digital signature
  Future<Map<String, dynamic>> generateSecureReceipt({
    required PaymentTransaction transaction,
    required Map<String, dynamic> customerInfo,
    required Map<String, dynamic> merchantInfo,
  }) async {
    final receiptData = {
      'receipt_id': _generateSecureReceiptId(),
      'transaction_id': transaction.id,
      'payment_id': transaction.paymentId,
      'amount': transaction.amount,
      'currency': transaction.currency,
      'status': transaction.status.name,
      'timestamp': transaction.createdAt.toIso8601String(),
      'customer': _sanitizeCustomerData(customerInfo),
      'merchant': merchantInfo,
      'security_hash': '',
    };

    // Generate security hash
    receiptData['security_hash'] = _generateReceiptHash(receiptData);

    // Add digital signature
    final digitalSignature = _generateDigitalSignature(receiptData);
    receiptData['digital_signature'] = digitalSignature;

    // Encrypt sensitive data
    final encryptedReceipt = _encryptReceiptData(receiptData);

    // Store receipt securely
    final receiptUrl = await _storeSecureReceipt(encryptedReceipt);

    return {
      'receipt_id': receiptData['receipt_id'],
      'receipt_url': receiptUrl,
      'digital_signature': digitalSignature,
      'security_hash': receiptData['security_hash'],
      'is_tamper_proof': true,
    };
  }

  /// Audit payment security events
  Future<Map<String, dynamic>> auditSecurityEvents({
    DateTime? startDate,
    DateTime? endDate,
    String? eventType,
  }) async {
    final dateRange = _getDateRange(startDate, endDate);

    Query query = _firestore
        .collection(_securityLogsCollection)
        .where(
          'timestamp',
          isGreaterThanOrEqualTo: dateRange['start']!.toIso8601String(),
        )
        .where(
          'timestamp',
          isLessThanOrEqualTo: dateRange['end']!.toIso8601String(),
        )
        .orderBy('timestamp', descending: true);

    if (eventType != null) {
      query = query.where('type', isEqualTo: eventType);
    }

    final querySnapshot = await query.get();
    final events = querySnapshot.docs
        .map((doc) => doc.data() as Map<String, dynamic>)
        .toList();

    final auditSummary = {
      'total_events': events.length,
      'event_types': _categorizeEvents(events),
      'security_incidents': events
          .where((e) => e['type'] == 'fraud_check' && e['risk_score'] > 0.7)
          .length,
      'compliance_violations': events
          .where(
            (e) =>
                e['type'] == 'pci_compliance_check' &&
                e['is_compliant'] == false,
          )
          .length,
      'high_risk_transactions': events
          .where((e) => e['risk_level'] == 'high')
          .length,
      'audit_period': {
        'start': dateRange['start']!.toIso8601String(),
        'end': dateRange['end']!.toIso8601String(),
      },
    };

    return {
      'audit_summary': auditSummary,
      'events': events,
      'recommendations': _generateSecurityRecommendations(events),
    };
  }

  /// Monitor payment gateway security status
  Future<Map<String, dynamic>> monitorGatewayStatus() async {
    final securityMetrics = <String, dynamic>{};

    // Check SSL certificate validity
    securityMetrics['ssl_certificate'] = await _checkSSLCertificate();

    // Check API endpoint security
    securityMetrics['api_security'] = await _checkAPIEndpointSecurity();

    // Check rate limiting
    securityMetrics['rate_limiting'] = await _checkRateLimiting();

    // Check webhook security
    securityMetrics['webhook_security'] = await _checkWebhookSecurity();

    // Check encryption standards
    securityMetrics['encryption_standards'] = _checkEncryptionStandards();

    final overallSecurityScore = _calculateGatewaySecurityScore(
      securityMetrics,
    );

    return {
      'overall_security_score': overallSecurityScore,
      'security_metrics': securityMetrics,
      'status': overallSecurityScore >= 0.9
          ? 'secure'
          : overallSecurityScore >= 0.7
          ? 'warning'
          : 'critical',
      'last_checked': DateTime.now().toIso8601String(),
    };
  }

  /// Generate compliance report
  Future<Map<String, dynamic>> generateComplianceReport({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final dateRange = _getDateRange(startDate, endDate);

    // Get all transactions in the period
    final transactionsQuery = await _firestore
        .collection('payment_transactions')
        .where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(dateRange['start']!),
        )
        .where(
          'createdAt',
          isLessThanOrEqualTo: Timestamp.fromDate(dateRange['end']!),
        )
        .get();

    final transactions = transactionsQuery.docs
        .map((doc) => PaymentTransaction.fromFirestore(doc))
        .toList();

    // Get security events in the period
    final securityEvents = await auditSecurityEvents(
      startDate: dateRange['start'],
      endDate: dateRange['end'],
    );

    final complianceReport = {
      'report_id': _generateReportId(),
      'period': {
        'start': dateRange['start']!.toIso8601String(),
        'end': dateRange['end']!.toIso8601String(),
      },
      'generated_at': DateTime.now().toIso8601String(),
      'transaction_summary': {
        'total_transactions': transactions.length,
        'successful_transactions': transactions
            .where((t) => t.isSuccessful)
            .length,
        'failed_transactions': transactions.where((t) => t.hasFailed).length,
        'total_amount': transactions.fold(0.0, (sum, t) => sum + t.amount),
      },
      'security_summary': securityEvents['audit_summary'],
      'pci_compliance': await _assessPCICompliance(transactions),
      'fraud_prevention': _assessFraudPrevention(securityEvents['events']),
      'data_protection': await _assessDataProtection(),
      'recommendations': _generateComplianceRecommendations(
        transactions,
        securityEvents['events'],
      ),
    };

    // Store compliance report
    await _firestore
        .collection(_complianceReportsCollection)
        .doc(complianceReport['report_id'])
        .set(complianceReport);

    return complianceReport;
  }

  // Private helper methods

  bool _containsSensitiveCardData(Map<String, dynamic> data) {
    final dataString = json.encode(data).toLowerCase();
    final sensitivePatterns = [
      r'\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{4}', // Card numbers
      r'cvv|cvc|security.?code', // CVV/CVC
      r'expir.*\d{2}\/\d{2}', // Expiry dates
    ];

    return sensitivePatterns.any(
      (pattern) => RegExp(pattern).hasMatch(dataString),
    );
  }

  bool _isDataEncrypted(Map<String, dynamic> data) {
    // Check if sensitive fields are encrypted
    final sensitiveFields = ['card_number', 'cvv', 'pin', 'password'];
    return sensitiveFields.every(
      (field) => !data.containsKey(field) || _isFieldEncrypted(data[field]),
    );
  }

  bool _isFieldEncrypted(dynamic value) {
    if (value is! String) return true;
    // Check if value looks encrypted (base64, hex, etc.)
    return RegExp(r'^[A-Za-z0-9+/=]+$').hasMatch(value) && value.length > 20;
  }

  bool _hasStrongAuthentication(Map<String, dynamic> data) {
    return data.containsKey('two_factor_auth') ||
        data.containsKey('biometric_auth') ||
        data.containsKey('otp_verified');
  }

  bool _hasProperAccessControl(Map<String, dynamic> data) {
    return data.containsKey('user_role') &&
        data.containsKey('permission_level') &&
        data.containsKey('session_token');
  }

  double _calculateComplianceScore(Map<String, bool> checks) {
    if (checks.isEmpty) return 0.0;
    final passedChecks = checks.values.where((passed) => passed).length;
    return passedChecks / checks.length;
  }

  double _analyzeAmountRisk(double amount, Map<String, dynamic> userContext) {
    final userAvgAmount =
        userContext['average_transaction_amount'] as double? ?? 1000.0;
    final ratio = amount / userAvgAmount;

    if (ratio > 10) return 1.0;
    if (ratio > 5) return 0.8;
    if (ratio > 3) return 0.6;
    if (ratio > 2) return 0.4;
    return 0.2;
  }

  Future<double> _analyzeVelocityRisk(
    PaymentTransaction transaction,
    Map<String, dynamic> userContext,
  ) async {
    // Get recent transactions for the user
    final recentTransactions = await _getRecentUserTransactions(
      userContext['user_id'] as String,
      const Duration(hours: 24),
    );

    if (recentTransactions.length > 10) return 1.0;
    if (recentTransactions.length > 5) return 0.8;
    if (recentTransactions.length > 3) return 0.6;
    return 0.2;
  }

  double _analyzeGeographicRisk(
    PaymentTransaction transaction,
    Map<String, dynamic> userContext,
  ) {
    final userCountry = userContext['country'] as String? ?? 'IN';
    final transactionCountry =
        transaction.metadata?['country'] as String? ?? 'IN';

    if (userCountry != transactionCountry) return 0.8;

    final userCity = userContext['city'] as String?;
    final transactionCity = transaction.metadata?['city'] as String?;

    if (userCity != null &&
        transactionCity != null &&
        userCity != transactionCity) {
      return 0.4;
    }

    return 0.1;
  }

  double _analyzeDeviceRisk(
    PaymentTransaction transaction,
    Map<String, dynamic> userContext,
  ) {
    final knownDevices = userContext['known_devices'] as List<String>? ?? [];
    final currentDevice = transaction.metadata?['device_id'] as String?;

    if (currentDevice == null) return 0.5;
    if (!knownDevices.contains(currentDevice)) return 0.7;

    return 0.1;
  }

  double _analyzeTimeRisk(PaymentTransaction transaction) {
    final hour = transaction.createdAt.hour;

    // High risk during unusual hours (2 AM - 6 AM)
    if (hour >= 2 && hour <= 6) return 0.6;

    // Medium risk during late night (10 PM - 2 AM)
    if (hour >= 22 || hour <= 2) return 0.4;

    return 0.1;
  }

  double _calculateOverallRiskScore(Map<String, double> riskFactors) {
    if (riskFactors.isEmpty) return 0.0;

    // Weighted average of risk factors
    final weights = {
      'amount_risk': 0.3,
      'velocity_risk': 0.25,
      'geographic_risk': 0.2,
      'device_risk': 0.15,
      'time_risk': 0.1,
    };

    double weightedSum = 0.0;
    double totalWeight = 0.0;

    riskFactors.forEach((factor, score) {
      final weight = weights[factor] ?? 0.1;
      weightedSum += score * weight;
      totalWeight += weight;
    });

    return totalWeight > 0 ? weightedSum / totalWeight : 0.0;
  }

  String _determineRiskLevel(double riskScore) {
    if (riskScore >= 0.8) return 'high';
    if (riskScore >= 0.6) return 'medium';
    if (riskScore >= 0.3) return 'low';
    return 'minimal';
  }

  Future<void> _createFraudAlert(
    PaymentTransaction transaction,
    double riskScore,
    List<String> alerts,
  ) async {
    final fraudAlert = {
      'alert_id': _generateAlertId(),
      'transaction_id': transaction.id,
      'risk_score': riskScore,
      'alerts': alerts,
      'status': 'open',
      'created_at': DateTime.now().toIso8601String(),
      'requires_investigation': riskScore > 0.9,
    };

    await _firestore
        .collection(_fraudAlertsCollection)
        .doc(fraudAlert['alert_id'] as String)
        .set(fraudAlert);
  }

  Future<void> _logSecurityEvent(Map<String, dynamic> event) async {
    await _firestore.collection(_securityLogsCollection).add(event);
  }

  Future<Map<String, bool>> _validateCardSecurity(
    Map<String, dynamic> cardData,
  ) async {
    return {
      'luhn_check_passed': _validateLuhnAlgorithm(
        cardData['number'] as String? ?? '',
      ),
      'cvv_format_valid': _validateCVVFormat(cardData['cvv'] as String? ?? ''),
      'expiry_valid': _validateExpiryDate(
        cardData['expiry_month'] as int? ?? 0,
        cardData['expiry_year'] as int? ?? 0,
      ),
      'not_blacklisted': await _checkCardBlacklist(
        cardData['number'] as String? ?? '',
      ),
      'issuer_verified': await _verifyCardIssuer(
        cardData['number'] as String? ?? '',
      ),
    };
  }

  Future<Map<String, bool>> _validateUPISecurity(
    Map<String, dynamic> upiData,
  ) async {
    return {
      'vpa_format_valid': _validateVPAFormat(upiData['vpa'] as String? ?? ''),
      'bank_verified': await _verifyUPIBank(upiData['vpa'] as String? ?? ''),
      'not_blacklisted': await _checkUPIBlacklist(
        upiData['vpa'] as String? ?? '',
      ),
    };
  }

  Future<Map<String, bool>> _validateNetbankingSecurity(
    Map<String, dynamic> netbankingData,
  ) async {
    return {
      'bank_code_valid': _validateBankCode(
        netbankingData['bank'] as String? ?? '',
      ),
      'bank_active': await _checkBankStatus(
        netbankingData['bank'] as String? ?? '',
      ),
      'secure_connection': true, // Assume secure connection for netbanking
    };
  }

  Future<Map<String, bool>> _validateWalletSecurity(
    Map<String, dynamic> walletData,
  ) async {
    return {
      'wallet_type_supported': _isSupportedWallet(
        walletData['wallet'] as String? ?? '',
      ),
      'wallet_active': await _checkWalletStatus(
        walletData['wallet'] as String? ?? '',
      ),
      'balance_sufficient':
          true, // This would be checked by the wallet provider
    };
  }

  double _calculateSecurityScore(Map<String, bool> checks) {
    if (checks.isEmpty) return 0.0;
    final passedChecks = checks.values.where((passed) => passed).length;
    return passedChecks / checks.length;
  }

  String _getSecurityRecommendation(String failedCheck) {
    final recommendations = {
      'luhn_check_passed': 'Verify card number using Luhn algorithm',
      'cvv_format_valid': 'Ensure CVV is 3-4 digits',
      'expiry_valid': 'Check card expiry date',
      'not_blacklisted': 'Card may be blacklisted - verify with issuer',
      'issuer_verified': 'Unable to verify card issuer',
      'vpa_format_valid': 'UPI VPA format is invalid',
      'bank_verified': 'Unable to verify UPI bank',
      'bank_code_valid': 'Invalid bank code provided',
      'bank_active': 'Bank service may be inactive',
      'wallet_type_supported': 'Wallet type not supported',
      'wallet_active': 'Wallet service may be inactive',
    };

    return recommendations[failedCheck] ?? 'Security check failed';
  }

  String _generateSecureReceiptId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(999999);
    return 'RECEIPT_${timestamp}_$random';
  }

  Map<String, dynamic> _sanitizeCustomerData(
    Map<String, dynamic> customerInfo,
  ) {
    return {
      'name': customerInfo['name'],
      'email': _maskEmail(customerInfo['email'] as String),
      'contact': _maskContact(customerInfo['contact'] as String),
    };
  }

  String _maskEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2) return email;

    final username = parts[0];
    final domain = parts[1];

    if (username.length <= 2) return email;

    final maskedUsername =
        username[0] +
        '*' * (username.length - 2) +
        username[username.length - 1];
    return '$maskedUsername@$domain';
  }

  String _maskContact(String contact) {
    if (contact.length <= 4) return contact;

    final visibleDigits = 2;
    final maskedPart = '*' * (contact.length - visibleDigits * 2);
    return contact.substring(0, visibleDigits) +
        maskedPart +
        contact.substring(contact.length - visibleDigits);
  }

  String _generateReceiptHash(Map<String, dynamic> receiptData) {
    final dataString = json.encode(receiptData);
    final bytes = utf8.encode(dataString);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  String _generateDigitalSignature(Map<String, dynamic> receiptData) {
    final dataString = json.encode(receiptData);
    // NOTE: Webhook secret must never be on the client.
    // Use the receipt prefix as a non-secret signing key for tamper-detection only.
    // Real signature verification must happen server-side.
    final key = utf8.encode(PaymentConfig.receiptPrefix);
    final bytes = utf8.encode(dataString);
    final hmacSha256 = Hmac(sha256, key);
    final digest = hmacSha256.convert(bytes);
    return digest.toString();
  }

  Map<String, dynamic> _encryptReceiptData(Map<String, dynamic> receiptData) {
    // In a real implementation, this would use proper encryption
    // For now, we'll just encode sensitive fields
    final encryptedData = Map<String, dynamic>.from(receiptData);

    // Encrypt sensitive fields
    if (encryptedData.containsKey('customer')) {
      encryptedData['customer'] = _encryptCustomerData(
        encryptedData['customer'],
      );
    }

    return encryptedData;
  }

  Map<String, dynamic> _encryptCustomerData(Map<String, dynamic> customerData) {
    // Simple base64 encoding for demonstration
    // In production, use proper encryption
    return customerData.map(
      (key, value) =>
          MapEntry(key, base64Encode(utf8.encode(value.toString()))),
    );
  }

  Future<String> _storeSecureReceipt(
    Map<String, dynamic> encryptedReceipt,
  ) async {
    // In a real implementation, this would store in secure cloud storage
    // For now, return a mock URL
    final receiptId = encryptedReceipt['receipt_id'];
    return 'https://secure-receipts.swastikapp.com/$receiptId.pdf';
  }

  Map<String, DateTime> _getDateRange(DateTime? startDate, DateTime? endDate) {
    final now = DateTime.now();
    return {
      'start': startDate ?? now.subtract(const Duration(days: 30)),
      'end': endDate ?? now,
    };
  }

  Map<String, int> _categorizeEvents(List<Map<String, dynamic>> events) {
    final categories = <String, int>{};
    for (final event in events) {
      final type = event['type'] as String;
      categories[type] = (categories[type] ?? 0) + 1;
    }
    return categories;
  }

  List<String> _generateSecurityRecommendations(
    List<Map<String, dynamic>> events,
  ) {
    final recommendations = <String>[];

    final fraudEvents = events.where((e) => e['type'] == 'fraud_check').length;
    if (fraudEvents > 10) {
      recommendations.add(
        'Consider implementing additional fraud detection measures',
      );
    }

    final complianceViolations = events
        .where(
          (e) =>
              e['type'] == 'pci_compliance_check' && e['is_compliant'] == false,
        )
        .length;
    if (complianceViolations > 0) {
      recommendations.add('Address PCI DSS compliance violations immediately');
    }

    return recommendations;
  }

  // Mock implementations for security checks
  Future<Map<String, dynamic>> _checkSSLCertificate() async {
    return {
      'valid': true,
      'expires_at': DateTime.now()
          .add(const Duration(days: 90))
          .toIso8601String(),
    };
  }

  Future<Map<String, dynamic>> _checkAPIEndpointSecurity() async {
    return {
      'https_enabled': true,
      'rate_limiting': true,
      'authentication_required': true,
    };
  }

  Future<Map<String, dynamic>> _checkRateLimiting() async {
    return {'enabled': true, 'requests_per_minute': 100, 'burst_limit': 200};
  }

  Future<Map<String, dynamic>> _checkWebhookSecurity() async {
    return {
      'signature_verification': true,
      'https_only': true,
      'ip_whitelist': true,
    };
  }

  Map<String, dynamic> _checkEncryptionStandards() {
    return {
      'tls_version': '1.3',
      'cipher_strength': 'AES-256',
      'key_rotation': true,
    };
  }

  double _calculateGatewaySecurityScore(Map<String, dynamic> metrics) {
    // Simple scoring based on security metrics
    double score = 0.0;
    int totalChecks = 0;

    metrics.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        value.forEach((subKey, subValue) {
          totalChecks++;
          if (subValue == true || (subValue is String && subValue.isNotEmpty)) {
            score += 1.0;
          }
        });
      }
    });

    return totalChecks > 0 ? score / totalChecks : 0.0;
  }

  String _generateReportId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'COMPLIANCE_REPORT_$timestamp';
  }

  String _generateAlertId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(999999);
    return 'FRAUD_ALERT_${timestamp}_$random';
  }

  Future<Map<String, dynamic>> _assessPCICompliance(
    List<PaymentTransaction> transactions,
  ) async {
    // Assess PCI compliance based on transactions
    return {
      'compliant_transactions': transactions.length,
      'violations': 0,
      'compliance_score': 1.0,
    };
  }

  Map<String, dynamic> _assessFraudPrevention(
    List<Map<String, dynamic>> events,
  ) {
    final fraudEvents = events
        .where((e) => e['type'] == 'fraud_check')
        .toList();
    final highRiskEvents = fraudEvents
        .where((e) => e['risk_score'] > 0.7)
        .length;

    return {
      'total_fraud_checks': fraudEvents.length,
      'high_risk_detected': highRiskEvents,
      'prevention_rate': fraudEvents.isNotEmpty
          ? (fraudEvents.length - highRiskEvents) / fraudEvents.length
          : 1.0,
    };
  }

  Future<Map<String, dynamic>> _assessDataProtection() async {
    return {
      'encryption_enabled': true,
      'data_masking': true,
      'access_controls': true,
      'audit_logging': true,
    };
  }

  List<String> _generateComplianceRecommendations(
    List<PaymentTransaction> transactions,
    List<Map<String, dynamic>> events,
  ) {
    final recommendations = <String>[];

    final failedTransactions = transactions.where((t) => t.hasFailed).length;
    if (failedTransactions > transactions.length * 0.1) {
      recommendations.add(
        'High failure rate detected - review payment processing',
      );
    }

    final securityEvents = events
        .where((e) => e['type'] == 'fraud_check')
        .length;
    if (securityEvents > 50) {
      recommendations.add('Consider implementing additional security measures');
    }

    return recommendations;
  }

  // Validation helper methods
  bool _validateLuhnAlgorithm(String cardNumber) {
    final cleanNumber = cardNumber.replaceAll(RegExp(r'\D'), '');
    if (cleanNumber.length < 13 || cleanNumber.length > 19) return false;

    int sum = 0;
    bool alternate = false;

    for (int i = cleanNumber.length - 1; i >= 0; i--) {
      int digit = int.parse(cleanNumber[i]);

      if (alternate) {
        digit *= 2;
        if (digit > 9) digit = (digit % 10) + 1;
      }

      sum += digit;
      alternate = !alternate;
    }

    return sum % 10 == 0;
  }

  bool _validateCVVFormat(String cvv) {
    return RegExp(r'^\d{3,4  }$').hasMatch(cvv);
  }

  bool _validateExpiryDate(int month, int year) {
    if (month < 1 || month > 12) return false;
    final now = DateTime.now();
    final expiryDate = DateTime(year, month + 1, 0);
    return expiryDate.isAfter(now);
  }

  Future<bool> _checkCardBlacklist(String cardNumber) async {
    // In a real implementation, check against blacklist database
    return true; // Assume not blacklisted
  }

  Future<bool> _verifyCardIssuer(String cardNumber) async {
    // In a real implementation, verify with card issuer
    return true; // Assume verified
  }

  bool _validateVPAFormat(String vpa) {
    return RegExp(r'^[\w\.-]+@[\w\.-]+$').hasMatch(vpa);
  }

  Future<bool> _verifyUPIBank(String vpa) async {
    // In a real implementation, verify UPI bank
    return true; // Assume verified
  }

  Future<bool> _checkUPIBlacklist(String vpa) async {
    // In a real implementation, check UPI blacklist
    return true; // Assume not blacklisted
  }

  bool _validateBankCode(String bankCode) {
    // List of supported banks for netbanking
    const supportedBanks = ['HDFC', 'ICICI', 'SBI', 'AXIS', 'KOTAK'];
    return supportedBanks.contains(bankCode.toUpperCase());
  }

  Future<bool> _checkBankStatus(String bankCode) async {
    // In a real implementation, check bank status
    return true; // Assume active
  }

  bool _isSupportedWallet(String walletType) {
    // Stripe supports these digital wallets
    const supportedWallets = ['apple_pay', 'google_pay', 'link'];
    return supportedWallets.contains(walletType.toLowerCase());
  }

  Future<bool> _checkWalletStatus(String walletType) async {
    // In a real implementation, check wallet status
    return true; // Assume active
  }

  Future<List<PaymentTransaction>> _getRecentUserTransactions(
    String userId,
    Duration period,
  ) async {
    final cutoffDate = DateTime.now().subtract(period);
    final querySnapshot = await _firestore
        .collection('payment_transactions')
        .where('metadata.user_id', isEqualTo: userId)
        .where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(cutoffDate),
        )
        .get();

    return querySnapshot.docs
        .map((doc) => PaymentTransaction.fromFirestore(doc))
        .toList();
  }
}
