import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import '../../../shared/widgets/error/index.dart';
import '../../../shared/widgets/network_error_recovery_widget.dart';

class SelectLocationMapScreen extends StatefulWidget {
  const SelectLocationMapScreen({super.key});

  @override
  State<SelectLocationMapScreen> createState() =>
      _SelectLocationMapScreenState();
}

class _SelectLocationMapScreenState extends State<SelectLocationMapScreen> {
  LatLng? _selectedLocation;
  String? _selectedAddress;
  String? _city;
  String? _state;
  String? _country;
  GoogleMapController? mapController;
  bool _isLoading = true;
  String? _error;
  bool _hasLocationPermission = false;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    mapController?.dispose();
    super.dispose();
  }

  void onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  Future<void> _getCurrentLocation() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Use a default location if location services disabled
        if (mounted) {
          setState(() {
            _selectedLocation = const LatLng(20.5937, 78.9629); // India center
            _isLoading = false;
            _hasLocationPermission = false;
          });
          await _getAddressFromLatLng(_selectedLocation!);
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          // Use a default location if permission denied
          if (mounted) {
            setState(() {
              _selectedLocation = const LatLng(
                20.5937,
                78.9629,
              ); // India center
              _isLoading = false;
              _hasLocationPermission = false;
            });
            await _getAddressFromLatLng(_selectedLocation!);
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        // Use a default location if permission permanently denied
        if (mounted) {
          setState(() {
            _selectedLocation = const LatLng(20.5937, 78.9629); // India center
            _isLoading = false;
            _hasLocationPermission = false;
          });
          await _getAddressFromLatLng(_selectedLocation!);
        }
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      final currentLatLng = LatLng(position.latitude, position.longitude);

      if (mounted) {
        setState(() {
          _selectedLocation = currentLatLng;
          _hasLocationPermission = true;
          _isLoading = false;
          _error = null;
        });

        mapController?.animateCamera(CameraUpdate.newLatLng(currentLatLng));
        await _getAddressFromLatLng(currentLatLng);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = null; // Don't show error, just use default location
          _isLoading = false;
          // Use current location or default to India center
          _selectedLocation = const LatLng(20.5937, 78.9629); // India center
          _hasLocationPermission = false;
        });
        await _getAddressFromLatLng(_selectedLocation!);
      }
    }
  }

  Future<void> _getAddressFromLatLng(LatLng position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty && mounted) {
        Placemark place = placemarks[0];
        final addressParts = [
          place.name,
          place.subLocality,
          place.locality,
          place.administrativeArea,
          place.country,
        ].where((part) => part != null && part.isNotEmpty).toList();

        setState(() {
          _selectedAddress = addressParts.join(', ');
          _city = place.locality ?? place.subAdministrativeArea;
          _state = place.administrativeArea;
          _country = place.country;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _selectedAddress =
              'Lat: ${position.latitude.toStringAsFixed(4)}, Lng: ${position.longitude.toStringAsFixed(4)}';
          _city = null;
          _state = null;
          _country = null;
        });
      }
    }
  }

  void _onMapTap(LatLng tappedPoint) {
    if (!mounted) return;
    setState(() {
      _selectedLocation = tappedPoint;
    });
    // Fire-and-forget with mounted guard inside _getAddressFromLatLng
    _getAddressFromLatLng(tappedPoint);
  }

  void _confirmSelection() {
    if (_selectedLocation != null) {
      // Return a map with all location details
      final locationData = {
        'coordinates': _selectedLocation,
        'address': _selectedAddress,
        'city': _city,
        'state': _state,
        'country': _country,
      };
      Navigator.pop(context, locationData);
    } else {
      context.showErrorSnackBar(
        message: 'Please select a location on the map',
        onRetry: _getCurrentLocation,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Select Location',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        elevation: 2,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFFFF7A00),
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Getting your location...',
                    style: TextStyle(color: Color(0xFF6B7280), fontSize: 16),
                  ),
                ],
              ),
            )
          : _error != null
          ? Center(
              child: AnimatedErrorDisplay(
                title: 'Location Error',
                message: _error!,
                type: ErrorDisplayType.warning,
                onRetry: _getCurrentLocation,
                onDismiss: () {
                  setState(() {
                    _error = null;
                    // Set default location if error is dismissed
                    _selectedLocation = const LatLng(20.5937, 78.9629);
                  });
                },
                showDismissButton: true,
              ),
            )
          : _selectedLocation == null
          ? const Center(
              child: FallbackUI(
                title: 'No Location Selected',
                message:
                    'Unable to determine your location. Please tap on the map to select a location manually.',
                type: FallbackUIType.empty,
              ),
            )
          : Stack(
              children: [
                // Location selection notice
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.orange[700]!, Colors.orange[600]!],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            color: Colors.white,
                            size: 22,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Tap anywhere on the map to select temple location',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _selectedLocation!,
                    zoom:
                        _selectedLocation!.latitude == 20.5937 &&
                            _selectedLocation!.longitude == 78.9629
                        ? 5 // Wider view if showing India center
                        : 16, // Closer view if showing user's location
                  ),
                  onTap: _onMapTap,
                  markers: {
                    Marker(
                      markerId: const MarkerId('selected-location'),
                      position: _selectedLocation!,
                      infoWindow: InfoWindow(
                        title: 'Selected Location',
                        snippet: _selectedAddress ?? 'Tap to confirm',
                      ),
                    ),
                  },
                  onMapCreated: onMapCreated, // Use memory-managed map creation
                  myLocationEnabled: _hasLocationPermission,
                  myLocationButtonEnabled: _hasLocationPermission,
                ),

                // Error indicator for network issues
                if (_selectedAddress == null)
                  Positioned(
                    top: 16,
                    left: 16,
                    right: 16,
                    child: CompactNetworkErrorRecovery(
                      message: 'Unable to load address information',
                      onRetry: () => _getAddressFromLatLng(_selectedLocation!),
                    ),
                  ),

                // Bottom sheet with location info
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 20,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Drag handle
                          Container(
                            width: 50,
                            height: 5,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Location info
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.orange[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.orange[200]!,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.orange,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.location_on,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Selected Location',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF6B7280),
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _selectedAddress ??
                                            'Tap on the map to select a location',
                                        style: TextStyle(
                                          fontSize: 15,
                                          color: Colors.grey[900],
                                          fontWeight: FontWeight.w600,
                                          height: 1.3,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 18),

                          // Confirm button
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton(
                              onPressed: _confirmSelection,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                                elevation: 3,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.check_circle, size: 24),
                                  SizedBox(width: 10),
                                  Text(
                                    'Confirm Location',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
