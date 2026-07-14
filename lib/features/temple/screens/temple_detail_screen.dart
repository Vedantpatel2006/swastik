import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/themes/app_colors.dart';
import '../../../shared/models/temple.dart';
import '../../../shared/models/review.dart';
import '../../../shared/models/event.dart';
import '../../../shared/services/event_service.dart';
import '../../../features/user/screens/donation_screen.dart';
import '../../../features/user/screens/booking_screen.dart';
import '../widgets/auto_live_darshan_widget.dart';
import '../widgets/enhanced_darshan_schedule_widget.dart';
import '../widgets/review_card_widget.dart';
import '../widgets/community_photo_grid.dart';
import '../widgets/photo_upload_bottom_sheet.dart';
import '../services/review_service.dart';
import '../services/temple_service.dart';
import '../services/favorites_service.dart';
import 'write_review_screen.dart';
import 'event_registration_screen.dart';

/// Enhanced Temple detail screen showing comprehensive temple information with tabbed interface
class TempleDetailScreen extends StatefulWidget {
  final Temple temple;
  /// Optional tab index to open on. 3 = Live Darshan tab.
  final int initialTabIndex;

  const TempleDetailScreen({
    super.key,
    required this.temple,
    this.initialTabIndex = 0,
  });

  @override
  State<TempleDetailScreen> createState() => _TempleDetailScreenState();
}

