import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../shared/models/temple_filters.dart';

/// Enhanced navigation service with comprehensive state management and deep linking
class EnhancedNavigationService {
  static final EnhancedNavigationService _instance =
      EnhancedNavigationService._internal();
  static EnhancedNavigationService get instance => _instance;

  EnhancedNavigationService._internal();

  // Navigation state
  int _currentTabIndex = 0;
  final Map<int, NavigationTabState> _tabStates = {};
  final Map<String, ScrollController> _scrollControllers = {};

  // Stream controllers
  final StreamController<NavigationStateChange> _stateChangeController =
      StreamController<NavigationStateChange>.broadcast();
  final StreamController<DeepLinkEvent> _deepLinkController =
      StreamController<DeepLinkEvent>.broadcast();

  // Persistence keys
  static const String _navigationStateKey = 'enhanced_navigation_state';
  static const String _scrollPositionsKey = 'scroll_positions';
  static const String _tabStatesKey = 'tab_states';

  // Getters
  int get currentTabIndex => _currentTabIndex;
  Stream<NavigationStateChange> get stateChangeStream =>
      _stateChangeController.stream;
  Stream<DeepLinkEvent> get deepLinkStream => _deepLinkController.stream;

  /// Initialize the enhanced navigation service
  Future<void> initialize() async {
    _initializeTabStates();
    await _loadPersistedState();
  }

  /// Initialize tab states if not already present
  void _initializeTabStates() {
    for (int i = 0; i < 4; i++) {
      _tabStates[i] ??= NavigationTabState(
        tabIndex: i,
        currentRoute: _getDefaultRoute(i),
        routeStack: [_getDefaultRoute(i)],
        scrollPosition: 0.0,
        lastVisited: DateTime.now(),
        preservedData: {},
      );
    }
  }

  /// Load persisted navigation state
  Future<void> _loadPersistedState() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load current tab index
      _currentTabIndex = prefs.getInt(_navigationStateKey) ?? 0;

      // Load tab states
      final tabStatesJson = prefs.getString(_tabStatesKey);
      if (tabStatesJson != null) {
        final Map<String, dynamic> statesData = jsonDecode(tabStatesJson);
        for (final entry in statesData.entries) {
          final tabIndex = int.tryParse(entry.key);
          if (tabIndex != null) {
            _tabStates[tabIndex] = NavigationTabState.fromJson(entry.value);
          }
        }
      }

      // Load scroll positions
      final scrollPositionsJson = prefs.getString(_scrollPositionsKey);
      if (scrollPositionsJson != null) {
        final Map<String, dynamic> positions = jsonDecode(scrollPositionsJson);
        for (final entry in positions.entries) {
          final controller = ScrollController(
            initialScrollOffset: entry.value.toDouble(),
          );
          _scrollControllers[entry.key] = controller;
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

      // Persist current tab index
      await prefs.setInt(_navigationStateKey, _currentTabIndex);

      // Persist tab states
      final tabStatesData = <String, dynamic>{};
      for (final entry in _tabStates.entries) {
        tabStatesData[entry.key.toString()] = entry.value.toJson();
      }
      await prefs.setString(_tabStatesKey, jsonEncode(tabStatesData));

      // Persist scroll positions
      final scrollPositions = <String, double>{};
      for (final entry in _scrollControllers.entries) {
        if (entry.value.hasClients) {
          scrollPositions[entry.key] = entry.value.offset;
        }
      }
      await prefs.setString(_scrollPositionsKey, jsonEncode(scrollPositions));
    } catch (e) {
      debugPrint('Failed to persist navigation state: $e');
      // Don't rethrow - persistence failures shouldn't break navigation
    }
  }

  /// Switch to a specific tab with state preservation
  Future<void> switchToTab(int index, {Map<String, dynamic>? context}) async {
    if (index < 0 || index >= 4 || index == _currentTabIndex) {
      return;
    }

    // Save current tab state
    await _saveCurrentTabState();

    final previousTab = _currentTabIndex;
    _currentTabIndex = index;

    // Ensure target tab state exists
    _tabStates[index] ??= NavigationTabState(
      tabIndex: index,
      currentRoute: _getDefaultRoute(index),
      routeStack: [_getDefaultRoute(index)],
      scrollPosition: 0.0,
      lastVisited: DateTime.now(),
      preservedData: {},
    );

    // Update last visited time
    _tabStates[index]!.lastVisited = DateTime.now();

    // Emit state change event
    _stateChangeController.add(
      NavigationStateChange(
        previousTab: previousTab,
        currentTab: index,
        context: context,
        timestamp: DateTime.now(),
      ),
    );

    await _persistState();
  }

