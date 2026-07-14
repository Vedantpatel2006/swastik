import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/navigation/enhanced_navigation_service.dart';

/// Widget that manages navigation state and provides it to child widgets
class NavigationStateManager extends StatefulWidget {
  final Widget child;
  final Function(DeepLinkEvent)? onDeepLink;
  final Function(NavigationStateChange)? onStateChange;

  const NavigationStateManager({
    super.key,
    required this.child,
    this.onDeepLink,
    this.onStateChange,
  });

  @override
  State<NavigationStateManager> createState() => _NavigationStateManagerState();
}

class _NavigationStateManagerState extends State<NavigationStateManager>
    with WidgetsBindingObserver {
  final EnhancedNavigationService _navigationService = EnhancedNavigationService.instance;
  late final StreamSubscription<DeepLinkEvent> _deepLinkSubscription;
  late final StreamSubscription<NavigationStateChange> _stateChangeSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeNavigationService();
    _setupSubscriptions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _deepLinkSubscription.cancel();
    _stateChangeSubscription.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.paused:
        // App is going to background - save state
        _saveNavigationState();
        break;
      case AppLifecycleState.resumed:
        // App is coming back to foreground - restore state if needed
        _restoreNavigationState();
        break;
      case AppLifecycleState.detached:
        // App is being terminated - final save
        _saveNavigationState();
        break;
      default:
        break;
    }
  }

  Future<void> _initializeNavigationService() async {
    try {
      await _navigationService.initialize();
    } catch (e) {
      debugPrint('Failed to initialize navigation service: $e');
    }
  }

  void _setupSubscriptions() {
    _deepLinkSubscription = _navigationService.deepLinkStream.listen(
      (event) {
        widget.onDeepLink?.call(event);
        _handleDeepLinkEvent(event);
      },
      onError: (error) {
        debugPrint('Deep link stream error: $error');
      },
    );

    _stateChangeSubscription = _navigationService.stateChangeStream.listen(
      (event) {
        widget.onStateChange?.call(event);
        _handleStateChangeEvent(event);
      },
      onError: (error) {
        debugPrint('State change stream error: $error');
      },
    );
  }

  void _handleDeepLinkEvent(DeepLinkEvent event) {
    // Log deep link for analytics/debugging
    debugPrint('Deep link handled: ${event.deepLink}');
    
    // You can add additional deep link handling logic here
    // such as analytics tracking, user notifications, etc.
  }

  void _handleStateChangeEvent(NavigationStateChange event) {
    // Log state change for analytics/debugging
    debugPrint('Navigation state changed: ${event.previousTab} -> ${event.currentTab}');
    
    // You can add additional state change handling logic here
    // such as analytics tracking, preloading data for new tab, etc.
  }

  Future<void> _saveNavigationState() async {
    try {
      // Save current scroll positions
      final currentContext = context;
      if (currentContext.mounted) {
        _saveScrollPositions(currentContext);
      }
      
      // The navigation service will handle persistence automatically
    } catch (e) {
      debugPrint('Failed to save navigation state: $e');
    }
  }

  Future<void> _restoreNavigationState() async {
    try {
      // The navigation service handles restoration automatically during initialization
      // Additional restoration logic can be added here if needed
    } catch (e) {
      debugPrint('Failed to restore navigation state: $e');
    }
  }

  void _saveScrollPositions(BuildContext context) {
    // Find all scroll controllers in the widget tree and save their positions
    // This is a simplified implementation - in practice, you might want to
    // register scroll controllers with specific keys
    
    final scrollableWidgets = <ScrollController>[];
    
    void findScrollControllers(Element element) {
      final widget = element.widget;
      if (widget is Scrollable && widget.controller != null) {
        scrollableWidgets.add(widget.controller!);
      }
      element.visitChildren(findScrollControllers);
    }
    
    try {
      context.visitChildElements(findScrollControllers);
      
      // Save positions using navigation service
      for (int i = 0; i < scrollableWidgets.length; i++) {
        final controller = scrollableWidgets[i];
        if (controller.hasClients) {
          _navigationService.preserveScrollPosition(
            'scroll_$i',
            controller.offset,
          );
        }
      }
    } catch (e) {
      debugPrint('Error saving scroll positions: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return NavigationStateProvider(
      navigationService: _navigationService,
      child: widget.child,
    );
  }
}

/// Provider widget that makes navigation service available to child widgets
class NavigationStateProvider extends InheritedWidget {
  final EnhancedNavigationService navigationService;

