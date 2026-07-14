import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/booking.dart';
import '../models/temple.dart';
import '../../core/themes/app_colors.dart';

/// Preview screen shown before confirming a booking.
/// Allows users to review all details before final submission.
class BookingConfirmationPreviewScreen extends StatelessWidget {
  final Booking booking;
  final Temple temple;
  final VoidCallback onConfirm;
  final VoidCallback onEdit;

  const BookingConfirmationPreviewScreen({
    super.key,
    required this.booking,
    required this.temple,
    required this.onConfirm,
    required this.onEdit,
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
          'Confirm Booking',
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

            // Booking Details Card
            _buildCard(
              title: 'Booking Details',
              icon: Icons.event_note_outlined,
              iconColor: AppColors.primaryOrange,
              child: Column(
                children: [
                  _buildRow('Date', _formatDate(booking.bookingDate)),
                  _buildDivider(),
                  _buildRow('Time', _formatTime(booking.bookingTime)),
                  _buildDivider(),
                  _buildRow('Type', _formatBookingType(booking.bookingType)),
                  _buildDivider(),
                  _buildRow(
                    'Guests',
                    '${booking.numberOfPeople} person${booking.numberOfPeople > 1 ? 's' : ''}',
                  ),
                  if (booking.specialRequests != null &&
                      booking.specialRequests!.isNotEmpty) ...[
                    _buildDivider(),
                    _buildRow('Special Requests', booking.specialRequests!),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Contact Details Card
            if (booking.contactPhone != null || booking.contactEmail != null)
              _buildCard(
                title: 'Contact Details',
                icon: Icons.person_outline,
                iconColor: AppColors.primaryBlue,
                child: Column(
                  children: [
                    if (booking.contactName != null)
                      _buildRow('Name', booking.contactName!),
                    if (booking.contactName != null &&
                        booking.contactPhone != null)
                      _buildDivider(),
                    if (booking.contactPhone != null)
                      _buildRow('Phone', booking.contactPhone!),
                    if (booking.contactPhone != null &&
                        booking.contactEmail != null)
                      _buildDivider(),
                    if (booking.contactEmail != null)
                      _buildRow('Email', booking.contactEmail!),
                  ],
                ),
              ),
            if (booking.contactPhone != null || booking.contactEmail != null)
              const SizedBox(height: 16),

            // Payment Details Card
            if (booking.amount != null && booking.amount! > 0)
              _buildCard(
                title: 'Payment',
                icon: Icons.payment_outlined,
                iconColor: AppColors.successGreen,
                child: Column(
                  children: [
                    _buildRow(
                      'Amount',
                      '₹${NumberFormat('#,##,###').format(booking.amount!.toInt())}',
                      valueColor: AppColors.primaryOrange,
                      valueBold: true,
                    ),
                    _buildDivider(),
                    _buildRow(
                      'Status',
                      booking.paymentStatus?.name.toUpperCase() ?? 'PENDING',
                    ),
                  ],
                ),
              ),
            if (booking.amount != null && booking.amount! > 0)
              const SizedBox(height: 16),

            // Important Notice
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFD699)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: AppColors.primaryOrange,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Please arrive 15 minutes before your scheduled time. Cancellations must be made at least 24 hours in advance.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.secondaryText,
                        height: 1.5,
                      ),
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
                      'Confirm Booking',
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

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  String _formatBookingType(String type) {
    return type
        .split('_')
        .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
}
