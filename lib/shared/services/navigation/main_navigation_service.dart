import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing main navigation state and deep linking
class MainNavigationService {
  static final MainNavigationService _instance =
      MainNavigationService._internal();
  static MainNavigationService get instance => _instance;

  MainNavigationService._internal();

  // Navigation state — 5-tab structure:
  // 0: Home, 1: Community, 2: Booking, 3: Donate, 4: Profile
  static const int _tabCount = 5;

  int _currentTabIndex = 0;
  final Map<int, List<String>> _tabNavigationStacks = {
    0: ['/home'], // Home
    1: ['/community'], // Community
    2: ['/booking'], // Booking Puja
    3: ['/donate'], // Donate
    4: ['/profile'], // Profile
  };

  // Stream controllers for state management
  final StreamController<int> _tabIndexController =
      StreamController<int>.broadcast();
  final StreamController<Map<String, int>> _badgeController =
      StreamController<Map<String, int>>.broadcast();

  // Badge counts — one entry per tab name
  final Map<String, int> _badgeCounts = {
    'home': 0,
    'community': 0,
    'booking': 0,
    'donate': 0,
    'profile': 0,
  };

  // Getters
  int get currentTabIndex => _currentTabIndex;
  Stream<int> get tabIndexStream => _tabIndexController.stream;
  Stream<Map<String, int>> get badgeStream => _badgeController.stream;
  Map<String, int> get badgeCounts => Map.unmodifiable(_badgeCounts);

  // Tab persistence key
  static const String _tabIndexKey = 'main_navigation_tab_index';
  static const String _navigationStackKey = 'main_navigation_stacks';

  /// Initialize the navigation service
  Future<void> initialize() async {
    await _loadPersistedState();
  }

  /// Load persisted navigation state
  Future<void> _loadPersistedState() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load tab index — validate against current tab count
      final savedIndex = prefs.getInt(_tabIndexKey);
      if (savedIndex != null && savedIndex >= 0 && savedIndex < _tabCount) {
        _currentTabIndex = savedIndex;
      }

