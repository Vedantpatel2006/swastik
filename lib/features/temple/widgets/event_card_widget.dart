import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../shared/models/event.dart';
import '../../../shared/models/event_registration.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/app_spacing.dart';
import '../../../core/themes/app_radius.dart';

class EventCardWidget extends StatelessWidget {
  final Event event;
  final EventRegistration? registration;
  final VoidCallback? onTap;
  final VoidCallback? onRegister;
  final bool showRegistrationStatus;

  const EventCardWidget({
    super.key,
    required this.event,
    this.registration,
    this.onTap,
    this.onRegister,
    this.showRegistrationStatus = false,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isPast = event.endDate.isBefore(now);
    final isOngoing = event.startDate.isBefore(now) && event.endDate.isAfter(now);

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
                                event.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryText,
                                ),
                              ),
                            ),
                            if (isOngoing)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.successGreen,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'LIVE',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
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
                              _formatEventTime(),
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
              if (event.description.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  event.description,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.secondaryText,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (showRegistrationStatus && registration != null) ...[
                const SizedBox(height: AppSpacing.sm),
                _buildRegistrationStatus(),
              ],
              if (!isPast && !showRegistrationStatus && onRegister != null) ...[
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onRegister,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryOrange,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.mediumRadius,
                      ),
                    ),
                    child: const Text('Register'),
                  ),
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
        color: AppColors.primaryOrange.withValues(alpha: 0.1),
        borderRadius: AppRadius.mediumRadius,
      ),
      child: Column(
        children: [
          Text(
            DateFormat('MMM').format(event.startDate),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryOrange,
            ),
          ),
          Text(
            DateFormat('dd').format(event.startDate),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryOrange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegistrationStatus() {
    if (registration == null) return const SizedBox.shrink();

    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (registration!.status) {
      case RegistrationStatus.confirmed:
        statusColor = AppColors.successGreen;
        statusText = 'Confirmed';
        statusIcon = Icons.check_circle;
        break;
      case RegistrationStatus.checkedIn:
        statusColor = AppColors.primaryOrange;
        statusText = 'Checked In';
        statusIcon = Icons.verified;
        break;
      case RegistrationStatus.waitlisted:
        statusColor = AppColors.warningAmber;
        statusText = 'Waitlisted';
        statusIcon = Icons.schedule;
        break;
      case RegistrationStatus.cancelled:
        statusColor = AppColors.errorRed;
        statusText = 'Cancelled';
        statusIcon = Icons.cancel;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, size: 16, color: statusColor),
          const SizedBox(width: 6),
          Text(
            statusText,
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          if (registration!.numberOfAttendees > 1) ...[
            const SizedBox(width: 8),
            Text(
              '• ${registration!.numberOfAttendees} attendees',
              style: TextStyle(
                color: statusColor,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatEventTime() {
    final startTime = DateFormat('h:mm a').format(event.startDate);
    final endTime = DateFormat('h:mm a').format(event.endDate);

    if (event.startDate.day == event.endDate.day) {
      return '$startTime - $endTime';
    } else {
      final startDate = DateFormat('MMM dd, h:mm a').format(event.startDate);
      final endDate = DateFormat('MMM dd, h:mm a').format(event.endDate);
      return '$startDate - $endDate';
    }
  }
}
