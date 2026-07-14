import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/donation.dart';
import '../services/donation_service.dart';

class DonationAnalyticsWidget extends StatefulWidget {
  final String templeId;
  final DonationService donationService;

  const DonationAnalyticsWidget({
    super.key,
    required this.templeId,
    required this.donationService,
  });

  @override
  State<DonationAnalyticsWidget> createState() =>
      _DonationAnalyticsWidgetState();
}

class _DonationAnalyticsWidgetState extends State<DonationAnalyticsWidget> {
  DonationAnalytics? _analytics;
  bool _isLoading = true;
  String _selectedPeriod = '30days';

  final Map<String, String> _periodOptions = {
    '7days': 'Last 7 Days',
    '30days': 'Last 30 Days',
    '90days': 'Last 90 Days',
    '1year': 'Last Year',
  };

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final now = DateTime.now();
      DateTime startDate;

      switch (_selectedPeriod) {
        case '7days':
          startDate = now.subtract(const Duration(days: 7));
          break;
        case '30days':
          startDate = now.subtract(const Duration(days: 30));
          break;
        case '90days':
          startDate = now.subtract(const Duration(days: 90));
          break;
        case '1year':
          startDate = now.subtract(const Duration(days: 365));
          break;
        default:
          startDate = now.subtract(const Duration(days: 30));
      }

      final analytics = await widget.donationService.getTempleAnalytics(
        templeId: widget.templeId,
        startDate: startDate,
        endDate: now,
      );

      setState(() {
        _analytics = analytics;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load analytics: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header with period selector
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Donation Analytics',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              DropdownButton<String>(
                value: _selectedPeriod,
                items: _periodOptions.entries
                    .map(
                      (entry) => DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedPeriod = value;
                    });
                    _loadAnalytics();
                  }
                },
              ),
            ],
          ),
        ),

        // Content
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _analytics == null
              ? _buildEmptyState()
              : _buildAnalyticsContent(),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.analytics_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No donation data available',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'Analytics will appear here once donations are made',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsContent() {
    final analytics = _analytics!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary Cards
          _buildSummaryCards(analytics),
          const SizedBox(height: 24),

          // Charts
          _buildChartsSection(analytics),
          const SizedBox(height: 24),

          // Detailed Breakdown
          _buildDetailedBreakdown(analytics),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(DonationAnalytics analytics) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.5,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: [
        _buildSummaryCard(
          'Total Amount',
          '₹${NumberFormat('#,##,###.00').format(analytics.totalAmount)}',
          Icons.currency_rupee,
          Colors.green,
        ),
        _buildSummaryCard(
          'Total Donations',
          analytics.totalDonations.toString(),
          Icons.volunteer_activism,
          Colors.orange,
        ),
        _buildSummaryCard(
          'Average Donation',
          '₹${NumberFormat('#,##,###.00').format(analytics.averageDonation)}',
          Icons.trending_up,
          Colors.orange,
        ),
        _buildSummaryCard(
          'Payment Methods',
          analytics.countByPaymentMethod.length.toString(),
          Icons.payment,
          Colors.purple,
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartsSection(DonationAnalytics analytics) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Charts',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),

        // Monthly Trends Chart
        if (analytics.monthlyTrends.isNotEmpty) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Monthly Trends',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: _buildMonthlyTrendsChart(analytics.monthlyTrends),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Donation Types Pie Chart
        if (analytics.amountByType.isNotEmpty) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Donation Types',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: _buildDonationTypesPieChart(analytics.amountByType),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Payment Methods Chart
        if (analytics.countByPaymentMethod.isNotEmpty) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Payment Methods',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: _buildPaymentMethodsChart(
                      analytics.countByPaymentMethod,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMonthlyTrendsChart(Map<String, double> monthlyTrends) {
    final sortedEntries = monthlyTrends.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final spots = sortedEntries.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.value);
    }).toList();

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: true),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 60,
              getTitlesWidget: (value, meta) {
                return Text(
                  '₹${NumberFormat.compact().format(value)}',
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < sortedEntries.length) {
                  final monthKey = sortedEntries[index].key;
                  final parts = monthKey.split('-');
                  if (parts.length == 2) {
                    final month = int.tryParse(parts[1]) ?? 1;
                    return Text(
                      DateFormat.MMM().format(DateTime(2024, month)),
                      style: const TextStyle(fontSize: 10),
                    );
                  }
                }
                return const Text('');
              },
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(show: true),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.orange,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.orange.withValues(alpha: 0.1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDonationTypesPieChart(Map<DonationType, double> amountByType) {
    final colors = [
      Colors.orange,
      Colors.orange,
      Colors.green,
      Colors.purple,
      Colors.red,
      Colors.teal,
    ];

    final sections = amountByType.entries.map((entry) {
      final index = amountByType.keys.toList().indexOf(entry.key);
      return PieChartSectionData(
        value: entry.value,
        title:
            '${((entry.value / amountByType.values.fold(0.0, (a, b) => a + b)) * 100).toStringAsFixed(1)}%',
        color: colors[index % colors.length],
        radius: 60,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: PieChart(
            PieChartData(
              sections: sections,
              centerSpaceRadius: 40,
              sectionsSpace: 2,
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: amountByType.entries.map((entry) {
              final index = amountByType.keys.toList().indexOf(entry.key);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      color: colors[index % colors.length],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _getDonationTypeLabel(entry.key),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodsChart(
    Map<PaymentMethod, int> countByPaymentMethod,
  ) {
    final colors = [
      Colors.orange,
      Colors.orange,
      Colors.green,
      Colors.purple,
      Colors.red,
    ];

    final barGroups = countByPaymentMethod.entries.map((entry) {
      final index = countByPaymentMethod.keys.toList().indexOf(entry.key);
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: entry.value.toDouble(),
            color: colors[index % colors.length],
            width: 20,
          ),
        ],
      );
    }).toList();

    return BarChart(
      BarChartData(
        barGroups: barGroups,
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                final methods = countByPaymentMethod.keys.toList();
                if (index >= 0 && index < methods.length) {
                  return Text(
                    _getPaymentMethodLabel(methods[index]),
                    style: const TextStyle(fontSize: 10),
                  );
                }
                return const Text('');
              },
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
      ),
    );
  }

  Widget _buildDetailedBreakdown(DonationAnalytics analytics) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Detailed Breakdown',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),

        // Donation Types Breakdown
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'By Donation Type',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ...analytics.amountByType.entries.map(
                  (entry) => _buildBreakdownItem(
                    _getDonationTypeLabel(entry.key),
                    '₹${NumberFormat('#,##,###.00').format(entry.value)}',
                    entry.value / analytics.totalAmount,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Payment Methods Breakdown
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'By Payment Method',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ...analytics.countByPaymentMethod.entries.map(
                  (entry) => _buildBreakdownItem(
                    _getPaymentMethodLabel(entry.key),
                    '${entry.value} donations',
                    entry.value / analytics.totalDonations,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBreakdownItem(String label, String value, double percentage) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: percentage,
            backgroundColor: Colors.grey.shade200,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
          ),
          const SizedBox(height: 2),
          Text(
            '${(percentage * 100).toStringAsFixed(1)}%',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
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

  String _getPaymentMethodLabel(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.upi:
        return 'UPI';
      case PaymentMethod.card:
        return 'Card';
      case PaymentMethod.netBanking:
        return 'Net Banking';
      case PaymentMethod.wallet:
        return 'Wallet';
    }
  }
}
