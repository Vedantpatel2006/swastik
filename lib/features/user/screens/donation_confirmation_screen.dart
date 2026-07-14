import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/themes/app_colors.dart';
import '../../../shared/models/temple.dart';

/// Donation Confirmation Screen
/// Clean review screen before final donation submission
class DonationConfirmationScreen extends StatefulWidget {
  final Temple temple;
  final double donationAmount;
  final String donationType;
  final bool isAnonymous;
  final String? donorName;
  final VoidCallback onConfirm;
  final VoidCallback onEdit;

  const DonationConfirmationScreen({
    super.key,
    required this.temple,
    required this.donationAmount,
    required this.donationType,
    required this.isAnonymous,
    this.donorName,
    required this.onConfirm,
    required this.onEdit,
  });

  @override
  State<DonationConfirmationScreen> createState() =>
      _DonationConfirmationScreenState();
}

class _DonationConfirmationScreenState
    extends State<DonationConfirmationScreen> {
  bool _isProcessing = false;
  bool _termsAccepted = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamBackground,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close, size: 22),
          onPressed: () => Navigator.pop(context),
          color: AppColors.primaryText,
        ),
        title: const Text(
          'Review Donation',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.primaryText,
          ),
        ),
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
            // Temple Card
            _buildTempleCard(),
            const SizedBox(height: 20),

            // Amount Hero
            _buildAmountHero(),
            const SizedBox(height: 20),

            // Donation Details Card
            _buildDonationDetailsCard(),
            const SizedBox(height: 16),

            // Donor Info Card
            _buildDonorCard(),
            const SizedBox(height: 16),

            // Tax Benefit Note
            _buildTaxNote(),
            const SizedBox(height: 20),

            // Terms Checkbox
            _buildTermsCheckbox(),
            const SizedBox(height: 24),

            // Action Buttons
            _buildActionButtons(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildTempleCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.temple.images.isNotEmpty)
            CachedNetworkImage(
              imageUrl: widget.temple.images.first,
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                height: 160,
                color: AppColors.borderGray,
                child: const Center(
                  child: Icon(
                    Icons.temple_hindu,
                    size: 40,
                    color: AppColors.secondaryText,
                  ),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                height: 160,
                color: AppColors.borderGray,
                child: const Center(
                  child: Icon(
                    Icons.temple_hindu,
                    size: 40,
                    color: AppColors.secondaryText,
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryOrange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.temple_hindu,
                    color: AppColors.primaryOrange,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.temple.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryText,
                        ),
                      ),
                      if (widget.temple.location.address != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          widget.temple.location.address!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.secondaryText,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
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
            '₹${NumberFormat('#,##,###').format(widget.donationAmount.toInt())}',
            style: const TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.donationType,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (widget.isAnonymous) ...[
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

  Widget _buildDonationDetailsCard() {
    return _buildCard(
      title: 'Donation Details',
      icon: Icons.receipt_outlined,
      iconColor: AppColors.primaryOrange,
      child: Column(
        children: [
          _buildRow('Type', widget.donationType),
          _buildDivider(),
          _buildRow(
            'Amount',
            '₹${NumberFormat('#,##,###').format(widget.donationAmount.toInt())}',
            valueColor: AppColors.primaryOrange,
            valueBold: true,
          ),
          _buildDivider(),
          _buildRow('Date', DateFormat('d MMM yyyy').format(DateTime.now())),
        ],
      ),
    );
  }

  Widget _buildDonorCard() {
    if (widget.isAnonymous) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.infoPurple.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.infoPurple.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.privacy_tip_outlined,
              color: AppColors.infoPurple,
              size: 20,
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Your donation will be recorded anonymously in our temple records.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.infoPurple,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return _buildCard(
      title: 'Donor Details',
      icon: Icons.person_outline,
      iconColor: AppColors.primaryBlue,
      child: _buildRow(
        'Name',
        widget.donorName?.isNotEmpty == true
            ? widget.donorName!
            : 'Not provided',
      ),
    );
  }

  Widget _buildTaxNote() {
    return Container(
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
                  'This donation is eligible for tax deduction under Section 80G. A receipt will be sent to your registered email within 24 hours.',
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
    );
  }

  Widget _buildTermsCheckbox() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: _termsAccepted,
            onChanged: (value) =>
                setState(() => _termsAccepted = value ?? false),
            activeColor: AppColors.primaryOrange,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _termsAccepted = !_termsAccepted),
            child: RichText(
              text: const TextSpan(
                children: [
                  TextSpan(
                    text: 'I confirm the donation amount and agree to the ',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.secondaryText,
                    ),
                  ),
                  TextSpan(
                    text: 'Terms & Conditions',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.primaryOrange,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _isProcessing ? null : widget.onEdit,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: AppColors.borderGray, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              foregroundColor: AppColors.primaryText,
            ),
            child: const Text(
              'Edit',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: (_isProcessing || !_termsAccepted)
                ? null
                : () async {
                    HapticFeedback.mediumImpact();
                    setState(() => _isProcessing = true);
                    try {
                      widget.onConfirm();
                    } finally {
                      if (mounted) setState(() => _isProcessing = false);
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: _termsAccepted
                  ? AppColors.primaryOrange
                  : AppColors.borderGray,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isProcessing
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Confirm Donation',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ],
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
          Padding(padding: const EdgeInsets.all(16), child: child),
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
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.secondaryText,
            ),
          ),
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

  Widget _buildDivider() {
    return const Divider(height: 1, color: AppColors.borderGray);
  }
}
