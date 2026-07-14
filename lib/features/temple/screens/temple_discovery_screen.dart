import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:swastik/core/themes/app_colors.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:iconly/iconly.dart';
import '../../../shared/models/temple.dart';
import '../../../shared/models/temple_filters.dart';
import '../services/user_temple_service.dart';
import '../../../shared/services/location_service.dart';
import '../../../shared/services/service_container.dart';
import '../../../features/user/services/user_preferences_service.dart';
import '../widgets/temple_card.dart';
import '../../../shared/widgets/deity_image_widget.dart';
import '../../../shared/constants/deity_assets.dart';
import 'temple_detail_screen.dart';
import 'temple_search_screen.dart';

import '../../../shared/widgets/error/index.dart';
import '../../../shared/widgets/animations/app_animations.dart';
import '../../../shared/widgets/base/optimized_stateful_widget.dart';
import '../../../shared/widgets/performance/build_optimization_mixin.dart';
import '../../../shared/widgets/offline_indicator.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/loading/skeleton_loader.dart';
import '../../../shared/widgets/optimized_list_view.dart';
import '../../../shared/widgets/iconly_animated_icon.dart';
import '../../user/screens/notifications_screen.dart';

/// Advanced temple discovery screen with search, filters, map view, and sorting
class TempleDiscoveryScreen extends OptimizedStatefulWidget {
  const TempleDiscoveryScreen({super.key});

  @override
  State<TempleDiscoveryScreen> createState() => _TempleDiscoveryScreenState();
}

