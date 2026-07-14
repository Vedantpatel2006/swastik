import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../widgets/animations/transition_manager.dart';
import '../../widgets/animations/app_animations.dart';
import 'navigation_prefetcher.dart';

/// Navigation manager with integrated preloading capabilities
class PreloadingNavigationManager {
  static PreloadingNavigationManager? _instance;
  factory PreloadingNavigationManager() =>
      _instance ??= PreloadingNavigationManager._internal();
  PreloadingNavigationManager._internal();

  DataPreloader? _dataPreloader;
  PredictiveDataLoader? _predictiveLoader;
  final NavigationPrefetcher _navigationPrefetcher = NavigationPrefetcher();

  /// Get data preloader with lazy initialization
  DataPreloader get dataPreloader {
    _dataPreloader ??= _SimpleDataPreloader();
    return _dataPreloader!;
  }

  /// Get predictive loader with lazy initialization
  PredictiveDataLoader get predictiveLoader {
    _predictiveLoader ??= _SimplePredictiveDataLoader();
    return _predictiveLoader!;
  }

  final Map<String, Timer> _preloadTimers = {};
  final Set<String> _preloadingScreens = {};
  String? _currentScreen;

  /// Navigate to a screen with preloading
  Future<T?> navigateWithPreloading<T extends Object?>(
    BuildContext context,
    Widget page, {
    String? screenName,
    TransitionType transitionType = TransitionType.slideFromRight,
    Duration duration = AppAnimations.normalDuration,
    Curve curve = AppAnimations.pageTransitionCurve,
    bool enableHeroAnimations = true,
    String? heroTag,
    RouteSettings? settings,
    bool preloadData = true,
    Duration preloadDelay = const Duration(milliseconds: 200),
    List<String>? additionalPreloadKeys,
  }) async {
    final effectiveScreenName = screenName ?? _getScreenNameFromWidget(page);

    // Track navigation action for predictive loading
    predictiveLoader.trackUserAction(
      UserActionType.screenVisit,
      effectiveScreenName,
      metadata: {'transition': transitionType.name},
    );

    // Track navigation for prefetcher
    if (_currentScreen != null) {
      _navigationPrefetcher.trackNavigation(
        _currentScreen!,
        effectiveScreenName,
      );
    }

    // Start preloading data for the target screen and related data
    if (preloadData) {
      _schedulePreload(effectiveScreenName, preloadDelay);

      // Preload additional data if specified
      if (additionalPreloadKeys != null) {
        for (final key in additionalPreloadKeys) {
          _schedulePreload(key, preloadDelay);
        }
      }

      // Use navigation prefetcher for intelligent preloading
      await _navigationPrefetcher.prefetchForScreen(effectiveScreenName);
      await _navigationPrefetcher.prefetchPredictive(effectiveScreenName);

      // Preload predictive data based on navigation patterns
      await _preloadPredictiveNavigationData(effectiveScreenName);
    }

    // Update current screen
    _currentScreen = effectiveScreenName;

    // Navigate with custom transition
    return Navigator.of(context).pushWithTransition<T>(
      page,
      transitionType: transitionType,
      duration: duration,
      curve: curve,
      enableHeroAnimations: enableHeroAnimations,
      heroTag: heroTag,
      settings: settings,
    );
  }

  /// Navigate and replace with preloading
  Future<T?>
  navigateAndReplaceWithPreloading<T extends Object?, TO extends Object?>(
    BuildContext context,
    Widget page, {
    String? screenName,
    TransitionType transitionType = TransitionType.slideFromRight,
    Duration duration = AppAnimations.normalDuration,
    Curve curve = AppAnimations.pageTransitionCurve,
    bool enableHeroAnimations = true,
    String? heroTag,
    TO? result,
    RouteSettings? settings,
    bool preloadData = true,
    Duration preloadDelay = const Duration(milliseconds: 200),
  }) async {
    final effectiveScreenName = screenName ?? _getScreenNameFromWidget(page);

    // Track navigation action
    predictiveLoader.trackUserAction(
      UserActionType.screenVisit,
      effectiveScreenName,
      metadata: {'transition': transitionType.name, 'replace': true},
    );

    // Start preloading
    if (preloadData) {
      _schedulePreload(effectiveScreenName, preloadDelay);
    }

    return Navigator.of(context).pushReplacementWithTransition<T, TO>(
      page,
      transitionType: transitionType,
      duration: duration,
      curve: curve,
      enableHeroAnimations: enableHeroAnimations,
      heroTag: heroTag,
      result: result,
      settings: settings,
    );
  }

