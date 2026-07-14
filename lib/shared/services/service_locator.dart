import 'package:flutter/foundation.dart';
import 'cache/data_cache_manager.dart';
import 'cache/image_cache_manager.dart';
import 'offline/offline_manager.dart';
import 'offline/sync_service.dart';
import 'navigation/main_navigation_service.dart';
import 'preloader/resource_preloader.dart';
import '../../features/user/services/user_preferences_service.dart';
import '../../features/user/services/donation_service.dart';
import 'event_service.dart';

/// Simple service locator without memory optimization
class ServiceLocator {
  static final ServiceLocator _instance = ServiceLocator._internal();
  factory ServiceLocator() => _instance;
  ServiceLocator._internal();

  bool _initialized = false;

  /// Initialize service locator
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    if (kDebugMode) {
      print('ServiceLocator: Initialized successfully');
    }
  }

  // Service instances
  final Map<Type, Object> _services = {};

  /// Get data cache manager - Lazy loaded
  DataCacheManager get dataCache {
    _ensureInitialized();
    return _services.putIfAbsent(DataCacheManager, () => DataCacheManager())
        as DataCacheManager;
  }

  /// Get offline manager
  OfflineManager get offlineManager {
    _ensureInitialized();
    return _services.putIfAbsent(OfflineManager, () => OfflineManager())
        as OfflineManager;
  }

  /// Get sync service - Lazy loaded
  SyncService get syncService {
    _ensureInitialized();
    return _services.putIfAbsent(SyncService, () => SyncService())
        as SyncService;
  }

  /// Get main navigation service
  MainNavigationService get mainNavigation {
    _ensureInitialized();
    return _services.putIfAbsent(
          MainNavigationService,
          () => MainNavigationService.instance,
        )
        as MainNavigationService;
  }

  /// Get user preferences service
  UserPreferencesService get userPreferences {
    _ensureInitialized();
    return _services.putIfAbsent(
          UserPreferencesService,
          () => UserPreferencesService(),
        )
        as UserPreferencesService;
  }

  /// Get donation service - Lazy loaded
  DonationService get donationService {
    _ensureInitialized();
    return _services.putIfAbsent(DonationService, () => DonationService())
        as DonationService;
  }

  /// Get event service - Lazy loaded
  EventService get eventService {
    _ensureInitialized();
    return _services.putIfAbsent(EventService, () => EventService())
        as EventService;
  }

  /// Get image cache manager - Lazy loaded
  ImageCacheManager get imageCache {
    _ensureInitialized();
    return _services.putIfAbsent(ImageCacheManager, () => ImageCacheManager())
        as ImageCacheManager;
  }

  /// Get data preloader - Lazy loaded
  ResourcePreloader get dataPreloader {
    _ensureInitialized();
    return _services.putIfAbsent(ResourcePreloader, () => ResourcePreloader())
        as ResourcePreloader;
  }

  /// Get predictive data loader - Lazy loaded
  ResourcePreloader get predictiveDataLoader {
    _ensureInitialized();
    return _services.putIfAbsent(ResourcePreloader, () => ResourcePreloader())
        as ResourcePreloader;
  }

  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError(
        'ServiceLocator not initialized. Call initialize() first.',
      );
    }
  }

  /// Dispose all services
  Future<void> dispose() async {
    if (!_initialized) return;

    // Dispose all services that have dispose method
    for (final service in _services.values) {
      if (service is ChangeNotifier) {
        service.dispose();
      }
    }

    _services.clear();
    _initialized = false;

    if (kDebugMode) {
      print('ServiceLocator: All services disposed successfully');
    }
  }
}
