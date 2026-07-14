import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import '../../../core/themes/app_colors.dart';
import '../../../shared/models/donation.dart';
import '../../../shared/models/temple.dart';
import '../services/donation_service.dart';
import '../../../features/temple/services/user_temple_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../shared/widgets/error/animated_error_display.dart';
import '../../../shared/widgets/loading/skeleton_loader.dart';
import '../../../shared/screens/donation_confirmation_preview_screen.dart';

class DonationScreen extends StatefulWidget {
  final Temple? temple; // Optional temple parameter

  const DonationScreen({super.key, this.temple});

  @override
  State<DonationScreen> createState() => _DonationScreenState();
}

class _DonationScreenState extends State<DonationScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  final _donationService = DonationService();

  String _selectedPurpose = 'general';
  bool _isProcessing = false;
  List<String> _donationPurposes = [];
  List<double> _suggestedAmounts = [];
  List<Temple> _availableTemples = [];
  Temple? _selectedTemple;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadData();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _animationController.forward();
  }

  Future<void> _loadData() async {
    try {
      final donationPurposes = _donationService.getDonationPurposes();
      final suggestedAmounts = _donationService.getDonationAmountSuggestions();

      // If no temple provided, load available temples
      if (widget.temple == null) {
        final templeService = UserTempleService();
        await templeService.initialize();
        final temples = await templeService.searchTemples('');
        setState(() {
          _availableTemples = temples.take(20).toList(); // Limit to 20 temples
        });
      } else {
        setState(() {
          _selectedTemple = widget.temple;
        });
      }

      setState(() {
        _donationPurposes = donationPurposes;
        _suggestedAmounts = suggestedAmounts;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load donation options: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 255, 122, 0),
        foregroundColor: AppColors.white,
        elevation: 0,
        title: const Text(
          'Make Donation',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.temple == null) _buildTempleSelection(),
                  if (_selectedTemple != null) _buildTempleInfo(),
                  const SizedBox(height: 24),
                  _buildAmountSection(),
                  const SizedBox(height: 24),
                  _buildPurposeSection(),
                  const SizedBox(height: 24),
                  _buildNotesSection(),
                  const SizedBox(height: 32),
                  _buildDonateButton(),
                  const SizedBox(height: 16),
                  _buildDonationHistory(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTempleSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Temple',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryText,
          ),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<Temple>(
          value: _selectedTemple,
          isExpanded: true,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.borderGray),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: AppColors.primaryOrange,
                width: 2,
              ),
            ),
            labelText: 'Choose a temple to donate to',
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
          items: _availableTemples.map((temple) {
            return DropdownMenuItem(
              value: temple,
              child: Text(temple.name, overflow: TextOverflow.ellipsis),
            );
          }).toList(),
          onChanged: (temple) {
            setState(() {
              _selectedTemple = temple;
            });
          },
          validator: (value) {
            if (value == null) {
              return 'Please select a temple';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildTempleInfo() {
    if (_selectedTemple == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.lightOrange.withValues(alpha: 0.1),
            AppColors.lightOrange.withValues(alpha: 0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.lightOrange.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: _selectedTemple!.images.isNotEmpty
                ? Image.network(
                    _selectedTemple!.images.first,
                    width: 70,
                    height: 70,
                    fit: BoxFit.cover,
                    cacheHeight: 200,
                    cacheWidth: 200,
                    errorBuilder: (context, error, stackTrace) =>
                        _buildTempleIcon(),
                  )
                : _buildTempleIcon(),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedTemple!.name,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkGreen,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 14,
                      color: AppColors.lightOrange,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _selectedTemple!.location.address ?? 'Temple Location',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTempleIcon() {
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        color: AppColors.primaryOrange,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.temple_hindu, color: AppColors.white, size: 36),
    );
  }

  Widget _buildAmountSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Donation Amount',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryText,
          ),
        ),
        const SizedBox(height: 10),
        if (_suggestedAmounts.isNotEmpty) ...[
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _suggestedAmounts.map((amount) {
              final parsedText = double.tryParse(_amountController.text);
              final isSelected = parsedText != null && parsedText == amount;
              return InkWell(
                onTap: () {
                  setState(() {
                    _amountController.text = amount.toInt().toString();
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primaryOrange
                        : AppColors.white,
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primaryOrange
                          : AppColors.lightGray,
                      width: isSelected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '\$${amount.toInt()}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: isSelected ? Colors.white : Colors.grey[800],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
        ],
        TextFormField(
          controller: _amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
          ],
          decoration: InputDecoration(
            labelText: 'Enter Custom Amount',
            prefixText: '\$ ',
            hintText: '10',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.borderGray),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: AppColors.primaryOrange,
                width: 2,
              ),
            ),
            prefixIcon: const Icon(
              Icons.attach_money,
              color: AppColors.primaryOrange,
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter donation amount';
            }
            final amount = double.tryParse(value);
            if (amount == null || amount <= 0) {
              return 'Please enter a valid amount';
            }
            if (amount < 0.50) {
              return 'Minimum donation amount is \$0.50';
            }
            if (amount > 999999) {
              return 'Amount cannot exceed \$999,999';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildPurposeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Donation Purpose',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryText,
          ),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: _selectedPurpose,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.borderGray),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: AppColors.primaryOrange,
                width: 2,
              ),
            ),
            labelText: 'Select Purpose',
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
          items: _donationPurposes.map((purpose) {
            return DropdownMenuItem(
              value: purpose,
              child: Text(_getPurposeDisplayName(purpose)),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _selectedPurpose = value;
              });
            }
          },
        ),
      ],
    );
  }

  Widget _buildNotesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Notes (Optional)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryText,
          ),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _notesController,
          maxLines: 4,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.borderGray),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: AppColors.primaryOrange,
                width: 2,
              ),
            ),
            hintText: 'Add any special notes or dedication...',
            alignLabelWithHint: true,
            prefixIcon: const Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Icon(Icons.note_alt, color: AppColors.primaryOrange),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDonateButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isProcessing
            ? null
            : () {
                HapticFeedback.lightImpact();
                _showDonationPreview();
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryOrange,
          foregroundColor: Colors.white,
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          disabledBackgroundColor: AppColors.borderGray,
        ),
        child: _isProcessing
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.volunteer_activism, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Donate Now',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildDonationHistory() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.currentUser;

    if (currentUser == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Donations',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            TextButton(
              onPressed: () => Navigator.of(
                context,
                rootNavigator: true,
              ).pushNamed('/recent_donations'),
              child: const Text(
                'See all',
                style: TextStyle(fontSize: 14, color: AppColors.primaryOrange),
              ),
            ),
          ],
        ),
        StreamBuilder<List<Donation>>(
          stream: _donationService.watchUserDonations(currentUser.uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SearchSkeletonLoader(itemCount: 4);
            }

            if (snapshot.hasError) {
              return AnimatedErrorDisplay(
                message: 'Failed to load donation history',
                onRetry: () => setState(() {}),
              );
            }

            final donations = snapshot.data ?? [];
            final templeDonations = _selectedTemple != null
                ? donations
                      .where((d) => d.templeId == _selectedTemple!.id)
                      .take(3)
                      .toList()
                : donations.take(3).toList();

            if (templeDonations.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderGray),
                ),
                child: Text(
                  _selectedTemple != null
                      ? 'No previous donations to this temple'
                      : 'No previous donations',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.secondaryText,
                  ),
                ),
              );
            }

            return Column(
              children: templeDonations.map((donation) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.borderGray),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _getStatusColor(donation.status),
                      child: Icon(
                        _getStatusIcon(donation.status),
                        color: AppColors.white,
                        size: 18,
                      ),
                    ),
                    title: Text(
                      donation.formattedAmount,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: AppColors.primaryText,
                      ),
                    ),
                    subtitle: Text(
                      '${donation.purposeDisplayName} • ${donation.formattedDate}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.secondaryText,
                      ),
                    ),
                    trailing: Text(
                      donation.statusDisplayName,
                      style: TextStyle(
                        color: _getStatusColor(donation.status),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  /// Validate form and required fields before processing
  String? _validateDonationForm() {
    if (_formKey.currentState == null || !_formKey.currentState!.validate()) {
      return 'Form validation failed';
    }
    if (_selectedTemple == null) return 'Please select a temple';
    return null;
  }

  /// Build donation object from form inputs
  Donation _buildDonationObject(double amount, fb_auth.User currentUser) {
    return Donation(
      id: '',
      templeId: _selectedTemple!.id,
      userId: currentUser.uid,
      amount: amount,
      // US Stripe account: USD required for Google Pay.
      // Switch to 'INR' only after migrating to an Indian Stripe account.
      currency: 'USD',
      paymentMethod: 'stripe',
      purpose: _selectedPurpose,
      notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      donationDate: DateTime.now(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// Build customer info for payment processing
  Map<String, dynamic> _buildCustomerInfo(fb_auth.User currentUser) {
    final phone = currentUser.phoneNumber ?? '';
    return {
      'name': currentUser.displayName ?? 'User',
      'email': currentUser.email ?? '',
      'contact': phone,
      'phone': phone,
      'customer_id': currentUser.uid,
    };
  }

  /// Show error snackbar
  void _showErrorSnackBar(String message, {Duration? duration}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.errorRed,
        duration: duration ?? const Duration(seconds: 3),
      ),
    );
  }

  /// Show donation confirmation preview before processing payment
  void _showDonationPreview() {
    final formError = _validateDonationForm();
    if (formError != null) {
      _showErrorSnackBar(formError);
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.currentUser;
    if (currentUser == null) {
      _showErrorSnackBar('Please sign in to make a donation');
      return;
    }

    final amount = double.tryParse(_amountController.text) ?? 0.0;
    final previewDonation = _buildDonationObject(amount, currentUser);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DonationConfirmationPreviewScreen(
          donation: previewDonation,
          temple: _selectedTemple!,
          onEdit: () => Navigator.of(context).pop(),
          onConfirm: () {
            Navigator.of(context).pop();
            _processDonation();
          },
        ),
      ),
    );
  }

  Future<void> _processDonation() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.currentUser;
    if (currentUser == null) {
      _showErrorSnackBar('Please sign in to make a donation');
      return;
    }
    // Use Stripe Payment Sheet directly (supports cards, UPI, Google Pay, etc.)
    await _processDonationPayment(currentUser);
  }

  /// Process donation via Stripe Payment Sheet (supports cards, UPI, Google Pay, etc.)
  Future<void> _processDonationPayment(fb_auth.User currentUser) async {
    setState(() => _isProcessing = true);
    try {
      final amount = double.tryParse(_amountController.text) ?? 0.0;

      // ✅ VALIDATION: Check amount is valid
      if (!_isValidDonationAmount(amount)) {
        setState(() => _isProcessing = false);
        return;
      }
      final donation = _buildDonationObject(amount, currentUser);
      final customerInfo = _buildCustomerInfo(currentUser);

      final processedDonation = await _donationService
          .processDonationWithPayment(
            donation: donation,
            customerInfo: customerInfo,
          );

      if (processedDonation.status == DonationStatus.completed) {
        if (mounted) _showDonationReceipt(processedDonation);
      } else {
        throw Exception('Payment failed. Please try again.');
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString();
        if (msg.contains('canceled') ||
            msg.contains('cancelled') ||
            msg.contains('Canceled') ||
            msg.contains('Cancelled'))
          return;
        _showErrorSnackBar(
          'Donation failed: $msg',
          duration: const Duration(seconds: 5),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  String _getPurposeDisplayName(String purpose) {
    switch (purpose) {
      case 'general':
        return 'General Donation';
      case 'festival':
        return 'Festival Celebration';
      case 'maintenance':
        return 'Temple Maintenance';
      case 'construction':
        return 'Construction';
      case 'food':
        return 'Food Service';
      case 'education':
        return 'Education';
      default:
        return purpose;
    }
  }

  Color _getStatusColor(DonationStatus status) {
    switch (status) {
      case DonationStatus.completed:
        return AppColors.successGreen;
      case DonationStatus.pending:
        return AppColors.primaryOrange;
      case DonationStatus.failed:
        return AppColors.errorRed;
      case DonationStatus.refunded:
        return AppColors.primaryOrange;
    }
  }

  IconData _getStatusIcon(DonationStatus status) {
    switch (status) {
      case DonationStatus.completed:
        return Icons.check;
      case DonationStatus.pending:
        return Icons.schedule;
      case DonationStatus.failed:
        return Icons.close;
      case DonationStatus.refunded:
        return Icons.undo;
    }
  }

  void _showDonationReceipt(Donation donation) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => DonationReceiptDialog(
        donation: donation,
        temple: _selectedTemple!,
        onDone: () {
          Navigator.of(context).pop(); // Close dialog
          // Clear form
          _amountController.clear();
          _notesController.clear();
          setState(() {
            _selectedPurpose = 'general';
          });
        },
      ),
    );
  }

  /// Validate donation amount before processing
  bool _isValidDonationAmount(double amount) {
    if (amount.isNaN || amount.isInfinite) {
      _showErrorSnackBar('Please enter a valid donation amount');
      return false;
    }
    if (amount < 0.50) {
      _showErrorSnackBar('Minimum donation amount is \$0.50');
      return false;
    }
    if (amount > 999999) {
      _showErrorSnackBar('Maximum donation amount is \$999,999');
      return false;
    }
    return true;
  }
}

class DonationReceiptDialog extends StatelessWidget {
  final Donation donation;
  final Temple temple;
  final VoidCallback onDone;

  const DonationReceiptDialog({
    super.key,
    required this.donation,
    required this.temple,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.successGreen.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.receipt_long,
              color: AppColors.successGreen,
              size: 32,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Donation Receipt',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.successGreen,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Thank you for your generous donation! Your contribution helps support the temple and its community.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.veryLightGray,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderGray),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Donation Details',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    'Transaction ID',
                    donation.transactionId ?? donation.id,
                  ),
                  _buildDetailRow('Temple', temple.name),
                  _buildDetailRow(
                    'Amount',
                    '\$${donation.amount.toStringAsFixed(2)}',
                  ),
                  _buildDetailRow(
                    'Purpose',
                    _formatPurpose(donation.purpose ?? 'general'),
                  ),
                  _buildDetailRow(
                    'Payment Method',
                    _formatPaymentMethod(donation.paymentMethod),
                  ),
                  _buildDetailRow('Date', _formatDate(donation.donationDate)),
                  if (donation.notes != null)
                    _buildDetailRow('Notes', donation.notes!),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryOrange.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.primaryOrange.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: AppColors.primaryOrange,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'A receipt has been sent to your email. Keep this for tax purposes.',
                      style: TextStyle(
                        color: AppColors.coralOrange,
                        fontSize: 14,
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
          onPressed: () async {
            await _shareReceipt();
          },
          child: const Text('Share Receipt'),
        ),
        ElevatedButton(
          onPressed: onDone,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.successGreen,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('Done'),
        ),
      ],
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
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: AppColors.secondaryText,
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

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatPurpose(String purpose) {
    switch (purpose) {
      case 'general':
        return 'General Donation';
      case 'festival':
        return 'Festival Celebration';
      case 'maintenance':
        return 'Temple Maintenance';
      case 'construction':
        return 'Construction';
      case 'food':
        return 'Food Service';
      case 'education':
        return 'Education';
      default:
        return purpose.toUpperCase();
    }
  }

  String _formatPaymentMethod(String method) {
    switch (method) {
      case 'card':
        return 'Credit/Debit Card';
      case 'upi':
        return 'UPI';
      case 'netbanking':
        return 'Net Banking';
      case 'wallet':
        return 'Digital Wallet';
      default:
        return method.toUpperCase();
    }
  }

  Future<void> _shareReceipt() async {
    final receipt =
        '''
DONATION RECEIPT

Temple: ${temple.name}
Amount: \$${donation.amount.toStringAsFixed(2)}
Purpose: ${_formatPurpose(donation.purpose ?? 'general')}
Payment Method: ${_formatPaymentMethod(donation.paymentMethod)}
Date: ${_formatDate(donation.donationDate)}
Transaction ID: ${donation.transactionId ?? donation.id}

Thank you for your generous donation!
''';

    await Share.share(receipt, subject: 'Donation Receipt - ${temple.name}');
  }
}
