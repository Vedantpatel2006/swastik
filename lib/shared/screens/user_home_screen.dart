import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/themes/app_colors.dart';
import '../../core/services/accessibility_service.dart';
import '../services/connectivity_service.dart';
import '../services/navigation/main_navigation_service.dart';
import '../services/service_container.dart';
import '../../features/temple/screens/home_screen.dart';
import '../screens/community_screen.dart';
import '../../features/user/screens/booking_screen.dart';
import '../../features/user/screens/donation_screen.dart';
import '../../features/user/screens/user_profile_screen.dart';
import '../widgets/app_3d_icon.dart';

/// Main navigation screen with bottom navigation bar for user interface
class MainNavigationScreen extends StatefulWidget {
  final int initialIndex;

  const MainNavigationScreen({super.key, this.initialIndex = 0});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen>
    with WidgetsBindingObserver {
  final List<StreamSubscription> _subscriptions = [];

  int _currentIndex = 0;

  // Services
  final MainNavigationService _navigationService =
      MainNavigationService.instance;

  // Navigation state management - 5 tabs: Home, Community, Booking, Donate, Profile
  final Map<int, GlobalKey<NavigatorState>> _navigatorKeys = {
    0: GlobalKey<NavigatorState>(), // Home
    1: GlobalKey<NavigatorState>(), // Community
    2: GlobalKey<NavigatorState>(), // Booking Puja
    3: GlobalKey<NavigatorState>(), // Donate
    4: GlobalKey<NavigatorState>(), // Profile
  };

  // Badge indicators
  Map<String, int> _badgeCounts = {};

  // All stream subscriptions — cancelled together in dispose()
  // Note: individual named fields are intentionally not kept to avoid
  // double-cancel; everything goes through _subscriptions.
  StreamSubscription<int>? _tabIndexSubscription;
  StreamSubscription<Map<String, int>>? _badgeSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _currentIndex = widget.initialIndex;

    // Initialize navigation service first, then set up listeners that depend on it
    _initializeNavigationService().then((_) => _setupNotificationListeners());
  }

  Future<void> _initializeNavigationService() async {
    try {
      await _navigationService.initialize();

      // Set initial index from navigation service
      final savedIndex = _navigationService.currentTabIndex;
      if (savedIndex != _currentIndex) {
        setState(() {
          _currentIndex = savedIndex;
        });
      }

      // Get initial badge counts
      setState(() {
        _badgeCounts = _navigationService.badgeCounts;
      });
    } catch (e) {
      debugPrint('Failed to initialize navigation service: $e');
    }
  }

  void _setupNotificationListeners() {
    // Connectivity stream — just log changes; OfflineIndicator handles UI
    _subscriptions.add(
      ConnectivityService().statusStream.listen((status) {
        if (mounted) {
          debugPrint('Connectivity status changed: $status');
        }
      }),
    );

    // Tab index stream — sync external tab switches
    _tabIndexSubscription = _navigationService.tabIndexStream.listen((index) {
      if (mounted && index != _currentIndex) {
        setState(() {
          _currentIndex = index;
        });
      }
    });
    _subscriptions.add(_tabIndexSubscription!);

    // Badge stream — sync badge counts from navigation service
    // Use Map.from() to get a mutable copy since badgeStream emits unmodifiable maps
    _badgeSubscription = _navigationService.badgeStream.listen((badges) {
      if (mounted) {
        setState(() {
          _badgeCounts = Map.from(badges);
        });
      }
    });
    _subscriptions.add(_badgeSubscription!);

    // Real-time notification badge updates from Supabase
    _setupRealTimeNotificationBadges();
  }

