import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/donation.dart';
import '../services/donation_service.dart';
import '../services/receipt_service.dart';

class DonationHistoryWidget extends StatefulWidget {
  final DonationService donationService;
  final String? userId;

  const DonationHistoryWidget({
    super.key,
    required this.donationService,
    this.userId,
  });

  @override
  State<DonationHistoryWidget> createState() => _DonationHistoryWidgetState();
}

class _DonationHistoryWidgetState extends State<DonationHistoryWidget> {
  final ScrollController _scrollController = ScrollController();
  List<Donation> _donations = [];
  bool _isLoading = true;
  bool _hasMore = true;
  String _selectedFilter = 'all';

  final Map<String, String> _filterOptions = {
    'all': 'All Donations',
    'completed': 'Completed',
    'pending': 'Pending',
    'failed': 'Failed',
  };

  @override
  void initState() {
    super.initState();
    _loadDonations();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreDonations();
    }
  }

  Future<void> _loadDonations() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final donations = await widget.donationService.getUserDonations(
        userId: widget.userId,
        limit: 20,
      );

      setState(() {
        _donations = donations;
        _isLoading = false;
        _hasMore = donations.length >= 20;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load donations: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _loadMoreDonations() async {
    if (!_hasMore || _isLoading) return;

    try {
      // Note: This would need the actual DocumentSnapshot for pagination
      // For now, we'll skip loading more
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load more donations: ${e.toString()}'),
          ),
        );
      }
    }
  }

  List<Donation> get _filteredDonations {
    if (_selectedFilter == 'all') return _donations;

    final status = DonationStatus.values.firstWhere(
      (s) => s.name == _selectedFilter,
      orElse: () => DonationStatus.completed,
    );

    return _donations.where((d) => d.status == status).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header with filters
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Donation History',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: _loadDonations,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Filter chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _filterOptions.entries
                      .map(
                        (entry) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(entry.value),
                            selected: _selectedFilter == entry.key,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _selectedFilter = entry.key;
                                });
                              }
                            },
                            selectedColor: Colors.orange.shade100,
                            checkmarkColor: Colors.orange,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),

              // Summary
              if (_donations.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildSummaryCard(),
              ],
            ],
          ),
        ),

        // Donations list
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredDonations.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  controller: _scrollController,
                  itemCount: _filteredDonations.length + (_hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index >= _filteredDonations.length) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }

                    return _buildDonationCard(_filteredDonations[index]);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard() {
    final completedDonations = _donations
        .where((d) => d.status == DonationStatus.completed)
        .toList();

    final totalAmount = completedDonations.fold<double>(
      0.0,
      (sum, donation) => sum + donation.amount,
    );

    final taxEligibleAmount = completedDonations
        .where((d) => d.taxBenefitEligible)
        .fold<double>(0.0, (sum, donation) => sum + donation.amount);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Summary',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    'Total Donated',
                    '₹${NumberFormat('#,##,###.00').format(totalAmount)}',
                    Icons.volunteer_activism,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSummaryItem(
                    'Total Donations',
                    completedDonations.length.toString(),
                    Icons.favorite,
                    Colors.orange,
                  ),
                ),
              ],
            ),
            if (taxEligibleAmount > 0) ...[
              const SizedBox(height: 12),
              _buildSummaryItem(
                'Tax Eligible Amount',
                '₹${NumberFormat('#,##,###.00').format(taxEligibleAmount)}',
                Icons.receipt_long,
                Colors.orange,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.volunteer_activism_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No donations found',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'Your donation history will appear here',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildDonationCard(Donation donation) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: () => _showDonationDetails(donation),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      donation.templeName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  _buildStatusChip(donation.status),
                ],
              ),
              const SizedBox(height: 8),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '₹${NumberFormat('#,##,###.00').format(donation.amount)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  Text(
                    DateFormat(
                      'dd MMM yyyy, hh:mm a',
                    ).format(donation.createdAt),
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              Row(
                children: [
                  Icon(
                    _getDonationTypeIcon(donation.type),
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _getDonationTypeLabel(donation.type),
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    _getPaymentMethodIcon(donation.paymentMethod),
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _getPaymentMethodLabel(donation.paymentMethod),
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),

              if (donation.dedicatedTo != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Dedicated to: ${donation.dedicatedTo}',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],

              if (donation.taxBenefitEligible) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.receipt_long,
                        size: 12,
                        color: Colors.green.shade700,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Tax Benefit Eligible',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(DonationStatus status) {
    Color color;
    String label;

    switch (status) {
      case DonationStatus.completed:
        color = Colors.green;
        label = 'Completed';
        break;
      case DonationStatus.pending:
        color = Colors.orange;
        label = 'Pending';
        break;
      case DonationStatus.processing:
        color = Colors.orange;
        label = 'Processing';
        break;
      case DonationStatus.failed:
        color = Colors.red;
        label = 'Failed';
        break;
      case DonationStatus.refunded:
        color = Colors.purple;
        label = 'Refunded';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  IconData _getDonationTypeIcon(DonationType type) {
    switch (type) {
      case DonationType.general:
        return Icons.volunteer_activism;
      case DonationType.festival:
        return Icons.celebration;
      case DonationType.construction:
        return Icons.construction;
      case DonationType.maintenance:
        return Icons.build;
      case DonationType.food:
        return Icons.restaurant;
      case DonationType.special:
        return Icons.star;
    }
  }

  String _getDonationTypeLabel(DonationType type) {
    switch (type) {
      case DonationType.general:
        return 'General';
      case DonationType.festival:
        return 'Festival';
      case DonationType.construction:
        return 'Construction';
      case DonationType.maintenance:
        return 'Maintenance';
      case DonationType.food:
        return 'Food/Prasad';
      case DonationType.special:
        return 'Special';
    }
  }

  IconData _getPaymentMethodIcon(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.upi:
        return Icons.account_balance_wallet;
      case PaymentMethod.card:
        return Icons.credit_card;
      case PaymentMethod.netBanking:
        return Icons.account_balance;
      case PaymentMethod.wallet:
        return Icons.wallet;
    }
  }

  String _getPaymentMethodLabel(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.upi:
        return 'UPI';
      case PaymentMethod.card:
        return 'Card';
      case PaymentMethod.netBanking:
        return 'Net Banking';
      case PaymentMethod.wallet:
        return 'Digital Wallet';
    }
  }

  void _showDonationDetails(Donation donation) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DonationDetailsSheet(
        donation: donation,
        donationService: widget.donationService,
      ),
    );
  }
}

