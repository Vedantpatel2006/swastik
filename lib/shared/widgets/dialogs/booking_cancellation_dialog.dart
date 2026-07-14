import 'package:flutter/material.dart';

/// Dialog for collecting cancellation reason when user cancels a booking
class BookingCancellationDialog extends StatefulWidget {
  final String bookingId;
  final Function(String reason) onConfirm;

  const BookingCancellationDialog({
    super.key,
    required this.bookingId,
    required this.onConfirm,
  });

  @override
  State<BookingCancellationDialog> createState() => _BookingCancellationDialogState();
}

class _BookingCancellationDialogState extends State<BookingCancellationDialog> {
  String _selectedReason = 'change_of_plans';
  final _otherReasonController = TextEditingController();
  bool _isProcessing = false;

  final List<Map<String, String>> _cancellationReasons = [
    {'value': 'change_of_plans', 'label': 'Change of plans'},
    {'value': 'schedule_conflict', 'label': 'Schedule conflict'},
    {'value': 'emergency', 'label': 'Emergency'},
    {'value': 'weather', 'label': 'Weather conditions'},
    {'value': 'health_issues', 'label': 'Health issues'},
    {'value': 'booked_by_mistake', 'label': 'Booked by mistake'},
    {'value': 'other', 'label': 'Other (please specify)'},
  ];

  @override
  void dispose() {
    _otherReasonController.dispose();
    super.dispose();
  }

  void _handleConfirm() async {
    String reason = _selectedReason;
    
    if (_selectedReason == 'other') {
      final otherReason = _otherReasonController.text.trim();
      if (otherReason.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please specify the reason for cancellation'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      reason = 'Other: $otherReason';
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      await widget.onConfirm(reason);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to cancel booking: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.cancel_outlined, color: Colors.red[600], size: 28),
          const SizedBox(width: 12),
          const Text(
            'Cancel Booking',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Please select a reason for cancellation:',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 16),
            
            // Cancellation reasons
            ..._cancellationReasons.map((reason) {
              return RadioListTile<String>(
                value: reason['value']!,
                groupValue: _selectedReason,
                onChanged: _isProcessing
                    ? null
                    : (value) {
                        setState(() {
                          _selectedReason = value!;
                        });
                      },
                title: Text(
                  reason['label']!,
                  style: const TextStyle(fontSize: 14),
                ),
                dense: true,
                contentPadding: EdgeInsets.zero,
                activeColor: Colors.red[600],
              );
            }),

            // Other reason text field
            if (_selectedReason == 'other') ...[
              const SizedBox(height: 12),
              TextField(
                controller: _otherReasonController,
                decoration: InputDecoration(
                  hintText: 'Please specify the reason',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                maxLines: 3,
                enabled: !_isProcessing,
              ),
            ],

            const SizedBox(height: 16),
            
            // Warning message
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                border: Border.all(color: Colors.amber[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber, color: Colors.amber[800], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Cancellation may be subject to temple policies. Refunds (if applicable) will be processed within 5-7 business days.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.amber[900],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isProcessing
              ? null
              : () => Navigator.of(context).pop(false),
          child: Text(
            'Keep Booking',
            style: TextStyle(
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: _isProcessing ? null : _handleConfirm,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red[600],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: _isProcessing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text(
                  'Cancel Booking',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ],
    );
  }
}

/// Show booking cancellation dialog
Future<bool?> showBookingCancellationDialog({
  required BuildContext context,
  required String bookingId,
  required Function(String reason) onConfirm,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => BookingCancellationDialog(
      bookingId: bookingId,
      onConfirm: onConfirm,
    ),
  );
}
