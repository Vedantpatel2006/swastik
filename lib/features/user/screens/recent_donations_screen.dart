import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/themes/app_colors.dart';
import '../../../shared/models/donation.dart';
import '../../../shared/models/temple.dart';
import '../../../shared/services/unified_donation_service.dart';
import '../../../features/temple/services/user_temple_service.dart';
import '../../../features/temple/screens/temple_detail_screen.dart';
import '../../../features/user/screens/donation_screen.dart';

/// Recent Donations Screen
/// Shows all donations for the current user, sorted newest first.
/// Each card shows temple image, name, amount, status, purpose, date, and
/// transaction ID. Tapping the temple navigates to its detail screen.
class RecentDonationsScreen extends StatefulWidget {
  const RecentDonationsScreen({super.key});

  @override
  State<RecentDonationsScreen> createState() => _RecentDonationsScreenState();
}

class _RecentDonationsScreenState extends State<RecentDonationsScreen> {
  final UnifiedDonationService _donationService = UnifiedDonationService();
  final UserTempleService _templeService = UserTempleService();

  // Cache temple details so we don't re-fetch on every rebuild
  final Map<String, Temple?> _templeCache = {};

  StreamSubscription<List<Donation>>? _donationSub;
  List<Donation> _donations = [];
  bool _isLoading = true;
  String? _error;