  /// Navigate with hero animation and preloading
  Future<T?> navigateWithHeroAndPreloading<T extends Object?>(
    BuildContext context,
    Widget page, {
    required String heroTag,
    String? screenName,
    TransitionType transitionType = TransitionType.sharedElement,
    Duration duration = AppAnimations.normalDuration,
    Curve curve = AppAnimations.pageTransitionCurve,
    RouteSettings? settings,
    bool preloadData = true,
    Duration preloadDelay = const Duration(milliseconds: 100),
  }) async {
    final effectiveScreenName = screenName ?? _getScreenNameFromWidget(page);

    // Track navigation with hero animation
    predictiveLoader.trackUserAction(
      UserActionType.screenVisit,
      effectiveScreenName,
      metadata: {'transition': transitionType.name, 'hero': heroTag},
    );

    // Preload with shorter delay for hero transitions
    if (preloadData) {
      _schedulePreload(effectiveScreenName, preloadDelay);
    }

    return Navigator.of(context).pushWithHeroTransition<T>(
      page,
      heroTag: heroTag,
      transitionType: transitionType,
      duration: duration,
      curve: curve,
      settings: settings,
    );
  }

  /// Preload data for multiple screens based on navigation patterns
  Future<void> preloadNavigationData(String currentScreen) async {
    try {
      // Preload common navigation targets
      await _preloadCommonTargets(currentScreen);

      // Preload predictive data
      await _preloadPredictiveNavigationData(currentScreen);
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'PreloadingNavigationManager: Error preloading navigation data - $e',
        );
      }
    }
  }

  /// Preload predictive navigation data based on user behavior
  Future<void> _preloadPredictiveNavigationData(String currentScreen) async {
    try {
      // Use data preloader to preload predictive data
      await dataPreloader.preloadPredictiveData(currentScreen);

      // Preload images for likely next screens
      final predictedScreens = _getPredictedNextScreens(currentScreen);
      for (final screen in predictedScreens) {
        _scheduleImagePreload(screen, const Duration(milliseconds: 300));
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'PreloadingNavigationManager: Error preloading predictive data - $e',
        );
      }
    }
  }

  /// Get predicted next screens based on navigation patterns
  List<String> _getPredictedNextScreens(String currentScreen) {
    // This could be enhanced with ML-based prediction
    switch (currentScreen.toLowerCase()) {
      case 'home':
        return ['temple_detail', 'search', 'profile'];
      case 'temple_list':
        return ['temple_detail', 'search'];
      case 'temple_detail':
        return ['edit_temple', 'temple_list', 'home'];
      case 'search':
        return ['temple_detail', 'home'];
      default:
        return ['home'];
    }
  }

  /// Schedule image preloading for a screen
  void _scheduleImagePreload(String screenName, Duration delay) {
    Timer(delay, () async {
      try {
        // Preload common images for the screen
        final imageKeys = _getScreenImageKeys(screenName);
        for (final key in imageKeys) {
          await dataPreloader.getCachedOrPreload(key, () async => null);
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
            'PreloadingNavigationManager: Error preloading images for $screenName - $e',
          );
        }
      }
    });
  }

  /// Get image keys that should be preloaded for a screen
  List<String> _getScreenImageKeys(String screenName) {
    switch (screenName.toLowerCase()) {
      case 'temple_detail':
        return ['temple_images', 'temple_thumbnails'];
      case 'temple_list':
        return ['temple_list_thumbnails'];
      case 'profile':
        return ['user_avatar', 'profile_images'];
      default:
        return [];
    }
  }

  /// Schedule preloading for a specific screen
  void _schedulePreload(String screenName, Duration delay) {
    // Cancel existing timer for this screen
    _preloadTimers[screenName]?.cancel();

    _preloadTimers[screenName] = Timer(delay, () {
      _executePreload(screenName);
      _preloadTimers.remove(screenName);
    });
  }

  /// Execute preloading for a screen
  Future<void> _executePreload(String screenName) async {
    if (_preloadingScreens.contains(screenName)) {
      return; // Already preloading
    }

    _preloadingScreens.add(screenName);

    try {
      await dataPreloader.preloadForScreen(screenName);

      if (kDebugMode) {
        debugPrint(
          'PreloadingNavigationManager: Preloaded data for $screenName',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'PreloadingNavigationManager: Failed to preload $screenName - $e',
        );
      }
    } finally {
      _preloadingScreens.remove(screenName);
    }
  }

  /// Preload common navigation targets based on current screen
  Future<void> _preloadCommonTargets(String currentScreen) async {
    final targets = _getCommonNavigationTargets(currentScreen);

    for (final target in targets) {
      _schedulePreload(target, const Duration(milliseconds: 500));
    }
  }

  /// Get common navigation targets for a screen
  List<String> _getCommonNavigationTargets(String currentScreen) {
    switch (currentScreen.toLowerCase()) {
      case 'home':
      case 'temple_list':
        return ['temple_detail', 'search', 'profile'];
      case 'temple_detail':
        return ['home', 'temple_list', 'edit_temple'];
      case 'search':
        return ['temple_detail', 'home'];
      case 'profile':
        return ['settings', 'home'];
      case 'login':
      case 'signup':
        return ['home', 'temple_list'];
      default:
        return ['home'];
    }
  }

  /// Extract screen name from widget type
  String _getScreenNameFromWidget(Widget widget) {
    final widgetType = widget.runtimeType.toString();

    // Convert widget class name to screen name
    return widgetType
        .replaceAll('Screen', '')
        .replaceAll('Page', '')
        .replaceAllMapped(
          RegExp(r'([A-Z])'),
          (match) => '_${match.group(1)!.toLowerCase()}',
        )
        .substring(1); // Remove leading underscore
  }

  /// Get navigation statistics
  Map<String, dynamic> getStatistics() {
    return {
      'activePreloadTimers': _preloadTimers.length,
      'preloadingScreens': _preloadingScreens.length,
      'dataPreloaderStats': dataPreloader.getStatistics(),
      'predictiveLoaderStats': predictiveLoader.getStatistics(),
    };
  }

  /// Clear all preload timers
  void clearPreloadTimers() {
    for (final timer in _preloadTimers.values) {
      timer.cancel();
    }
    _preloadTimers.clear();
    _preloadingScreens.clear();

    if (kDebugMode) {
      debugPrint('PreloadingNavigationManager: Cleared all preload timers');
    }
  }

  /// Dispose resources
  void dispose() {
    clearPreloadTimers();

    if (kDebugMode) {
      debugPrint('PreloadingNavigationManager: Disposed');
    }
  }
}

