import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../models/donation.dart';
import 'pdf_receipt_service.dart';

class ReceiptService {
  static const Map<String, Map<String, String>> _translations = {
    'en': {
      'receipt_title': 'Donation Receipt',
      'receipt_number': 'Receipt Number',
      'date': 'Date',
      'donor_details': 'Donor Details',
      'name': 'Name',
      'email': 'Email',
      'donation_details': 'Donation Details',
      'temple_name': 'Temple Name',
      'amount': 'Amount',
      'donation_type': 'Donation Type',
      'payment_method': 'Payment Method',
      'transaction_id': 'Transaction ID',
      'organization_details': 'Organization Details',
      'organization_name': 'Organization Name',
      'address': 'Address',
      'pan_number': 'PAN Number',
      'registration': 'Registration Number',
      'tax_benefit': 'Tax Benefit Information',
      'tax_eligible':
          'This donation is eligible for tax deduction under Section 80G',
      'tax_not_eligible': 'This donation is not eligible for tax deduction',
      'thank_you': 'Thank you for your generous donation',
      'signature': 'Authorized Signature',
      'currency': '₹',
    },
    'hi': {
      'receipt_title': 'दान रसीद',
      'receipt_number': 'रसीद संख्या',
      'date': 'दिनांक',
      'donor_details': 'दाता विवरण',
      'name': 'नाम',
      'email': 'ईमेल',
      'donation_details': 'दान विवरण',
      'temple_name': 'मंदिर का नाम',
      'amount': 'राशि',
      'donation_type': 'दान का प्रकार',
      'payment_method': 'भुगतान विधि',
      'transaction_id': 'लेनदेन आईडी',
      'organization_details': 'संगठन विवरण',
      'organization_name': 'संगठन का नाम',
      'address': 'पता',
      'pan_number': 'पैन नंबर',
      'registration': 'पंजीकरण संख्या',
      'tax_benefit': 'कर लाभ जानकारी',
      'tax_eligible': 'यह दान धारा 80G के तहत कर कटौती के लिए पात्र है',
      'tax_not_eligible': 'यह दान कर कटौती के लिए पात्र नहीं है',
      'thank_you': 'आपके उदार दान के लिए धन्यवाद',
      'signature': 'अधिकृत हस्ताक्षर',
      'currency': '₹',
    },
    'gu': {
      'receipt_title': 'દાન રસીદ',
      'receipt_number': 'રસીદ નંબર',
      'date': 'તારીખ',
      'donor_details': 'દાતા વિગતો',
      'name': 'નામ',
      'email': 'ઈમેલ',
      'donation_details': 'દાન વિગતો',
      'temple_name': 'મંદિરનું નામ',
      'amount': 'રકમ',
      'donation_type': 'દાનનો પ્રકાર',
      'payment_method': 'ચુકવણી પદ્ધતિ',
      'transaction_id': 'ટ્રાન્ઝેક્શન આઈડી',
      'organization_details': 'સંસ્થા વિગતો',
      'organization_name': 'સંસ્થાનું નામ',
      'address': 'સરનામું',
      'pan_number': 'પાન નંબર',
      'registration': 'નોંધણી નંબર',
      'tax_benefit': 'કર લાભ માહિતી',
      'tax_eligible': 'આ દાન કલમ 80G હેઠળ કર કપાત માટે પાત્ર છે',
      'tax_not_eligible': 'આ દાન કર કપાત માટે પાત્ર નથી',
      'thank_you': 'તમારા ઉદાર દાન માટે આભાર',
      'signature': 'અધિકૃત સહી',
      'currency': '₹',
    },
  };

  static const Map<String, Map<DonationType, String>>
  _donationTypeTranslations = {
    'en': {
      DonationType.general: 'General Donation',
      DonationType.festival: 'Festival Donation',
      DonationType.construction: 'Construction Donation',
      DonationType.maintenance: 'Maintenance Donation',
      DonationType.food: 'Food Donation',
      DonationType.special: 'Special Donation',
    },
    'hi': {
      DonationType.general: 'सामान्य दान',
      DonationType.festival: 'त्योहार दान',
      DonationType.construction: 'निर्माण दान',
      DonationType.maintenance: 'रखरखाव दान',
      DonationType.food: 'भोजन दान',
      DonationType.special: 'विशेष दान',
    },
    'gu': {
      DonationType.general: 'સામાન્ય દાન',
      DonationType.festival: 'તહેવાર દાન',
      DonationType.construction: 'બાંધકામ દાન',
      DonationType.maintenance: 'જાળવણી દાન',
      DonationType.food: 'ખોરાક દાન',
      DonationType.special: 'વિશેષ દાન',
    },
  };

