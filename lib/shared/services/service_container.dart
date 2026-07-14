import 'package:flutter/foundation.dart';
import 'supabase_notification_service.dart';
import 'location_service.dart';
import 'connectivity_service.dart';
import 'realtime_service.dart';
import 'automatic_notification_service.dart';
import 'fcm_service.dart';
import '../../features/temple/services/temple_service.dart';
import '../../features/user/services/booking_service.dart';
import '../../features/user/services/donation_service.dart';
import 'community_service.dart';
import '../../features/admin/services/admin_notification_service.dart';

/// Centralized service container to prevent multiple instantiations
/// All services are singletons and accessed through this container
/// This eliminates duplicate service creation and ensures consistent state
///
/// Usage:
/// ```dart
/// // Instead of: NotificationService()
/// services.notificationService.getUnreadCount()
///
/// // Instead of: LocationService()
/// services.locationService.getCurrentLocation()
/// ```
class ServiceContainer {
  static final ServiceContainer _instance = ServiceContainer._internal();

  factory ServiceContainer() => _instance;
  ServiceContainer._internal();

  // Lazy-initialized services (created only when first accessed)
  late final SupabaseNotificationService _notificationService =
      SupabaseNotificationService();
  late final LocationService _locationService = LocationService();
  late final ConnectivityService _connectivityService = ConnectivityService();
  late final RealtimeService _realtimeService = RealtimeService();
  late final TempleService _templeService = TempleService();
  late final BookingService _bookingService = BookingService();
  late final DonationService _donationService = DonationService();
  late final CommunityService _communityService = CommunityService();
  late final AdminNotificationService _adminNotificationService =
      AdminNotificationService();
  late final AutomaticNotificationService _automaticNotificationService =
      AutomaticNotificationService();

  bool _initialized = false;

  // Public getters - all return the same singleton instance
  SupabaseNotificationService get notificationService => _notificationService;
  LocationService get locationService => _locationService;
  ConnectivityService get connectivityService => _connectivityService;
  RealtimeService get realtimeService => _realtimeService;
  TempleService get templeService => _templeService;
  BookingService get bookingService => _bookingService;
  DonationService get donationService => _donationService;
  CommunityService get communityService => _communityService;
  AdminNotificationService get adminNotificationService =>
      _adminNotificationService;
  AutomaticNotificationService get automaticNotificationService =>
      _automaticNotificationService;

  /// Initialize all services (call once at app startup in main.dart)
  /// Prevents multiple initialize() calls
  /// Note: NotificationService is initialized separately in main.dart with userId
  Future<void> initializeAll() async {
    if (_initialized) {
      debugPrint('⚠️ ServiceContainer already initialized, skipping...');
      return;
    }

    try {
      debugPrint('🔄 Initializing ServiceContainer...');

      await Future.wait([
        // NotificationService is initialized in main.dart with userId
        Future(() => _locationService.initialize()),
        Future(() => _connectivityService.initialize()),
        Future(() => _adminNotificationService.initialize()),
        Future(() => FCMService().initialize()),
        Future(() => _automaticNotificationService.initialize()),
      ]);

      _initialized = true;
      debugPrint('✅ ServiceContainer initialized successfully');
    } catch (e) {
      debugPrint('❌ Error initializing ServiceContainer: $e');
      rethrow;
    }
  }

  /// Dispose all services (call at app shutdown)
  Future<void> disposeAll() async {
    try {
      debugPrint('🔄 Disposing ServiceContainer...');

      await Future.wait([
        Future(() => _notificationService.dispose()),
        Future(() => _locationService.dispose()),
        Future(() => _connectivityService.dispose()),
        Future(() => _realtimeService.dispose()),
        Future(() => _adminNotificationService.dispose()),
        Future(() => _automaticNotificationService.dispose()),
        Future(() => FCMService().dispose()),
      ]);

      _initialized = false;
      debugPrint('✅ ServiceContainer disposed');
    } catch (e) {
      debugPrint('❌ Error disposing ServiceContainer: $e');
    }
  }

  /// Check if services are initialized
  bool get isInitialized => _initialized;
}

/// Global singleton instance - access services from anywhere
final services = ServiceContainer();
