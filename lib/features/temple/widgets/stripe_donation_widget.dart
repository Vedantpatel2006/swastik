import 'package:flutter/material.dart';
import '../../../shared/models/donation.dart';
import '../../../shared/models/temple.dart';
import '../services/stripe_payment_service.dart';
import '../../../core/config/payment_config.dart';

/// Widget for handling Stripe donations
class StripeDonationWidget extends StatefulWidget {
  final Temple temple;
  final String userId;
  final Function(Donation)? onDonationComplete;
  final Function(String)? onError;

  const StripeDonationWidget({
    super.key,
    required this.temple,
    required this.userId,
    this.onDonationComplete,
    this.onError,
  });

  @override
  State<StripeDonationWidget> createState() => _StripeDonationWidgetState();
}

class _StripeDonationWidgetState extends State<StripeDonationWidget> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  String _selectedPurpose = 'general';
  bool _isProcessing = false;

  final List<String> _purposes = [
    'general',
    'festival',
    'maintenance',
    'construction',
  ];

  final List<double> _quickAmounts = [1.0, 5.0, 10.0, 25.0];

  @override
  Widget build(BuildContext context) {
    if (!PaymentConfig.isStripeConfigured) {
      return _buildConfigurationError();
    }

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              _buildQuickAmounts(),
              const SizedBox(height: 16),
              _buildAmountField(),
              const SizedBox(height: 16),
              _buildPurposeSelector(),
              const SizedBox(height: 16),
              _buildDonorInfoFields(),
              const SizedBox(height: 24),
              _buildDonateButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Icon(
          Icons.favorite,
          size: 48,
          color: Theme.of(context).primaryColor,
        ),
        const SizedBox(height: 8),
        Text(
          'Make a Donation',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'Support ${widget.temple.name}',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
        ),
      ],
    );
  }

  Widget _buildQuickAmounts() {
    return Wrap(
      spacing: 8,
      children: _quickAmounts.map((amount) {
        return ActionChip(
          label: Text('\$${amount.toInt()}'),
          onPressed: () {
            setState(() {
              _amountController.text = amount.toString();
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildAmountField() {
    return TextFormField(
      controller: _amountController,
      keyboardType: TextInputType.number,
      decoration: const InputDecoration(
        labelText: 'Donation Amount (USD)',
        prefixText: '\$ ',
        border: OutlineInputBorder(),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter an amount';
        }
        final amount = double.tryParse(value);
        if (amount == null || amount <= 0) {
          return 'Please enter a valid amount';
        }
        if (amount < 0.50) {
          return 'Minimum donation is \$0.50';
        }
        return null;
      },
    );
  }

  Widget _buildPurposeSelector() {
    return DropdownButtonFormField<String>(
      value: _selectedPurpose,
      decoration: const InputDecoration(
        labelText: 'Donation Purpose',
        border: OutlineInputBorder(),
      ),
      items: _purposes.map((purpose) {
        return DropdownMenuItem(
          value: purpose,
          child: Text(purpose.toUpperCase()),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) {
          setState(() {
            _selectedPurpose = value;
          });
        }
      },
    );
  }

  Widget _buildDonorInfoFields() {
    return Column(
      children: [
        TextFormField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Full Name',
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter your name';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email Address',
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter your email';
            }
            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
              return 'Please enter a valid email';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildDonateButton() {
    return ElevatedButton(
      onPressed: _isProcessing ? null : _processDonation,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      child: _isProcessing
          ? const CircularProgressIndicator(color: Colors.white)
          : const Text('Donate Now'),
    );
  }

  Widget _buildConfigurationError() {
    return const Card(
      margin: EdgeInsets.all(16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.orange),
            SizedBox(height: 16),
            Text(
              'Payment Configuration Required',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Stripe payment is not properly configured.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _processDonation() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isProcessing = true);

    try {
      final amount = double.parse(_amountController.text);
      
      final donation = Donation(
        id: '',
        userId: widget.userId,
        templeId: widget.temple.id,
        amount: amount,
        // US Stripe account: use USD for Google Pay compatibility.
        // INR is accepted by the Payment Sheet card flow but not Google Pay
        // on a US merchant account. Switch to 'INR' only with an Indian account.
        currency: 'USD',
        paymentMethod: 'stripe',
        purpose: _selectedPurpose,
        donationDate: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        status: DonationStatus.pending,
      );

      final customerInfo = {
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': null, // Payment Sheet will prompt if needed
      };

      final transaction = await StripePaymentService.instance.processDonationPayment(
        donation: donation,
        customerInfo: customerInfo,
      );

      if (transaction.isSuccessful) {
        final completedDonation = donation.copyWith(
          status: DonationStatus.completed,
          transactionId: transaction.gatewayOrderId,
        );
        widget.onDonationComplete?.call(completedDonation);
        _showSuccessDialog();
      } else {
        widget.onError?.call(transaction.failureReason ?? 'Payment failed');
        _showErrorDialog(transaction.failureReason ?? 'Payment failed');
      }
    } catch (e) {
      widget.onError?.call(e.toString());
      _showErrorDialog('Failed to process donation: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 48),
        title: const Text('Donation Successful!'),
        content: const Text('Thank you for your generous donation.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.error, color: Colors.red, size: 48),
        title: const Text('Payment Failed'),
        content: Text(error),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}