  const NavigationStateProvider({
    super.key,
    required this.navigationService,
    required super.child,
  });

  static NavigationStateProvider? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<NavigationStateProvider>();
  }

  static EnhancedNavigationService? serviceOf(BuildContext context) {
    return of(context)?.navigationService;
  }

  @override
  bool updateShouldNotify(NavigationStateProvider oldWidget) {
    return navigationService != oldWidget.navigationService;
  }
}

/// Mixin for widgets that need to preserve scroll state
mixin ScrollStateMixin<T extends StatefulWidget> on State<T> {
  ScrollController? _scrollController;
  String get scrollKey;

  ScrollController get scrollController {
    _scrollController ??= _getOrCreateScrollController();
    return _scrollController!;
  }

  ScrollController _getOrCreateScrollController() {
    final navigationService = NavigationStateProvider.serviceOf(context);
    if (navigationService != null) {
      return navigationService.getScrollController(scrollKey);
    }
    return ScrollController();
  }

  @override
  void dispose() {
    // Don't dispose the controller here as it's managed by the navigation service
    super.dispose();
  }
}

/// Mixin for widgets that need to preserve general state
mixin NavigationStateMixin<T extends StatefulWidget> on State<T> {
  
  /// Save data that should be preserved across navigation
  void preserveData(String key, dynamic value) {
    final navigationService = NavigationStateProvider.serviceOf(context);
    navigationService?.setCurrentTabPreservedData(key, value);
  }

  /// Retrieve preserved data
  dynamic getPreservedData(String key) {
    final navigationService = NavigationStateProvider.serviceOf(context);
    return navigationService?.getCurrentTabPreservedData()[key];
  }

  /// Get all preserved data for current tab
  Map<String, dynamic> getAllPreservedData() {
    final navigationService = NavigationStateProvider.serviceOf(context);
    return navigationService?.getCurrentTabPreservedData() ?? {};
  }
}

/// Widget that automatically preserves its scroll position
class PreservedScrollView extends StatefulWidget {
  final String scrollKey;
  final Widget child;
  final ScrollController? controller;
  final Axis scrollDirection;
  final bool reverse;
  final ScrollPhysics? physics;

  const PreservedScrollView({
    super.key,
    required this.scrollKey,
    required this.child,
    this.controller,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.physics,
  });

  @override
  State<PreservedScrollView> createState() => _PreservedScrollViewState();
}

class _PreservedScrollViewState extends State<PreservedScrollView>
    with ScrollStateMixin {
  
  @override
  String get scrollKey => widget.scrollKey;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: widget.controller ?? scrollController,
      scrollDirection: widget.scrollDirection,
      reverse: widget.reverse,
      physics: widget.physics,
      child: widget.child,
    );
  }
}

/// Helper functions for navigation
class NavigationHelper {
  /// Navigate to temple detail with proper deep link generation
  static Future<void> navigateToTemple(
    BuildContext context,
    String templeId, {
    String? tab,
    Map<String, String>? additionalParams,
  }) async {
    final navigationService = NavigationStateProvider.serviceOf(context);
    if (navigationService != null) {
      await navigationService.navigateToRoute(
        0, // Temple tab
        '/temple_detail',
        parameters: {
          'temple_id': templeId,
          if (tab != null) 'tab': tab,
          ...?additionalParams,
        },
      );
    }
  }

  /// Navigate to search with filters
  static Future<void> navigateToSearch(
    BuildContext context, {
    String? query,
    Map<String, dynamic>? filters,
  }) async {
    final navigationService = NavigationStateProvider.serviceOf(context);
    if (navigationService != null) {
      await navigationService.navigateToRoute(
        0, // Temple tab
        '/search',
        parameters: {
          if (query != null) 'query': query,
          ...?filters,
        },
      );
    }
  }

  /// Generate shareable deep link for current state
  static String generateCurrentStateLink(BuildContext context) {
    final navigationService = NavigationStateProvider.serviceOf(context);
    return navigationService?.generateCurrentStateDeepLink() ?? 'https://swastik.app/';
  }

  /// Handle incoming deep link
  static Future<DeepLinkResult> handleDeepLink(
    BuildContext context,
    String deepLink,
  ) async {
    final navigationService = NavigationStateProvider.serviceOf(context);
    if (navigationService != null) {
      return await navigationService.handleDeepLink(deepLink);
    }
    return DeepLinkResult(success: false, error: 'Navigation service not available');
  }
}