/// Extension on BuildContext for easy access to preloading navigation
extension PreloadingNavigationExtension on BuildContext {
  PreloadingNavigationManager get preloadingNav =>
      PreloadingNavigationManager();

  /// Navigate with preloading using context
  Future<T?> navigateWithPreloading<T extends Object?>(
    Widget page, {
    String? screenName,
    TransitionType transitionType = TransitionType.slideFromRight,
    Duration duration = AppAnimations.normalDuration,
    Curve curve = AppAnimations.pageTransitionCurve,
    bool enableHeroAnimations = true,
    String? heroTag,
    RouteSettings? settings,
    bool preloadData = true,
    Duration preloadDelay = const Duration(milliseconds: 200),
  }) {
    return preloadingNav.navigateWithPreloading<T>(
      this,
      page,
      screenName: screenName,
      transitionType: transitionType,
      duration: duration,
      curve: curve,
      enableHeroAnimations: enableHeroAnimations,
      heroTag: heroTag,
      settings: settings,
      preloadData: preloadData,
      preloadDelay: preloadDelay,
    );
  }

  /// Navigate and replace with preloading using context
  Future<T?>
  navigateAndReplaceWithPreloading<T extends Object?, TO extends Object?>(
    Widget page, {
    String? screenName,
    TransitionType transitionType = TransitionType.slideFromRight,
    Duration duration = AppAnimations.normalDuration,
    Curve curve = AppAnimations.pageTransitionCurve,
    bool enableHeroAnimations = true,
    String? heroTag,
    TO? result,
    RouteSettings? settings,
    bool preloadData = true,
    Duration preloadDelay = const Duration(milliseconds: 200),
  }) {
    return preloadingNav.navigateAndReplaceWithPreloading<T, TO>(
      this,
      page,
      screenName: screenName,
      transitionType: transitionType,
      duration: duration,
      curve: curve,
      enableHeroAnimations: enableHeroAnimations,
      heroTag: heroTag,
      result: result,
      settings: settings,
      preloadData: preloadData,
      preloadDelay: preloadDelay,
    );
  }