  /// Navigate to a specific route within a tab
  Future<void> navigateToRoute(
    int tabIndex,
    String route, {
    Map<String, dynamic>? parameters,
    bool clearStack = false,
    bool preserveState = true,
  }) async {
    if (tabIndex < 0 || tabIndex >= 4) return;

    final tabState = _tabStates[tabIndex];
    if (tabState == null) return;

    if (clearStack) {
      tabState.routeStack.clear();
      tabState.routeStack.add(_getDefaultRoute(tabIndex));
    }

    // Add route to stack if not already present
    if (tabState.routeStack.isEmpty || tabState.routeStack.last != route) {
      tabState.routeStack.add(route);
    }

    tabState.currentRoute = route;
    tabState.lastVisited = DateTime.now();

    // Store route parameters
    if (parameters != null) {
      tabState.preservedData['route_parameters'] = parameters;
    }

    // Switch to tab if not current
    if (tabIndex != _currentTabIndex) {
      await switchToTab(tabIndex);
    }

    await _persistState();
  }

  /// Handle deep link navigation
  Future<DeepLinkResult> handleDeepLink(String deepLink) async {
    try {
      final parsedLink = _parseDeepLink(deepLink);

      if (parsedLink == null) {
        return DeepLinkResult(
          success: false,
          error: 'Invalid deep link format',
        );
      }

      // Emit deep link event
      _deepLinkController.add(
        DeepLinkEvent(
          deepLink: deepLink,
          parsedData: parsedLink,
          timestamp: DateTime.now(),
        ),
      );

      // Navigate based on deep link type
      switch (parsedLink.type) {
        case DeepLinkType.temple:
          return await _handleTempleDeepLink(parsedLink);
        case DeepLinkType.search:
          return await _handleSearchDeepLink(parsedLink);
        case DeepLinkType.liveDarshan:
          return await _handleLiveDarshanDeepLink(parsedLink);
        case DeepLinkType.profile:
          return await _handleProfileDeepLink(parsedLink);
        case DeepLinkType.booking:
          return await _handleBookingDeepLink(parsedLink);
        case DeepLinkType.donation:
          return await _handleDonationDeepLink(parsedLink);
      }
    } catch (e) {
      debugPrint('Error handling deep link: $e');
      return DeepLinkResult(
        success: false,
        error: 'Failed to process deep link: $e',
      );
    }
  }

  /// Generate deep link for current navigation state
  String generateCurrentStateDeepLink() {
    final currentState = _tabStates[_currentTabIndex];
    if (currentState == null) return _generateBaseDeepLink();

    final route = currentState.currentRoute;
    final parameters =
        currentState.preservedData['route_parameters'] as Map<String, dynamic>?;

    return _generateDeepLinkForRoute(route, parameters);
  }