class DonationDetailsSheet extends StatelessWidget {
  final Donation donation;
  final DonationService donationService;

  const DonationDetailsSheet({
    super.key,
    required this.donation,
    required this.donationService,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.5,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Donation Details',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailCard(context),
                    const SizedBox(height: 16),
                    if (donation.status == DonationStatus.completed)
                      _buildReceiptActions(context),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Temple', donation.templeName),
            _buildDetailRow(
              'Amount',
              '₹${NumberFormat('#,##,###.00').format(donation.amount)}',
            ),
            _buildDetailRow('Type', _getDonationTypeLabel(donation.type)),
            _buildDetailRow(
              'Payment Method',
              _getPaymentMethodLabel(donation.paymentMethod),
            ),
            _buildDetailRow(
              'Date',
              DateFormat('dd MMMM yyyy, hh:mm a').format(donation.createdAt),
            ),
            if (donation.transactionId != null)
              _buildDetailRow('Transaction ID', donation.transactionId!),
            if (donation.receiptNumber != null)
              _buildDetailRow('Receipt Number', donation.receiptNumber!),
            if (donation.dedicatedTo != null)
              _buildDetailRow('Dedicated To', donation.dedicatedTo!),
            if (donation.notes != null)
              _buildDetailRow('Notes', donation.notes!),
            _buildDetailRow(
              'Tax Benefit',
              donation.taxBenefitEligible ? 'Yes' : 'No',
            ),
            if (donation.panNumber != null)
              _buildDetailRow('PAN Number', donation.panNumber!),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptActions(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Receipt Options',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _downloadReceipt(context, 'en'),
                    icon: const Icon(Icons.download),
                    label: const Text('English'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _downloadReceipt(context, 'hi'),
                    icon: const Icon(Icons.download),
                    label: const Text('हिंदी'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _downloadReceipt(context, 'gu'),
                    icon: const Icon(Icons.download),
                    label: const Text('ગુજરાતી'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getDonationTypeLabel(DonationType type) {
    switch (type) {
      case DonationType.general:
        return 'General Donation';
      case DonationType.festival:
        return 'Festival Donation';
      case DonationType.construction:
        return 'Construction';
      case DonationType.maintenance:
        return 'Maintenance';
      case DonationType.food:
        return 'Food/Prasad';
      case DonationType.special:
        return 'Special Occasion';
    }
  }

  String _getPaymentMethodLabel(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.upi:
        return 'UPI';
      case PaymentMethod.card:
        return 'Card';
      case PaymentMethod.netBanking:
        return 'Net Banking';
      case PaymentMethod.wallet:
        return 'Digital Wallet';
    }
  }

  Future<void> _downloadReceipt(BuildContext context, String language) async {
    try {
      final receipt = await donationService.generateReceipt(
        donation.id,
        language: language,
      );

      final receiptText = ReceiptService.generateReceiptText(receipt);

      // In a real app, you would save this to a file or share it
      // For now, we'll show it in a dialog
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Receipt (${language.toUpperCase()})'),
            content: SingleChildScrollView(
              child: Text(
                receiptText,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate receipt: ${e.toString()}'),
          ),
        );
      }
    }
  }
}