  /// Navigate with hero animation and preloading using context
  Future<T?> navigateWithHeroAndPreloading<T extends Object?>(
    Widget page, {
    required String heroTag,
    String? screenName,
    TransitionType transitionType = TransitionType.sharedElement,
    Duration duration = AppAnimations.normalDuration,
    Curve curve = AppAnimations.pageTransitionCurve,
    RouteSettings? settings,
    bool preloadData = true,
    Duration preloadDelay = const Duration(milliseconds: 100),
  }) {
    return preloadingNav.navigateWithHeroAndPreloading<T>(
      this,
      page,
      heroTag: heroTag,
      screenName: screenName,
      transitionType: transitionType,
      duration: duration,
      curve: curve,
      settings: settings,
      preloadData: preloadData,
      preloadDelay: preloadDelay,
    );
  }
}

/// Simple DataPreloader implementation
class _SimpleDataPreloader implements DataPreloader {
  @override
  Map<String, dynamic> getStatistics() {
    return {'preloadedItems': 0, 'cacheHits': 0, 'cacheMisses': 0};
  }

  @override
  Future<void> preloadPredictiveData(
    String screenName, {
    Map<String, dynamic>? metadata,
  }) async {
    // Simple stub implementation - does nothing
  }

  @override
  Future<T?> getCachedOrPreload<T>(
    String key,
    Future<T> Function() loader,
  ) async {
    // Simple stub implementation - just call the loader
    return await loader();
  }

  @override
  Future<void> preloadForScreen(String screenName) async {
    // Simple stub implementation - does nothing
  }
}

/// Simple PredictiveDataLoader implementation
class _SimplePredictiveDataLoader implements PredictiveDataLoader {
  @override
  void trackUserAction(
    UserActionType type,
    String screenName, {
    Map<String, dynamic>? metadata,
  }) {
    // Simple stub implementation - does nothing
  }

  @override
  Map<String, dynamic> getStatistics() {
    return {'trackedActions': 0, 'predictions': 0, 'accuracy': 0.0};
  }
}

/// Simple UserActionType enum
enum UserActionType { screenVisit, buttonTap, scroll, search }

/// Abstract classes for type safety
abstract class DataPreloader {
  Map<String, dynamic> getStatistics();
  Future<void> preloadPredictiveData(
    String screenName, {
    Map<String, dynamic>? metadata,
  });
  Future<T?> getCachedOrPreload<T>(String key, Future<T> Function() loader);
  Future<void> preloadForScreen(String screenName);
}

abstract class PredictiveDataLoader {
  void trackUserAction(
    UserActionType type,
    String screenName, {
    Map<String, dynamic>? metadata,
  });
  Map<String, dynamic> getStatistics();
}
