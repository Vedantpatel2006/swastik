import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../shared/models/booking.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/app_spacing.dart';
import '../../../core/themes/app_radius.dart';

class BookingCardWidget extends StatelessWidget {
  final Booking booking;
  final VoidCallback? onTap;
  final VoidCallback? onCancel;
  final VoidCallback? onModify;

  const BookingCardWidget({
    super.key,
    required this.booking,
    this.onTap,
    this.onCancel,
    this.onModify,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.largeRadius,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.largeRadius,
        child: Padding(
          padding: AppSpacing.allLg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDateBadge(),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                booking.bookingTypeDisplayName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryText,
                                ),
                              ),
                            ),
                            _buildStatusBadge(),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.access_time,
                              size: 14,
                              color: AppColors.secondaryText,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              booking.formattedTime,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.secondaryText,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Icon(
                              Icons.people,
                              size: 14,
                              color: AppColors.secondaryText,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${booking.numberOfPeople} ${booking.numberOfPeople == 1 ? 'person' : 'people'}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (booking.requiresPayment) ...[
                const SizedBox(height: AppSpacing.sm),
                _buildPaymentInfo(),
              ],
              if (booking.hasSpecialRequests) ...[
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.lightGray.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.note,
                        size: 14,
                        color: AppColors.secondaryText,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          booking.specialRequests!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.secondaryText,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (booking.isFuture && booking.timeUntilBooking != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    const Icon(
                      Icons.schedule,
                      size: 14,
                      color: AppColors.primaryOrange,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'In ${booking.formattedTimeUntilBooking}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.primaryOrange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
              if (onCancel != null || onModify != null) ...[
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    if (onModify != null)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onModify,
                          icon: const Icon(Icons.edit, size: 16),
                          label: const Text('Modify'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primaryOrange,
                            side: const BorderSide(
                              color: AppColors.primaryOrange,
                            ),
                          ),
                        ),
                      ),
                    if (onModify != null && onCancel != null)
                      const SizedBox(width: AppSpacing.sm),
                    if (onCancel != null)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onCancel,
                          icon: const Icon(Icons.cancel, size: 16),
                          label: const Text('Cancel'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.errorRed,
                            side: const BorderSide(color: AppColors.errorRed),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateBadge() {
    return Container(
      width: 60,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _getStatusColor().withValues(alpha: 0.1),
        borderRadius: AppRadius.mediumRadius,
      ),
      child: Column(
        children: [
          Text(
            DateFormat('MMM').format(booking.bookingDate),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: _getStatusColor(),
            ),
          ),
          Text(
            DateFormat('dd').format(booking.bookingDate),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: _getStatusColor(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getStatusColor().withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _getStatusColor(), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_getStatusIcon(), size: 12, color: _getStatusColor()),
          const SizedBox(width: 4),
          Text(
            booking.statusDisplayName,
            style: TextStyle(
              color: _getStatusColor(),
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentInfo() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: booking.isPaymentCompleted
            ? AppColors.successGreen.withValues(alpha: 0.1)
            : AppColors.warningAmber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: booking.isPaymentCompleted
              ? AppColors.successGreen
              : AppColors.warningAmber,
        ),
      ),
      child: Row(
        children: [
          Icon(
            booking.isPaymentCompleted
                ? Icons.check_circle
                : Icons.payment,
            size: 16,
            color: booking.isPaymentCompleted
                ? AppColors.successGreen
                : AppColors.warningAmber,
          ),
          const SizedBox(width: 6),
          Text(
            booking.formattedAmount,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: booking.isPaymentCompleted
                  ? AppColors.successGreen
                  : AppColors.warningAmber,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '• ${booking.paymentStatusDisplayName}',
            style: TextStyle(
              fontSize: 12,
              color: booking.isPaymentCompleted
                  ? AppColors.successGreen
                  : AppColors.warningAmber,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor() {
    switch (booking.status) {
      case BookingStatus.pending:
        return AppColors.warningAmber;
      case BookingStatus.confirmed:
        return AppColors.successGreen;
      case BookingStatus.cancelled:
        return AppColors.errorRed;
      case BookingStatus.completed:
        return AppColors.primaryOrange;
      case BookingStatus.noShow:
        return AppColors.secondaryText;
    }
  }

  IconData _getStatusIcon() {
    switch (booking.status) {
      case BookingStatus.pending:
        return Icons.schedule;
      case BookingStatus.confirmed:
        return Icons.check_circle;
      case BookingStatus.cancelled:
        return Icons.cancel;
      case BookingStatus.completed:
        return Icons.verified;
      case BookingStatus.noShow:
        return Icons.event_busy;
    }
  }
}