  /// Generate deep link for specific temple
  String generateTempleDeepLink(
    String templeId, {
    String? tab,
    Map<String, String>? additionalParams,
  }) {
    final baseUrl = 'https://swastik.app/temple/$templeId';
    final params = <String, String>{};

    if (tab != null) params['tab'] = tab;
    if (additionalParams != null) params.addAll(additionalParams);

    if (params.isEmpty) return baseUrl;

    final queryString = params.entries
        .map(
          (e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
        )
        .join('&');

    return '$baseUrl?$queryString';
  }

  /// Generate deep link for search with filters
  String generateSearchDeepLink(TempleFilters? filters, String? query) {
    final baseUrl = 'https://swastik.app/search';
    final params = <String, String>{};

    if (query != null && query.isNotEmpty) {
      params['q'] = query;
    }

    if (filters != null) {
      if (filters.maxDistance != null) {
        params['distance'] = filters.maxDistance!.toString();
      }
      if (filters.traditions != null && filters.traditions!.isNotEmpty) {
        params['traditions'] = filters.traditions!.join(',');
      }
      if (filters.features != null && filters.features!.isNotEmpty) {
        params['features'] = filters.features!.join(',');
      }
      if (filters.hasLiveDarshan == true) {
        params['live_only'] = 'true';
      }
    }

    if (params.isEmpty) return baseUrl;

    final queryString = params.entries
        .map(
          (e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
        )
        .join('&');

    return '$baseUrl?$queryString';
  }

  /// Get scroll controller for a specific screen
  ScrollController getScrollController(String screenKey) {
    return _scrollControllers.putIfAbsent(screenKey, () => ScrollController());
  }

  /// Preserve scroll position for a screen
  void preserveScrollPosition(String screenKey, double position) {
    final controller = _scrollControllers[screenKey];
    if (controller != null && controller.hasClients) {
      // Position will be automatically saved when persisting state
    } else {
      _scrollControllers[screenKey] = ScrollController(
        initialScrollOffset: position,
      );
    }
  }

  /// Get preserved data for current tab
  Map<String, dynamic> getCurrentTabPreservedData() {
    return _tabStates[_currentTabIndex]?.preservedData ?? {};
  }

  /// Set preserved data for current tab
  void setCurrentTabPreservedData(String key, dynamic value) {
    final tabState = _tabStates[_currentTabIndex];
    if (tabState != null) {
      tabState.preservedData[key] = value;
      _persistState();
    }
  }

  /// Get tab state for specific tab
  NavigationTabState? getTabState(int tabIndex) {
    return _tabStates[tabIndex];
  }

  /// Save current tab state before switching
  Future<void> _saveCurrentTabState() async {
    final currentState = _tabStates[_currentTabIndex];
    if (currentState != null) {
      // Save scroll positions
      for (final entry in _scrollControllers.entries) {
        if (entry.value.hasClients) {
          currentState.preservedData['scroll_${entry.key}'] =
              entry.value.offset;
        }
      }
    }
  }

  /// Parse deep link URL
  ParsedDeepLink? _parseDeepLink(String deepLink) {
    try {
      final uri = Uri.parse(deepLink);
      final pathSegments = uri.pathSegments;

      if (pathSegments.isEmpty) return null;

      final type = _getDeepLinkType(pathSegments.first);
      if (type == null) return null;

      return ParsedDeepLink(
        type: type,
        pathSegments: pathSegments,
        queryParameters: uri.queryParameters,
        originalUrl: deepLink,
      );
    } catch (e) {
      debugPrint('Error parsing deep link: $e');
      return null;
    }
  }

  /// Get deep link type from path segment
  DeepLinkType? _getDeepLinkType(String segment) {
    switch (segment.toLowerCase()) {
      case 'temple':
        return DeepLinkType.temple;
      case 'search':
        return DeepLinkType.search;
      case 'live':
      case 'darshan':
        return DeepLinkType.liveDarshan;
      case 'profile':
        return DeepLinkType.profile;
      case 'booking':
      case 'book':
        return DeepLinkType.booking;
      case 'donate':
      case 'donation':
        return DeepLinkType.donation;
      default:
        return null;
    }
  }

  /// Handle temple deep link
  Future<DeepLinkResult> _handleTempleDeepLink(
    ParsedDeepLink parsedLink,
  ) async {
    if (parsedLink.pathSegments.length < 2) {
      return DeepLinkResult(success: false, error: 'Temple ID missing');
    }

    final templeId = parsedLink.pathSegments[1];
    final parameters = <String, dynamic>{
      'temple_id': templeId,
      ...parsedLink.queryParameters,
    };

    await navigateToRoute(
      0, // Temple tab
      '/temple_detail',
      parameters: parameters,
    );

    return DeepLinkResult(
      success: true,
      targetTab: 0,
      targetRoute: '/temple_detail',
      parameters: parameters,
    );
  }

  /// Handle search deep link
  Future<DeepLinkResult> _handleSearchDeepLink(
    ParsedDeepLink parsedLink,
  ) async {
    final parameters = Map<String, dynamic>.from(parsedLink.queryParameters);

    await navigateToRoute(
      0, // Temple tab (includes search)
      '/search',
      parameters: parameters,
    );

    return DeepLinkResult(
      success: true,
      targetTab: 0,
      targetRoute: '/search',
      parameters: parameters,
    );
  }

  /// Handle live darshan deep link
  Future<DeepLinkResult> _handleLiveDarshanDeepLink(
    ParsedDeepLink parsedLink,
  ) async {
    String templeId = '';
    if (parsedLink.pathSegments.length > 1) {
      templeId = parsedLink.pathSegments[1];
    } else if (parsedLink.queryParameters.containsKey('temple_id')) {
      templeId = parsedLink.queryParameters['temple_id']!;
    }

    if (templeId.isEmpty) {
      return DeepLinkResult(
        success: false,
        error: 'Temple ID required for live darshan',
      );
    }

    await navigateToRoute(
      0, // Temple tab
      '/live_darshan',
      parameters: {'temple_id': templeId, ...parsedLink.queryParameters},
    );

    return DeepLinkResult(
      success: true,
      targetTab: 0,
      targetRoute: '/live_darshan',
      parameters: {'temple_id': templeId},
    );
  }

  /// Handle profile deep link
  Future<DeepLinkResult> _handleProfileDeepLink(
    ParsedDeepLink parsedLink,
  ) async {
    await navigateToRoute(
      3, // Profile tab
      '/profile',
      parameters: parsedLink.queryParameters,
    );

    return DeepLinkResult(
      success: true,
      targetTab: 3,
      targetRoute: '/profile',
      parameters: parsedLink.queryParameters,
    );
  }

  /// Handle booking deep link
  Future<DeepLinkResult> _handleBookingDeepLink(
    ParsedDeepLink parsedLink,
  ) async {
    await navigateToRoute(
      1, // Booking tab
      '/booking',
      parameters: parsedLink.queryParameters,
    );

    return DeepLinkResult(
      success: true,
      targetTab: 1,
      targetRoute: '/booking',
      parameters: parsedLink.queryParameters,
    );
  }

  /// Handle donation deep link
  Future<DeepLinkResult> _handleDonationDeepLink(
    ParsedDeepLink parsedLink,
  ) async {
    await navigateToRoute(
      2, // Donation tab
      '/donate',
      parameters: parsedLink.queryParameters,
    );

    return DeepLinkResult(
      success: true,
      targetTab: 2,
      targetRoute: '/donate',
      parameters: parsedLink.queryParameters,
    );
  }

  /// Generate base deep link
  String _generateBaseDeepLink() {
    return 'https://swastik.app/';
  }

  /// Generate deep link for specific route
  String _generateDeepLinkForRoute(
    String route,
    Map<String, dynamic>? parameters,
  ) {
    final baseUrl = 'https://swastik.app$route';

    if (parameters == null || parameters.isEmpty) {
      return baseUrl;
    }

    final queryParams = parameters.entries
        .where((e) => e.value != null)
        .map(
          (e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value.toString())}',
        )
        .join('&');

    return queryParams.isNotEmpty ? '$baseUrl?$queryParams' : baseUrl;
  }

  /// Get default route for tab
  String _getDefaultRoute(int tabIndex) {
    switch (tabIndex) {
      case 0:
        return '/temple';
      case 1:
        return '/booking';
      case 2:
        return '/donate';
      case 3:
        return '/profile';
      default:
        return '/temple';
    }
  }

  /// Reset navigation state
  Future<void> reset() async {
    _currentTabIndex = 0;
    _tabStates.clear();
    _scrollControllers.clear();
    _initializeTabStates();
    await _persistState();
  }

  /// Dispose resources
  void dispose() {
    _stateChangeController.close();
    _deepLinkController.close();
    for (final controller in _scrollControllers.values) {
      controller.dispose();
    }
    _scrollControllers.clear();
  }
}

/// Navigation tab state
class NavigationTabState {
  int tabIndex;
  String currentRoute;
  List<String> routeStack;
  double scrollPosition;
  DateTime lastVisited;
  Map<String, dynamic> preservedData;

