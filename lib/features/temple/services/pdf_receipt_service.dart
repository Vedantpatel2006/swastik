import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:path_provider/path_provider.dart';
import '../models/donation.dart';

/// Production-ready PDF receipt generation service
/// Requires: pdf: ^3.10.4 in pubspec.yaml
class PdfReceiptService {
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
  };

  static String _translate(String key, String language) {
    return _translations[language]?[key] ?? _translations['en']?[key] ?? key;
  }

  static String _formatCurrency(double amount, String language) {
    final currency = _translate('currency', language);
    final formatter = NumberFormat('#,##,###.00', 'en_IN');
    return '$currency${formatter.format(amount)}';
  }

  static String _formatDate(DateTime date, String language) {
    return DateFormat(
      'dd MMMM yyyy',
      language == 'hi' ? 'hi_IN' : 'en_IN',
    ).format(date);
  }

  /// Generate a professional PDF receipt
  static Future<Uint8List> generateReceiptPDF(DonationReceipt receipt) async {
    // Initialize locale data for DateFormat/NumberFormat
    await initializeDateFormatting('en_IN');
    await initializeDateFormatting('hi_IN');

    // Load Inter font from assets for full Unicode support (₹ symbol etc.)
    final pdf = pw.Document();
    pw.Font? baseFont;
    pw.Font? boldFont;
    try {
      final regularData = await _loadFontAsset(
        'assets/fonts/Inter-Regular.ttf',
      );
      final semiBoldData = await _loadFontAsset(
        'assets/fonts/Inter-SemiBold.ttf',
      );
      baseFont = pw.Font.ttf(regularData);
      boldFont = pw.Font.ttf(semiBoldData);
    } catch (_) {
      // Fallback to default font if assets unavailable
    }

    // Apply Inter font as document theme so ₹ and other Unicode chars render
    final pw.ThemeData? pdfTheme = baseFont != null
        ? pw.ThemeData.withFont(
            base: baseFont,
            bold: boldFont ?? baseFont,
            italic: baseFont,
            boldItalic: boldFont ?? baseFont,
          )
        : null;

    final language = receipt.language;
    final donation = receipt.donation;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        theme: pdfTheme,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeader(receipt, language),
              pw.SizedBox(height: 20),
              pw.Divider(thickness: 2),
              pw.SizedBox(height: 20),

              // Receipt Info
              _buildReceiptInfo(receipt, language),
              pw.SizedBox(height: 20),

              // Donor Details
              _buildSection(_translate('donor_details', language), [
                '${_translate('name', language)}: ${donation.isAnonymous ? 'Anonymous' : donation.userName}',
                if (!donation.isAnonymous)
                  '${_translate('email', language)}: ${donation.userEmail}',
              ]),
              pw.SizedBox(height: 15),

              // Donation Details
              _buildSection(_translate('donation_details', language), [
                '${_translate('temple_name', language)}: ${donation.templeName}',
                '${_translate('amount', language)}: ${_formatCurrency(donation.amount, language)}',
                '${_translate('donation_type', language)}: ${donation.type.name}',
                '${_translate('payment_method', language)}: ${donation.paymentMethod.name}',
                if (donation.transactionId != null)
                  '${_translate('transaction_id', language)}: ${donation.transactionId}',
                if (donation.dedicatedTo != null)
                  'Dedicated to: ${donation.dedicatedTo}',
              ]),
              pw.SizedBox(height: 15),

              // Organization Details
              _buildSection(_translate('organization_details', language), [
                '${_translate('organization_name', language)}: ${receipt.organizationName}',
                '${_translate('address', language)}: ${receipt.organizationAddress}',
                '${_translate('pan_number', language)}: ${receipt.organizationPan}',
                '${_translate('registration', language)}: ${receipt.organizationRegistration}',
              ]),
              pw.SizedBox(height: 15),

              // Tax Benefit Box
              _buildTaxBenefitBox(donation, language),
              pw.SizedBox(height: 30),

              // Thank You Message
              pw.Center(
                child: pw.Text(
                  _translate('thank_you', language),
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.orange,
                  ),
                ),
              ),

              pw.Spacer(),

              // Signature
              _buildSignature(language),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildHeader(DonationReceipt receipt, String language) {
    return pw.Column(
      children: [
        pw.Center(
          child: pw.Text(
            _translate('receipt_title', language),
            style: pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.orange,
            ),
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Center(
          child: pw.Text(
            receipt.organizationName,
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildReceiptInfo(DonationReceipt receipt, String language) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              '${_translate('receipt_number', language)}: ${receipt.receiptNumber}',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              '${_translate('date', language)}: ${_formatDate(receipt.issuedAt, language)}',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildSection(String title, List<String> items) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.orange,
          ),
        ),
        pw.SizedBox(height: 8),
        ...items.map(
          (item) => pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 4),
            child: pw.Text(item, style: const pw.TextStyle(fontSize: 11)),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildTaxBenefitBox(Donation donation, String language) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: donation.taxBenefitEligible
            ? PdfColors.green50
            : PdfColors.grey300,
        border: pw.Border.all(
          color: donation.taxBenefitEligible ? PdfColors.green : PdfColors.grey,
        ),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            _translate('tax_benefit', language),
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            donation.taxBenefitEligible
                ? _translate('tax_eligible', language)
                : _translate('tax_not_eligible', language),
            style: pw.TextStyle(
              color: donation.taxBenefitEligible
                  ? PdfColors.green700
                  : PdfColors.grey700,
            ),
          ),
          if (donation.taxBenefitEligible && donation.panNumber != null)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 4),
              child: pw.Text(
                'PAN: ${donation.panNumber}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }

  static pw.Widget _buildSignature(String language) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Column(
          children: [
            pw.SizedBox(height: 40),
            pw.Container(width: 150, height: 1, color: PdfColors.black),
            pw.SizedBox(height: 4),
            pw.Text(
              _translate('signature', language),
              style: const pw.TextStyle(fontSize: 10),
            ),
          ],
        ),
      ],
    );
  }

  /// Generate receipt and save to device documents directory
  static Future<String> generateAndSaveReceipt(
    DonationReceipt receipt,
    String savePath,
  ) async {
    final pdfBytes = await generateReceiptPDF(receipt);
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/receipt_${receipt.receiptNumber}.pdf';
    final file = File(filePath);
    await file.writeAsBytes(pdfBytes);
    return filePath;
  }

  /// Load a font asset as ByteData for PDF embedding
  static Future<ByteData> _loadFontAsset(String assetPath) async {
    return await rootBundle.load(assetPath);
  }
}
