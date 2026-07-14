import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import '../../../shared/models/temple.dart';
import '../../../shared/models/temple_filters.dart';
import '../services/temple_filter_service.dart';
import '../../../shared/services/location_service.dart';
import '../../../shared/widgets/accessibility/accessible_button.dart';
import '../../../shared/widgets/accessibility/accessible_text_field.dart';
import '../../../shared/utils/error_handler.dart';

/// Advanced filter interface widget using centralized filter service
class AdvancedFilterInterface extends StatefulWidget {
  final TempleFilters currentFilters;
  final Function(TempleFilters) onFiltersChanged;
  final Map<String, int> filterCounts;
  final List<String> availableTraditions;
  final List<String> availableFeatures;

  const AdvancedFilterInterface({
    super.key,
    required this.currentFilters,
    required this.onFiltersChanged,
    this.filterCounts = const {},
    this.availableTraditions = TempleFilterService.availableTraditions,
    this.availableFeatures = const [
      'Live Darshan',
      'Parking',
      'Food Court',
      'Accommodation',
      'Wheelchair Accessible',
      'Library',
      'Meditation Hall',
      'Online Booking',
    ],
  });

  @override
  State<AdvancedFilterInterface> createState() => _AdvancedFilterInterfaceState();
}

class _AdvancedFilterInterfaceState extends State<AdvancedFilterInterface> {
  final TempleFilterService _filterService = TempleFilterService();
  final LocationService _locationService = LocationService();
  final TextEditingController _manualLocationController = TextEditingController();
  
  late double _currentDistance;
  Location? _userLocation;
  bool _isLoadingLocation = false;
  bool _useManualLocation = false;
  String? _locationError;
  
  // Filter state - temporary state until user applies
  List<String> _selectedTraditions = [];
  List<String> _selectedFeatures = [];
  int _activeFilterCount = 0;
  
  // Original filters to compare changes
  late TempleFilters _originalFilters;

  @override
  void initState() {
    super.initState();
    _initializeFilterService();
    _originalFilters = widget.currentFilters;
    _currentDistance = widget.currentFilters.maxDistance ?? 50.0;
    _userLocation = widget.currentFilters.userLocation;
    _selectedTraditions = List<String>.from(widget.currentFilters.traditions ?? []);
    _selectedFeatures = List<String>.from(widget.currentFilters.features ?? []);
    
    if (_userLocation != null && _userLocation!.address != null) {
      _manualLocationController.text = _userLocation!.address!;
      _useManualLocation = true;
    }
    
    _updateActiveFilterCount();
    
    // Try to get current location if not already set
    if (_userLocation == null) {
      _getCurrentLocation();
    }
  }

  Future<void> _initializeFilterService() async {
    await _filterService.initialize();
  }

  @override
  void dispose() {
    _manualLocationController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    if (!mounted) return;
    
    setState(() {
      _isLoadingLocation = true;
      _locationError = null;
    });

    final location = await ErrorHandler.safeExecute(
      () async {
        return await _locationService.getCurrentLocation();
      },
      context: 'AdvancedFilterInterface._getCurrentLocation',
      showErrorToUser: false,
      buildContext: context,
    );

    if (!mounted) return;

    if (location != null) {
      setState(() {
        _userLocation = location;
        _isLoadingLocation = false;
        _locationError = null;
      });

      _updateActiveFilterCount();
    } else {
      setState(() {
        _locationError = 'Unable to get current location';
        _isLoadingLocation = false;
      });
    }
  }

  Future<void> _handleManualLocationInput() async {
    final address = _manualLocationController.text.trim();
    
    if (address.isEmpty) {
      if (!mounted) return;
      setState(() {
        _userLocation = null;
        _locationError = null;
      });
      _updateActiveFilterCount();
      return;
    }

    if (!mounted) return;
    setState(() {
      _isLoadingLocation = true;
      _locationError = null;
    });

    final location = await ErrorHandler.safeExecute(
      () => _locationService.getLocationFromAddress(address),
      context: 'AdvancedFilterInterface._handleManualLocationInput',
      showErrorToUser: false,
      buildContext: context,
    );

    if (!mounted) return;

    if (location != null) {
      setState(() {
        _userLocation = location;
        _isLoadingLocation = false;
        _locationError = null;
      });

      _updateActiveFilterCount();
    } else {
      setState(() {
        _locationError = 'Unable to find location for: $address';
        _isLoadingLocation = false;
      });
    }
  }

