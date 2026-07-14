import '../../shared/services/notification_service.dart';
import '../../shared/services/community_service.dart';
import '../../features/user/services/donation_service.dart';
import '../../features/user/services/booking_service.dart';
import '../../features/temple/services/user_temple_service.dart';
import '../../shared/services/location_service.dart';
import '../../features/user/services/location_select_service.dart';
import '../../features/user/services/user_preferences_service.dart';

/// Centralized service container to prevent multiple service instantiations
/// and ensure consistent state across the application.
///
/// Usage:
/// ```dart
/// final services = Services.instance;
/// services.notificationService.getUnreadCount();
/// ```
class Services {
  static final Services _instance = Services._internal();

  factory Services() => _instance;

  Services._internal() {
    _initializeServices();
  }

  static Services get instance => _instance;

  // Service instances
  late final NotificationService _notificationService;
  late final CommunityService _communityService;
  late final DonationService _donationService;
  late final BookingService _bookingService;
  late final UserTempleService _templeService;
  late final LocationService _locationService;
  late final LocationSelectService _locationSelectService;
  late final UserPreferencesService _preferencesService;

  bool _initialized = false;

  void _initializeServices() {
    if (_initialized) return;

    _notificationService = NotificationService();
    _communityService = CommunityService();
    _donationService = DonationService();
    _bookingService = BookingService();
    _templeService = UserTempleService();
    _locationService = LocationService();
    _locationSelectService = LocationSelectService();
    _preferencesService = UserPreferencesService();

    _initialized = true;
  }

  // Getters for services
  NotificationService get notificationService => _notificationService;
  CommunityService get communityService => _communityService;
  DonationService get donationService => _donationService;
  BookingService get bookingService => _bookingService;
  UserTempleService get templeService => _templeService;
  LocationService get locationService => _locationService;
  LocationSelectService get locationSelectService => _locationSelectService;
  UserPreferencesService get preferencesService => _preferencesService;
}
