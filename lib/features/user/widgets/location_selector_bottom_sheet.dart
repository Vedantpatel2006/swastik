import 'package:flutter/material.dart';
import '../../../core/themes/app_colors.dart';
import '../../../shared/services/interfaces/location_service_interface.dart';
import '../services/location_select_service.dart';

/// Bottom sheet for selecting user location (GPS or manual)
class LocationSelectorBottomSheet extends StatefulWidget {
  final String currentLocation;
  final Function(String) onLocationSelected;

  const LocationSelectorBottomSheet({
    super.key,
    required this.currentLocation,
    required this.onLocationSelected,
  });

  @override
  State<LocationSelectorBottomSheet> createState() =>
      _LocationSelectorBottomSheetState();
}

class _LocationSelectorBottomSheetState
    extends State<LocationSelectorBottomSheet> {
  final LocationSelectService _locationService = LocationSelectService();
  final TextEditingController _searchController = TextEditingController();
  
  bool _isLoadingGps = false;
  String? _errorMessage;

  // Popular cities in India
  final List<String> _popularCities = [
    'Mumbai, Maharashtra',
    'Delhi, Delhi',
    'Bangalore, Karnataka',
    'Hyderabad, Telangana',
    'Chennai, Tamil Nadu',
    'Kolkata, West Bengal',
    'Pune, Maharashtra',
    'Ahmedabad, Gujarat',
    'Jaipur, Rajasthan',
    'Varanasi, Uttar Pradesh',
    'Ayodhya, Uttar Pradesh',
    'Tirupati, Andhra Pradesh',
    'Shirdi, Maharashtra',
    'Amritsar, Punjab',
    'Haridwar, Uttarakhand',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    if (!mounted) return;
    setState(() {
      _isLoadingGps = true;
      _errorMessage = null;
    });

    try {
      // Check permission
      final permissionStatus = await _locationService.getLocationPermissionStatus();

      if (!mounted) return;

      if (permissionStatus != LocationPermissionStatus.granted) {
        // Request permission
        final newStatus = await _locationService.requestLocationPermission();

        if (!mounted) return;

        if (newStatus != LocationPermissionStatus.granted) {
          setState(() {
            _errorMessage = 'Location permission denied';
            _isLoadingGps = false;
          });

          if (newStatus == LocationPermissionStatus.deniedForever) {
            _showPermissionDialog();
          }
          return;
        }
      }

      // Use GPS location
      final success = await _locationService.useCurrentGpsLocation();

      if (!mounted) return;

      if (success) {
        final location = _locationService.currentLocation;
        widget.onLocationSelected(location);
        Navigator.pop(context);
      } else {
        setState(() {
          _errorMessage = 'Failed to get current location. Please try again.';
          _isLoadingGps = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoadingGps = false;
      });
    }
  }

  void _showPermissionDialog() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Permission Required'),
        content: const Text(
          'Please enable location permission in settings to use your current location.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _locationService.openLocationSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _selectManualLocation(String location) async {
    try {
      final success = await _locationService.setManualLocation(location);
      
      if (success) {
        widget.onLocationSelected(location);
        
        if (mounted) {
          Navigator.pop(context);
        }
      } else {
        setState(() {
          _errorMessage = 'Failed to set location';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Icon(
                  Icons.location_on,
                  color: AppColors.primaryOrange,
                  size: 28,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Select Location',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryText,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  color: AppColors.secondaryText,
                ),
              ],
            ),
          ),

          // Error message
          if (_errorMessage != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.errorBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.errorBorder),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: AppColors.errorRed,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: AppColors.errorRed,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // Use Current Location Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _isLoadingGps ? null : _useCurrentLocation,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: AppColors.orangeGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryOrange.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isLoadingGps)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      else
                        const Icon(
                          Icons.my_location,
                          color: Colors.white,
                          size: 22,
                        ),
                      const SizedBox(width: 12),
                      Text(
                        _isLoadingGps ? 'Getting location...' : 'Use Current Location',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Divider with text
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(child: Divider(color: Colors.grey[300])),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Or select manually',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: Colors.grey[300])),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Search field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search city or area...',
                prefixIcon: const Icon(
                  Icons.search,
                  color: AppColors.primaryOrange,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.veryLightGray,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              onChanged: (value) => setState(() {}),
              onSubmitted: (value) {
                if (value.trim().isNotEmpty) {
                  _selectManualLocation(value.trim());
                }
              },
            ),
          ),

          const SizedBox(height: 20),

          // Popular cities list
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Popular Cities',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.secondaryText,
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Cities list
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 20),
              itemCount: _popularCities.length,
              itemBuilder: (context, index) {
                final city = _popularCities[index];
                final isSelected = city == widget.currentLocation;
                
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _selectManualLocation(city),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primaryOrange.withValues(alpha: 0.1)
                            : null,
                        border: Border(
                          bottom: BorderSide(
                            color: AppColors.borderGray,
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.location_city,
                            color: isSelected
                                ? AppColors.primaryOrange
                                : AppColors.secondaryText,
                            size: 20,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              city,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                color: isSelected
                                    ? AppColors.primaryOrange
                                    : AppColors.primaryText,
                              ),
                            ),
                          ),
                          if (isSelected)
                            const Icon(
                              Icons.check_circle,
                              color: AppColors.primaryOrange,
                              size: 20,
                            ),
                        ],
                      ),
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
}