      // Load navigation stacks — only restore if count matches current tab count
      final stacksJson = prefs.getStringList(_navigationStackKey);
      if (stacksJson != null && stacksJson.length == _tabCount) {
        for (int i = 0; i < _tabCount; i++) {
          final routes = stacksJson[i]
              .split(',')
              .where((r) => r.isNotEmpty)
              .toList();
          if (routes.isNotEmpty) {
            _tabNavigationStacks[i] = routes;
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to load persisted navigation state: $e');
    }
  }

  /// Persist navigation state
  Future<void> _persistState() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Persist tab index
      await prefs.setInt(_tabIndexKey, _currentTabIndex);

      // Persist navigation stacks in tab order
      final stacksJson = List.generate(
        _tabCount,
        (i) => (_tabNavigationStacks[i] ?? [_getDefaultRoute(i)]).join(','),
      );
      await prefs.setStringList(_navigationStackKey, stacksJson);
    } catch (e) {
      debugPrint('Failed to persist navigation state: $e');
    }
  }

  /// Switch to a specific tab
  Future<void> switchToTab(int index) async {
    if (index < 0 || index >= _tabCount || index == _currentTabIndex) {
      return;
    }

    _currentTabIndex = index;
    _tabIndexController.add(_currentTabIndex);
    await _persistState();
  }

  /// Get the current route for a specific tab
  String getCurrentRoute(int tabIndex) {
    final stack = _tabNavigationStacks[tabIndex];
    return stack?.isNotEmpty == true ? stack!.last : _getDefaultRoute(tabIndex);
  }

  /// Push a route to a specific tab's navigation stack
  void pushRoute(int tabIndex, String route) {
    if (tabIndex < 0 || tabIndex >= _tabCount) return;

    final stack = _tabNavigationStacks[tabIndex] ?? [];
    stack.add(route);
    _tabNavigationStacks[tabIndex] = stack;
    _persistState();
  }

  /// Pop a route from a specific tab's navigation stack
  String? popRoute(int tabIndex) {
    if (tabIndex < 0 || tabIndex >= _tabCount) return null;

    final stack = _tabNavigationStacks[tabIndex];
    if (stack == null || stack.length <= 1) return null;

    final poppedRoute = stack.removeLast();
    _persistState();
    return poppedRoute;
  }

  /// Clear navigation stack for a specific tab
  void clearTabStack(int tabIndex) {
    if (tabIndex < 0 || tabIndex >= _tabCount) return;

    _tabNavigationStacks[tabIndex] = [_getDefaultRoute(tabIndex)];
    _persistState();
  }

  /// Get default route for a tab
  String _getDefaultRoute(int tabIndex) {
    switch (tabIndex) {
      case 0:
        return '/home';
      case 1:
        return '/community';
      case 2:
        return '/booking';
      case 3:
        return '/donate';
      case 4:
        return '/profile';
      default:
        return '/home';
    }
  }

  /// Handle deep linking
  Future<int> handleDeepLink(String route) async {
    final tabIndex = _getTabIndexForRoute(route);

    if (tabIndex != -1) {
      _tabNavigationStacks[tabIndex] = [_getDefaultRoute(tabIndex), route];
      await switchToTab(tabIndex);
      return tabIndex;
    }

    return _currentTabIndex;
  }

  /// Get tab index for a specific route
  int _getTabIndexForRoute(String route) {
    if (route.startsWith('/home') ||
        route.startsWith('/temple') ||
        route.startsWith('/temple_detail') ||
        route.startsWith('/temple_discovery') ||
        route.startsWith('/search') ||
        route.startsWith('/favorites')) {
      return 0; // Home tab
    } else if (route.startsWith('/community')) {
      return 1; // Community tab
    } else if (route.startsWith('/booking') || route.startsWith('/book_puja')) {
      return 2; // Booking tab
    } else if (route.startsWith('/donate') || route.startsWith('/donation')) {
      return 3; // Donate tab
    } else if (route.startsWith('/profile') ||
        route.startsWith('/preferences')) {
      return 4; // Profile tab
    }
    return -1;
  }

  /// Update badge count for a specific tab
  void updateBadgeCount(String tabKey, int count) {
    if (_badgeCounts.containsKey(tabKey)) {
      _badgeCounts[tabKey] = count;
      _badgeController.add(Map.from(_badgeCounts));
    }
  }

  /// Clear badge for a specific tab
  void clearBadge(String tabKey) {
    updateBadgeCount(tabKey, 0);
  }

  /// Clear all badges
  void clearAllBadges() {
    for (final key in _badgeCounts.keys) {
      _badgeCounts[key] = 0;
    }
    _badgeController.add(Map.from(_badgeCounts));
  }

  /// Get tab name for index
  String getTabName(int index) {
    switch (index) {
      case 0:
        return 'home';
      case 1:
        return 'community';
      case 2:
        return 'booking';
      case 3:
        return 'donate';
      case 4:
        return 'profile';
      default:
        return 'home';
    }
  }

  /// Get tab index for name
  int getTabIndex(String name) {
    switch (name.toLowerCase()) {
      case 'home':
        return 0;
      case 'community':
        return 1;
      case 'booking':
        return 2;
      case 'donate':
        return 3;
      case 'profile':
        return 4;
      default:
        return 0;
    }
  }

  /// Check if a tab has notifications
  bool hasNotifications(int tabIndex) {
    final tabName = getTabName(tabIndex);
    return (_badgeCounts[tabName] ?? 0) > 0;
  }

  /// Get total notification count
  int getTotalNotificationCount() {
    return _badgeCounts.values.fold(0, (sum, count) => sum + count);
  }

  /// Reset navigation state
  Future<void> reset() async {
    _currentTabIndex = 0;
    _tabNavigationStacks
      ..clear()
      ..addAll({
        0: ['/home'],
        1: ['/community'],
        2: ['/booking'],
        3: ['/donate'],
        4: ['/profile'],
      });
    clearAllBadges();

    _tabIndexController.add(_currentTabIndex);
    await _persistState();
  }

  /// Dispose resources
  void dispose() {
    _tabIndexController.close();
    _badgeController.close();
  }
}