  NavigationTabState({
    required this.tabIndex,
    required this.currentRoute,
    required this.routeStack,
    this.scrollPosition = 0.0,
    required this.lastVisited,
    Map<String, dynamic>? preservedData,
  }) : preservedData = preservedData ?? {};

  Map<String, dynamic> toJson() {
    return {
      'tabIndex': tabIndex,
      'currentRoute': currentRoute,
      'routeStack': routeStack,
      'scrollPosition': scrollPosition,
      'lastVisited': lastVisited.toIso8601String(),
      'preservedData': preservedData,
    };
  }

  factory NavigationTabState.fromJson(Map<String, dynamic> json) {
    return NavigationTabState(
      tabIndex: json['tabIndex'] ?? 0,
      currentRoute: json['currentRoute'] ?? '/temple',
      routeStack: List<String>.from(json['routeStack'] ?? ['/temple']),
      scrollPosition: (json['scrollPosition'] ?? 0.0).toDouble(),
      lastVisited:
          DateTime.tryParse(json['lastVisited'] ?? '') ?? DateTime.now(),
      preservedData: Map<String, dynamic>.from(json['preservedData'] ?? {}),
    );
  }
}

/// Navigation state change event
class NavigationStateChange {
  final int previousTab;
  final int currentTab;
  final Map<String, dynamic>? context;
  final DateTime timestamp;

  NavigationStateChange({
    required this.previousTab,
    required this.currentTab,
    this.context,
    required this.timestamp,
  });
}

/// Deep link event
class DeepLinkEvent {
  final String deepLink;
  final ParsedDeepLink parsedData;
  final DateTime timestamp;

  DeepLinkEvent({
    required this.deepLink,
    required this.parsedData,
    required this.timestamp,
  });
}

/// Parsed deep link data
class ParsedDeepLink {
  final DeepLinkType type;
  final List<String> pathSegments;
  final Map<String, String> queryParameters;
  final String originalUrl;

  ParsedDeepLink({
    required this.type,
    required this.pathSegments,
    required this.queryParameters,
    required this.originalUrl,
  });
}

/// Deep link result
class DeepLinkResult {
  final bool success;
  final String? error;
  final int? targetTab;
  final String? targetRoute;
  final Map<String, dynamic>? parameters;

  DeepLinkResult({
    required this.success,
    this.error,
    this.targetTab,
    this.targetRoute,
    this.parameters,
  });
}

/// Deep link types
enum DeepLinkType { temple, search, liveDarshan, profile, booking, donation }
