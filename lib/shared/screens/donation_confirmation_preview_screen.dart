import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/donation.dart';
import '../models/temple.dart';
import '../../core/themes/app_colors.dart';

/// Preview screen shown before confirming a donation.
/// Shows donation details and tax benefit information.
class DonationConfirmationPreviewScreen extends StatelessWidget {
  final Donation donation;
  final Temple temple;
  final VoidCallback onConfirm;
  final VoidCallback onEdit;
  final bool isAnonymous;

  const DonationConfirmationPreviewScreen({
    super.key,
    required this.donation,
    required this.temple,
    required this.onConfirm,
    required this.onEdit,
    this.isAnonymous = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamBackground,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.primaryText,
        title: const Text(
          'Confirm Donation',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.primaryText,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.borderGray),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Amount Hero
            _buildAmountHero(),
            const SizedBox(height: 20),

            // Temple Details Card
            _buildCard(
              title: 'Temple Details',
              icon: Icons.temple_hindu,
              iconColor: AppColors.primaryOrange,
              child: Column(
                children: [
                  _buildRow('Temple', temple.name),
                  if (temple.location.address != null) ...[
                    _buildDivider(),
                    _buildRow('Location', temple.location.address!),
                  ],
                  if (temple.contact.phone != null) ...[
                    _buildDivider(),
                    _buildRow('Contact', temple.contact.phone!),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Donation Details Card
            _buildCard(
              title: 'Donation Details',
              icon: Icons.receipt_outlined,
              iconColor: AppColors.primaryOrange,
              child: Column(
                children: [
                  _buildRow(
                    'Purpose',
                    _formatPurpose(donation.purpose ?? 'general'),
                  ),
                  _buildDivider(),
                  _buildRow('Payment', donation.paymentMethod.toUpperCase()),
                  if (donation.notes != null && donation.notes!.isNotEmpty) ...[
                    _buildDivider(),
                    _buildRow('Notes', donation.notes!),
                  ],
                  _buildDivider(),
                  _buildRow('Date', _formatDate(donation.donationDate)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Tax Benefit Note
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.successGreen.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.verified_outlined,
                    color: AppColors.successGreen,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tax Benefit Available',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.successGreen,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Eligible for deduction under Section 80G. A receipt will be sent to your registered email within 24 hours.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.secondaryText,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onEdit,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(
                        color: AppColors.borderGray,
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      foregroundColor: AppColors.primaryText,
                    ),
                    child: const Text(
                      'Edit',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      onConfirm();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryOrange,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Confirm Donation',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountHero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryOrange, AppColors.lightOrange],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryOrange.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.volunteer_activism, color: Colors.white70, size: 28),
          const SizedBox(height: 8),
          Text(
            '₹${NumberFormat('#,##,###').format(donation.amount.toInt())}',
            style: const TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _formatPurpose(donation.purpose ?? 'general'),
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (isAnonymous) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.visibility_off, size: 14, color: Colors.white),
                  SizedBox(width: 6),
                  Text(
                    'Anonymous Donation',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Shared helpers ───────────────────────────────────────────────────────

  Widget _buildCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Icon(icon, color: iconColor, size: 18),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryText,
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1, color: AppColors.borderGray),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildRow(
    String label,
    String value, {
    Color? valueColor,
    bool valueBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.secondaryText,
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: valueBold ? FontWeight.bold : FontWeight.w600,
                color: valueColor ?? AppColors.primaryText,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() =>
      const Divider(height: 1, color: AppColors.borderGray);

  String _formatDate(DateTime date) =>
      DateFormat('EEE, d MMM yyyy').format(date);

  String _formatPurpose(String purpose) {
    return purpose
        .split('_')
        .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
}
