import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/themes/app_colors.dart';
import '../../../shared/models/user_stats.dart';
import '../../../shared/models/donation.dart';
import '../../../shared/models/booking.dart';
import '../../../features/temple/services/favorites_service.dart';
import '../services/donation_service.dart';
import '../services/booking_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../shared/widgets/error/index.dart';
import '../../../shared/widgets/offline_indicator.dart';
import '../../../shared/widgets/animated_button.dart';
import 'edit_profile_screen.dart';
import 'booking_detail_screen.dart';

/// Screen for user account management and spiritual journey overview
class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final FavoritesService _favoritesService = FavoritesService();
  final DonationService _donationService = DonationService();
  final BookingService _bookingService = BookingService();

  // Data
  UserStats? _userStats;
  List<VisitHistoryItem> _recentVisits = [];
  List<Donation> _recentDonations = [];
  List<Booking> _recentBookings = [];

  // State
  bool _isLoading = true;
  String? _error;
  bool _isSigningOut = false;

  // Streams
  StreamSubscription<UserStats>? _statsSubscription;
  StreamSubscription<List<VisitHistoryItem>>? _visitsSubscription;
  StreamSubscription<List<Donation>>? _donationsSubscription;
  StreamSubscription<List<Booking>>? _bookingsSubscription;
  StreamSubscription<int>? _notificationSubscription;

  // Notification badge count
  int _unreadNotifications = 0;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      await _favoritesService.initialize();
      await _loadData();
      _setupStreams();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to initialize profile: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  void _setupStreams() {
    if (!mounted) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.currentUser;
    if (currentUser == null) return;

    _statsSubscription = _favoritesService.watchUserStats().listen(
      (stats) {
        if (mounted) setState(() => _userStats = stats);
      },
      onError: (e) {
        if (mounted) setState(() => _error = 'Error loading stats: $e');
      },
    );

    _visitsSubscription = _favoritesService.watchVisitHistory().listen((
      visits,
    ) {
      if (mounted) setState(() => _recentVisits = visits.take(5).toList());
    }, onError: (e) => debugPrint('Error loading visits: $e'),
    );

    _donationsSubscription = _donationService
        .watchUserDonations(currentUser.uid)
        .listen((donations) {
          if (mounted)
            setState(() => _recentDonations = donations.take(3).toList());
        }, onError: (e) => debugPrint('Error loading donations: $e'));

    _bookingsSubscription = _bookingService
        .watchUserBookings(currentUser.uid)
        .listen((bookings) {
          if (mounted)
            setState(() => _recentBookings = bookings.take(3).toList());
        }, onError: (e) => debugPrint('Error loading bookings: $e'));

    _notificationSubscription = _favoritesService
        .watchUnreadNotifications(currentUser.uid)
        .listen((count) {
          if (mounted) setState(() => _unreadNotifications = count);
        }, onError: (e) => debugPrint('Error loading notifications: $e'));
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUser = authProvider.currentUser;

      final results = await Future.wait([
        _favoritesService.getUserStats(),
        _favoritesService.getVisitHistory(),
        if (currentUser != null)
          _donationService.getUserDonations(currentUser.uid)
        else
          Future.value(<Donation>[]),
        if (currentUser != null)
          _bookingService.getUserBookings(currentUser.uid)
        else
          Future.value(<Booking>[]),
      ]);

      if (mounted) {
        setState(() {
          _userStats = results[0] as UserStats;
          _recentVisits = (results[1] as List<VisitHistoryItem>)
              .take(5)
              .toList();
          _recentDonations = (results[2] as List<Donation>).take(3).toList();
          _recentBookings = (results[3] as List<Booking>).take(3).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _error = 'Failed to load profile data: ${e.toString()}';
          _isLoading = false;
        });
    }
  }

  Future<void> _onRefresh() async {
    await _loadData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.refresh, color: AppColors.white, size: 16),
              SizedBox(width: 8),
              Text('Profile updated'),
            ],
          ),
          backgroundColor: AppColors.successGreen,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _signOut() async {
    final confirmed = await _showSignOutConfirmationDialog();
    if (!confirmed) return;
    try {
      setState(() => _isSigningOut = true);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.signOut();
      if (mounted)
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/auth_intro', (route) => false);
    } catch (e) {
      if (mounted) {
        setState(() => _isSigningOut = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to sign out: ${e.toString()}'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }

  Future<bool> _showSignOutConfirmationDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Sign Out'),
            content: const Text(
              'Are you sure you want to sign out? Your data will be saved locally.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.errorRed,
                  foregroundColor: AppColors.white,
                ),
                child: const Text('Sign Out'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _navigateToEditProfile() async {
    final result = await Navigator.of(
      context,
      rootNavigator: true,
    ).push(
      MaterialPageRoute(builder: (context) => const EditProfileScreen()),
    );
    if (result == true && mounted) await _loadData();
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;
    if (difference == 0) return 'Today';
    if (difference == 1) return 'Yesterday';
    if (difference < 7) return '$difference days ago';
    if (difference < 30) {
      final weeks = difference ~/ 7;
      return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
    }
    final months = difference ~/ 30;
    return '$months ${months == 1 ? 'month' : 'months'} ago';
  }

  @override
  void dispose() {
    _statsSubscription?.cancel();
    _visitsSubscription?.cancel();
    _donationsSubscription?.cancel();
    _bookingsSubscription?.cancel();
    _notificationSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).currentUser;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Material(
        color: AppColors.primaryOrange,
        child: Column(
          children: [
            const OfflineIndicator(),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primaryOrange,
                        ),
                      ),
                    )
                  : _error != null
                  ? Center(
                      child: AnimatedErrorDisplay(
                        title: 'Profile Error',
                        message: _error!,
                        type: ErrorDisplayType.network,
                        onRetry: _loadData,
                        onDismiss: () => setState(() => _error = null),
                        showDismissButton: true,
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _onRefresh,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: ColoredBox(
                          color: AppColors.scaffoldBackground,
                          child: Column(
                            children: [
                              _buildProfileHeader(user),
                              if (_userStats != null) ...[
                                const SizedBox(height: 24),
                                _buildSpiritualJourneySection(),
                              ],
                              if (_recentVisits.isNotEmpty) ...[
                                const SizedBox(height: 24),
                                _buildRecentActivitySection(),
                              ],
                              if (_recentDonations.isNotEmpty) ...[
                                const SizedBox(height: 24),
                                _buildRecentDonationsSection(),
                              ],
                              if (_recentBookings.isNotEmpty) ...[
                                const SizedBox(height: 24),
                                _buildRecentBookingsSection(),
                              ],
                              const SizedBox(height: 24),
                              _buildAccountSettingsSection(),
                              const SizedBox(height: 16),
                              _buildSignOutSection(),
                              const SizedBox(height: 32),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Profile Header ───────────────────────────────────────────────────────

  Widget _buildProfileHeader(user) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.primaryOrange, AppColors.coralOrange],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          children: [
            // Notification badge (only when there are unread notifications)
            if (_unreadNotifications > 0) ...[
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () => Navigator.of(
                    context,
                    rootNavigator: true,
                  ).pushNamed('/notifications'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.errorRed,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$_unreadNotifications',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Avatar
            if (user?.photoURL != null && user!.photoURL!.isNotEmpty)
              CircleAvatar(
                radius: 40,
                backgroundImage: NetworkImage(user!.photoURL!),
                onBackgroundImageError: (_, __) {},
                child: Container(),
              )
            else
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: const Icon(Icons.person, size: 40, color: Colors.white),
              ),
            const SizedBox(height: 16),

            // Name
            Text(
              (user?.displayName?.isNotEmpty ?? false)
                  ? user!.displayName!
                  : user?.email ?? 'User',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),

            // Edit Profile button
            OutlinedButton.icon(
              onPressed: _navigateToEditProfile,
              icon: const Icon(Icons.edit, size: 16, color: Colors.white),
              label: const Text(
                'Edit Profile',
                style: TextStyle(color: Colors.white),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white, width: 1.5),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Member since
            if (user?.metadata.creationTime != null)
              Text(
                'Member since ${_formatDate(user!.metadata.creationTime!)}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 14,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─── Spiritual Journey ────────────────────────────────────────────────────

  Widget _buildSpiritualJourneySection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Spiritual Journey',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryText,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.favorite,
                  title: 'Favorites',
                  value: _userStats!.totalFavorites.toString(),
                  color: AppColors.errorRed,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.event,
                  title: 'Events',
                  value: _userStats!.eventsAttended.toString(),
                  color: AppColors.infoPurple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.star,
                  title: 'Reviews',
                  value: _userStats!.reviewsWritten.toString(),
                  color: AppColors.errorRed,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.currency_rupee,
                  title: 'Total Donated',
                  value:
                      '₹${_userStats!.totalDonationAmount.toStringAsFixed(0)}',
                  color: AppColors.successGreen,
                ),
              ),
            ],
          ),
          if (_userStats!.hasActivity) ...[
            const SizedBox(height: 16),
            _buildJourneyMilestones(),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return UserStatCard(icon: icon, title: title, value: value, color: color);
  }

  Widget _buildJourneyMilestones() {
    final milestones = <Map<String, dynamic>>[];

    if (_userStats!.totalVisits >= 1)
      milestones.add({
        'icon': Icons.temple_hindu,
        'title': 'First Temple Visit',
        'description': 'Started your spiritual journey',
        'achieved': true,
      });
    if (_userStats!.totalFavorites >= 5)
      milestones.add({
        'icon': Icons.favorite,
        'title': 'Temple Explorer',
        'description':
            'Added ${_userStats!.totalFavorites} temples to favorites',
        'achieved': true,
      });
    if (_userStats!.totalDonations >= 5)
      milestones.add({
        'icon': Icons.volunteer_activism,
        'title': 'Generous Devotee',
        'description': 'Made ${_userStats!.totalDonations} donations',
        'achieved': true,
      });
    if (_userStats!.reviewsWritten >= 3)
      milestones.add({
        'icon': Icons.star,
        'title': 'Community Contributor',
        'description': 'Written ${_userStats!.reviewsWritten} temple reviews',
        'achieved': true,
      });

    if (_userStats!.totalVisits < 25) {
      milestones.add({
        'icon': Icons.star,
        'title': 'Dedicated Devotee',
        'description': 'Visit 25 temples (${_userStats!.totalVisits}/25)',
        'achieved': false,
        'progress': _userStats!.totalVisits / 25,
      });
    }

    if (milestones.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Journey Milestones',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryText,
            ),
          ),
          const SizedBox(height: 16),
          ...milestones.map((m) => _buildMilestoneItem(m)),
        ],
      ),
    );
  }

  Widget _buildMilestoneItem(Map<String, dynamic> milestone) {
    final isAchieved = milestone['achieved'] as bool;
    final progress = milestone['progress'] as double?;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isAchieved
                  ? AppColors.successGreen.withValues(alpha: 0.1)
                  : AppColors.borderGray.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              milestone['icon'] as IconData,
              color: isAchieved
                  ? AppColors.successGreen
                  : AppColors.disabledText,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  milestone['title'] as String,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isAchieved
                        ? AppColors.primaryText
                        : AppColors.secondaryText,
                  ),
                ),
                Text(
                  milestone['description'] as String,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.secondaryText,
                  ),
                ),
                if (progress != null) ...[
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: AppColors.borderGray,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.primaryOrange,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (isAchieved)
            const Icon(
              Icons.check_circle,
              color: AppColors.successGreen,
              size: 20,
            ),
        ],
      ),
    );
  }

  // ─── Recent Activity ──────────────────────────────────────────────────────

  Widget _buildRecentActivitySection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Activity',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryText,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                for (final (index, visit) in _recentVisits.indexed)
                  _buildRecentActivityItem(
                    visit,
                    index == _recentVisits.length - 1,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivityItem(VisitHistoryItem visit, bool isLast) {
    return InkWell(
      onTap: () => Navigator.of(
        context,
        rootNavigator: true,
      ).pushNamed('/temple_search'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(
                  bottom: BorderSide(
                    color: AppColors.borderGray.withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primaryOrange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.temple_hindu,
                color: AppColors.primaryOrange,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    visit.templeName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(visit.visitDate),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppColors.disabledText,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Recent Donations ─────────────────────────────────────────────────────

  Widget _buildRecentDonationsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Donations',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryText,
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(
                  context,
                  rootNavigator: true,
                ).pushNamed('/donations'),
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: _recentDonations
                  .asMap()
                  .entries
                  .map(
                    (e) => _buildDonationItem(
                      e.value,
                      e.key == _recentDonations.length - 1,
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDonationItem(Donation donation, bool isLast) {
    final statusColor = _getDonationStatusColor(donation.status);
    return InkWell(
      onTap: () =>
          Navigator.of(context, rootNavigator: true).pushNamed('/donations'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(
                  bottom: BorderSide(
                    color: AppColors.borderGray.withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.volunteer_activism,
                color: statusColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    donation.formattedAmount,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${donation.purposeDisplayName} • ${donation.formattedDate}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                donation.statusDisplayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getDonationStatusColor(DonationStatus status) {
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

  // ─── Recent Bookings ──────────────────────────────────────────────────────

  Widget _buildRecentBookingsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Bookings',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryText,
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(
                  context,
                  rootNavigator: true,
                ).pushNamed('/bookings'),
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: _recentBookings
                  .asMap()
                  .entries
                  .map(
                    (e) => _buildBookingItem(
                      e.value,
                      e.key == _recentBookings.length - 1,
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingItem(Booking booking, bool isLast) {
    final statusColor = _getBookingStatusColor(booking.status);
    return InkWell(
      onTap: () => Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          builder: (_) => BookingDetailScreen(booking: booking),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(
                  bottom: BorderSide(
                    color: AppColors.borderGray.withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getBookingStatusIcon(booking.status),
                color: statusColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    booking.bookingTypeDisplayName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${booking.formattedDateTime} • ${booking.numberOfPeople} ${booking.numberOfPeople == 1 ? 'person' : 'people'}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                booking.statusDisplayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getBookingStatusColor(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending:
        return AppColors.primaryOrange;
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

  IconData _getBookingStatusIcon(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending:
        return Icons.schedule;
      case BookingStatus.confirmed:
        return Icons.check_circle;
      case BookingStatus.cancelled:
        return Icons.cancel;
      case BookingStatus.completed:
        return Icons.done_all;
      case BookingStatus.noShow:
        return Icons.person_off;
    }
  }

  // ─── Account Settings ─────────────────────────────────────────────────────

  Widget _buildAccountSettingsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Account Settings',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryText,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildSettingsTile(
                  icon: Icons.favorite_border,
                  title: 'Favourite Temples',
                  subtitle: 'View and manage your saved temples',
                  color: AppColors.errorRed,
                  onTap: () => Navigator.of(
                    context,
                    rootNavigator: true,
                  ).pushNamed('/favorites'),
                ),
                _buildDivider(),
                _buildSettingsTile(
                  icon: Icons.notifications_outlined,
                  title: 'Notification Settings',
                  subtitle: 'Manage alerts, quiet hours and preferences',
                  color: AppColors.primaryOrange,
                  onTap: () => Navigator.of(
                    context,
                    rootNavigator: true,
                  ).pushNamed('/notification_preferences'),
                  trailing: _unreadNotifications > 0
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.errorRed,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$_unreadNotifications',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      : null,
                ),
                _buildDivider(),
                _buildSettingsTile(
                  icon: Icons.tune_outlined,
                  title: 'App Preferences',
                  subtitle: 'Language, theme and display settings',
                  color: AppColors.infoPurple,
                  onTap: () => Navigator.of(
                    context,
                    rootNavigator: true,
                  ).pushNamed('/preferences'),
                ),
                _buildDivider(),
                _buildSettingsTile(
                  icon: Icons.history,
                  title: 'My Bookings',
                  subtitle: 'View all your darshan and puja bookings',
                  color: AppColors.successGreen,
                  onTap: () => Navigator.of(
                    context,
                    rootNavigator: true,
                  ).pushNamed('/my_bookings'),
                ),
                _buildDivider(),
                _buildSettingsTile(
                  icon: Icons.volunteer_activism_outlined,
                  title: 'Donation History',
                  subtitle: 'Track your contributions to temples',
                  color: AppColors.warningAmber,
                  onTap: () => Navigator.of(
                    context,
                    rootNavigator: true,
                  ).pushNamed('/recent_donations'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.primaryText,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: AppColors.secondaryText),
      ),
      trailing:
          trailing ??
          const Icon(
            Icons.chevron_right,
            color: AppColors.disabledText,
            size: 20,
          ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      indent: 60,
      endIndent: 16,
      color: AppColors.borderGray.withValues(alpha: 0.5),
    );
  }

  // ─── Sign Out ─────────────────────────────────────────────────────────────

  Widget _buildSignOutSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: AnimatedButton(
        onPressed: _isSigningOut ? null : _signOut,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.errorRed,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppColors.errorRed.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: _isSigningOut
              ? const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Signing Out...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.logout, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Sign Out',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ─── UserStatCard ─────────────────────────────────────────────────────────────

class UserStatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const UserStatCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$title: $value',
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.secondaryText,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