  static const Map<String, Map<PaymentMethod, String>>
  _paymentMethodTranslations = {
    'en': {
      PaymentMethod.upi: 'UPI',
      PaymentMethod.card: 'Card',
      PaymentMethod.netBanking: 'Net Banking',
      PaymentMethod.wallet: 'Digital Wallet',
    },
    'hi': {
      PaymentMethod.upi: 'यूपीआई',
      PaymentMethod.card: 'कार्ड',
      PaymentMethod.netBanking: 'नेट बैंकिंग',
      PaymentMethod.wallet: 'डिजिटल वॉलेट',
    },
    'gu': {
      PaymentMethod.upi: 'યુપીઆઈ',
      PaymentMethod.card: 'કાર્ડ',
      PaymentMethod.netBanking: 'નેટ બેંકિંગ',
      PaymentMethod.wallet: 'ડિજિટલ વોલેટ',
    },
  };

  static String _translate(String key, String language) {
    return _translations[language]?[key] ?? _translations['en']?[key] ?? key;
  }

  static String _translateDonationType(DonationType type, String language) {
    return _donationTypeTranslations[language]?[type] ??
        _donationTypeTranslations['en']?[type] ??
        type.name;
  }

  static String _translatePaymentMethod(PaymentMethod method, String language) {
    return _paymentMethodTranslations[language]?[method] ??
        _paymentMethodTranslations['en']?[method] ??
        method.name;
  }

  static String _formatCurrency(double amount, String language) {
    final currency = _translate('currency', language);
    final formatter = NumberFormat(
      '#,##,###.00',
      language == 'hi' ? 'hi_IN' : 'en_IN',
    );
    return '$currency${formatter.format(amount)}';
  }

  static String _formatDate(DateTime date, String language) {
    switch (language) {
      case 'hi':
        return DateFormat('dd MMMM yyyy', 'hi_IN').format(date);
      case 'gu':
        return DateFormat('dd MMMM yyyy', 'gu_IN').format(date);
      default:
        return DateFormat('dd MMMM yyyy', 'en_IN').format(date);
    }
  }