class _TempleDiscoveryScreenState extends OptimizedState<TempleDiscoveryScreen>
    with
        TickerProviderStateMixin,
        BuildOptimizationMixin<TempleDiscoveryScreen> {
  // Services
  final UserTempleService _templeService = UserTempleService();
  final LocationService _locationService = LocationService();
  final UserPreferencesService _preferencesService = UserPreferencesService();

  // Controllers
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // State variables
  List<Temple> _temples = [];
  List<Temple> _filteredTemples = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMoreData = true;
  String? _error;
  Timer? _searchDebounce;
  Location? _userLocation;
  String? _currentUserId;

  // Stream subscriptions
  StreamSubscription<Location>? _locationSubscription;

  // Animation controllers
  late AnimationController _searchAnimationController;
  late AnimationController _listController;
  late AnimationController _loadingController;
  int _currentPage = 0;

  // Filter state
  TempleFilters _currentFilters = const TempleFilters();

  // Deity category filter
  // TODO: Move deity filter into TempleFilters model for better cache correctness
  // and service-layer filtering instead of UI-layer filtering
  String _selectedDeity = 'All';

  // Constants
  static const int _pageSize = 20;
  static const double _loadMoreThreshold = 0.8;

  // Keys
  static const _kSearchFieldKey = Key('temple_search_field');

  @override
  void initState() {
    super.initState();

    // Note: Removed immersive mode - it breaks navigation gestures
    // Use immersive mode only for video/live darshan screens

    _initializeAnimations();
    _loadInitialData();

    // Get current user ID for notifications
    final user = FirebaseAuth.instance.currentUser;
    _currentUserId = user?.uid;

    // Log performance metrics in debug mode
    if (kDebugMode) {
      developer.log(
        'Initializing TempleDiscoveryScreen',
        name: 'TempleDiscoveryScreen',
      );
    }
  }

  void _loadInitialData() {
    // Note: Search is handled by navigation to search screen
    // Scroll pagination is handled by NotificationListener
    _initializeScreen();
  }

  Future<void> _loadTemples({bool reset = false}) async {
    if (reset) {
      setState(() {
        _isLoading = true;
        _currentPage = 0;
        _hasMoreData = true;
        _temples.clear();
        _filteredTemples.clear();
        _error = null;
      });

      // Invalidate caches when resetting
      invalidateAllCaches();
    } else {
      setState(() {
        _isLoadingMore = true;
      });
    }

    try {
      // Cache expensive filter creation with deity filter
      final filters = computeOnce(
        'filtersWithLocation',
        () {
          return _currentFilters.copyWith(userLocation: _userLocation);
        },
        dependencies: [_currentFilters, _userLocation, _selectedDeity],
      );

      List<Temple> newTemples;
      if (_searchController.text.isNotEmpty) {
        if (kDebugMode) {
          debugPrint(
            'Searching temples with query: "${_searchController.text}"',
          );
        }
        newTemples = await _templeService.searchTemples(
          _searchController.text,
          filters: filters,
        );
      } else {
        if (kDebugMode) {
          debugPrint('Loading all temples with filters');
        }
        // Get all temples with filters
        newTemples = await _templeService.searchTemples('', filters: filters);
      }

      // Apply deity filter after getting temples
      // TODO: Move this filtering to service layer (UserTempleService.searchTemples)
      // This will enable Firestore-side filtering and better performance
      if (_selectedDeity != 'All') {
        newTemples = newTemples.where((temple) {
          return DeityAssets.matchesDeity(temple.mainDeity, _selectedDeity);
        }).toList();
      }

      if (kDebugMode) {
        debugPrint('Search completed: Found ${newTemples.length} temples');
        debugPrint('Current filters: ${filters.toString()}');
        debugPrint('Selected deity: $_selectedDeity');
      }

      // Cache pagination computation
      // TODO: This is not real pagination - it loads all temples and slices in memory
      // For production scalability, UserTempleService.searchTemples() should support:
      // searchTemples(query, filters, page: _currentPage, limit: _pageSize)
      // This will enable Firestore-side pagination and reduce memory usage
      final paginationResult = computeOnce(
        'paginationResult_$_currentPage',
        () {
          final startIndex = _currentPage * _pageSize;
          return newTemples.skip(startIndex).take(_pageSize).toList();
        },
        dependencies: [newTemples, _currentPage, _pageSize],
      );

      if (mounted) {
        setState(() {
          if (reset) {
            _temples = paginationResult;
          } else {
            _temples.addAll(paginationResult);
          }
          _filteredTemples = List.from(_temples);
          _hasMoreData = paginationResult.length == _pageSize;
          _currentPage++;
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    } catch (e, stackTrace) {
      // Log actual error for debugging
      developer.log(
        'Failed to load temples',
        error: e,
        stackTrace: stackTrace,
        name: 'TempleDiscoveryScreen',
      );

      if (mounted) {
        setState(() {
          _error =
              'Unable to load temples. Please check your internet connection.';
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _loadMoreTemples() async {
    if (_isLoadingMore || !_hasMoreData) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      await _loadTemples();
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  void _initializeAnimations() {
    _searchAnimationController = AnimationController(
      duration: AppAnimations.fastDuration,
      vsync: this,
    );

    _listController = AnimationController(
      duration: AppAnimations.normalDuration,
      vsync: this,
    );

    _loadingController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _loadingController.repeat();
  }

  @override
  void dispose() {
    // Cancel any pending operations
    _searchDebounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    _searchAnimationController.dispose();
    _listController.dispose();
    _loadingController.dispose();
    _locationSubscription?.cancel();

    super.dispose();

    // Log performance metrics in debug mode
    if (kDebugMode) {
      developer.log(
        'TempleDiscoveryScreen disposed',
        name: 'TempleDiscoveryScreen',
      );
    }
  }

  Future<void> _initializeScreen() async {
    try {
      // Initialize services
      await _templeService.initialize();
      await _locationService.initialize();
      await _preferencesService.initialize();

      // Load user preferences and location
      await _loadUserPreferences();
      await _loadUserLocation();

      // Load initial temples
      await _loadTemples(reset: true);
    } catch (e, stackTrace) {
      developer.log(
        'Failed to initialize screen',
        error: e,
        stackTrace: stackTrace,
        name: 'TempleDiscoveryScreen',
      );

      if (mounted) {
        setState(() {
          _error = 'Unable to initialize. Please restart the app.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadUserPreferences() async {
    try {
      await _preferencesService.getUserPreferences();
    } catch (e) {
      debugPrint('Failed to load user preferences: $e');
    }
  }

  Future<void> _loadUserLocation() async {
    try {
      // Get initial location with better geocoding
      final location = await _locationService.getCurrentLocation();
      if (mounted && location != null) {
        setState(() {
          _userLocation = location;
        });

        if (kDebugMode) {
          debugPrint(
            'Temple Discovery: Got location - address: "${location.address}", city: "${location.city}", state: "${location.state}"',
          );
        }

        // If we got coordinates but no proper address, try to get better address info
        if (location.address == null ||
            location.address!.isEmpty ||
            location.city == null ||
            location.city!.isEmpty ||
            location.city == 'Unknown') {
          _tryToImproveLocationAddress(location);
        }
      } else {
        if (kDebugMode) {
          debugPrint('Temple Discovery: No location received from service');
        }

        // For testing purposes, provide a fallback location
        if (kDebugMode) {
          setState(() {
            _userLocation = const Location(
              latitude: 23.0225,
              longitude: 72.5714,
              address: 'Ahmedabad, Gujarat',
              city: 'Ahmedabad',
              state: 'Gujarat',
              country: 'India',
            );
          });
          debugPrint('Temple Discovery: Using fallback test location');
        }
      }

      // Start watching location for real-time updates
      _locationSubscription = _locationService.watchLocation().listen(
        (newLocation) {
          if (kDebugMode) {
            debugPrint(
              'Location watcher: Got new location - address: "${newLocation.address}", city: "${newLocation.city}", state: "${newLocation.state}"',
            );
          }

          if (mounted && newLocation != _userLocation) {
            // Only update if the new location has better or equal information
            final shouldUpdate = _shouldUpdateLocation(
              _userLocation,
              newLocation,
            );

            if (shouldUpdate) {
              if (kDebugMode) {
                debugPrint('Location watcher: Updating location');
              }

              // Calculate distance before updating location
              final oldLocation = _userLocation;
              setState(() {
                _userLocation = newLocation;
              });

              // Refresh temples when location changes significantly
              if (oldLocation != null) {
                _locationService
                    .calculateDistance(oldLocation, newLocation)
                    .then((dist) {
                      if (mounted && dist > 1.0) {
                        // If moved more than 1km, refresh
                        _loadTemples(reset: true);
                      }
                    });
              }
            } else {
              if (kDebugMode) {
                debugPrint(
                  'Location watcher: Skipping update - new location has less information',
                );
              }
            }
          }
        },
        onError: (error) {
          debugPrint('Location stream error: $error');
        },
      );
    } catch (e) {
      debugPrint('Failed to get user location: $e');

      // For testing purposes, provide a fallback location
      if (kDebugMode && mounted) {
        setState(() {
          _userLocation = const Location(
            latitude: 23.0225,
            longitude: 72.5714,
            address: 'Ahmedabad, Gujarat',
            city: 'Ahmedabad',
            state: 'Gujarat',
            country: 'India',
          );
        });
        debugPrint(
          'Temple Discovery: Using fallback test location due to error',
        );
      }
    }
  }

  /// Try to improve location address information
  Future<void> _tryToImproveLocationAddress(Location location) async {
    try {
      // Wait a bit and try to get better address info
      await Future.delayed(const Duration(milliseconds: 1000));
      final betterAddress = await _locationService.getFormattedAddress(
        location,
      );
      final city = await _locationService.getCityFromLocation(location);

      if (mounted && (betterAddress != null || city != null)) {
        setState(() {
          _userLocation = Location(
            latitude: location.latitude,
            longitude: location.longitude,
            address: betterAddress ?? location.address,
            city: city ?? location.city,
            state: location.state,
            country: location.country ?? 'India',
            postalCode: location.postalCode,
          );
        });

        if (kDebugMode) {
          debugPrint('Improved location address: ${_userLocation?.address}');
          debugPrint('Improved location city: ${_userLocation?.city}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to improve location address: $e');
      }
    }
  }

  /// Determine if we should update the current location with a new one
  bool _shouldUpdateLocation(Location? currentLocation, Location newLocation) {
    // If we don't have a current location, always update
    if (currentLocation == null) {
      return true;
    }

    // If the new location has address information and current doesn't, update
    if (newLocation.address != null &&
        newLocation.address!.isNotEmpty &&
        (currentLocation.address == null || currentLocation.address!.isEmpty)) {
      return true;
    }

    // If the new location has city/state and current doesn't, update
    if ((newLocation.city != null && newLocation.city!.isNotEmpty) &&
        (currentLocation.city == null || currentLocation.city!.isEmpty)) {
      return true;
    }

    // If both have address info, check if coordinates are significantly different
    if (currentLocation.address != null && newLocation.address != null) {
      final latDiff = (currentLocation.latitude - newLocation.latitude).abs();
      final lngDiff = (currentLocation.longitude - newLocation.longitude).abs();

      // Update if moved more than ~100 meters (0.001 degrees ≈ 111 meters)
      return latDiff > 0.001 || lngDiff > 0.001;
    }

    // Don't update if new location has less information
    if ((currentLocation.address != null &&
            currentLocation.address!.isNotEmpty) &&
        (newLocation.address == null || newLocation.address!.isEmpty)) {
      return false;
    }

    // Default to updating
    return true;
  }

  /// Get a user-friendly location display text
  String _getLocationDisplayText(Location? location) {
    if (location == null) {
      return 'Tap to select location';
    }

    if (kDebugMode) {
      debugPrint(
        '_getLocationDisplayText: address="${location.address}", city="${location.city}", state="${location.state}"',
      );
    }

    // First priority: use the formatted address if available
    if (location.address != null &&
        location.address!.isNotEmpty &&
        location.address != 'Current Location' &&
        !location.address!.contains('(') && // Avoid coordinate strings
        location.address!.length > 3) {
      if (kDebugMode) {
        debugPrint(
          '_getLocationDisplayText: Using address: ${location.address}',
        );
      }
      return location.address!;
    }

    // Second priority: build from city and state
    final parts = <String>[];
    if (location.city != null &&
        location.city!.isNotEmpty &&
        location.city != 'Unknown' &&
        location.city!.length > 1) {
      parts.add(location.city!);
    }
    if (location.state != null &&
        location.state!.isNotEmpty &&
        location.state != 'Unknown' &&
        location.state!.length > 1 &&
        !parts.contains(location.state!)) {
      parts.add(location.state!);
    }

    if (parts.isNotEmpty) {
      final result = parts.join(', ');
      if (kDebugMode) {
        debugPrint('_getLocationDisplayText: Using city/state: $result');
      }
      return result;
    }

    // Third priority: if we have coordinates, show a generic message
    if (location.latitude != 0.0 || location.longitude != 0.0) {
      if (kDebugMode) {
        debugPrint('_getLocationDisplayText: Falling back to Current Location');
      }
      return 'Current Location';
    }

    return 'Tap to select location';
  }

  // Removed _onSearchChanged() - search is handled by navigation to search screen
  // Removed _onScroll() - scroll pagination handled by NotificationListener

  void _onTempleCardTap(Temple temple) {
    // Navigate to temple detail using direct navigation (safer than named routes)
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TempleDetailScreen(temple: temple)),
    );
  }

  void _navigateToTempleDetails(Temple temple) {
    _onTempleCardTap(temple);
  }

  void _toggleFilters() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color.fromARGB(255, 255, 152, 0),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    const Text(
                      'Filter Temples',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(IconlyBold.delete, color: Colors.white),
                    ),
                  ],
                ),
              ),
              // Filter content
              Expanded(child: _buildSimpleFilters(setModalState)),
            ],
          ),
        ),
      ),
    );
  }

  void _applyFilters(TempleFilters filters) {
    if (kDebugMode) {
      debugPrint('Applying filters: ${filters.toString()}');
    }

    setState(() {
      _currentFilters = filters;
    });

    // Invalidate filter-dependent caches
    invalidateCache('filtersWithLocation');

    _loadTemples(reset: true);
  }

  Widget _buildSimpleFilters(StateSetter setModalState) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Distance Filter
          _buildDistanceFilter(setModalState),

          const SizedBox(height: 24),

          // Religion Filter
          _buildReligionFilter(setModalState),

          const SizedBox(height: 24),

          // Features Filter
          _buildFeaturesFilter(setModalState),

          const SizedBox(height: 24),

          // Sort Options
          _buildSortOptions(setModalState),

          const SizedBox(height: 32),

          // Action Buttons
          _buildFilterActions(),
        ],
      ),
    );
  }

  Widget _buildDistanceFilter(StateSetter setModalState) {
    final currentDistance = _currentFilters.maxDistance ?? 50.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              IconlyBold.location,
              color: Color.fromARGB(255, 255, 152, 0),
              size: 20,
            ),
            const SizedBox(width: 8),
            const Text(
              'Distance',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
            ),
            const Spacer(),
            Text(
              '${currentDistance.round()} km',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color.fromARGB(255, 255, 152, 0),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: const Color.fromARGB(255, 255, 152, 0),
            thumbColor: const Color.fromARGB(255, 255, 152, 0),
            overlayColor: const Color.fromARGB(
              255,
              255,
              152,
              0,
            ).withValues(alpha: 0.2),
          ),
          child: Slider(
            value: currentDistance,
            min: 5.0,
            max: 100.0,
            divisions: 19,
            label: '${currentDistance.round()} km',
            onChanged: (value) {
              final updatedFilters = _currentFilters.copyWith(
                maxDistance: value,
              );
              setModalState(() {
                _currentFilters = updatedFilters;
              });
            },
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '5 km',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            Text(
              '100 km',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReligionFilter(StateSetter setModalState) {
    final traditions = [
      'All',
      'Hinduism',
      'Buddhism',
      'Jainism',
      'Sikhism',
      'Christianity',
      'Islam',
    ];
    final selectedTraditions = _currentFilters.traditions ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.temple_hindu,
              color: Color.fromARGB(255, 255, 152, 0),
              size: 20,
            ),
            const SizedBox(width: 8),
            const Text(
              'Religion',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: traditions.map((tradition) {
            final isSelected = tradition == 'All'
                ? selectedTraditions.isEmpty
                : selectedTraditions.contains(tradition);

            return GestureDetector(
              onTap: () {
                List<String> newTraditions;
                if (tradition == 'All') {
                  newTraditions = [];
                } else {
                  newTraditions = List<String>.from(selectedTraditions);
                  if (newTraditions.contains(tradition)) {
                    newTraditions.remove(tradition);
                  } else {
                    newTraditions.add(tradition);
                  }
                }

                final updatedFilters = _currentFilters.copyWith(
                  traditions: newTraditions.isEmpty ? null : newTraditions,
                );
                setModalState(() {
                  _currentFilters = updatedFilters;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color.fromARGB(255, 255, 152, 0)
                      : Colors.grey[100],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? const Color.fromARGB(255, 255, 152, 0)
                        : Colors.grey[300]!,
                  ),
                ),
                child: Text(
                  tradition,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey[700],
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    fontSize: 14,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildFeaturesFilter(StateSetter setModalState) {
    final features = [
      {'name': 'Live Darshan', 'icon': IconlyBold.video},
      {'name': 'Parking', 'icon': IconlyBold.category},
      {'name': 'Food Court', 'icon': IconlyBold.buy},
      {'name': 'Accommodation', 'icon': IconlyBold.home},
    ];
    final selectedFeatures = _currentFilters.features ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              IconlyBold.star,
              color: Color.fromARGB(255, 255, 152, 0),
              size: 20,
            ),
            const SizedBox(width: 8),
            const Text(
              'Features',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: features.map((feature) {
            final featureName = feature['name'] as String;
            final featureIcon = feature['icon'] as IconData;
            final isSelected = selectedFeatures.contains(featureName);

            return GestureDetector(
              onTap: () {
                final newFeatures = List<String>.from(selectedFeatures);
                if (newFeatures.contains(featureName)) {
                  newFeatures.remove(featureName);
                } else {
                  newFeatures.add(featureName);
                }

                final updatedFilters = _currentFilters.copyWith(
                  features: newFeatures.isEmpty ? null : newFeatures,
                );
                setModalState(() {
                  _currentFilters = updatedFilters;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color.fromARGB(255, 255, 152, 0)
                      : Colors.grey[100],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? const Color.fromARGB(255, 255, 152, 0)
                        : Colors.grey[300]!,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      featureIcon,
                      size: 16,
                      color: isSelected ? Colors.white : Colors.grey[600],
                    ),
                    const SizedBox(width: 6),
                    Text(
                      featureName,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey[700],
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSortOptions(StateSetter setModalState) {
    final sortOptions = [
      {'name': 'Name', 'value': SortOption.name, 'icon': IconlyBold.document},
      {
        'name': 'Distance',
        'value': SortOption.distance,
        'icon': IconlyBold.location,
      },
      {'name': 'Rating', 'value': SortOption.rating, 'icon': IconlyBold.star},
      {
        'name': 'Popular',
        'value': SortOption.popularity,
        'icon': IconlyBold.chart,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              IconlyBold.filter,
              color: Color.fromARGB(255, 255, 152, 0),
              size: 20,
            ),
            const SizedBox(width: 8),
            const Text(
              'Sort By',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: sortOptions.map((option) {
            final optionName = option['name'] as String;
            final optionValue = option['value'] as SortOption;
            final optionIcon = option['icon'] as IconData;
            final isSelected = _currentFilters.sortBy == optionValue;

            return GestureDetector(
              onTap: () {
                final updatedFilters = _currentFilters.copyWith(
                  sortBy: optionValue,
                );
                setModalState(() {
                  _currentFilters = updatedFilters;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color.fromARGB(255, 255, 152, 0)
                      : Colors.grey[100],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? const Color.fromARGB(255, 255, 152, 0)
                        : Colors.grey[300]!,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      optionIcon,
                      size: 16,
                      color: isSelected ? Colors.white : Colors.grey[600],
                    ),
                    const SizedBox(width: 6),
                    Text(
                      optionName,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey[700],
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildFilterActions() {
    final hasActiveFilters = _currentFilters.hasFilters;

    return Column(
      children: [
        if (hasActiveFilters)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange[200]!),
            ),
            child: Row(
              children: [
                Icon(IconlyBold.filter, color: Colors.orange[600], size: 20),
                const SizedBox(width: 8),
                Text(
                  'Filters are active',
                  style: TextStyle(
                    color: Colors.orange[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        Row(
          children: [
            if (hasActiveFilters)
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _currentFilters = const TempleFilters();
                    });
                    _applyFilters(_currentFilters);
                    Navigator.of(context).pop();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey[700],
                    side: BorderSide(color: Colors.grey[300]!),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Clear All'),
                ),
              ),
            if (hasActiveFilters) const SizedBox(width: 12),
            Expanded(
              flex: hasActiveFilters ? 1 : 1,
              child: ElevatedButton(
                onPressed: () {
                  _applyFilters(_currentFilters);
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 255, 152, 0),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  elevation: 2,
                ),
                child: const Text(
                  'Apply Filters',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showLocationPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          ),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color.fromARGB(255, 255, 152, 0),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Text(
                    'Select Location',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            // Location options
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Use GPS Location
                    ListTile(
                      leading: const Icon(
                        IconlyBold.location,
                        color: Colors.orange,
                      ),
                      title: const Text('Use GPS Location'),
                      subtitle: Text(_getLocationDisplayText(_userLocation)),
                      onTap: () async {
                        Navigator.of(context).pop();
                        // Show loading indicator
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Row(
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                SizedBox(width: 16),
                                Text('Getting your location...'),
                              ],
                            ),
                            duration: Duration(seconds: 5),
                          ),
                        );

                        try {
                          // Clear cache first to force fresh location
                          await _locationService.clearCache();
                          await _loadUserLocation();
                          _loadTemples(reset: true);
                          // Hide loading and show success
                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                          if (_userLocation != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Location updated: ${_getLocationDisplayText(_userLocation)}',
                                ),
                                backgroundColor: Colors.green,
                                duration: const Duration(seconds: 3),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Could not get your location. Please try again.',
                                ),
                                backgroundColor: Colors.orange,
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Location error: ${e.toString()}'),
                              backgroundColor: Colors.red,
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        }
                      },
                    ),
                    const Divider(),
                    // Manual Location Input
                    ListTile(
                      leading: const Icon(
                        IconlyBold.edit,
                        color: Colors.orange,
                      ),
                      title: const Text('Enter Location Manually'),
                      subtitle: const Text('Type city or address'),
                      onTap: () {
                        Navigator.of(context).pop();
                        _showManualLocationInput();
                      },
                    ),
                    const Divider(),
                    // Popular Cities
                    const Text(
                      'Popular Cities',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView(
                        children: [
                          _buildCityOption('Ahmedabad', 'Gujarat'),
                          _buildCityOption('Surat', 'Gujarat'),
                          _buildCityOption('Vadodara', 'Gujarat'),
                          _buildCityOption('Rajkot', 'Gujarat'),
                          _buildCityOption('Gandhinagar', 'Gujarat'),
                          _buildCityOption('Mumbai', 'Maharashtra'),
                          _buildCityOption('Delhi', 'Delhi'),
                          _buildCityOption('Bangalore', 'Karnataka'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCityOption(String city, String state) {
    return ListTile(
      title: Text(city),
      subtitle: Text(state),
      onTap: () async {
        Navigator.of(context).pop();
        try {
          final location = await _locationService.getLocationFromAddress(
            '$city, $state',
          );
          if (location != null && mounted) {
            setState(() {
              _userLocation = location;
            });
            _loadTemples(reset: true);
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to get location for $city')),
            );
          }
        }
      },
    );
  }

  void _showManualLocationInput() {
    final TextEditingController locationController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Location'),
        content: TextField(
          controller: locationController,
          decoration: const InputDecoration(
            hintText: 'Enter city, state or address',
            prefixIcon: Icon(IconlyBold.location),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final address = locationController.text.trim();
              if (address.isNotEmpty) {
                Navigator.of(context).pop();
                try {
                  final location = await _locationService
                      .getLocationFromAddress(address);
                  if (location != null && mounted) {
                    setState(() {
                      _userLocation = location;
                    });
                    _loadTemples(reset: true);
                  } else {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Location not found')),
                      );
                    }
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: ${e.toString()}')),
                    );
                  }
                }
              }
            },
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  void _showNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NotificationsScreen()),
    );
  }

  void _openAdvancedSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TempleSearchScreen(
          initialQuery: _searchController.text,
          initialFilters: TempleFilters(
            searchQuery: _searchController.text,
            traditions: _currentFilters.traditions,
            features: _currentFilters.features,
            maxDistance: _currentFilters.maxDistance,
            userLocation: _userLocation,
            hasLiveDarshan: _currentFilters.hasLiveDarshan,
            isActive: _currentFilters.isActive,
            cities: _currentFilters.cities,
            states: _currentFilters.states,
            sortBy: _currentFilters.sortBy,
            ascending: _currentFilters.ascending,
          ),
          userId: _currentUserId,
        ),
      ),
    );
  }

  @override
  Widget buildWidget(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      body: Column(
        children: [
          _buildTopBar(),
          _buildSearchBar(),
          _buildDeityCategories(),
          const OfflineIndicator(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      color: const Color.fromARGB(255, 255, 152, 0),
      padding: const EdgeInsets.only(top: 15, left: 16, right: 10, bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Center(
              child: Semantics(
                label: 'Current location selector',
                hint: 'Tap to change your location for temple discovery',
                child: GestureDetector(
                  onTap: _showLocationPicker,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        'Current Location',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            IconlyBold.location,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              _getLocationDisplayText(_userLocation),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.keyboard_arrow_down,
                            color: Colors.white,
                            size: 20,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Stack(
            children: [
              Semantics(
                label: 'Notifications',
                hint: 'View your notifications and updates',
                child: IconButton(
                  icon: IconlyNotificationIcon(
                    hasNotifications: false,
                    onTap: _showNotifications,
                    size: 24.0,
                    iconColor: Colors.white,
                  ),
                  onPressed: _showNotifications,
                  tooltip: 'Notifications',
                ),
              ),
              // Dynamic notification badge
              if (_currentUserId != null)
                Positioned(
                  right: 10,
                  top: 8,
                  child: StreamBuilder<int>(
                    stream: services.notificationService.getUnreadCount(
                      _currentUserId!,
                    ),
                    builder: (context, snapshot) {
                      final unreadCount = snapshot.data ?? 0;
                      if (unreadCount == 0) return const SizedBox.shrink();

                      return Semantics(
                        label: '$unreadCount unread notifications',
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            unreadCount > 99 ? '99+' : unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: const Color.fromARGB(255, 255, 152, 0),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Semantics(
                label: 'Temple search',
                hint: 'Tap to search for temples by name or location',
                child: InkWell(
                  onTap: _openAdvancedSearch,
                  borderRadius: BorderRadius.circular(12),
                  child: AbsorbPointer(
                    child: TextField(
                      key: _kSearchFieldKey,
                      controller: _searchController,
                      style: const TextStyle(color: Colors.black87),
                      decoration: InputDecoration(
                        hintText: 'Search for temples...',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        prefixIcon: Icon(
                          IconlyBold.search,
                          color: Colors.grey[600],
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  IconlyBold.delete,
                                  color: Colors.grey[600],
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  _loadTemples(reset: true);
                                },
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              children: [
                Semantics(
                  label: 'Filter temples',
                  hint: _currentFilters.hasFilters
                      ? 'Filters are active. Tap to modify filters'
                      : 'Tap to filter temples by distance, religion, and features',
                  child: IconlyFilterIcon(
                    isActive: _currentFilters.hasFilters,
                    onTap: _toggleFilters,
                    size: 24.0,
                    activeColor: const Color.fromARGB(255, 255, 152, 0),
                    inactiveColor: Colors.grey[700],
                  ),
                ),
                // Active filter indicator
                if (_currentFilters.hasFilters)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Semantics(
                      label: 'Filters active',
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color.fromARGB(255, 255, 152, 0),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeityCategories() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Horizontal scrolling deity categories
          SizedBox(
            height: 90,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: DeityAssets.deityCategories.length,
              itemBuilder: (context, index) {
                final deity = DeityAssets.deityCategories[index];
                final deityName = deity['name'] as String;
                final isSelected = _selectedDeity == deityName;

                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _selectedDeity = deityName;
                    });
                    _loadTemples(reset: true);
                  },
                  child: Container(
                    width: 70,
                    margin: const EdgeInsets.only(right: 12),
                    child: Column(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color.fromARGB(255, 255, 152, 0)
                                : const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? const Color.fromARGB(255, 255, 152, 0)
                                  : Colors.grey[300]!,
                              width: 2,
                            ),
                          ),
                          child: DeityImageWidget(
                            deityName: deityName,
                            size: 28,
                            isSelected: isSelected,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          deityName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: isSelected
                                ? AppColors.primaryOrange
                                : Colors.grey[700],
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _temples.isEmpty) {
      return buildOnce(
        'loadingIndicator',
        () => const TempleSkeletonLoader(itemCount: 8),
        dependencies: [_isLoading, _temples.isEmpty],
      );
    }

    if (_error != null) {
      return buildOnce(
        'errorDisplay',
        () => Center(
          child: AnimatedErrorDisplay(
            message: _error!,
            onRetry: _initializeScreen,
          ),
        ),
        dependencies: [_error],
      );
    }

    if (_filteredTemples.isEmpty) {
      return buildOnce(
        'emptyState',
        () => _searchController.text.isNotEmpty
            ? EmptyStates.noSearchResults(
                onClearSearch: () {
                  _searchController.clear();
                  _loadTemples(reset: true);
                },
              )
            : EmptyStates.noTemples(onRefresh: () => _loadTemples(reset: true)),
        dependencies: [_filteredTemples.isEmpty, _searchController.text],
      );
    }

    return buildOnce(
      'templeList',
      _buildTempleList,
      dependencies: [_filteredTemples, _hasMoreData, _isLoadingMore],
    );
  }

  Widget _buildTempleList() {
    return NotificationListener<ScrollNotification>(
      onNotification: (scrollNotification) {
        if (scrollNotification is ScrollEndNotification &&
            _scrollController.position.pixels >=
                _scrollController.position.maxScrollExtent *
                    _loadMoreThreshold) {
          _loadMoreTemples();
        }
        return false;
      },
      child: _buildListView(),
    );
  }

  Widget _buildListView() {
    return OptimizedListView<Temple>(
      items: _filteredTemples,
      controller: _scrollController,
      enableLazyLoading: true,
      itemBuilder: (context, temple, index) {
        return TempleCard(
          key: ValueKey('temple_${temple.id}'),
          temple: temple,
          onTap: () => _navigateToTempleDetails(temple),
        );
      },
      addAutomaticKeepAlives: true,
      addRepaintBoundaries: true,
      clipBehavior: Clip.none,
      physics: const AlwaysScrollableScrollPhysics(),
    );
  }
}
