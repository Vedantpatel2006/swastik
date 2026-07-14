import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../../shared/models/temple.dart';
import '../../../shared/models/temple_filters.dart';
import '../services/user_temple_service.dart';
import '../services/favorites_service.dart';
import '../screens/temple_detail_screen.dart';
import '../screens/temple_search_screen.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/app_spacing.dart';
import '../../../core/themes/app_radius.dart';
import '../../user/services/location_select_service.dart';
import '../../user/widgets/location_selector_bottom_sheet.dart';
import '../../../shared/services/service_container.dart' show services;
import '../../../shared/services/navigation/main_navigation_service.dart';
import '../widgets/home_sections/live_now_section.dart';
import '../widgets/home_sections/favourite_temples_section.dart';
import '../widgets/home_sections/nearby_temples_section.dart';
import '../widgets/home_sections/recent_visit_section.dart';
import '../widgets/home_sections/all_temples_section.dart';
import '../../../shared/widgets/app_3d_icon.dart';

/// Home Screen V2 - Based on Figma food delivery design
/// Adapted for Swastik temple app with grid layout
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final UserTempleService _templeService = UserTempleService();
  final FavoritesService _favoritesService = FavoritesService();
  final LocationSelectService _locationSelectService = LocationSelectService();
  final ScrollController _scrollController = ScrollController();
  late PageController _bannerPageController;

  List<Temple> _allTemples = [];
  bool _isLoading = true;
  String? _error;
  String _userLocation = 'Select Location';
  Timer? _bannerAutoScrollTimer;
  Timer? _statusRefreshTimer;
  StreamSubscription<String>? _locationSubscription;
  int _currentBannerPage = 0;
  int _silentRefreshCount = 0;
  bool _isAppInBackground = false;

  final List<Map<String, Object>> _banners = [
    {
      'title': 'Book Your Darshan',
      'subtitle': 'We are here with the best\ndarshan experience.',
      'buttonText': 'Book Now',
      'gradient': <Color>[AppColors.liveRed, AppColors.lightRed],
      'image': 'assets/icons/icons8-diya-64.png',
    },
    {
      'title': 'Live Darshan Available',
      'subtitle': 'Watch live aarti from\nyour favorite temples.',
      'buttonText': 'Watch Now',
      'gradient': <Color>[AppColors.lightOrange, AppColors.primaryOrange],
      'image': 'assets/icons/Bookpuja.png',
    },
    {
      'title': 'Donate to Temples',
      'subtitle': 'Support your local temples\nand earn blessings.',
      'buttonText': 'Donate',
      'gradient': <Color>[AppColors.successGreen, AppColors.darkGreen],
      'image': 'assets/icons/Bookpuja.png',
    },
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bannerPageController = PageController(viewportFraction: 1.0);
    _locationSelectService.initialize().then((_) {
      _initializeServices();
      _loadUserLocation();
    });
    _setupLocationListener();
    _startBannerAutoScroll();
    _startStatusRefreshTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _isAppInBackground = true;
      _bannerAutoScrollTimer?.cancel();
    } else if (state == AppLifecycleState.resumed) {
      _isAppInBackground = false;
      _startBannerAutoScroll();
    }
  }

  Future<void> _initializeServices() async {
    try {
      await _templeService.initialize();
      await _favoritesService.initialize();
      await _loadTemples();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to initialize. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadTemples() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Get user's location for distance calculation
      Location? userLocation;
      try {
        final locationService = _locationSelectService;
        // Service is already initialized in initState — no need to call again

        // First, try to get the current location object (works for both GPS and manual)
        userLocation = locationService.getCurrentLocationObject();

        if (userLocation != null) {
          debugPrint(
            'HomeScreen: Using existing location - '
            'Lat: ${userLocation.latitude}, Lng: ${userLocation.longitude}',
          );
        } else {
          // No location available - silently continue without showing dialogs
          // The user can manually select location via the location selector
          debugPrint(
            'HomeScreen: No location available, continuing without location-based features',
          );
        }
      } catch (e) {
        debugPrint('Could not get user location for distance calculation: $e');
      }

      // Load temples with location filter if available
      final filters = userLocation != null
          ? TempleFilters(userLocation: userLocation)
          : null;

      final temples = await _templeService.searchTemples('', filters: filters);

      // Cross-reference with FavoritesService so isFavorite is correctly set
      // on every temple (UserTempleService never populates this field itself).
      List<Temple> markedTemples = temples;
      try {
        final favoriteIds = await _favoritesService.getFavoriteTempleIds();
        if (favoriteIds.isNotEmpty) {
          markedTemples = temples
              .map((t) => t.copyWith(isFavorite: favoriteIds.contains(t.id)))
              .toList();
        }
      } catch (e) {
        debugPrint('HomeScreen: Could not load favorite IDs - $e');
      }

      // Debug: Check if temples have distance
      final templesWithDistance = markedTemples
          .where((t) => t.distanceFromUser != null)
          .length;
      debugPrint(
        'Loaded ${markedTemples.length} temples, ${templesWithDistance} have distance calculated',
      );
      debugPrint(
        'User location: ${userLocation != null ? "${userLocation.latitude}, ${userLocation.longitude}" : "null"}',
      );

      if (mounted) {
        setState(() {
          _allTemples = markedTemples;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load temples. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadUserLocation() async {
    try {
      // Service is already initialized in initState — just read the saved value
      final savedLocation = await _locationSelectService.getSavedLocation();
      if (mounted) {
        setState(() {
          _userLocation = savedLocation;
        });
      }
    } catch (e) {
      debugPrint('Error loading location: $e');
    }
  }

  void _setupLocationListener() {
    _locationSubscription = _locationSelectService.locationStream.listen((
      location,
    ) {
      if (mounted) {
        setState(() {
          _userLocation = location;
        });
        // Reload temples with new location for distance calculation
        _loadTemples();
      }
    });
  }

  void _showLocationSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (context, scrollController) => LocationSelectorBottomSheet(
          currentLocation: _userLocation,
          onLocationSelected: (location) {
            setState(() {
              _userLocation = location;
            });
          },
        ),
      ),
    );
  }

  void _onTempleCardTap(Temple temple) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TempleDetailScreen(temple: temple),
      ),
    );
  }

  /// Tapping a live temple card goes straight to the Live Darshan tab (index 3).
  void _onLiveTempleCardTap(Temple temple) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TempleDetailScreen(
          temple: temple,
          initialTabIndex: temple.liveDarshan?.isCurrentlyLive == true ? 3 : 0,
        ),
      ),
    );
  }

  void _startBannerAutoScroll() {
    _bannerAutoScrollTimer?.cancel();
    _bannerAutoScrollTimer = Timer.periodic(const Duration(seconds: 4), (
      timer,
    ) {
      if (!mounted || _isAppInBackground) return;
      if (_bannerPageController.hasClients) {
        _currentBannerPage = (_currentBannerPage + 1) % _banners.length;
        _bannerPageController.animateToPage(
          _currentBannerPage,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  /// Ticks every minute.
  /// - Every tick  → setState() so open/close badges re-read DateTime.now()
  /// - Every 2nd tick → silently re-fetch temples from Firestore so
  ///   isCurrentlyLive reflects any admin-side changes.
  void _startStatusRefreshTimer() {
    _statusRefreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      _silentRefreshCount++;
      // Always rebuild so TempleStatusService re-runs with the current time
      setState(() {});
      // Every 2 minutes fetch fresh data (captures isCurrentlyLive changes)
      if (_silentRefreshCount % 2 == 0) {
        _silentRefreshTemples();
      }
    });
  }

  /// Fetches fresh temple data without showing a loading spinner.
  Future<void> _silentRefreshTemples() async {
    try {
      final userLocation = _locationSelectService.getCurrentLocationObject();
      final filters = userLocation != null
          ? TempleFilters(userLocation: userLocation)
          : null;

      final freshTemples = await _templeService.searchTemples(
        '',
        filters: filters,
      );

      if (!mounted || freshTemples.isEmpty) return;

      // Re-apply isFavorite flags so the Favourites section doesn't go blank.
      List<Temple> markedTemples = freshTemples;
      try {
        final favoriteIds = await _favoritesService.getFavoriteTempleIds();
        if (favoriteIds.isNotEmpty) {
          markedTemples = freshTemples
              .map((t) => t.copyWith(isFavorite: favoriteIds.contains(t.id)))
              .toList();
        }
      } catch (e) {
        debugPrint('Silent refresh: could not load favorite IDs - $e');
      }

      setState(() {
        _allTemples = markedTemples;
      });
    } catch (e) {
      debugPrint('Silent temple refresh failed: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    _bannerPageController.dispose();
    _bannerAutoScrollTimer?.cancel();
    _statusRefreshTimer?.cancel();
    _locationSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.primaryOrange,
        elevation: 0,
        toolbarHeight: AppSpacing.huge + AppSpacing.lg,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            // Profile Avatar - Left
            Semantics(
              label: 'Profile',
              button: true,
              child: GestureDetector(
                onTap: () {
                  final mainNavService = MainNavigationService.instance;
                  mainNavService.switchToTab(4);
                },
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.white.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                  ),
                  child: ClipOval(
                    child: user?.photoURL != null
                        ? CachedNetworkImage(
                            imageUrl: user!.photoURL!,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Shimmer.fromColors(
                              baseColor: AppColors.lightGray,
                              highlightColor: AppColors.white,
                              child: Container(color: AppColors.lightGray),
                            ),
                            errorWidget: (context, error, stackTrace) {
                              return const Icon(
                                Icons.person,
                                size: 24,
                                color: AppColors.white,
                              );
                            },
                          )
                        : const Icon(
                            Icons.person,
                            size: 24,
                            color: AppColors.white,
                          ),
                  ),
                ),
              ),
            ),

            // Location - Center (Expanded to take remaining space)
            Expanded(
              child: Semantics(
                label:
                    'Current location: $_userLocation. Tap to change location',
                button: true,
                child: GestureDetector(
                  onTap: _showLocationSelector,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: AppColors.white,
                        size: 18,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Flexible(
                        child: Text(
                          _userLocation,
                          style: const TextStyle(
                            fontSize: 15,
                            color: AppColors.white,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.keyboard_arrow_down,
                        size: 18,
                        color: AppColors.white,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Notification - Right
            Semantics(
              label: 'Notifications',
              button: true,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.white.withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          Navigator.of(
                            context,
                            rootNavigator: true,
                          ).pushNamed('/notifications');
                        },
                        icon: const Icon(
                          Icons.notifications_outlined,
                          size: 24,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: -2,
                    top: -2,
                    child: StreamBuilder<int>(
                      stream: user != null
                          ? services.notificationService.getUnreadCount(
                              user.uid,
                            )
                          : Stream.value(0),
                      builder: (context, snapshot) {
                        final unreadCount = snapshot.data ?? 0;
                        if (unreadCount == 0) return const SizedBox.shrink();

                        return Container(
                          padding: AppSpacing.allXs,
                          decoration: const BoxDecoration(
                            color: AppColors.errorRed,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            unreadCount > 9 ? '9+' : '$unreadCount',
                            style: const TextStyle(
                              color: AppColors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _error != null
          ? _buildErrorState()
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_allTemples.isEmpty) {
      return _buildEmptyState();
    }

    final hasRecentVisit = _allTemples.any((t) => t.lastVisited != null);

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 8)),

        // Search Bar
        SliverToBoxAdapter(child: _buildSearchBar()),

        const SliverToBoxAdapter(child: SizedBox(height: 12)),

        // Promotional Banner with Indicators
        SliverToBoxAdapter(
          child: Column(
            children: [
              _buildPromotionalBanner(),
              const SizedBox(height: 8),
              _buildBannerIndicators(),
            ],
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 16)),

        // Quick Actions Strip
        SliverToBoxAdapter(child: _buildQuickActions()),

        const SliverToBoxAdapter(child: SizedBox(height: 16)),

        // Live Now Section (live temples or random fallback)
        SliverToBoxAdapter(
          child: LiveNowSection(
            temples: _allTemples,
            onTempleTap: _onLiveTempleCardTap,
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 16)),

        // Nearby Section
        SliverToBoxAdapter(
          child: NearbyTemplesSection(
            temples: _allTemples,
            onTempleTap: _onTempleCardTap,
            onEnableLocation: _showLocationSelector,
          ),
        ),

        // Favourite Temples — always visible; shows entry-point card when empty
        ...[
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          SliverToBoxAdapter(
            child: FavouriteTemplesSection(
              temples: _allTemples,
              onTempleTap: _onTempleCardTap,
            ),
          ),
        ],

        // Recent Visit — only visible when user has visit history
        if (hasRecentVisit) ...[
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          SliverToBoxAdapter(
            child: RecentVisitSection(
              temples: _allTemples,
              onTempleTap: _onTempleCardTap,
            ),
          ),
        ],

        const SliverToBoxAdapter(child: SizedBox(height: 16)),

        // All Temples Section with Deity Filters
        SliverToBoxAdapter(
          child: AllTemplesSection(
            temples: _allTemples,
            onTempleTap: _onTempleCardTap,
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      {
        'icon': Icons.calendar_today_rounded,
        'assetPath': IconAssets.actionBookDarshan,
        'label': 'Book\nPuja',
        'color': AppColors.primaryOrange,
        'onTap': () => MainNavigationService.instance.switchToTab(2),
      },
      {
        'icon': Icons.favorite_rounded,
        'assetPath': IconAssets.actionFavourites,
        'label': 'Favourites',
        'color': AppColors.liveRed,
        'onTap': () =>
            Navigator.of(context, rootNavigator: true).pushNamed('/favorites'),
      },
      {
        'icon': Icons.volunteer_activism_rounded,
        'assetPath': IconAssets.actionDonate,
        'label': 'Donate',
        'color': AppColors.successGreen,
        'onTap': () => MainNavigationService.instance.switchToTab(3),
      },
      {
        'icon': Icons.event_rounded,
        'assetPath': IconAssets.actionEvents,
        'label': 'Events',
        'color': AppColors.primaryOrange,
        'onTap': () => Navigator.of(
          context,
          rootNavigator: true,
        ).pushNamed('/events'),
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: actions.map((action) {
          final color = action['color'] as Color;
          return Expanded(
            child: GestureDetector(
              onTap: action['onTap'] as VoidCallback,
              child: Column(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: color.withValues(alpha: 0.20),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: App3DIcon(
                        assetPath: action['assetPath'] as String,
                        fallbackIcon: action['icon'] as IconData,
                        fallbackColor: color,
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 30,
                    child: Text(
                      action['label'] as String,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryText,
                        height: 1.3,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Semantics(
      label: 'Search temples',
      button: true,
      child: GestureDetector(
        onTap: () {
          // Navigate to search screen using root navigator
          Navigator.of(
            context,
            rootNavigator: true,
          ).pushNamed('/temple_search');
        },
        child: Container(
          margin: AppSpacing.horizontalLg,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: 14,
          ),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: AppRadius.mediumRadius,
            boxShadow: [
              BoxShadow(
                color: AppColors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(Icons.search, color: AppColors.disabledText, size: 22),
              const SizedBox(width: AppSpacing.md),
              const Text(
                'Search temples...',
                style: TextStyle(color: AppColors.disabledText, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPromotionalBanner() {
    return SizedBox(
      height: 180,
      child: PageView.builder(
        itemCount: _banners.length,
        controller: _bannerPageController,
        onPageChanged: (index) {
          setState(() {
            _currentBannerPage = index;
          });
        },
        itemBuilder: (context, index) {
          final banner = _banners[index];
          return Semantics(
            label: '${banner['title']}. ${banner['subtitle']}',
            button: true,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                gradient: LinearGradient(
                  colors: banner['gradient'] as List<Color>,
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Background Image
                  Positioned(
                    right: -20,
                    top: 0,
                    bottom: 0,
                    child: Opacity(
                      opacity: 0.3,
                      child: Image.asset(
                        banner['image'] as String,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            Shimmer.fromColors(
                              baseColor: AppColors.white.withValues(alpha: 0.3),
                              highlightColor: AppColors.white.withValues(
                                alpha: 0.5,
                              ),
                              child: Container(
                                width: 100,
                                color: AppColors.white.withValues(alpha: 0.3),
                              ),
                            ),
                      ),
                    ),
                  ),

                  // Content
                  Padding(
                    padding: AppSpacing.allXl,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          banner['title'] as String,
                          style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          banner['subtitle'] as String,
                          style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        ElevatedButton(
                          onPressed: () {
                            // Handle banner action based on index
                            switch (index) {
                              case 0:
                                // Navigate to bookings
                                final mainNavService =
                                    MainNavigationService.instance;
                                mainNavService.switchToTab(2);
                                break;
                              case 1:
                                // Navigate to search for live darshan
                                Navigator.of(
                                  context,
                                  rootNavigator: true,
                                ).pushNamed('/temple_search');
                                break;
                              case 2:
                                // Navigate to donations
                                final mainNavService =
                                    MainNavigationService.instance;
                                mainNavService.switchToTab(3);
                                break;
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.white,
                            foregroundColor:
                                (banner['gradient'] as List<Color>)[0],
                            padding: const EdgeInsets.symmetric(
                              horizontal: 28,
                              vertical: 10,
                            ),
                            minimumSize: const Size(0, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.xl),
                            ),
                          ),
                          child: Text(
                            banner['buttonText'] as String,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBannerIndicators() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_banners.length, (index) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          width: _currentBannerPage == index ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: _currentBannerPage == index
                ? AppColors.primaryOrange
                : AppColors.borderGray,
            borderRadius: BorderRadius.circular(AppRadius.xs),
          ),
        );
      }),
    );
  }

  Widget _buildLoadingState() {
    return Shimmer.fromColors(
      baseColor: AppColors.lightGray,
      highlightColor: AppColors.white,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section header skeleton
            _skeletonBox(width: 140, height: 20),
            const SizedBox(height: 12),
            // Horizontal card skeletons (nearby temples)
            SizedBox(
              height: 140,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: 4,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, __) =>
                    _skeletonBox(width: 120, height: 140, radius: 12),
              ),
            ),
            const SizedBox(height: 24),
            // Second section header
            _skeletonBox(width: 120, height: 20),
            const SizedBox(height: 12),
            // Horizontal card skeletons (favourites)
            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: 4,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, __) =>
                    _skeletonBox(width: 100, height: 120, radius: 12),
              ),
            ),
            const SizedBox(height: 24),
            // Third section header
            _skeletonBox(width: 100, height: 20),
            const SizedBox(height: 12),
            // Vertical temple card skeletons
            ...List.generate(
              4,
              (_) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _skeletonTempleCard(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _skeletonBox({
    double? width,
    required double height,
    double radius = 4,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  Widget _skeletonTempleCard() {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 80,
            decoration: const BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 14,
                  width: double.infinity,
                  color: AppColors.white,
                ),
                const SizedBox(height: 8),
                Container(height: 12, width: 150, color: AppColors.white),
                const SizedBox(height: 6),
                Container(height: 10, width: 100, color: AppColors.white),
              ],
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: AppColors.errorRed),
          const SizedBox(height: 16),
          Text(
            _error ?? 'An error occurred',
            style: TextStyle(color: AppColors.secondaryText),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadTemples,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 8)),

        // Search Bar - still visible in empty state
        SliverToBoxAdapter(child: _buildSearchBar()),

        // Empty state message
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.temple_hindu,
                    size: 64,
                    color: AppColors.secondaryText,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No temples found',
                    style: TextStyle(
                      fontSize: 18,
                      color: AppColors.primaryText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Try adjusting your location or search for temples',
                    style: TextStyle(color: AppColors.secondaryText),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _loadTemples,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryOrange,
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(
                            context,
                            rootNavigator: true,
                          ).pushNamed('/temple_search');
                        },
                        icon: const Icon(Icons.search),
                        label: const Text('Search'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryOrange,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