class _TempleDetailScreenState extends State<TempleDetailScreen>
    with TickerProviderStateMixin {
  bool _isFavorite = false;
  bool _favoriteServiceLoaded =
      false; // true once FavoritesService has resolved
  late TabController _tabController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  final _reviewService = ReviewService();
  final _eventService = EventService();
  final _favoritesService = FavoritesService();
  String? _selectedRatingFilter;
  bool _showOnlyWithPhotos = false;
  Map<String, dynamic>? _reviewStats;
  Temple? _temple;
  StreamSubscription<Temple?>? _templeStreamSub;

  @override
  void initState() {
    super.initState();
    _temple = widget.temple;
    _isFavorite = (_temple ?? widget.temple).isFavorite;
    _tabController = TabController(
      length: 8,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 7),
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _fadeController.forward();
    _loadReviewStats();
    _initFavoritesService();
    // Subscribe to real-time temple updates
    _templeStreamSub = TempleService()
        .getTempleStream((_temple ?? widget.temple).id)
        .listen((temple) {
          if (temple != null && mounted) {
            setState(() {
              _temple = temple;
              // Only sync isFavorite from the stream if FavoritesService has
              // NOT yet resolved — once it has, the service is the source of
              // truth and we must not let the Firestore field (always false)
              // overwrite the correct value.
              if (!_favoriteServiceLoaded) {
                _isFavorite = temple.isFavorite;
              }
            });
          }
        });
  }

  Future<void> _initFavoritesService() async {
    try {
      await _favoritesService.initialize();
      // Sync initial favorite state from the service (source of truth)
      final isFav = await _favoritesService.isFavorite(
        (_temple ?? widget.temple).id,
      );
      if (mounted) {
        setState(() {
          _isFavorite = isFav;
          _favoriteServiceLoaded = true; // lock — stream must not overwrite now
        });
      }
    } catch (e) {
      debugPrint('FavoritesService init error: $e');
      if (mounted) {
        setState(() => _favoriteServiceLoaded = true);
      }
    }
  }

  Future<void> _loadReviewStats() async {
    try {
      final stats = await _reviewService.getReviewStats(
        (_temple ?? widget.temple).id,
      );
      if (mounted) {
        setState(() {
          _reviewStats = stats;
        });
      }
    } catch (e) {
      debugPrint('Error loading review stats: $e');
    }
  }

  @override
  void dispose() {
    _templeStreamSub?.cancel();
    _tabController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            _buildSliverAppBar(),
            SliverPersistentHeader(
              delegate: _SliverTabBarDelegate(
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  indicatorColor: AppColors.primaryOrange,
                  labelColor: AppColors.primaryOrange,
                  unselectedLabelColor: AppColors.secondaryText,
                  tabs: const [
                    Tab(icon: Icon(Icons.info), text: 'Overview'),
                    Tab(icon: Icon(Icons.book_online), text: 'Booking'),
                    Tab(icon: Icon(Icons.schedule), text: 'Schedule'),
                    Tab(icon: Icon(Icons.live_tv), text: 'Live Darshan'),
                    Tab(icon: Icon(Icons.volunteer_activism), text: 'Donate'),
                    Tab(icon: Icon(Icons.event), text: 'Events'),
                    Tab(icon: Icon(Icons.reviews), text: 'Reviews'),
                    Tab(icon: Icon(Icons.photo_library), text: 'Gallery'),
                  ],
                ),
              ),
              pinned: true,
            ),
          ],
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildOverviewTab(),
              _buildBookingTab(),
              _buildScheduleTab(),
              _buildLiveDarshanTab(),
              _buildDonationTab(),
              _buildEventsTab(),
              _buildReviewsTab(),
              _buildGalleryTab(),
            ],
          ),
        ),
      ),
      floatingActionButton: null,
    );
  }

  Widget _buildSliverAppBar() {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final expandedHeight = (screenHeight * 0.35).clamp(220.0, 320.0);
    return SliverAppBar(
      expandedHeight: expandedHeight,
      pinned: true,
      stretch: true,
      flexibleSpace: FlexibleSpaceBar(
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            (_temple ?? widget.temple).name,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
              shadows: [
                Shadow(
                  offset: Offset(0, 1),
                  blurRadius: 3,
                  color: Colors.black54,
                ),
              ],
            ),
          ),
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            (_temple ?? widget.temple).images.isNotEmpty
                ? PageView.builder(
                    itemCount: (_temple ?? widget.temple).images.length,
                    itemBuilder: (context, index) {
                      return Image.network(
                        (_temple ?? widget.temple).images[index],
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[300],
                            child: const Icon(
                              Icons.temple_hindu,
                              size: 64,
                              color: Colors.grey,
                            ),
                          );
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            color: Colors.grey[200],
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          );
                        },
                      );
                    },
                  )
                : Container(
                    color: Colors.grey[300],
                    child: const Icon(
                      Icons.temple_hindu,
                      size: 64,
                      color: Colors.grey,
                    ),
                  ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                  ],
                ),
              ),
            ),
            if ((_temple ?? widget.temple).images.length > 1)
              Positioned(
                bottom: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${(_temple ?? widget.temple).images.length} photos',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        IconButton(
          onPressed: _shareTemple,
          icon: const Icon(Icons.share),
          tooltip: 'Share temple',
        ),
        IconButton(
          onPressed: _toggleFavorite,
          icon: Icon(
            _isFavorite ? Icons.favorite : Icons.favorite_border,
            color: _isFavorite ? Colors.red : null,
          ),
          tooltip: _isFavorite ? 'Remove from favorites' : 'Add to favorites',
        ),
      ],
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBasicInfo(),
          const SizedBox(height: 24),
          _buildDescription(),
          const SizedBox(height: 24),
          _buildLocationInfo(),
          const SizedBox(height: 24),
          _buildContactInfo(),
          const SizedBox(height: 24),
          _buildFeatures(),
          const SizedBox(height: 24),
          _buildTimings(),
          const SizedBox(height: 24),
          _buildCommunityStats(),
          const SizedBox(height: 24),
          _buildActionButtons(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildScheduleTab() {
    final temple = _temple ?? widget.temple;
    final hasLiveDarshanSchedule =
        temple.liveDarshan?.schedule.isNotEmpty == true;
    final hasTimings = temple.timings.isNotEmpty;

    if (!hasLiveDarshanSchedule && !hasTimings) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.secondaryText.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.schedule,
                  size: 40,
                  color: AppColors.secondaryText,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'No schedule available',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryText,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Darshan schedule will be displayed here when available',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.secondaryText,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Regular temple timings
          if (hasTimings) ...[
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time,
                          color: AppColors.primaryOrange,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Temple Timings',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    ...temple.timings.entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                entry.key,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primaryOrange.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: AppColors.primaryOrange.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              ),
                              child: Text(
                                entry.value,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryOrange,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            if (hasLiveDarshanSchedule) const SizedBox(height: 16),
          ],
          // Live darshan schedule
          if (hasLiveDarshanSchedule)
            EnhancedDarshanScheduleWidget(
              schedules: temple.liveDarshan!.schedule,
              showCurrentTime: true,
              highlightCurrentSchedule: true,
              enableNotifications: true,
              templeId: temple.id,
              templeName: temple.name,
            ),
        ],
      ),
    );
  }

  Widget _buildLiveDarshanTab() {
    if ((_temple ?? widget.temple).liveDarshan?.isConfiguredByAdmin == true) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            AutoLiveDarshanWidget(temple: _temple ?? widget.temple),
            const SizedBox(height: 24),
            _buildLiveDarshanInfo(),
          ],
        ),
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.secondaryText.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.live_tv,
                size: 40,
                color: AppColors.secondaryText,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Live Darshan not available',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryText,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'This temple does not currently offer live darshan streaming',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.secondaryText,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDonationTab() {
    if ((_temple ?? widget.temple).acceptsDonations) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Make a Donation',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryText,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Support ${(_temple ?? widget.temple).name}',
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.secondaryText,
                  ),
                ),
                const SizedBox(height: 24),
                if ((_temple ?? widget.temple).donationPurposes.isNotEmpty) ...[
                  const Text(
                    'Donation Purposes',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: (_temple ?? widget.temple).donationPurposes.map((
                      purpose,
                    ) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryOrange.withValues(
                            alpha: 0.08,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.primaryOrange.withValues(
                              alpha: 0.3,
                            ),
                          ),
                        ),
                        child: Text(
                          purpose,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.primaryOrange,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                ],
                if ((_temple ?? widget.temple).minimumDonationAmount != null)
                  _buildDonationInfoRow(
                    icon: Icons.currency_rupee,
                    iconColor: AppColors.successGreen,
                    label: 'Minimum Amount',
                    value:
                        '₹${(_temple ?? widget.temple).minimumDonationAmount!.toStringAsFixed(0)}',
                  ),
                if ((_temple ?? widget.temple).suggestedDonationAmount != null)
                  _buildDonationInfoRow(
                    icon: Icons.recommend,
                    iconColor: AppColors.primaryOrange,
                    label: 'Suggested Amount',
                    value:
                        '₹${(_temple ?? widget.temple).suggestedDonationAmount!.toStringAsFixed(0)}',
                  ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              DonationScreen(temple: _temple ?? widget.temple),
                        ),
                      );
                    },
                    icon: const Icon(Icons.volunteer_activism),
                    label: const Text('Donate Now'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryOrange,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.secondaryText.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.volunteer_activism_outlined,
                size: 40,
                color: AppColors.secondaryText,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Donations not accepted',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryText,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'This temple does not currently accept online donations',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.secondaryText,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDonationInfoRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.secondaryText,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventsTab() {
    final temple = _temple ?? widget.temple;
    return StreamBuilder<List<Event>>(
      stream: _eventService.watchEventsForTemple(temple.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(64),
              child: CircularProgressIndicator(color: AppColors.infoPurple),
            ),
          );
        }

        final now = DateTime.now();
        final all = snapshot.data ?? [];
        final upcoming = all.where((e) => e.startDate.isAfter(now)).toList()
          ..sort((a, b) => a.startDate.compareTo(b.startDate));
        final past = all.where((e) => !e.startDate.isAfter(now)).toList()
          ..sort((a, b) => b.startDate.compareTo(a.startDate));

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildUpcomingEventsSection(upcoming),
              if (past.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildPastEventsSection(past),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildUpcomingEventsSection(List<Event> upcoming) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.event, color: AppColors.infoPurple),
                const SizedBox(width: 8),
                const Text(
                  'Upcoming Events',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryText,
                  ),
                ),
                const Spacer(),
                if (upcoming.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.infoPurple,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      upcoming.length.toString(),
                      style: const TextStyle(
                        color: AppColors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (upcoming.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.event_available,
                        size: 48,
                        color: AppColors.disabledText,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No upcoming events',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: AppColors.secondaryText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Check back later for festivals and special occasions',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.disabledText,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              ...upcoming.map(_buildEventCard),
          ],
        ),
      ),
    );
  }

  Widget _buildPastEventsSection(List<Event> past) {
    final shown = past.take(5).toList();
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Past Events',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryText,
              ),
            ),
            const SizedBox(height: 16),
            ...shown.map(
              (e) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: AppColors.disabledText,
                  child: const Icon(
                    Icons.event,
                    color: AppColors.white,
                    size: 18,
                  ),
                ),
                title: Text(
                  e.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primaryText,
                  ),
                ),
                subtitle: Text(
                  DateFormat('MMM dd, yyyy').format(e.startDate),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.secondaryText,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventCard(Event event) {
    final isUpcoming = event.startDate.isAfter(DateTime.now());
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderGray),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: Container(
          width: 52,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.infoPurple.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                DateFormat('MMM').format(event.startDate),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.infoPurple,
                ),
              ),
              Text(
                DateFormat('dd').format(event.startDate),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.infoPurple,
                ),
              ),
            ],
          ),
        ),
        title: Text(
          event.name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: AppColors.primaryText,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.access_time,
                  size: 12,
                  color: AppColors.secondaryText,
                ),
                const SizedBox(width: 4),
                Text(
                  '${DateFormat('h:mm a').format(event.startDate)} – '
                  '${DateFormat('h:mm a').format(event.endDate)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              event.description,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.secondaryText,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        trailing: isUpcoming
            ? ElevatedButton(
                onPressed: () => _navigateToEventRegistration(event),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.infoPurple,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  minimumSize: const Size(0, 36),
                ),
                child: const Text('Register', style: TextStyle(fontSize: 12)),
              )
            : null,
      ),
    );
  }

  void _navigateToEventRegistration(Event event) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EventRegistrationScreen(event: event),
      ),
    );
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registration successful!'),
          backgroundColor: AppColors.successGreen,
        ),
      );
    }
  }

  Widget _buildReviewsTab() {
    final totalReviews = (_reviewStats?['totalReviews'] as int?) ?? 0;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRatingsSummary(),
          const SizedBox(height: 16),
          _buildWriteReviewButton(),
          if (totalReviews > 0) ...[
            const SizedBox(height: 16),
            _buildReviewFilters(),
          ],
          const SizedBox(height: 16),
          _buildReviewsListEnhanced(),
        ],
      ),
    );
  }

  Widget _buildWriteReviewButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => WriteReviewScreen(
                templeId: (_temple ?? widget.temple).id,
                templeName: (_temple ?? widget.temple).name,
              ),
            ),
          );

          if (result == true) {
            _loadReviewStats();
          }
        },
        icon: const Icon(Icons.rate_review),
        label: const Text('Write a Review'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryOrange,
          foregroundColor: AppColors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildReviewFilters() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderGray),
      ),
      child: Row(
        children: [
          const Text(
            'Filter:',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: AppColors.primaryText,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildReviewFilterChip(
                    'All',
                    null,
                    _selectedRatingFilter == null && !_showOnlyWithPhotos,
                  ),
                  const SizedBox(width: 8),
                  _buildReviewFilterChip(
                    '5 Stars',
                    '5',
                    _selectedRatingFilter == '5',
                  ),
                  const SizedBox(width: 8),
                  _buildReviewFilterChip(
                    '4 Stars',
                    '4',
                    _selectedRatingFilter == '4',
                  ),
                  const SizedBox(width: 8),
                  _buildReviewFilterChip(
                    'With Photos',
                    'photos',
                    _showOnlyWithPhotos,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewFilterChip(String label, String? value, bool isSelected) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primaryOrange.withValues(alpha: 0.15),
      checkmarkColor: AppColors.primaryOrange,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primaryOrange : AppColors.primaryText,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        fontSize: 12,
      ),
      side: BorderSide(
        color: isSelected ? AppColors.primaryOrange : AppColors.borderGray,
      ),
      onSelected: (selected) {
        setState(() {
          if (value == null) {
            _selectedRatingFilter = null;
            _showOnlyWithPhotos = false;
          } else if (value == 'photos') {
            _showOnlyWithPhotos = selected;
            _selectedRatingFilter = null;
          } else {
            _selectedRatingFilter = selected ? value : null;
            _showOnlyWithPhotos = false;
          }
        });
      },
    );
  }

  Widget _buildReviewsListEnhanced() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    // Determine which stream to use based on filters
    Stream<List<Review>> reviewsStream;

    if (_showOnlyWithPhotos) {
      reviewsStream = _reviewService.getTempleReviewsWithPhotos(
        (_temple ?? widget.temple).id,
      );
    } else if (_selectedRatingFilter != null) {
      reviewsStream = _reviewService.getTempleReviewsByRating(
        templeId: (_temple ?? widget.temple).id,
        rating: double.parse(_selectedRatingFilter!),
      );
    } else {
      reviewsStream = _reviewService.getTempleReviews(
        (_temple ?? widget.temple).id,
      );
    }

    return StreamBuilder<List<Review>>(
      stream: reviewsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(color: AppColors.primaryOrange),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.errorRed.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.error_outline,
                      size: 32,
                      color: AppColors.errorRed,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading reviews: ${snapshot.error}',
                    style: const TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        final reviews = snapshot.data ?? [];

        if (reviews.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.primaryOrange.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.rate_review,
                      size: 32,
                      color: AppColors.primaryOrange,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No reviews yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _selectedRatingFilter != null || _showOnlyWithPhotos
                        ? 'No reviews match your filter'
                        : 'Be the first to review this temple!',
                    style: const TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reviews (${reviews.length})',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...reviews.map(
              (review) => ReviewCardWidget(
                review: review,
                currentUserId: currentUserId,
                onDeleted: () {
                  // Reload stats when review is deleted
                  _loadReviewStats();
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBasicInfo() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (_temple ?? widget.temple).name,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if ((_temple ?? widget.temple).mainDeity != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.temple_hindu,
                              size: 16,
                              color: Colors.orange,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              (_temple ?? widget.temple).mainDeity!,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.location_on, size: 18, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    (_temple ?? widget.temple).location.address ??
                        '${(_temple ?? widget.temple).location.city ?? ''}, ${(_temple ?? widget.temple).location.state ?? ''}',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if ((_temple ?? widget.temple).distanceFromUser != null)
                  _buildInfoChip(
                    icon: Icons.near_me,
                    label:
                        '${(_temple ?? widget.temple).distanceFromUser!.toStringAsFixed(1)} km away',
                    color: Colors.orange,
                  ),
                if (!(_temple ?? widget.temple).isActive)
                  _buildInfoChip(
                    icon: Icons.warning,
                    label: 'Temporarily Closed',
                    color: Colors.red,
                  ),
                if ((_temple ?? widget.temple).acceptsBookings)
                  _buildInfoChip(
                    icon: Icons.event_available,
                    label: 'Bookings Available',
                    color: Colors.green,
                  ),
                if ((_temple ?? widget.temple).acceptsDonations)
                  _buildInfoChip(
                    icon: Icons.volunteer_activism,
                    label: 'Accepts Donations',
                    color: Colors.orange,
                  ),
                if ((_temple ?? widget.temple).hasUpcomingEvents &&
                    (_temple ?? widget.temple).upcomingEventsCount > 0)
                  _buildInfoChip(
                    icon: Icons.event,
                    label:
                        '${(_temple ?? widget.temple).upcomingEventsCount} Events',
                    color: Colors.purple,
                  ),
              ],
            ),
            if ((_temple ?? widget.temple).traditions.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Traditions',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: (_temple ?? widget.temple).traditions.map((
                  tradition,
                ) {
                  return Chip(
                    label: Text(tradition),
                    backgroundColor: Colors.orange[50],
                    labelStyle: TextStyle(color: Colors.orange[700]),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
    bool isLive = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: isLive ? 8 : 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescription() {
    if ((_temple ?? widget.temple).description.isEmpty)
      return const SizedBox.shrink();

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'About',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              (_temple ?? widget.temple).description,
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationInfo() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Location',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            // Map preview
            Container(
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey[200],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    // Tappable map placeholder — opens Google Maps
                    GestureDetector(
                      onTap: _openDirections,
                      child: Container(
                        color: const Color(0xFFE8F4EA),
                        child: Stack(
                          children: [
                            CustomPaint(
                              painter: _MapGridPainter(),
                              child: const SizedBox.expand(),
                            ),
                            Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black
                                              .withValues(alpha: 0.15),
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.location_on,
                                      color: Colors.red,
                                      size: 32,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black
                                              .withValues(alpha: 0.08),
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      '${(_temple ?? widget.temple).location.latitude.toStringAsFixed(4)}, '
                                      '${(_temple ?? widget.temple).location.longitude.toStringAsFixed(4)}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black87,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Tap to open in Maps',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.orange,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: ElevatedButton.icon(
                        onPressed: _openDirections,
                        icon: const Icon(Icons.directions, size: 18),
                        label: const Text('Directions'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.location_on),
              title: const Text('Address'),
              subtitle: Text(
                (_temple ?? widget.temple).location.address ??
                    [
                      (_temple ?? widget.temple).location.city,
                      (_temple ?? widget.temple).location.state,
                      (_temple ?? widget.temple).location.postalCode,
                      (_temple ?? widget.temple).location.country,
                    ].where((e) => e != null && e.isNotEmpty).join(', '),
              ),
              trailing: const Icon(Icons.copy),
              onTap: () {
                final address =
                    (_temple ?? widget.temple).location.address ??
                    [
                      (_temple ?? widget.temple).location.city,
                      (_temple ?? widget.temple).location.state,
                      (_temple ?? widget.temple).location.postalCode,
                      (_temple ?? widget.temple).location.country,
                    ].where((e) => e != null && e.isNotEmpty).join(', ');

                Clipboard.setData(ClipboardData(text: address));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Address copied to clipboard')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.my_location),
              title: const Text('Coordinates'),
              subtitle: Text(
                '${(_temple ?? widget.temple).location.latitude.toStringAsFixed(6)}, '
                '${(_temple ?? widget.temple).location.longitude.toStringAsFixed(6)}',
              ),
              trailing: const Icon(Icons.copy),
              onTap: () {
                final coords =
                    '${(_temple ?? widget.temple).location.latitude},${(_temple ?? widget.temple).location.longitude}';
                Clipboard.setData(ClipboardData(text: coords));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Coordinates copied to clipboard'),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactInfo() {
    final hasContact =
        (_temple ?? widget.temple).contact.phone != null ||
        (_temple ?? widget.temple).contact.email != null ||
        (_temple ?? widget.temple).contact.website != null ||
        ((_temple ?? widget.temple).contact.socialMedia != null &&
            (_temple ?? widget.temple).contact.socialMedia!.isNotEmpty);

    if (!hasContact) return const SizedBox.shrink();

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Contact',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if ((_temple ?? widget.temple).contact.phone != null)
              ListTile(
                leading: const Icon(Icons.phone, color: Colors.orange),
                title: const Text('Phone'),
                subtitle: Text((_temple ?? widget.temple).contact.phone!),
                trailing: IconButton(
                  icon: const Icon(Icons.call, color: Colors.green),
                  onPressed: _makePhoneCall,
                ),
                onTap: _makePhoneCall,
              ),
            if ((_temple ?? widget.temple).contact.email != null)
              ListTile(
                leading: const Icon(Icons.email, color: Colors.orange),
                title: const Text('Email'),
                subtitle: Text((_temple ?? widget.temple).contact.email!),
                trailing: IconButton(
                  icon: const Icon(Icons.open_in_new, color: Colors.blue),
                  onPressed: _sendEmail,
                ),
                onTap: _sendEmail,
              ),
            if ((_temple ?? widget.temple).contact.website != null)
              ListTile(
                leading: const Icon(Icons.language, color: Colors.orange),
                title: const Text('Website'),
                subtitle: Text((_temple ?? widget.temple).contact.website!),
                trailing: IconButton(
                  icon: const Icon(Icons.open_in_new, color: Colors.blue),
                  onPressed: _openWebsite,
                ),
                onTap: _openWebsite,
              ),
            if ((_temple ?? widget.temple).contact.socialMedia != null &&
                (_temple ?? widget.temple).contact.socialMedia!.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'Social Media',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: (_temple ?? widget.temple)
                      .contact
                      .socialMedia!
                      .entries
                      .map((entry) {
                        return _buildSocialMediaButton(entry.key, entry.value);
                      })
                      .toList(),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSocialMediaButton(String platform, String url) {
    IconData icon;
    Color color;

    switch (platform.toLowerCase()) {
      case 'facebook':
        icon = Icons.facebook;
        color = const Color(0xFF1877F2);
        break;
      case 'instagram':
        icon = Icons.camera_alt;
        color = const Color(0xFFE4405F);
        break;
      case 'twitter':
      case 'x':
        icon = Icons.close; // X icon
        color = Colors.black;
        break;
      case 'youtube':
        icon = Icons.play_circle_filled;
        color = const Color(0xFFFF0000);
        break;
      case 'whatsapp':
        icon = Icons.chat;
        color = const Color(0xFF25D366);
        break;
      default:
        icon = Icons.link;
        color = Colors.orange;
    }

    return InkWell(
      onTap: () => _openSocialMedia(url),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              platform,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatures() {
    if ((_temple ?? widget.temple).features.isEmpty)
      return const SizedBox.shrink();

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Features',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: (_temple ?? widget.temple).features.map((feature) {
                return Chip(
                  label: Text(feature),
                  backgroundColor: Colors.orange[50],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimings() {
    if ((_temple ?? widget.temple).timings.isEmpty)
      return const SizedBox.shrink();

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Timings',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...(_temple ?? widget.temple).timings.entries.map((entry) {
              return ListTile(
                title: Text(entry.key),
                trailing: Text(
                  entry.value,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildCommunityStats() {
    final temple = _temple ?? widget.temple;
    final hasRating = temple.averageRating > 0;
    final hasReviews = temple.totalReviews > 0;
    final hasPhotos = temple.totalPhotosShared > 0;
    final hasVisits = temple.visitCount > 0;

    // Don't show the section if there's nothing meaningful to display
    if (!hasRating && !hasReviews && !hasPhotos && !hasVisits) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Community',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (hasRating)
                  Expanded(
                    child: _buildStatItem(
                      icon: Icons.star,
                      value: temple.averageRating.toStringAsFixed(1),
                      label: 'Rating',
                      color: Colors.amber,
                    ),
                  ),
                if (hasReviews)
                  Expanded(
                    child: _buildStatItem(
                      icon: Icons.reviews,
                      value: temple.totalReviews.toString(),
                      label: 'Reviews',
                      color: Colors.orange,
                    ),
                  ),
                if (hasPhotos)
                  Expanded(
                    child: _buildStatItem(
                      icon: Icons.photo_camera,
                      value: temple.totalPhotosShared.toString(),
                      label: 'Photos',
                      color: Colors.green,
                    ),
                  ),
                if (hasVisits)
                  Expanded(
                    child: _buildStatItem(
                      icon: Icons.visibility,
                      value: temple.visitCount.toString(),
                      label: 'Your Visits',
                      color: Colors.purple,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildLiveDarshanInfo() {
    final liveDarshan = (_temple ?? widget.temple).liveDarshan;
    if (liveDarshan == null) return const SizedBox.shrink();

    // Only show if there is at least one piece of info to display
    final hasStreamQuality = liveDarshan.streamQuality != null;
    final hasLastStreamDate = liveDarshan.lastStreamDate != null;
    if (!hasStreamQuality && !hasLastStreamDate) return const SizedBox.shrink();

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Live Darshan Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            // Viewer count removed — requires quota-heavy YouTube API part
            // and was previously showing mocked data.
            if (hasStreamQuality)
              ListTile(
                leading: const Icon(Icons.hd, color: Colors.green),
                title: const Text('Stream Quality'),
                trailing: Text(
                  liveDarshan.streamQuality!,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            if (hasLastStreamDate)
              ListTile(
                leading: const Icon(Icons.history, color: Colors.orange),
                title: const Text('Last Stream'),
                trailing: Text(
                  DateFormat(
                    'MMM dd, yyyy',
                  ).format(liveDarshan.lastStreamDate!),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingsSummary() {
    if (_reviewStats == null) {
      return const Card(
        elevation: 2,
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final totalReviews = _reviewStats!['totalReviews'] as int;
    final averageRating = _reviewStats!['averageRating'] as double;
    final ratingDistribution =
        _reviewStats!['ratingDistribution'] as Map<int, int>;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ratings & Reviews',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (totalReviews == 0)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Icon(Icons.star_border, size: 48, color: Colors.grey),
                      SizedBox(height: 8),
                      Text(
                        'No ratings yet',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              )
            else
              Row(
                children: [
                  Column(
                    children: [
                      Text(
                        averageRating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: List.generate(5, (index) {
                          return Icon(
                            index < averageRating.floor()
                                ? Icons.star
                                : Icons.star_border,
                            color: Colors.amber,
                            size: 20,
                          );
                        }),
                      ),
                      Text(
                        '$totalReviews ${totalReviews == 1 ? 'review' : 'reviews'}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const SizedBox(width: 32),
                  Expanded(
                    child: Column(
                      children: List.generate(5, (index) {
                        final starCount = 5 - index;
                        final count = ratingDistribution[starCount] ?? 0;
                        final percentage = totalReviews > 0
                            ? count / totalReviews
                            : 0.0;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              Text('$starCount'),
                              const SizedBox(width: 8),
                              Expanded(
                                child: LinearProgressIndicator(
                                  value: percentage,
                                  backgroundColor: Colors.grey[300],
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                        Colors.amber,
                                      ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 30,
                                child: Text(
                                  '$count',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _openDirections,
            icon: const Icon(Icons.directions),
            label: const Text('Get Directions'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _shareTemple,
                icon: const Icon(Icons.share),
                label: const Text('Share'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _toggleFavorite,
                icon: Icon(
                  _isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: _isFavorite ? Colors.red : null,
                ),
                label: Text(_isFavorite ? 'Favorited' : 'Add to Favorites'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _toggleFavorite() async {
    await HapticFeedback.lightImpact();
    final templeId = (_temple ?? widget.temple).id;
    final wasAlreadyFavorite = _isFavorite;
    // Optimistic update
    setState(() {
      _isFavorite = !_isFavorite;
    });
    try {
      if (wasAlreadyFavorite) {
        await _favoritesService.removeFromFavorites(templeId);
      } else {
        await _favoritesService.addToFavorites(templeId);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              wasAlreadyFavorite
                  ? 'Removed from favorites'
                  : 'Added to favorites',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Revert optimistic update on failure
      if (mounted) {
        setState(() {
          _isFavorite = wasAlreadyFavorite;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update favorites: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }

  Future<void> _shareTemple() async {
    try {
      await HapticFeedback.selectionClick();

      String shareText =
          '''
Check out ${(_temple ?? widget.temple).name}!

${(_temple ?? widget.temple).description}

Location: ${(_temple ?? widget.temple).location.address ?? '${(_temple ?? widget.temple).location.city}, ${(_temple ?? widget.temple).location.state}'}

${(_temple ?? widget.temple).traditions.isNotEmpty ? 'Traditions: ${(_temple ?? widget.temple).traditions.join(', ')}' : ''}

${(_temple ?? widget.temple).contact.website != null ? 'Website: ${(_temple ?? widget.temple).contact.website}' : ''}

Shared via Temple App''';

      await Share.share(
        shareText.trim(),
        subject: 'Check out ${(_temple ?? widget.temple).name}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }

  Future<void> _openDirections() async {
    try {
      final lat = (_temple ?? widget.temple).location.latitude;
      final lng = (_temple ?? widget.temple).location.longitude;
      final url =
          'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng';

      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch maps';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open directions: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }

  Future<void> _makePhoneCall() async {
    if ((_temple ?? widget.temple).contact.phone == null) return;

    try {
      final url = 'tel:${(_temple ?? widget.temple).contact.phone}';
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
      } else {
        throw 'Could not make phone call';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to make call: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }

  Future<void> _sendEmail() async {
    if ((_temple ?? widget.temple).contact.email == null) return;

    try {
      final url = 'mailto:${(_temple ?? widget.temple).contact.email}';
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
      } else {
        throw 'Could not send email';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send email: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }

  Future<void> _openWebsite() async {
    if ((_temple ?? widget.temple).contact.website == null) return;

    try {
      final url = (_temple ?? widget.temple).contact.website!;
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch website';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open website: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }

  Future<void> _openSocialMedia(String url) async {
    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch social media';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open social media: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }

  // New Booking Tab
  Widget _buildBookingTab() {
    if (!(_temple ?? widget.temple).acceptsBookings) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.book_online_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Bookings not available',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'This temple does not currently accept online bookings',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Book Your Visit',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Available Booking Types',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  ...(_temple ?? widget.temple).availableBookingTypes.map((
                    type,
                  ) {
                    return _buildBookingTypeCard(type);
                  }),
                  if ((_temple ?? widget.temple).bookingSettings != null) ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),
                    const Text(
                      'Booking Information',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...(_temple ?? widget.temple).bookingSettings!.entries.map((
                      entry,
                    ) {
                      // Map raw Firestore keys to human-readable labels
                      final labelMap = {
                        'slotsPerDay': 'Slots Per Day',
                        'slots_per_day': 'Slots Per Day',
                        'advanceBookingDays': 'Advance Booking Days',
                        'advance_booking_days': 'Advance Booking Days',
                        'maxGroupSize': 'Max Group Size',
                        'max_group_size': 'Max Group Size',
                        'minGroupSize': 'Min Group Size',
                        'min_group_size': 'Min Group Size',
                        'bookingFee': 'Booking Fee',
                        'booking_fee': 'Booking Fee',
                        'cancellationPolicy': 'Cancellation Policy',
                        'cancellation_policy': 'Cancellation Policy',
                        'confirmationRequired': 'Confirmation Required',
                        'confirmation_required': 'Confirmation Required',
                        'openingTime': 'Opening Time',
                        'opening_time': 'Opening Time',
                        'closingTime': 'Closing Time',
                        'closing_time': 'Closing Time',
                      };
                      final label =
                          labelMap[entry.key] ??
                          entry.key
                              .replaceAllMapped(
                                RegExp(r'([a-z])([A-Z])'),
                                (m) => '${m[1]} ${m[2]}',
                              )
                              .replaceAll('_', ' ')
                              .split(' ')
                              .map(
                                (w) => w.isEmpty
                                    ? ''
                                    : '${w[0].toUpperCase()}${w.substring(1)}',
                              )
                              .join(' ');
                      return ListTile(
                        leading: const Icon(
                          Icons.info_outline,
                          color: Colors.orange,
                        ),
                        title: Text(label),
                        subtitle: Text(entry.value.toString()),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingTypeCard(String type) {
    IconData icon;
    String title;
    String description;
    Color color;

    switch (type.toLowerCase()) {
      case 'visit':
        icon = Icons.temple_hindu;
        title = 'Temple Visit';
        description = 'Book a regular darshan visit';
        color = Colors.orange;
        break;
      case 'event':
        icon = Icons.event;
        title = 'Special Event';
        description = 'Book for festivals and special occasions';
        color = Colors.purple;
        break;
      case 'special_service':
      case 'puja':
        icon = Icons.auto_awesome;
        title = 'Special Service/Puja';
        description = 'Book special pujas and services';
        color = Colors.orange;
        break;
      default:
        icon = Icons.book_online;
        title = type;
        description = 'Book this service';
        color = Colors.green;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(description),
        trailing: ElevatedButton(
          onPressed: () => _showBookingForm(type),
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
          ),
          child: const Text('Book'),
        ),
      ),
    );
  }

  void _showBookingForm(String bookingType) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookingScreen(
          templeId: (_temple ?? widget.temple).id,
          initialBookingType: bookingType,
        ),
      ),
    );
  }

  // New Gallery Tab
  Widget _buildGalleryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Temple Photos',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _uploadPhoto,
                        icon: const Icon(Icons.add_a_photo),
                        label: const Text('Upload'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if ((_temple ?? widget.temple).images.isNotEmpty)
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                      itemCount: (_temple ?? widget.temple).images.length,
                      itemBuilder: (context, index) {
                        return GestureDetector(
                          onTap: () => _viewFullImage(index),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              (_temple ?? widget.temple).images[index],
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.broken_image),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    )
                  else
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Column(
                          children: [
                            Icon(
                              Icons.photo_library,
                              size: 64,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No photos available',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Community Photos',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${(_temple ?? widget.temple).totalPhotosShared} photos',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  CommunityPhotoGrid(templeId: (_temple ?? widget.temple).id),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _uploadPhoto() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PhotoUploadBottomSheet(
        templeId: (_temple ?? widget.temple).id,
        templeName: (_temple ?? widget.temple).name,
      ),
    );
  }

  void _viewFullImage(int index) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            title: Text(
              '${index + 1} / ${(_temple ?? widget.temple).images.length}',
            ),
          ),
          body: PageView.builder(
            controller: PageController(initialPage: index),
            itemCount: (_temple ?? widget.temple).images.length,
            itemBuilder: (context, i) {
              return InteractiveViewer(
                child: Center(
                  child: Image.network(
                    (_temple ?? widget.temple).images[i],
                    fit: BoxFit.contain,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// Custom SliverPersistentHeaderDelegate for TabBar
class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverTabBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;

  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return false;
  }
}

/// Paints a subtle grid that evokes a map background.
class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFCCE5CC)
      ..strokeWidth = 1;

    const spacing = 28.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