  // Summary stats
  double _totalDonated = 0;
  int _completedCount = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _donationSub?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() {
        _error = 'Please sign in to view your donations.';
        _isLoading = false;
      });
      return;
    }

    try {
      await _templeService.initialize();

      _donationSub = _donationService.watchUserDonations(uid).listen(
        (donations) async {
          // Prefetch temple details for any new temple IDs
          final newIds = donations
              .map((d) => d.templeId)
              .where((id) => !_templeCache.containsKey(id))
              .toSet();

          await Future.wait(newIds.map(_fetchTemple));

          if (mounted) {
            setState(() {
              _donations = donations;
              _isLoading = false;
              _error = null;
              _computeStats(donations);
            });
          }
        },
        onError: (e) {
          if (mounted) {
            setState(() {
              _error = 'Failed to load donations. Please try again.';
              _isLoading = false;
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to initialize. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchTemple(String templeId) async {
    try {
      final temple = await _templeService.getTempleDetails(templeId);
      _templeCache[templeId] = temple;
    } catch (_) {
      _templeCache[templeId] = null;
    }
  }

  void _computeStats(List<Donation> donations) {
    _totalDonated = donations
        .where((d) => d.status == DonationStatus.completed)
        .fold(0, (sum, d) => sum + d.amount);
    _completedCount =
        donations.where((d) => d.status == DonationStatus.completed).length;
  }

  Future<void> _refresh() async {
    setState(() => _isLoading = true);
    _donationSub?.cancel();
    _templeCache.clear();
    await _init();
  }

  void _onTempleTap(Temple temple) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TempleDetailScreen(temple: temple),
      ),
    );
  }

  void _onDonateTap(Temple? temple) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DonationScreen(temple: temple),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.primaryOrange,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.white,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Row(
          children: [
            Icon(
              Icons.volunteer_activism_rounded,
              color: AppColors.white,
              size: 20,
            ),
            SizedBox(width: 8),
            Text(
              'My Donations',
              style: TextStyle(
                color: AppColors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Donate again',
            icon: const Icon(
              Icons.add_circle_outline_rounded,
              color: AppColors.white,
              size: 24,
            ),
            onPressed: () => _onDonateTap(null),
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _error != null
              ? _buildErrorState()
              : _donations.isEmpty
                  ? _buildEmptyState()
                  : _buildContent(),
    );
  }

  // ---------------------------------------------------------------------------
  // Content
  // ---------------------------------------------------------------------------

  Widget _buildContent() {
    return RefreshIndicator(
      color: AppColors.primaryOrange,
      onRefresh: _refresh,
      child: CustomScrollView(
        slivers: [
          // Summary banner
          SliverToBoxAdapter(child: _buildSummaryBanner()),

          // Count label
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                '${_donations.length} donation${_donations.length == 1 ? '' : 's'}',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.secondaryText,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),

          // Donation cards
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final donation = _donations[index];
                  final temple = _templeCache[donation.templeId];
                  return _DonationCard(
                    donation: donation,
                    temple: temple,
                    onTempleTap: temple != null ? () => _onTempleTap(temple) : null,
                    onDonateTap: () => _onDonateTap(temple),
                  );
                },
                childCount: _donations.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryOrange, AppColors.coralOrange],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryOrange.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Total donated
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total Donated',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatAmount(_totalDonated, 'INR'),
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Divider
          Container(
            width: 1,
            height: 48,
            color: AppColors.white.withValues(alpha: 0.3),
          ),

          const SizedBox(width: 20),

          // Completed count
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Completed',
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$_completedCount',
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(width: 20),

          // Icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.volunteer_activism_rounded,
              color: AppColors.white,
              size: 26,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Loading / Error / Empty
  // ---------------------------------------------------------------------------

  Widget _buildLoadingState() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: 5,
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: AppColors.lightGray,
        highlightColor: AppColors.white,
        child: Container(
          height: 130,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 56,
              color: AppColors.errorRed,
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.secondaryText,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
                foregroundColor: AppColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.volunteer_activism_outlined,
              size: 72,
              color: AppColors.primaryOrange.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 20),
            const Text(
              'No donations yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryText,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your donation history will appear here.\nSupport a temple today.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.secondaryText,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _onDonateTap(null),
              icon: const Icon(Icons.favorite_rounded),
              label: const Text('Donate Now'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _formatAmount(double amount, String currency) {
    switch (currency) {
      case 'INR':
        return '₹${amount.toStringAsFixed(0)}';
      case 'USD':
        return '\$${amount.toStringAsFixed(2)}';
      case 'EUR':
        return '€${amount.toStringAsFixed(2)}';
      default:
        return '$currency ${amount.toStringAsFixed(0)}';
    }
  }
}

// =============================================================================
// Donation Card
// =============================================================================

class _DonationCard extends StatelessWidget {
  final Donation donation;
  final Temple? temple;
  final VoidCallback? onTempleTap;
  final VoidCallback onDonateTap;

  const _DonationCard({
    required this.donation,
    required this.temple,
    required this.onTempleTap,
    required this.onDonateTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Top row: temple image + info ──────────────────────────────────
          InkWell(
            onTap: onTempleTap,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // Temple image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 72,
                      height: 72,
                      child: _templeImage(),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Temple name + location + amount
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Temple name
                        Text(
                          temple?.name ?? 'Temple',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryText,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),

                        const SizedBox(height: 3),

                        // Location
                        if (temple != null)
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on,
                                size: 12,
                                color: AppColors.secondaryText,
                              ),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  _locationText(temple!),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.secondaryText,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),

                        const SizedBox(height: 6),

                        // Amount + status
                        Row(
                          children: [
                            Text(
                              donation.formattedAmount,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryOrange,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _StatusBadge(status: donation.status),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Chevron (only if temple is tappable)
                  if (onTempleTap != null)
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.disabledText,
                      size: 20,
                    ),
                ],
              ),
            ),
          ),

          // ── Divider ───────────────────────────────────────────────────────
          const Divider(height: 1, color: AppColors.borderGray),

          // ── Detail row ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Column(
              children: [
                _DetailRow(
                  icon: Icons.category_outlined,
                  label: 'Purpose',
                  value: donation.purposeDisplayName,
                ),
                const SizedBox(height: 6),
                _DetailRow(
                  icon: Icons.payment_rounded,
                  label: 'Payment',
                  value: donation.paymentMethodDisplayName,
                ),
                const SizedBox(height: 6),
                _DetailRow(
                  icon: Icons.calendar_today_rounded,
                  label: 'Date',
                  value: donation.formattedDateTime,
                ),
                if (donation.transactionId != null) ...[
                  const SizedBox(height: 6),
                  _DetailRow(
                    icon: Icons.receipt_long_rounded,
                    label: 'Txn ID',
                    value: donation.transactionId!,
                    mono: true,
                  ),
                ],
                if (donation.notes != null &&
                    donation.notes!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _DetailRow(
                    icon: Icons.notes_rounded,
                    label: 'Note',
                    value: donation.notes!,
                  ),
                ],
              ],
            ),
          ),

          // ── Action row ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Row(
              children: [
                // Donate again
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onDonateTap,
                    icon: const Icon(
                      Icons.volunteer_activism_rounded,
                      size: 16,
                    ),
                    label: const Text('Donate Again'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryOrange,
                      side: const BorderSide(color: AppColors.primaryOrange),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),

                // Receipt button (only if available)
                if (donation.hasReceipt) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Receipt URL is available — open in browser or share
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Receipt: ${donation.receiptUrl}',
                            ),
                            action: SnackBarAction(
                              label: 'OK',
                              onPressed: () {},
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.download_rounded, size: 16),
                      label: const Text('Receipt'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.successGreen,
                        foregroundColor: AppColors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _templeImage() {
    final images = temple?.images ?? [];
    if (images.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: images.first,
        fit: BoxFit.cover,
        placeholder: (_, __) => Shimmer.fromColors(
          baseColor: AppColors.lightGray,
          highlightColor: AppColors.white,
          child: Container(color: AppColors.lightGray),
        ),
        errorWidget: (_, __, ___) => _placeholderImage(),
      );
    }
    return _placeholderImage();
  }

  Widget _placeholderImage() {
    const images = [
      'assets/images/deities/ganesha.png',
      'assets/images/deities/krishna.png',
      'assets/images/deities/hanuman.png',
      'assets/images/deities/durga.png',
      'assets/images/deities/temple.png',
    ];
    final idx = donation.templeId.hashCode % images.length;
    return Image.asset(
      images[idx.abs()],
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: AppColors.lightGray,
        child: const Icon(
          Icons.temple_hindu,
          size: 28,
          color: AppColors.secondaryText,
        ),
      ),
    );
  }

  String _locationText(Temple t) {
    final parts = <String>[];
    if (t.location.city?.isNotEmpty == true) parts.add(t.location.city!);
    if (t.location.state?.isNotEmpty == true) parts.add(t.location.state!);
    return parts.isEmpty ? 'Location not available' : parts.join(', ');
  }
}

// =============================================================================
// Status Badge
// =============================================================================

class _StatusBadge extends StatelessWidget {
  final DonationStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (status) {
      DonationStatus.completed => (AppColors.successGreen, Icons.check_circle_rounded),
      DonationStatus.pending   => (AppColors.warningAmber, Icons.hourglass_top_rounded),
      DonationStatus.failed    => (AppColors.errorRed,     Icons.cancel_rounded),
      DonationStatus.refunded  => (AppColors.infoPurple,   Icons.replay_rounded),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            status.name[0].toUpperCase() + status.name.substring(1),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Detail Row
// =============================================================================

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool mono;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.mono = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: AppColors.secondaryText),
        const SizedBox(width: 6),
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.secondaryText,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryText,
              fontFamily: mono ? 'monospace' : null,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