  void _setupRealTimeNotificationBadges() {
    // Listen to real-time notification count changes
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser != null) {
      final unreadCountStream = services.notificationService.getUnreadCount(
        currentUser.uid,
      );
      final unreadSubscription = unreadCountStream.listen((unreadCount) {
        if (mounted) {
          // Notifications are surfaced on the Home tab (index 0)
          setState(() {
            _badgeCounts['home'] = unreadCount;
          });

          // Keep navigation service badge counts in sync
          _navigationService.updateBadgeCount('home', unreadCount);
        }
      });
      _subscriptions.add(unreadSubscription);
    }
  }

  void _onTabTapped(int index) {
    if (index == _currentIndex) {
      // If same tab is tapped, pop to root of that tab's navigator
      _navigatorKeys[index]?.currentState?.popUntil((route) => route.isFirst);
      return;
    }

    // Provide haptic feedback
    AccessibilityService.instance.provideAccessibleHapticFeedback(
      context,
      type: 'selectionClick',
    );

    setState(() {
      _currentIndex = index;
    });

    // Update navigation service
    _navigationService.switchToTab(index);

    // Announce tab change for accessibility
    AccessibilityService.instance.announceToScreenReader(_getTabLabel(index));
  }

  String _getTabLabel(int index) {
    switch (index) {
      case 0:
        return 'Home tab selected';
      case 1:
        return 'Community tab selected';
      case 2:
        return 'Booking Puja tab selected';
      case 3:
        return 'Donate tab selected';
      case 4:
        return 'Profile tab selected';
      default:
        return 'Tab selected';
    }
  }

  String _getTabSemanticLabel(int index) {
    final tabName = _navigationService.getTabName(index);
    final badge = _badgeCounts[tabName] ?? 0;
    final badgeText = badge > 0 ? ', $badge notifications' : '';

    switch (index) {
      case 0:
        return 'Home tab$badgeText';
      case 1:
        return 'Search tab$badgeText';
      case 2:
        return 'Booking Puja tab$badgeText';
      case 3:
        return 'Donate tab$badgeText';
      case 4:
        return 'Profile tab$badgeText';
      default:
        return 'Tab$badgeText';
    }
  }

  Widget _buildTabNavigator(int index, Widget child) {
    return Navigator(
      key: _navigatorKeys[index],
      onGenerateRoute: (routeSettings) {
        return MaterialPageRoute(
          builder: (context) => child,
          settings: routeSettings,
        );
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Handle app lifecycle changes for navigation state
    if (state == AppLifecycleState.paused) {
      // Navigation service handles persistence automatically
    }
  }

  @override
  void dispose() {
    // Cancel all subscriptions
    for (var subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();

    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // Handle back button press - pop current tab's navigator first
        final navigator = _navigatorKeys[_currentIndex]?.currentState;
        if (navigator != null && navigator.canPop()) {
          navigator.pop();
        } else {
          // If we can't pop from the current tab, show exit confirmation
          final shouldExit = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Exit App'),
              content: const Text('Do you want to exit the app?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primaryOrange,
                  ),
                  child: const Text('Exit'),
                ),
              ],
            ),
          );

          if (shouldExit == true && context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: [
            _buildTabNavigator(0, const HomeScreen()),
            _buildTabNavigator(1, const CommunityScreen()),
            _buildTabNavigator(2, const BookingScreen()),
            _buildTabNavigator(3, const DonationScreen()),
            _buildTabNavigator(4, const UserProfileScreen()),
          ],
        ),
        bottomNavigationBar: _buildBottomNavigationBar(),
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 68,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  0,
                  IconAssets.navHome,
                  Icons.home,
                  Icons.home_outlined,
                  'Home',
                ),
                _buildNavItem(
                  1,
                  IconAssets.navCommunity,
                  Icons.people,
                  Icons.people_outline,
                  'Community',
                ),
                _buildNavItem(
                  2,
                  IconAssets.navBooking,
                  Icons.book_online,
                  Icons.book_online_outlined,
                  'Book',
                ),
                _buildNavItem(
                  3,
                  IconAssets.navDonate,
                  Icons.volunteer_activism,
                  Icons.volunteer_activism_outlined,
                  'Donate',
                ),
                _buildNavItem(
                  4,
                  IconAssets.navProfile,
                  Icons.person,
                  Icons.person_outline,
                  'Profile',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    String assetPath,
    IconData activeIcon,
    IconData inactiveIcon,
    String label,
  ) {
    final isSelected = _currentIndex == index;
    final tabName = _navigationService.getTabName(index);
    final badgeCount = _badgeCounts[tabName] ?? 0;

    return Expanded(
      child: Semantics(
        label: _getTabSemanticLabel(index),
        button: true,
        selected: isSelected,
        onTap: () => _onTabTapped(index),
        child: InkWell(
          onTap: () => _onTabTapped(index),
          borderRadius: BorderRadius.circular(16),
          splashColor: AppColors.primaryOrange.withValues(alpha: 0.1),
          highlightColor: AppColors.primaryOrange.withValues(alpha: 0.05),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primaryOrange.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primaryOrange.withValues(alpha: 0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: App3DIcon(
                          key: ValueKey('$index-$isSelected'),
                          assetPath: assetPath,
                          fallbackIcon: isSelected ? activeIcon : inactiveIcon,
                          fallbackColor: isSelected
                              ? AppColors.primaryOrange
                              : AppColors.secondaryText,
                          size: 24,
                          opacity: isSelected ? 1.0 : 0.55,
                        ),
                      ),
                    ),
                    if (badgeCount > 0)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: AppColors.errorRed,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.white,
                              width: 1.5,
                            ),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            badgeCount > 99 ? '99+' : badgeCount.toString(),
                            style: const TextStyle(
                              color: AppColors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? AppColors.primaryOrange
                        : AppColors.secondaryText,
                    letterSpacing: 0.1,
                  ),
                  child: Text(label),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