  void _updateFilters() {
    // Only update the active filter count, don't apply filters yet
    _updateActiveFilterCount();
  }

  void _applyFilters() {
    final updatedFilters = widget.currentFilters.copyWith(
      maxDistance: _currentDistance,
      userLocation: _userLocation,
      traditions: _selectedTraditions.isEmpty ? null : _selectedTraditions,
      features: _selectedFeatures.isEmpty ? null : _selectedFeatures,
    );
    
    widget.onFiltersChanged(updatedFilters);
  }

  bool _hasChanges() {
    return _currentDistance != (_originalFilters.maxDistance ?? 50.0) ||
           _userLocation != _originalFilters.userLocation ||
           !_listEquals(_selectedTraditions, _originalFilters.traditions ?? []) ||
           !_listEquals(_selectedFeatures, _originalFilters.features ?? []);
  }

  bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (!b.contains(a[i])) return false;
    }
    return true;
  }

  void _openLocationSettings() async {
    // Simple fallback - just show a message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enable location services in your device settings',
          ),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _updateActiveFilterCount() {
    _activeFilterCount =
        _filterService.hasActiveFilters(
          TempleFilters(
            traditions: _selectedTraditions.isEmpty
                ? null
                : _selectedTraditions,
            features: _selectedFeatures.isEmpty ? null : _selectedFeatures,
            maxDistance: _currentDistance,
            userLocation: _userLocation,
          ),
        )
        ? 1
        : 0;

    if (_selectedTraditions.isNotEmpty) _activeFilterCount++;
    if (_selectedFeatures.isNotEmpty) _activeFilterCount++;
    if (_userLocation != null) _activeFilterCount++;

    setState(() {});
  }

  void _clearAllFilters() {
    final clearedFilters = _filterService.clearFilters(_originalFilters);
    setState(() {
      _selectedTraditions.clear();
      _selectedFeatures.clear();
      _userLocation = clearedFilters.userLocation;
      _currentDistance = clearedFilters.maxDistance ?? 50.0;
      _manualLocationController.clear();
      _useManualLocation = false;
      _locationError = null;
    });
    _updateActiveFilterCount();
  }

  void _toggleTradition(String tradition) {
    setState(() {
      if (_selectedTraditions.contains(tradition)) {
        _selectedTraditions.remove(tradition);
      } else {
        _selectedTraditions.add(tradition);
      }
    });
    _updateActiveFilterCount();

    // Provide haptic feedback for better UX
    HapticFeedback.selectionClick();
  }

  void _toggleFeature(String feature) {
    setState(() {
      if (_selectedFeatures.contains(feature)) {
        _selectedFeatures.remove(feature);
      } else {
        _selectedFeatures.add(feature);
      }
    });
    _updateActiveFilterCount();
    
    // Provide haptic feedback for better UX
    HapticFeedback.selectionClick();
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Advanced Filters',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        if (_activeFilterCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$_activeFilterCount active',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with active filter count
            _buildHeader(),
            
            const SizedBox(height: 16),
            
            // Distance slider
            _buildDistanceSlider(),
            
            const SizedBox(height: 24),
            
            // Location section
            _buildLocationSection(),
            
            const SizedBox(height: 16),
            
            // Location status and controls
            _buildLocationControls(),
            
            const SizedBox(height: 24),
            
            // Tradition filters
            _buildTraditionFilters(),
            
            const SizedBox(height: 24),
            
            // Feature filters
            _buildFeatureFilters(),
            
            const SizedBox(height: 24),
            
            // Action buttons
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildDistanceSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Maximum Distance',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            Text(
              '${_currentDistance.round()} km',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Slider(
          value: _currentDistance,
          min: 1.0,
          max: 100.0,
          divisions: 99,
          label: '${_currentDistance.round()} km',
          onChanged: (value) {
            setState(() {
              _currentDistance = value;
            });
          },
          onChangeEnd: (value) {
            _updateFilters();
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '1 km',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              '100 km',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLocationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Location',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        
        // Toggle between GPS and manual location
        Row(
          children: [
            Expanded(
              child: RadioListTile<bool>(
                title: const Text('Use GPS'),
                value: false,
                groupValue: _useManualLocation,
                onChanged: (value) {
                  setState(() {
                    _useManualLocation = false;
                  });
                  _getCurrentLocation();
                },
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            Expanded(
              child: RadioListTile<bool>(
                title: const Text('Manual'),
                value: true,
                groupValue: _useManualLocation,
                onChanged: (value) {
                  setState(() {
                    _useManualLocation = true;
                  });
                },
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 8),
        
        // Manual location input
        if (_useManualLocation) ...[
          AccessibleTextField(
            controller: _manualLocationController,
            labelText: 'Enter location',
            hintText: 'City, State or Address',
            prefixIcon: const Icon(Icons.location_on),
            onSubmitted: (_) => _handleManualLocationInput(),
          ),
          const SizedBox(height: 8),
          AccessibleButton(
            onPressed: _handleManualLocationInput,
            child: const Text('Update Location'),
          ),
        ],
      ],
    );
  }

  Widget _buildLocationControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Current location display
        if (_userLocation != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.location_on,
                  color: Theme.of(context).primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _userLocation!.address ?? 
                    '${_userLocation!.latitude.toStringAsFixed(4)}, ${_userLocation!.longitude.toStringAsFixed(4)}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ],
        
        // Loading indicator
        if (_isLoadingLocation) ...[
          const SizedBox(height: 8),
          const Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 8),
              Text('Getting location...'),
            ],
          ),
        ],
        
        // Error display
        if (_locationError != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).colorScheme.error.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.error_outline,
                  color: Theme.of(context).colorScheme.error,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _locationError!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              AccessibleButton(
                onPressed: _getCurrentLocation,
                child: const Text('Retry'),
              ),
              const SizedBox(width: 8),
              AccessibleButton(
                onPressed: _openLocationSettings,
                child: const Text('Settings'),
              ),
            ],
          ),
        ],
        
        // Action buttons when no error
        if (_locationError == null && !_isLoadingLocation) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              if (!_useManualLocation)
                AccessibleButton(
                  onPressed: _getCurrentLocation,
                  child: const Text('Refresh Location'),
                ),
              const Spacer(),
              AccessibleButton(
                onPressed: () {
                  setState(() {
                    _userLocation = null;
                    _currentDistance = 50.0;
                    _manualLocationController.clear();
                  });
                  _updateFilters();
                },
                child: const Text('Clear'),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildTraditionFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Religious Traditions',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (_selectedTraditions.isNotEmpty)
              Text(
                '${_selectedTraditions.length} selected',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: widget.availableTraditions.map((tradition) {
            final isSelected = _selectedTraditions.contains(tradition);
            final count = widget.filterCounts['tradition_$tradition'] ?? 0;
            
            return FilterChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(tradition),
                  if (count > 0) ...[
                    const SizedBox(width: 4),
                    Text(
                      '($count)',
                      style: TextStyle(
                        fontSize: 12,
                        color: isSelected 
                          ? Colors.white.withValues(alpha: 0.8)
                          : Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ],
              ),
              selected: isSelected,
              onSelected: (_) => _toggleTradition(tradition),
              selectedColor: Theme.of(context).primaryColor,
              checkmarkColor: Colors.white,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : null,
                fontWeight: isSelected ? FontWeight.w500 : null,
              ),
            );
          }).toList(),
        ),
        if (_selectedTraditions.isNotEmpty) ...[
          const SizedBox(height: 8),
          AccessibleButton(
            onPressed: () {
              setState(() {
                _selectedTraditions.clear();
              });
              _updateFilters();
            },
            child: const Text('Clear Traditions'),
          ),
        ],
      ],
    );
  }

  Widget _buildFeatureFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Temple Features',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (_selectedFeatures.isNotEmpty)
              Text(
                '${_selectedFeatures.length} selected',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: widget.availableFeatures.map((feature) {
            final isSelected = _selectedFeatures.contains(feature);
            final count = widget.filterCounts['feature_$feature'] ?? 0;
            
            return FilterChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _getFeatureIcon(feature),
                  const SizedBox(width: 4),
                  Text(feature),
                  if (count > 0) ...[
                    const SizedBox(width: 4),
                    Text(
                      '($count)',
                      style: TextStyle(
                        fontSize: 12,
                        color: isSelected 
                          ? Colors.white.withValues(alpha: 0.8)
                          : Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ],
              ),
              selected: isSelected,
              onSelected: (_) => _toggleFeature(feature),
              selectedColor: Theme.of(context).primaryColor,
              checkmarkColor: Colors.white,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : null,
                fontWeight: isSelected ? FontWeight.w500 : null,
              ),
            );
          }).toList(),
        ),
        if (_selectedFeatures.isNotEmpty) ...[
          const SizedBox(height: 8),
          AccessibleButton(
            onPressed: () {
              setState(() {
                _selectedFeatures.clear();
              });
              _updateFilters();
            },
            child: const Text('Clear Features'),
          ),
        ],
      ],
    );
  }

  Widget _getFeatureIcon(String feature) {
    IconData iconData;
    switch (feature.toLowerCase()) {
      case 'parking':
        iconData = Icons.local_parking;
        break;
      case 'wheelchair accessible':
        iconData = Icons.accessible;
        break;
      case 'food court':
        iconData = Icons.restaurant;
        break;
      case 'accommodation':
        iconData = Icons.hotel;
        break;
      case 'library':
        iconData = Icons.library_books;
        break;
      case 'meditation hall':
        iconData = Icons.self_improvement;
        break;
      case 'live darshan':
        iconData = Icons.videocam;
        break;
      case 'online booking':
        iconData = Icons.book_online;
        break;
      default:
        iconData = Icons.star;
    }
    
    return Icon(
      iconData,
      size: 16,
      color: _selectedFeatures.contains(feature) 
        ? Colors.white 
        : Theme.of(context).primaryColor,
    );
  }

  Widget _buildActionButtons() {
    final hasChanges = _hasChanges();
    
    return Column(
      children: [
        if (hasChanges)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'You have unsaved filter changes',
                    style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _activeFilterCount > 0 ? _clearAllFilters : null,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey[700],
                  side: BorderSide(color: Colors.grey[300]!),
                ),
                child: const Text('Clear All'),
              ),
            ),
            const SizedBox(width: 12),
            if (hasChanges) ...[
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    // Reset to original values
                    setState(() {
                      _currentDistance = _originalFilters.maxDistance ?? 50.0;
                      _userLocation = _originalFilters.userLocation;
                      _selectedTraditions = List<String>.from(_originalFilters.traditions ?? []);
                      _selectedFeatures = List<String>.from(_originalFilters.features ?? []);
                      if (_userLocation != null && _userLocation!.address != null) {
                        _manualLocationController.text = _userLocation!.address!;
                      } else {
                        _manualLocationController.clear();
                      }
                    });
                    _updateFilters();
                  },
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              flex: hasChanges ? 1 : 2,
              child: ElevatedButton(
                onPressed: hasChanges ? () {
                  _applyFilters();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Filters applied: $_activeFilterCount active'),
                      duration: const Duration(seconds: 2),
                      backgroundColor: Colors.green,
                    ),
                  );
                } : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: hasChanges ? Colors.orange : Colors.grey[300],
                  foregroundColor: hasChanges ? Colors.white : Colors.grey[600],
                ),
                child: Text(hasChanges ? 'Apply Filters' : 'No Changes'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}