import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/themes/app_colors.dart';
import '../../../shared/models/temple.dart';

/// Booking Confirmation Screen
/// Clean review screen before final booking submission
class BookingConfirmationScreen extends StatefulWidget {
  final Temple temple;
  final String bookingType;
  final DateTime selectedDate;
  final TimeOfDay selectedTime;
  final String? notes;
  final String? contactName;
  final String? contactPhone;
  final int numberOfPeople;
  final VoidCallback onConfirm;
  final VoidCallback onEdit;

  const BookingConfirmationScreen({
    super.key,
    required this.temple,
    required this.bookingType,
    required this.selectedDate,
    required this.selectedTime,
    this.notes,
    this.contactName,
    this.contactPhone,
    this.numberOfPeople = 1,
    required this.onConfirm,
    required this.onEdit,
  });

  @override
  State<BookingConfirmationScreen> createState() =>
      _BookingConfirmationScreenState();
}

class _BookingConfirmationScreenState
    extends State<BookingConfirmationScreen> {
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
          'Review Booking',
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

            // Booking Summary Card
            _buildSummaryCard(),
            const SizedBox(height: 16),

            // Contact Card (if provided)
            if ((widget.contactName != null && widget.contactName!.isNotEmpty) ||
                (widget.contactPhone != null && widget.contactPhone!.isNotEmpty))
              _buildContactCard(),
            if ((widget.contactName != null && widget.contactName!.isNotEmpty) ||
                (widget.contactPhone != null && widget.contactPhone!.isNotEmpty))
              const SizedBox(height: 16),

            // Notes Card (if provided)
            if (widget.notes != null && widget.notes!.isNotEmpty)
              _buildNotesCard(),
            if (widget.notes != null && widget.notes!.isNotEmpty)
              const SizedBox(height: 16),

            // Cancellation Policy
            _buildCancellationPolicy(),
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
                  child: Icon(Icons.temple_hindu, size: 40, color: AppColors.secondaryText),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                height: 160,
                color: AppColors.borderGray,
                child: const Center(
                  child: Icon(Icons.temple_hindu, size: 40, color: AppColors.secondaryText),
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

  Widget _buildSummaryCard() {
    return _buildCard(
      title: 'Booking Details',
      icon: Icons.event_note_outlined,
      iconColor: AppColors.primaryOrange,
      child: Column(
        children: [
          _buildRow('Puja / Service', widget.bookingType),
          _buildDivider(),
          _buildRow(
            'Date',
            DateFormat('EEE, d MMM yyyy').format(widget.selectedDate),
          ),
          _buildDivider(),
          _buildRow('Time', widget.selectedTime.format(context)),
          _buildDivider(),
          _buildRow('Guests', '${widget.numberOfPeople} person${widget.numberOfPeople > 1 ? 's' : ''}'),
        ],
      ),
    );
  }

  Widget _buildContactCard() {
    return _buildCard(
      title: 'Contact Details',
      icon: Icons.person_outline,
      iconColor: AppColors.primaryBlue,
      child: Column(
        children: [
          if (widget.contactName != null && widget.contactName!.isNotEmpty) ...[
            _buildRow('Name', widget.contactName!),
          ],
          if (widget.contactName != null &&
              widget.contactName!.isNotEmpty &&
              widget.contactPhone != null &&
              widget.contactPhone!.isNotEmpty)
            _buildDivider(),
          if (widget.contactPhone != null && widget.contactPhone!.isNotEmpty)
            _buildRow('Phone', widget.contactPhone!),
        ],
      ),
    );
  }

  Widget _buildNotesCard() {
    return _buildCard(
      title: 'Special Requests',
      icon: Icons.notes_outlined,
      iconColor: AppColors.infoPurple,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          widget.notes!,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.secondaryText,
            height: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildCancellationPolicy() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFD699)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, color: AppColors.primaryOrange, size: 18),
              const SizedBox(width: 8),
              const Text(
                'Cancellation Policy',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryOrange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildPolicyRow('Free cancellation up to 24 hours before booking'),
          const SizedBox(height: 6),
          _buildPolicyRow('50% refund for cancellation within 24 hours'),
          const SizedBox(height: 6),
          _buildPolicyRow('No refund within 12 hours of start time'),
        ],
      ),
    );
  }

  Widget _buildPolicyRow(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 5),
          child: CircleAvatar(
            radius: 3,
            backgroundColor: AppColors.secondaryText,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.secondaryText,
              height: 1.5,
            ),
          ),
        ),
      ],
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
            onChanged: (value) => setState(() => _termsAccepted = value ?? false),
            activeColor: AppColors.primaryOrange,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
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
                    text: 'I agree to the ',
                    style: TextStyle(fontSize: 13, color: AppColors.secondaryText),
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
                  TextSpan(
                    text: ' and Cancellation Policy',
                    style: TextStyle(fontSize: 13, color: AppColors.secondaryText),
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
                    'Confirm Booking',
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
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value) {
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
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryText,
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
