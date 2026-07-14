import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/app_spacing.dart';
import '../../../core/themes/app_radius.dart';
import '../../../shared/models/booking.dart';
import '../../../shared/widgets/dialogs/booking_cancellation_dialog.dart';
import '../services/booking_service.dart';
import 'booking_screen.dart';

class BookingDetailScreen extends StatefulWidget {
  final Booking booking;

  const BookingDetailScreen({
    super.key,
    required this.booking,
  });

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  final _bookingService = BookingService();
  bool _isLoading = false;

  Future<void> _modifyBooking() async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookingScreen(bookingId: widget.booking.id,
        ),
      ),
    ).then((result) {
      if (result == true && mounted) {
        Navigator.pop(context, true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('EEEE, MMMM d, yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking Details'),
        backgroundColor: AppColors.primaryOrange,
        foregroundColor: AppColors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatusBadge(),
                  const SizedBox(height: AppSpacing.xl),
                  _buildSectionTitle('Temple Information'),
                  const SizedBox(height: AppSpacing.md),
                  _buildInfoCard(
                    icon: Icons.temple_hindu,
                    title: widget.booking.bookingTypeDisplayName,
                    subtitle: 'Booking Type',
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _buildSectionTitle('Date & Time'),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoCard(
                          icon: Icons.calendar_today,
                          title: dateFormat.format(widget.booking.bookingDate),
                          subtitle: 'Date',
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: _buildInfoCard(
                          icon: Icons.access_time,
                          title: widget.booking.formattedTime,
                          subtitle: 'Time',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _buildSectionTitle('Booking Details'),
                  const SizedBox(height: AppSpacing.md),
                  _buildDetailRow('Booking ID', widget.booking.id),
                  _buildDetailRow('Number of People', '${widget.booking.numberOfPeople}'),
                  if (widget.booking.specialRequests != null)
                    _buildDetailRow('Special Requests', widget.booking.specialRequests!),
                  const SizedBox(height: AppSpacing.xl),
                  _buildSectionTitle('Payment Information'),
                  const SizedBox(height: AppSpacing.md),
                  _buildPaymentInfo(),
                  const SizedBox(height: AppSpacing.xxl),
                  if (widget.booking.status == BookingStatus.confirmed ||
                      widget.booking.status == BookingStatus.pending)
                    _buildActionButtons(),
                ],
              ),
            ),
    );
  }

  Widget _buildStatusBadge() {
    Color statusColor;
    String statusText;

    switch (widget.booking.status) {
      case BookingStatus.confirmed:
        statusColor = AppColors.successGreen;
        statusText = 'Confirmed';
        break;
      case BookingStatus.pending:
        statusColor = AppColors.warningAmber;
        statusText = 'Pending';
        break;
      case BookingStatus.cancelled:
        statusColor = AppColors.errorRed;
        statusText = 'Cancelled';
        break;
      case BookingStatus.completed:
        statusColor = AppColors.primaryOrange;
        statusText = 'Completed';
        break;
      case BookingStatus.noShow:
        statusColor = AppColors.secondaryText;
        statusText = 'No Show';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: statusColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            widget.booking.status == BookingStatus.confirmed
                ? Icons.check_circle
                : widget.booking.status == BookingStatus.cancelled
                    ? Icons.cancel
                    : Icons.info,
            color: statusColor,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            statusText,
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppColors.primaryText,
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderGray),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.primaryOrange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(
              icon,
              color: AppColors.primaryOrange,
              size: 24,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.secondaryText,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentInfo() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderGray),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Amount',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.secondaryText,
                ),
              ),
              Text(
                '₹${widget.booking.amount?.toStringAsFixed(2) ?? '0.00'}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Payment Status',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.secondaryText,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: widget.booking.paymentStatus == BookingPaymentStatus.paid
                      ? AppColors.successGreen.withValues(alpha: 0.1)
                      : AppColors.warningAmber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  widget.booking.paymentStatus?.name.toUpperCase() ?? 'PENDING',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: widget.booking.paymentStatus == BookingPaymentStatus.paid
                        ? AppColors.successGreen
                        : AppColors.warningAmber,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _modifyBooking,
            icon: const Icon(Icons.edit),
            label: const Text('Modify Booking'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              foregroundColor: AppColors.white,
              minimumSize: const Size(0, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _cancelBooking,
            icon: const Icon(Icons.cancel),
            label: const Text('Cancel Booking'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.errorRed,
              side: const BorderSide(color: AppColors.errorRed),
              minimumSize: const Size(0, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _cancelBooking() async {
    final confirmed = await showBookingCancellationDialog(
      context: context,
      bookingId: widget.booking.id,
      onConfirm: (reason) async {
        await _bookingService.cancelBooking(widget.booking.id);
      },
    );

    if (confirmed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Booking cancelled successfully'),
          backgroundColor: AppColors.successGreen,
        ),
      );
      Navigator.pop(context, true);
    }
  }
}