  static Widget buildReceiptWidget(DonationReceipt receipt) {
    final language = receipt.language;
    final donation = receipt.donation;

    return Container(
      width: 600,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Center(
            child: Column(
              children: [
                Text(
                  _translate('receipt_title', language),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  receipt.organizationName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          const Divider(thickness: 2),
          const SizedBox(height: 16),

          // Receipt Details
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_translate('receipt_number', language)}: ${receipt.receiptNumber}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_translate('date', language)}: ${_formatDate(receipt.issuedAt, language)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Donor Details
          _buildSection(_translate('donor_details', language), [
            '${_translate('name', language)}: ${donation.isAnonymous ? 'Anonymous' : donation.userName}',
            if (!donation.isAnonymous)
              '${_translate('email', language)}: ${donation.userEmail}',
          ]),

          const SizedBox(height: 16),

          // Donation Details
          _buildSection(_translate('donation_details', language), [
            '${_translate('temple_name', language)}: ${_getTempleName(donation, language)}',
            '${_translate('amount', language)}: ${_formatCurrency(donation.amount, language)}',
            '${_translate('donation_type', language)}: ${_translateDonationType(donation.type, language)}',
            '${_translate('payment_method', language)}: ${_translatePaymentMethod(donation.paymentMethod, language)}',
            if (donation.transactionId != null)
              '${_translate('transaction_id', language)}: ${donation.transactionId}',
            if (donation.dedicatedTo != null)
              'Dedicated to: ${donation.dedicatedTo}',
          ]),

          const SizedBox(height: 16),

          // Organization Details
          _buildSection(_translate('organization_details', language), [
            '${_translate('organization_name', language)}: ${receipt.organizationName}',
            '${_translate('address', language)}: ${receipt.organizationAddress}',
            '${_translate('pan_number', language)}: ${receipt.organizationPan}',
            '${_translate('registration', language)}: ${receipt.organizationRegistration}',
          ]),

          const SizedBox(height: 16),

          // Tax Benefit Information
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: donation.taxBenefitEligible
                  ? Colors.green.shade50
                  : Colors.grey.shade50,
              border: Border.all(
                color: donation.taxBenefitEligible ? Colors.green : Colors.grey,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _translate('tax_benefit', language),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  donation.taxBenefitEligible
                      ? _translate('tax_eligible', language)
                      : _translate('tax_not_eligible', language),
                  style: TextStyle(
                    color: donation.taxBenefitEligible
                        ? Colors.green.shade700
                        : Colors.grey.shade700,
                  ),
                ),
                if (donation.taxBenefitEligible && donation.panNumber != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'PAN: ${donation.panNumber}',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Thank you message
          Center(
            child: Text(
              _translate('thank_you', language),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.orange,
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Signature
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Column(
                children: [
                  const SizedBox(height: 40),
                  Container(width: 150, height: 1, color: Colors.black),
                  const SizedBox(height: 4),
                  Text(
                    _translate('signature', language),
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _buildSection(String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.orange,
          ),
        ),
        const SizedBox(height: 8),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(item),
          ),
        ),
      ],
    );
  }

  static String _getTempleName(Donation donation, String language) {
    // Return temple name (localized names removed)
    return donation.templeName;
  }

  static Future<Uint8List> generateReceiptPDF(DonationReceipt receipt) async {
    // Use the production-ready PDF service
    try {
      await initializeDateFormatting('en_IN');
      await initializeDateFormatting('hi_IN');
      await initializeDateFormatting('gu_IN');
      return await PdfReceiptService.generateReceiptPDF(receipt);
    } catch (e) {
      throw Exception('Failed to generate PDF receipt: $e');
    }
  }

  static Future<Uint8List> generateReceiptImage(DonationReceipt receipt) async {
    // This would require rendering the widget to an image
    // For now, we'll return a placeholder
    return Uint8List.fromList([]);
  }

  static String generateReceiptText(DonationReceipt receipt) {
    final language = receipt.language;
    final donation = receipt.donation;

    final buffer = StringBuffer();

    buffer.writeln('=' * 50);
    buffer.writeln(_translate('receipt_title', language).toUpperCase());
    buffer.writeln('=' * 50);
    buffer.writeln();

    buffer.writeln(receipt.organizationName);
    buffer.writeln(receipt.organizationAddress);
    buffer.writeln();

    buffer.writeln(
      '${_translate('receipt_number', language)}: ${receipt.receiptNumber}',
    );
    buffer.writeln(
      '${_translate('date', language)}: ${_formatDate(receipt.issuedAt, language)}',
    );
    buffer.writeln();

    buffer.writeln(_translate('donor_details', language).toUpperCase());
    buffer.writeln('-' * 30);
    buffer.writeln(
      '${_translate('name', language)}: ${donation.isAnonymous ? 'Anonymous' : donation.userName}',
    );
    if (!donation.isAnonymous) {
      buffer.writeln('${_translate('email', language)}: ${donation.userEmail}');
    }
    buffer.writeln();

    buffer.writeln(_translate('donation_details', language).toUpperCase());
    buffer.writeln('-' * 30);
    buffer.writeln(
      '${_translate('temple_name', language)}: ${_getTempleName(donation, language)}',
    );
    buffer.writeln(
      '${_translate('amount', language)}: ${_formatCurrency(donation.amount, language)}',
    );
    buffer.writeln(
      '${_translate('donation_type', language)}: ${_translateDonationType(donation.type, language)}',
    );
    buffer.writeln(
      '${_translate('payment_method', language)}: ${_translatePaymentMethod(donation.paymentMethod, language)}',
    );

    if (donation.transactionId != null) {
      buffer.writeln(
        '${_translate('transaction_id', language)}: ${donation.transactionId}',
      );
    }

    if (donation.dedicatedTo != null) {
      buffer.writeln('Dedicated to: ${donation.dedicatedTo}');
    }
    buffer.writeln();

    buffer.writeln(_translate('tax_benefit', language).toUpperCase());
    buffer.writeln('-' * 30);
    buffer.writeln(
      donation.taxBenefitEligible
          ? _translate('tax_eligible', language)
          : _translate('tax_not_eligible', language),
    );

    if (donation.taxBenefitEligible && donation.panNumber != null) {
      buffer.writeln('PAN: ${donation.panNumber}');
    }
    buffer.writeln();

    buffer.writeln(_translate('organization_details', language).toUpperCase());
    buffer.writeln('-' * 30);
    buffer.writeln(
      '${_translate('pan_number', language)}: ${receipt.organizationPan}',
    );
    buffer.writeln(
      '${_translate('registration', language)}: ${receipt.organizationRegistration}',
    );
    buffer.writeln();

    buffer.writeln('=' * 50);
    buffer.writeln(_translate('thank_you', language));
    buffer.writeln('=' * 50);

    return buffer.toString();
  }
}
