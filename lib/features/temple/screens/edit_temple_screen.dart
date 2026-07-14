import 'dart:io';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../core/themes/app_colors.dart';
import '../../../shared/services/realtime_service.dart';
import '../../../shared/services/storage/hybrid_storage_service.dart';
import '../services/hybrid_live_detector.dart';
import '../services/youtube_channel_service.dart';
import 'select_location_map.dart';

// Abstract interface for temple document data
abstract class TempleDocument {
  String get id;
  bool get exists;
  Map<String, dynamic>? data();
}

// Extension to make DocumentSnapshot compatible with TempleDocument
extension DocumentSnapshotTempleDocument on DocumentSnapshot {
  TempleDocument get asTempleDocument => _DocumentSnapshotWrapper(this);
}

class _DocumentSnapshotWrapper implements TempleDocument {
  final DocumentSnapshot _snapshot;
  _DocumentSnapshotWrapper(this._snapshot);
  
  @override
  String get id => _snapshot.id;
  
  @override
  bool get exists => _snapshot.exists;
  
  @override
  Map<String, dynamic>? data() => _snapshot.data() as Map<String, dynamic>?;
}

class EditTempleScreen extends StatefulWidget {
  final TempleDocument temple;

  const EditTempleScreen({super.key, required this.temple});

  @override
  State<EditTempleScreen> createState() => _EditTempleScreenState();
}

class _EditTempleScreenState extends State<EditTempleScreen>
    with TickerProviderStateMixin, RealtimeMixin {
  final _formKey = GlobalKey<FormState>();
  final _imagePicker = ImagePicker();
  bool _isLoading = false;
  bool _isCheckingPermissions = true;

  // Tab controller for organized sections
  late TabController _tabController;

  // Basic Information Controllers
  final _nameController = TextEditingController();
  final _titleController = TextEditingController();
  final _locationTextController = TextEditingController();
  final _locationLinkController = TextEditingController();
  final _aboutTempleController = TextEditingController();

  // Contact Information Controllers
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _websiteController = TextEditingController();
  final _facebookController = TextEditingController();
  final _instagramController = TextEditingController();
  final _twitterController = TextEditingController();
  final _youtubeController = TextEditingController();

  // Pricing - Enhanced Puja Services
  final _pujaPriceController =
      TextEditingController(); // Keep for backward compatibility
  List<Map<String, dynamic>> _pujaServices = [];

  final _minDonationController = TextEditingController();
  final _suggestedDonationController = TextEditingController();

  // Live Darshan Controllers - Support for multiple channels
  final List<Map<String, TextEditingController>> _liveDarshanChannels = [];
  
  // Legacy single channel controllers (for backward compatibility)
  final _youtubeChannelUrlController = TextEditingController();
  final _youtubeChannelIdController = TextEditingController();
  final _liveKeywordController = TextEditingController();

  // Deity Information Controllers
  final _mainDeityController = TextEditingController();
  final _templeHistoryController = TextEditingController();

  // Community Controllers
  final _communityGuidelinesController = TextEditingController();

  // Location data
  String? _locationAddress;
  double? _locationLat;
  double? _locationLng;

  // Timings - Comprehensive timing system
  TimeOfDay? _openingTime;
  TimeOfDay? _closingTime;
  List<Map<String, String>> _pujaTimings = []; // {name, time}
  List<Map<String, String>> _specialDarshanTimings = []; // {name, time}
  String? _weeklyClosedDay;
  final List<String> _weekDays = [
    'None',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  String _festivalTimingsNote = '';

  // Images
  List<String> _existingImageUrls = [];
  List<File> _newImageFiles = [];
  int _primaryImageIndex = 0;
  List<String> _imagesToDelete = [];
  // Features & Amenities - Comprehensive list
  final Map<String, bool> _features = {
    'Parking Available': false,
    'Wheelchair Accessible': false,
    'Prasad Available': false,
    'Accommodation Available': false,
    'Dining Facilities': false,
    'Shoe Storage': false,
    'Restrooms': false,
    'Drinking Water': false,
    'Photography Allowed': false,
    'Audio System': false,
    'CCTV Security': false,
    'First Aid': false,
    'Donation Counter': false,
    'Book Store': false,
    'Free WiFi': false,
  };

  // Booking System
  bool _acceptsBookings = false;
  final Map<String, bool> _bookingTypes = {
    'Temple Visit': false,
    'Special Puja': false,
    'Event Booking': false,
    'Accommodation': false,
    'Prasad Booking': false,
  };
  int _advanceBookingDays = 30;
  int _slotsPerDay = 10;
  int _slotDurationMinutes = 30;

  // Donation System
  bool _acceptsDonations = false;
  final Map<String, bool> _donationPurposes = {
    'General Fund': true,
    'Festival Celebration': false,
    'Temple Maintenance': false,
    'Construction': false,
    'Food Distribution': false,
    'Education': false,
    'Healthcare': false,
  };

  // Deity & Traditions
  String _mainDeity = 'Lord Shiva';
  final List<String> _mainDeityOptions = [
    'Lord Shiva',
    'Lord Vishnu',
    'Lord Krishna',
    'Lord Rama',
    'Lord Ganesha',
    'Lord Hanuman',
    'Mata Durga',
    'Mata Lakshmi',
    'Mata Saraswati',
    'Mata Kali',
    'Mata Parvati',
    'Lord Brahma',
    'Lord Murugan',
    'Lord Ayyappa',
    'Lord Venkateswara',
    'Sai Baba',
    'Other',
  ];

  // Event Management
  bool _hasEvents = false;
  final Map<String, bool> _eventCategories = {
    'Religious Festivals': false,
    'Cultural Programs': false,
    'Educational Events': false,
    'Community Gatherings': false,
    'Spiritual Discourses': false,
  };
  int _eventCapacity = 100;

  // Community Features
  bool _allowsReviews = true;
  bool _allowsPhotoSharing = true;
  bool _moderationEnabled = true;

  // Accessibility
  bool _wheelchairAccessible = false;
  bool _parkingAvailable = false;
  String _parkingDetails = '';
  String _accessibilityNotes = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _checkAdminPermissions();
    _setupRealtimeTempleStream();
  }

  /// Setup realtime stream for the temple being edited
  void _setupRealtimeTempleStream() {
    if (!widget.temple.exists) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Temple document not found')),
          );
        }
      });
      return;
    }

    // Subscribe to realtime stream for this specific temple
    subscribeToRealtimeStream(
      'edit_temple_${widget.temple.id}',
      RealtimeService().getTempleStream(widget.temple.id),
      (dynamic data) {
        if (!mounted) return;

        if (data != null && data is Map<String, dynamic>) {
          _loadTempleDataFromSnapshot(data);
          debugPrint('📡 Realtime update: Temple ${widget.temple.id} data refreshed');
        } else {
          // Temple was deleted
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Temple was deleted by another user'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      onError: (error) {
        debugPrint('❌ Realtime stream error: $error');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Realtime connection error: $error'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      },
    );
  }
  Future<void> _checkAdminPermissions() async {
    try {
      final authProvider = context.read<AuthProvider>();
      final isAdmin = await authProvider.isAdmin;

      if (!isAdmin) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Access denied. Admin privileges required.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Permission check failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isCheckingPermissions = false;
      });
    }
  }

  // Helper method to safely parse integers from dynamic data
  int _safeParseInt(dynamic value, int defaultValue) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value);
      return parsed ?? defaultValue;
    }
    return defaultValue;
  }

  // Helper method to safely parse doubles from dynamic data
  double? _safeParseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }

  void _loadTempleDataFromSnapshot(Map<String, dynamic> data) {
    if (!mounted) return;
    
    try {
      print('🔍 Debug: Starting temple data loading...');
      print('🔍 Debug: Temple ID: ${widget.temple.id}');
      print('🔍 Debug: Data keys: ${data.keys.toList()}');
      print('🔍 Debug: Temple name from data: ${data['name']}');

      // Load basic information
      print('�  Debug: Loading basic information...');
      _nameController.text = data['name']?.toString() ?? '';
      print('   ✅ Name loaded: ${_nameController.text}');

      _titleController.text = data['title']?.toString() ?? '';
      print('   ✅ Title loaded: ${_titleController.text}');

      _locationTextController.text =
          data['location']?['address']?.toString() ??
          data['location']?.toString() ??
          '';
      print('   ✅ Location loaded: ${_locationTextController.text}');

      _aboutTempleController.text = data['aboutTemple']?.toString() ?? '';
      final aboutPreview = _aboutTempleController.text.isEmpty
          ? "(empty)"
          : _aboutTempleController.text.length > 50
          ? '${_aboutTempleController.text.substring(0, 50)}...'
          : _aboutTempleController.text;
      print('   ✅ About temple loaded: $aboutPreview');

      // Load main deity
      final deityFromData = data['mainDeity']?.toString() ?? '';
      if (deityFromData.isNotEmpty) {
        // Check if it's one of the predefined options
        if (_mainDeityOptions.contains(deityFromData)) {
          _mainDeity = deityFromData;
          _mainDeityController.text = deityFromData;
        } else {
          // Custom deity - set to "Other"
          _mainDeity = 'Other';
          _mainDeityController.text = deityFromData;
        }
      }
      
      _templeHistoryController.text = data['history']?.toString() ?? '';
      print('✅ Debug: Basic information loaded successfully');

      // Load location data
      print('📍 Debug: Loading location data...');
      if (data['location'] != null) {
        final locationData = data['location'];
        if (locationData is Map<String, dynamic>) {
          final location = locationData;
          _locationAddress =
              location['fullAddress']?.toString() ??
              location['address']?.toString();
          _locationLat = _safeParseDouble(location['latitude']);
          _locationLng = _safeParseDouble(location['longitude']);

          // Update the location text controller with the loaded address
          if (_locationAddress != null && _locationAddress!.isNotEmpty) {
            _locationTextController.text = _locationAddress!;
          }
          print('   ✅ Location address: $_locationAddress');
          print('   ✅ Location coordinates: $_locationLat, $_locationLng');
        } else if (locationData is String) {
          // Handle legacy string format
          _locationAddress = locationData;
          _locationTextController.text = locationData;
          print('   ✅ Location (legacy format): $locationData');
        }
        _locationLinkController.text = data['locationLink']?.toString() ?? '';
      }
      print('✅ Debug: Location data loaded successfully');

      // Load contact information
      print('Debug: Loading contact information...');
      if (data['contact'] != null) {
        final contactData = data['contact'];
        if (contactData is Map<String, dynamic>) {
          final contact = contactData;
          _phoneController.text = contact['phone']?.toString() ?? '';
          _emailController.text = contact['email']?.toString() ?? '';
          _websiteController.text = contact['website']?.toString() ?? '';

          if (contact['socialMedia'] != null && contact['socialMedia'] is Map) {
            final socialMedia = contact['socialMedia'] as Map<String, dynamic>;
            _facebookController.text =
                socialMedia['facebook']?.toString() ?? '';
            _instagramController.text =
                socialMedia['instagram']?.toString() ?? '';
            _twitterController.text = socialMedia['twitter']?.toString() ?? '';
            _youtubeController.text = socialMedia['youtube']?.toString() ?? '';
          }
        }
      }
      print('Debug: Contact information loaded successfully');

      // Load pricing and puja services
      print('Debug: Loading pricing...');
      _pujaPriceController.text = data['pujaPrice']?.toString() ?? '';
      
      // Load puja services
      if (data['pujaServices'] != null && data['pujaServices'] is List) {
        _pujaServices = (data['pujaServices'] as List).map((service) {
          return {
            'name': service['name']?.toString() ?? '',
            'nameHindi': service['nameHindi']?.toString() ?? '',
            'nameGujarati': service['nameGujarati']?.toString() ?? '',
            'category': service['category']?.toString() ?? 'Regular Puja',
            'price': (service['price'] as num?)?.toDouble() ?? 0.0,
            'duration': service['duration'] as int? ?? 30,
            'description': service['description']?.toString() ?? '',
            'descriptionHindi': service['descriptionHindi']?.toString() ?? '',
            'descriptionGujarati':
                service['descriptionGujarati']?.toString() ?? '',
            'requiresAdvanceBooking':
                service['requiresAdvanceBooking'] as bool? ?? false,
            'advanceBookingDays': service['advanceBookingDays'] as int? ?? 0,
            'maxBookingsPerDay': service['maxBookingsPerDay'] as int?,
            'timeSlots': service['timeSlots'] != null
                ? List<String>.from(service['timeSlots'] as List)
                : <String>[],
            'isActive': service['isActive'] as bool? ?? true,
          };
        }).toList();
      }
      
      _minDonationController.text =
          data['minimumDonationAmount']?.toString() ?? '';
      _suggestedDonationController.text =
          data['suggestedDonationAmount']?.toString() ?? '';
      print('Debug: Pricing loaded successfully');

      // Load timings - New comprehensive timing system
      print('Debug: Loading timings...');
      try {
        // Load opening time
        if (data['openingTime'] != null) {
          final parts = data['openingTime'].toString().split(':');
          if (parts.length == 2) {
            _openingTime = TimeOfDay(
              hour: int.parse(parts[0]),
              minute: int.parse(parts[1]),
            );
          }
        }
        
        // Load closing time
        if (data['closingTime'] != null) {
          final parts = data['closingTime'].toString().split(':');
          if (parts.length == 2) {
            _closingTime = TimeOfDay(
              hour: int.parse(parts[0]),
              minute: int.parse(parts[1]),
            );
          }
        }
        
        // Load weekly closed day
        _weeklyClosedDay = data['weeklyClosedDay']?.toString();

        // Load puja timings
        if (data['pujaTimings'] != null && data['pujaTimings'] is List) {
          _pujaTimings = (data['pujaTimings'] as List)
              .where((e) => e != null && e is Map)
              .map((e) {
                final map = e as Map<String, dynamic>;
                return {
                  'name': map['name']?.toString() ?? '',
                  'time': map['time']?.toString() ?? '',
                };
              })
              .toList();
        }
        
        // Load special darshan timings
        if (data['specialDarshanTimings'] != null &&
            data['specialDarshanTimings'] is List) {
          _specialDarshanTimings = (data['specialDarshanTimings'] as List)
              .where((e) => e != null && e is Map)
              .map((e) {
                final map = e as Map<String, dynamic>;
                return {
                  'name': map['name']?.toString() ?? '',
                  'time': map['time']?.toString() ?? '',
                };
              })
              .toList();
        }
        
        // Load festival timings note
        _festivalTimingsNote = data['festivalTimingsNote']?.toString() ?? '';
      } catch (e) {
        print('Error loading timings: $e');
        _openingTime = null;
        _closingTime = null;
        _pujaTimings = [];
        _specialDarshanTimings = [];
      }
      print('Debug: Timings loaded successfully');

      // Load images - FIXED: Add safer list handling
      print('Debug: Loading images...');
      try {
        if (data['images'] != null) {
          final imagesList = data['images'];
          if (imagesList is List) {
            _existingImageUrls = imagesList
                .where((e) => e != null)
                .map((e) => e.toString())
                .toList();
            print('Debug: Loaded ${_existingImageUrls.length} images');
          } else {
            print(
              'Debug: images field is not a List: ${imagesList.runtimeType}',
            );
            _existingImageUrls = [];
          }
        } else {
          _existingImageUrls = [];
        }
      } catch (e) {
        print('Error loading images: $e');
        _existingImageUrls = [];
      }
      print('Debug: Images loaded successfully');

      // Load primary image index - FIXED: Add type safety and debugging
      print('Debug: Loading primary image index...');
      try {
        if (data['coverPhotoUrl'] != null && _existingImageUrls.isNotEmpty) {
          final coverUrl = data['coverPhotoUrl'].toString();
          print(
            'Debug: Looking for coverUrl: $coverUrl in images: $_existingImageUrls',
          );
          final foundIndex = _existingImageUrls.indexOf(coverUrl);
          print('Debug: Found index: $foundIndex');
          if (foundIndex >= 0 && foundIndex < _existingImageUrls.length) {
            _primaryImageIndex = foundIndex;
          } else {
            _primaryImageIndex = 0;
          }
        } else {
          _primaryImageIndex = 0;
        }
      } catch (e) {
        print('Error setting primary image index: $e');
        _primaryImageIndex = 0;
      }
      print('Debug: Primary image index loaded successfully');

      // Load features (no traditions)
      print('Debug: Loading features...');
      try {
        if (data['features'] != null) {
          final featuresList = data['features'];
          if (featuresList is List) {
            final features = featuresList
                .where((e) => e != null)
                .map((e) => e.toString())
                .toList();
            for (final feature in features) {
              if (_features.containsKey(feature)) {
                _features[feature] = true;
              }
            }
          }
        }
      } catch (e) {
        print('Error loading features: $e');
      }
      print('Debug: Features loaded successfully');

      // Temple category removed - using mainDeity instead
      print('Debug: Temple category field removed (using mainDeity)');

      // Load booking system - FIXED: Add safer list handling
      print('Debug: Loading booking system...');
      _acceptsBookings = data['acceptsBookings'] ?? false;
      try {
        if (data['availableBookingTypes'] != null) {
          final bookingTypesList = data['availableBookingTypes'];
          if (bookingTypesList is List) {
            final bookingTypes = bookingTypesList
                .where((e) => e != null)
                .map((e) => e.toString())
                .toList();
            for (final type in bookingTypes) {
              if (_bookingTypes.containsKey(type)) {
                _bookingTypes[type] = true;
              }
            }
          }
        }
      } catch (e) {
        print('Error loading booking types: $e');
      }
      if (data['bookingSettings'] != null && data['bookingSettings'] is Map) {
        final settings = data['bookingSettings'] as Map<String, dynamic>;
        // FIXED: Add safe integer parsing
        _advanceBookingDays = _safeParseInt(settings['advanceBookingDays'], 30);
        _slotsPerDay = _safeParseInt(settings['slotsPerDay'], 10);
        _slotDurationMinutes = _safeParseInt(
          settings['slotDurationMinutes'],
          30,
        );
      }
      print('Debug: Booking system loaded successfully');

      // Load donation system - FIXED: Add safer list handling
      print('Debug: Loading donation system...');
      _acceptsDonations = data['acceptsDonations'] ?? false;
      try {
        if (data['donationPurposes'] != null) {
          final purposesList = data['donationPurposes'];
          if (purposesList is List) {
            final purposes = purposesList
                .where((e) => e != null)
                .map((e) => e.toString())
                .toList();
            // Reset all to false first
            _donationPurposes.updateAll((key, value) => false);
            for (final purpose in purposes) {
              if (_donationPurposes.containsKey(purpose)) {
                _donationPurposes[purpose] = true;
              }
            }
          }
        }
      } catch (e) {
        print('Error loading donation purposes: $e');
      }
      print('Debug: Donation system loaded successfully');

      // Load event management - FIXED: Add safer list handling
      print('Debug: Loading event management...');
      _hasEvents = data['hasUpcomingEvents'] ?? false;
      try {
        if (data['eventCategories'] != null) {
          final categoriesList = data['eventCategories'];
          if (categoriesList is List) {
            final categories = categoriesList
                .where((e) => e != null)
                .map((e) => e.toString())
                .toList();
            for (final category in categories) {
              if (_eventCategories.containsKey(category)) {
                _eventCategories[category] = true;
              }
            }
          }
        }
      } catch (e) {
        print('Error loading event categories: $e');
      }
      if (data['eventSettings'] != null && data['eventSettings'] is Map) {
        final settings = data['eventSettings'] as Map<String, dynamic>;
        _eventCapacity = _safeParseInt(settings['capacity'], 100);
      }
      print('Debug: Event management loaded successfully');

      // Load community features
      print('Debug: Loading community features...');
      _allowsReviews = data['allowsReviews'] ?? true;
      if (data['communitySettings'] != null &&
          data['communitySettings'] is Map) {
        final settings = data['communitySettings'] as Map<String, dynamic>;
        _allowsPhotoSharing = settings['allowsPhotoSharing'] ?? true;
        _moderationEnabled = settings['moderationEnabled'] ?? true;
        _communityGuidelinesController.text =
            settings['guidelines']?.toString() ?? '';
      }
      print('Debug: Community features loaded successfully');

      // Load live darshan - Support both single and multiple channels
      print('Debug: Loading live darshan...');
      if (data['liveDarshan'] != null && data['liveDarshan'] is Map) {
        final liveDarshan = data['liveDarshan'] as Map<String, dynamic>;
        
        // Check if it's the new multiple channels format
        if (liveDarshan['channels'] != null &&
            liveDarshan['channels'] is List) {
          final channels = liveDarshan['channels'] as List;
          _liveDarshanChannels.clear();
          
          for (final channel in channels) {
            if (channel is Map<String, dynamic>) {
              _liveDarshanChannels.add({
                'name': TextEditingController(
                  text: channel['name']?.toString() ?? '',
                ),
                'url': TextEditingController(
                  text: channel['youtubeChannelUrl']?.toString() ?? '',
                ),
                'channelId': TextEditingController(
                  text: channel['youtubeChannelId']?.toString() ?? '',
                ),
                'keyword': TextEditingController(
                  text: channel['keyword']?.toString() ?? '',
                ),
              });
            }
          }
          print(
            '   ✅ Loaded ${_liveDarshanChannels.length} live darshan channels',
          );
        } else {
          // Legacy single channel format - convert to new format
          _youtubeChannelUrlController.text =
              liveDarshan['youtubeChannelUrl']?.toString() ?? '';
          _youtubeChannelIdController.text =
              liveDarshan['youtubeChannelId']?.toString() ?? '';

          // If there's legacy data, create a single channel entry
          if (_youtubeChannelUrlController.text.isNotEmpty ||
              _youtubeChannelIdController.text.isNotEmpty) {
            _liveDarshanChannels.clear();
            _liveDarshanChannels.add({
              'name': TextEditingController(text: 'Main Channel'),
              'url': TextEditingController(
                text: _youtubeChannelUrlController.text,
              ),
              'channelId': TextEditingController(
                text: _youtubeChannelIdController.text,
              ),
              'keyword': TextEditingController(
                text: data['liveKeyword']?.toString() ?? '',
              ),
            });
            print('   ✅ Converted legacy single channel to new format');
          }
        }
      }
      
      // Load legacy live keyword (for backward compatibility)
      _liveKeywordController.text = data['liveKeyword']?.toString() ?? '';
      print('Debug: Live darshan loaded successfully');

      // Load accessibility
      print('Debug: Loading accessibility...');
      if (data['accessibility'] != null && data['accessibility'] is Map) {
        final accessibility = data['accessibility'] as Map<String, dynamic>;
        _wheelchairAccessible = accessibility['wheelchairAccessible'] ?? false;
        _parkingAvailable = accessibility['parkingAvailable'] ?? false;
        _parkingDetails = accessibility['parkingDetails']?.toString() ?? '';
        _accessibilityNotes =
            accessibility['accessibilityNotes']?.toString() ?? '';
      }
      print('Debug: Accessibility loaded successfully');
      print('✅ Debug: All temple data loaded successfully!');

      // Verify that key fields have been populated
      _verifyDataLoading();
    } catch (e) {
      // Handle any data loading errors gracefully
      print('Error loading temple data: $e');
      // Use WidgetsBinding to show error after build completes
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error loading temple data: ${e.toString()}'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      });
      // Set default values to prevent crashes
      _nameController.text = '';
      _titleController.text = '';
      _locationTextController.text = '';
      _aboutTempleController.text = '';
      _mainDeityController.text = '';
      _templeHistoryController.text = '';
      _primaryImageIndex = 0;
      _existingImageUrls.clear();
    }
  }

  /// Verify that data has been loaded into form fields
  void _verifyDataLoading() {
    print('🔍 Verifying data loading:');
    print(
      '   Name: "${_nameController.text}" (${_nameController.text.isEmpty ? "EMPTY" : "OK"})',
    );
    print(
      '   Title: "${_titleController.text}" (${_titleController.text.isEmpty ? "EMPTY" : "OK"})',
    );
    print(
      '   Location: "${_locationTextController.text}" (${_locationTextController.text.isEmpty ? "EMPTY" : "OK"})',
    );
    print(
      '   About: "${_aboutTempleController.text.isEmpty
          ? "(empty)"
          : _aboutTempleController.text.length > 30
          ? '${_aboutTempleController.text.substring(0, 30)}...'
          : _aboutTempleController.text}" (${_aboutTempleController.text.isEmpty ? "EMPTY" : "OK"})',
    );
    print(
      '   Phone: "${_phoneController.text}" (${_phoneController.text.isEmpty ? "EMPTY" : "OK"})',
    );
    print(
      '   Email: "${_emailController.text}" (${_emailController.text.isEmpty ? "EMPTY" : "OK"})',
    );
    print('   Images: ${_existingImageUrls.length} images loaded');
    
    // Show a snackbar if critical fields are empty
    if (_nameController.text.isEmpty && _titleController.text.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '⚠️ Warning: Temple data appears to be empty. Please check the source data.',
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    
    // RealtimeMixin will automatically handle stream cleanup
    
    // Dispose all controllers
    _nameController.dispose();
    _titleController.dispose();
    _locationTextController.dispose();
    _locationLinkController.dispose();
    _aboutTempleController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _websiteController.dispose();
    _facebookController.dispose();
    _instagramController.dispose();
    _twitterController.dispose();
    _youtubeController.dispose();
    _pujaPriceController.dispose();
    _minDonationController.dispose();
    _suggestedDonationController.dispose();
    _youtubeChannelUrlController.dispose();
    _youtubeChannelIdController.dispose();
    _liveKeywordController.dispose();
    _mainDeityController.dispose();
    _templeHistoryController.dispose();
    _communityGuidelinesController.dispose();

    // Dispose multiple live darshan channel controllers
    for (final channel in _liveDarshanChannels) {
      channel.values.forEach((controller) {
        controller.dispose();
      });
    }

    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    if (_isCheckingPermissions) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('Edit Temple'),
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Edit Temple',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever),
            onPressed: _showDeleteConfirmation,
            tooltip: 'Delete Temple',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Basic Info'),
            Tab(text: 'Contact'),
            Tab(text: 'Features'),
            Tab(text: 'Services'),
            Tab(text: 'Media'),
            Tab(text: 'Advanced'),
          ],
        ),
      ),
      body: Form(
        key: _formKey,
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildBasicInfoTab(),
            _buildContactTab(),
            _buildFeaturesTab(),
            _buildServicesTab(),
            _buildMediaTab(),
            _buildAdvancedTab(),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            if (_tabController.index > 0)
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    _tabController.animateTo(_tabController.index - 1);
                  },
                  child: const Text('Previous'),
                ),
              ),
            if (_tabController.index > 0) const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleNextOrUpdate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : Text(
                        _tabController.index == 5 ? 'Update Temple' : 'Next',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleNextOrUpdate() {
    if (_tabController.index == 5) {
      _updateTemple();
    } else {
      _tabController.animateTo(_tabController.index + 1);
    }
  }

  // Build methods for each tab (same as Add Temple but with loaded data)
  Widget _buildBasicInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Data loading status indicator
          if (_nameController.text.isNotEmpty ||
              _titleController.text.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Temple data loaded: ${_nameController.text}',
                      style: TextStyle(
                        color: Colors.green[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  // Realtime indicator
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.sync, color: Colors.orange, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          'LIVE',
                          style: TextStyle(
                            color: Colors.orange[700],
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          _buildSectionCard(
            title: 'Temple Information',
            icon: Icons.temple_hindu,
            children: [
              _buildTextField(
                controller: _nameController,
                label: 'Temple Name *',
                icon: Icons.temple_hindu,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Temple name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _titleController,
                label: 'Temple Title *',
                icon: Icons.title,
                hint: 'e.g., Shri Ram Mandir, Mata Vaishno Devi Temple',
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Temple title is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _aboutTempleController,
                label: 'About Temple *',
                icon: Icons.description,
                maxLines: 4,
                hint: 'Describe the temple, its significance, and history',
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Temple description is required';
                  }
                  return null;
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            title: 'Location',
            icon: Icons.location_on,
            children: [
              _buildTextField(
                controller: _locationTextController,
                label: 'Address *',
                icon: Icons.location_on,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Address is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _pickLocationOnMap,
                  icon: const Icon(Icons.map),
                  label: const Text('Update Location on Map'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              if (_locationAddress != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Current: $_locationAddress',
                          style: TextStyle(
                            color: Colors.green[900],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            title: 'Main Deity',
            icon: Icons.auto_awesome,
            children: [
              DropdownButtonFormField<String>(
                value: _mainDeity,
                decoration: InputDecoration(
                  labelText: 'Main Deity *',
                  prefixIcon: const Icon(Icons.auto_awesome),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                items: _mainDeityOptions.map((deity) {
                  return DropdownMenuItem(
                    value: deity, child: Text(deity),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _mainDeity = value!;
                    // If "Other" is selected, keep the custom text
                    if (_mainDeity != 'Other') {
                      _mainDeityController.text = _mainDeity;
                    }
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select main deity';
                  }
                  return null;
                },
              ),
              if (_mainDeity == 'Other') ...[
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _mainDeityController,
                  label: 'Specify Deity Name *',
                  icon: Icons.edit,
                  hint: 'Enter deity name',
                  validator: (value) {
                    if (_mainDeity == 'Other' &&
                        (value == null || value.trim().isEmpty)) {
                      return 'Please specify the deity name';
                    }
                    return null;
                  },
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            title: 'Timings',
            icon: Icons.access_time,
            children: [_buildTimingsSection()],
          ),
        ],
      ),
    );
  }

  Widget _buildContactTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildSectionCard(
            title: 'Contact Information',
            icon: Icons.contact_phone,
            children: [
              _buildTextField(
                controller: _phoneController,
                label: 'Phone Number',
                icon: Icons.phone,
                keyboardType: TextInputType.phone,
                hint: '+91 9876543210',
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    if (!RegExp(r'^\+?[\d\s\-\(\)]+$').hasMatch(value)) {
                      return 'Please enter a valid phone number';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _emailController,
                label: 'Email Address',
                icon: Icons.email,
                keyboardType: TextInputType.emailAddress,
                hint: 'temple@example.com',
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    if (!RegExp(
                      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                    ).hasMatch(value)) {
                      return 'Please enter a valid email address';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _websiteController,
                label: 'Website URL',
                icon: Icons.web,
                keyboardType: TextInputType.url,
                hint: 'https://temple-website.com',
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    final uri = Uri.tryParse(value);
                    if (uri?.hasAbsolutePath != true) {
                      return 'Please enter a valid website URL';
                    }
                  }
                  return null;
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            title: 'Social Media',
            icon: Icons.share,
            children: [
              _buildTextField(
                controller: _facebookController,
                label: 'Facebook Page',
                icon: Icons.facebook,
                hint: 'https://facebook.com/templepage',
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _instagramController,
                label: 'Instagram Handle',
                icon: Icons.camera_alt,
                hint: '@templename',
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _twitterController,
                label: 'Twitter Handle',
                icon: Icons.alternate_email,
                hint: '@templename',
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _youtubeController,
                label: 'YouTube Channel',
                icon: Icons.video_library,
                hint: 'https://youtube.com/@templename',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildSectionCard(
            title: 'Temple Features & Amenities',
            icon: Icons.featured_play_list,
            children: [
              const Text(
                'Select all facilities available at the temple',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 12),
              ..._features.entries.map((entry) {
                return CheckboxListTile(
                  title: Text(entry.key),
                  value: entry.value,
                  onChanged: (value) {
                    setState(() {
                      _features[entry.key] = value!;
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                );
              }),
            ],
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            title: 'Accessibility',
            icon: Icons.accessible,
            children: [
              SwitchListTile(
                title: const Text('Wheelchair Accessible'),
                subtitle: const Text(
                  'Temple is accessible for wheelchair users',
                ),
                value: _wheelchairAccessible,
                onChanged: (value) {
                  setState(() {
                    _wheelchairAccessible = value;
                  });
                },
              ),
              SwitchListTile(
                title: const Text('Parking Available'),
                subtitle: const Text('Parking facility available'),
                value: _parkingAvailable,
                onChanged: (value) {
                  setState(() {
                    _parkingAvailable = value;
                  });
                },
              ),
              if (_parkingAvailable) ...[
                const SizedBox(height: 16),
                _buildTextField(
                  controller: TextEditingController(text: _parkingDetails),
                  label: 'Parking Details',
                  icon: Icons.local_parking,
                  hint: 'Free parking for 100 cars, paid parking available',
                  onChanged: (value) => _parkingDetails = value,
                ),
              ],
              const SizedBox(height: 16),
              _buildTextField(
                controller: TextEditingController(text: _accessibilityNotes),
                label: 'Accessibility Notes',
                icon: Icons.note,
                maxLines: 3,
                hint: 'Additional accessibility information',
                onChanged: (value) => _accessibilityNotes = value,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildServicesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildSectionCard(
            title: 'Booking System',
            icon: Icons.book_online,
            children: [
              SwitchListTile(
                title: const Text('Accept Bookings'),
                subtitle: const Text('Enable online booking system'),
                value: _acceptsBookings,
                onChanged: (value) {
                  setState(() {
                    _acceptsBookings = value;
                  });
                },
              ),
              if (_acceptsBookings) ...[
                const Divider(),
                const Text(
                  'Booking Types',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                ..._bookingTypes.entries.map((entry) {
                  return CheckboxListTile(
                    title: Text(entry.key),
                    value: entry.value,
                    onChanged: (value) {
                      setState(() {
                        _bookingTypes[entry.key] = value!;
                      });
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                  );
                }),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: TextEditingController(
                          text: _advanceBookingDays.toString(),
                        ),
                        label: 'Advance Booking Days',
                        icon: Icons.calendar_today,
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          _advanceBookingDays = int.tryParse(value) ?? 30;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildTextField(
                        controller: TextEditingController(
                          text: _slotsPerDay.toString(),
                        ),
                        label: 'Slots Per Day',
                        icon: Icons.schedule,
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          _slotsPerDay = int.tryParse(value) ?? 10;
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            title: 'Donation System',
            icon: Icons.volunteer_activism,
            children: [
              SwitchListTile(
                title: const Text('Accept Donations'),
                subtitle: const Text('Enable online donation system'),
                value: _acceptsDonations,
                onChanged: (value) {
                  setState(() {
                    _acceptsDonations = value;
                  });
                },
              ),
              if (_acceptsDonations) ...[
                const Divider(),
                const Text(
                  'Donation Purposes',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                ..._donationPurposes.entries.map((entry) {
                  return CheckboxListTile(
                    title: Text(entry.key),
                    value: entry.value,
                    onChanged: (value) {
                      setState(() {
                        _donationPurposes[entry.key] = value!;
                      });
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                  );
                }),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _minDonationController,
                        label: 'Minimum Amount (₹)',
                        icon: Icons.currency_rupee,
                        keyboardType: TextInputType.number,
                        hint: '10',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildTextField(
                        controller: _suggestedDonationController,
                        label: 'Suggested Amount (₹)',
                        icon: Icons.recommend,
                        keyboardType: TextInputType.number,
                        hint: '100',
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          // Base Puja Price Section
          _buildSectionCard(
            title: 'Base Puja Price',
            icon: Icons.currency_rupee,
            children: [
              const Text(
                'Set a default price for general puja services',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _pujaPriceController,
                label: 'Base Puja Price (₹) *',
                icon: Icons.currency_rupee,
                keyboardType: TextInputType.number,
                hint: '51',
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Base puja price is required';
                  }
                  final parsedValue = double.tryParse(value);
                  if (parsedValue == null) {
                    return 'Please enter a valid price';
                  }
                  return null;
                },
              ),
            ],
          ),
          
          const SizedBox(height: 16),

          // Puja Services Catalog Section
          _buildSectionCard(
            title: 'Puja Services Catalog',
            icon: Icons.temple_hindu,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Add specific puja services with individual pricing',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Examples: Morning Aarti, Abhishek, Special Puja',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _addPujaService,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryOrange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (_pujaServices.isEmpty)
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: AppColors.veryLightGray,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderGray, width: 1),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.temple_hindu,
                          size: 56,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No puja services added yet',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Click "Add" to create your first service',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Column(
                  children: _pujaServices.asMap().entries.map((entry) {
                    final index = entry.key;
                    final service = entry.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.borderGray,
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: _getCategoryColor(
                            service['category'],
                          ),
                          radius: 22,
                          child: Icon(
                            _getCategoryIcon(service['category']),
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          service['name'],
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '${service['category']} • ₹${service['price']} • ${service['duration']} min',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 20),
                              color: AppColors.primaryOrange,
                              onPressed: () => _editPujaService(index),
                              tooltip: 'Edit',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20),
                              color: AppColors.errorRed,
                              onPressed: () {
                                setState(() {
                                  _pujaServices.removeAt(index);
                                });
                              },
                              tooltip: 'Delete',
                            ),
                          ],
                        ),
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.veryLightGray,
                              borderRadius: const BorderRadius.only(
                                bottomLeft: Radius.circular(12),
                                bottomRight: Radius.circular(12),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (service['description']?.isNotEmpty ??
                                    false) ...[
                                  Text(
                                    service['description'],
                                    style: TextStyle(
                                      color: Colors.grey[700],
                                      fontSize: 13,
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    if (service['requiresAdvanceBooking'] ??
                                        false)
                                      Chip(
                                        label: Text(
                                          'Advance: ${service['advanceBookingDays']} days',
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                        backgroundColor: Colors.orange[50],
                                        side: BorderSide(
                                          color: Colors.orange[200]!,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
                                        avatar: Icon(
                                          Icons.calendar_today,
                                          size: 14,
                                          color: Colors.orange[700],
                                        ),
                                      ),
                                    if (service['maxBookingsPerDay'] != null)
                                      Chip(
                                        label: Text(
                                          'Max: ${service['maxBookingsPerDay']}/day',
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                        backgroundColor: Colors.purple[50],
                                        side: BorderSide(
                                          color: Colors.purple[200]!,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
                                        avatar: Icon(
                                          Icons.people,
                                          size: 14,
                                          color: Colors.purple[700],
                                        ),
                                      ),
                                    if (service['timeSlots']?.isNotEmpty ??
                                        false)
                                      Chip(
                                        label: Text(
                                          '${service['timeSlots'].length} time slots',
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                        backgroundColor: Colors.green[50],
                                        side: BorderSide(
                                          color: Colors.green[200]!,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
                                        avatar: Icon(
                                          Icons.access_time,
                                          size: 14,
                                          color: Colors.green[700],
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            title: 'Event Management',
            icon: Icons.event,
            children: [
              SwitchListTile(
                title: const Text('Host Events'),
                subtitle: const Text('Temple hosts events and festivals'),
                value: _hasEvents,
                onChanged: (value) {
                  setState(() {
                    _hasEvents = value;
                  });
                },
              ),
              if (_hasEvents) ...[
                const Divider(),
                const Text(
                  'Event Categories',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                ..._eventCategories.entries.map((entry) {
                  return CheckboxListTile(
                    title: Text(entry.key),
                    value: entry.value,
                    onChanged: (value) {
                      setState(() {
                        _eventCategories[entry.key] = value!;
                      });
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                  );
                }),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: TextEditingController(
                    text: _eventCapacity.toString(),
                  ),
                  label: 'Event Capacity',
                  icon: Icons.people,
                  keyboardType: TextInputType.number,
                  hint: '100',
                  onChanged: (value) {
                    _eventCapacity = int.tryParse(value) ?? 100;
                  },
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMediaTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildSectionCard(
            title: 'Temple Images',
            icon: Icons.photo_library,
            children: [
              _buildImageGallery(),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _pickImages,
                      icon: const Icon(Icons.add_photo_alternate),
                      label: const Text('Add Images'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed:
                          _existingImageUrls.isNotEmpty ||
                              _newImageFiles.isNotEmpty
                          ? _clearAllImages
                          : null,
                      icon: const Icon(Icons.clear_all),
                      label: const Text('Clear All'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            title: 'Community Settings',
            icon: Icons.people,
            children: [
              SwitchListTile(
                title: const Text('Allow Reviews'),
                subtitle: const Text('Users can write reviews'),
                value: _allowsReviews,
                onChanged: (value) {
                  setState(() {
                    _allowsReviews = value;
                  });
                },
              ),
              SwitchListTile(
                title: const Text('Allow Photo Sharing'),
                subtitle: const Text('Users can share photos'),
                value: _allowsPhotoSharing,
                onChanged: (value) {
                  setState(() {
                    _allowsPhotoSharing = value;
                  });
                },
              ),
              SwitchListTile(
                title: const Text('Enable Moderation'),
                subtitle: const Text('Review content before publishing'),
                value: _moderationEnabled,
                onChanged: (value) {
                  setState(() {
                    _moderationEnabled = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _communityGuidelinesController,
                label: 'Community Guidelines',
                icon: Icons.rule,
                maxLines: 4,
                hint: 'Guidelines for user behavior and content',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildLiveDarshanSection(),
          const SizedBox(height: 16),
          _buildSectionCard(
            title: 'Temple History',
            icon: Icons.history_edu,
            children: [
              _buildTextField(
                controller: _templeHistoryController,
                label: 'Temple History',
                icon: Icons.history,
                maxLines: 6,
                hint:
                    'Historical significance, founding story, important events...',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImageGallery() {
    final totalImages = _existingImageUrls.length + _newImageFiles.length;

    if (totalImages == 0) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: InkWell(
          onTap: _pickImages,
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_photo_alternate, size: 48, color: Colors.grey),
              SizedBox(height: 8),
              Text(
                'Add Temple Images',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
              Text(
                'Tap to select multiple images',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: totalImages + 1,
      itemBuilder: (context, index) {
        if (index == totalImages) {
          return InkWell(
            onTap: _pickImages,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, size: 32, color: Colors.grey),
                  Text('Add More', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          );
        }

        final isExistingImage = index < _existingImageUrls.length;
        final isPrimary = _primaryImageIndex == index;

        return Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: isPrimary
                    ? Border.all(color: Colors.orange, width: 3)
                    : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: isExistingImage
                    ? Image.network(
                        _existingImageUrls[index],
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[300],
                            child: const Icon(Icons.error, color: Colors.red),
                          );
                        },
                      )
                    : Image.file(
                        _newImageFiles[index - _existingImageUrls.length],
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      ),
              ),
            ),
            if (isPrimary)
              Positioned(
                top: 4,
                left: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'PRIMARY',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            Positioned(
              top: 4,
              right: 4,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isPrimary)
                    InkWell(
                      onTap: () {
                        setState(() {
                          _primaryImageIndex = index;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.orange,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.star,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: () => _removeImage(index),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // Helper methods for building UI components
  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.orange, width: 2),
        ),
      ),
    );
  }

  Widget _buildTimingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Opening and Closing Time
        const Text(
          'Temple Opening Hours',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => _selectOpeningTime(),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Opening Time *',
                    prefixIcon: const Icon(Icons.wb_sunny),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    _openingTime != null
                        ? _openingTime!.format(context)
                        : 'Select time',
                    style: TextStyle(
                      color: _openingTime != null ? Colors.black : Colors.grey,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onTap: () => _selectClosingTime(),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Closing Time *',
                    prefixIcon: const Icon(Icons.nightlight),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    _closingTime != null
                        ? _closingTime!.format(context)
                        : 'Select time',
                    style: TextStyle(
                      color: _closingTime != null ? Colors.black : Colors.grey,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Weekly Closed Day
        DropdownButtonFormField<String>(
          value: _weeklyClosedDay ?? 'None',
          decoration: InputDecoration(
            labelText: 'Weekly Closed Day',
            prefixIcon: const Icon(Icons.event_busy),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            helperText: 'Select if temple is closed on any specific day',
          ),
          items: _weekDays.map((day) {
            return DropdownMenuItem(value: day, child: Text(day));
          }).toList(),
          onChanged: (value) {
            setState(() {
              _weeklyClosedDay = value == 'None' ? null : value;
            });
          },
        ),

        const SizedBox(height: 24),

        // Puja/Aarti Timings
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Puja / Aarti Timings',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            TextButton.icon(
              onPressed: _addPujaTimings,
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_pujaTimings.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text(
                'No puja timings added yet',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          ..._pujaTimings.map(
            (timing) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.temple_hindu, color: Colors.orange),
                title: Text(
                  timing['name']!,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(timing['time']!),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    setState(() {
                      _pujaTimings.remove(timing);
                    });
                  },
                ),
              ),
            ),
          ),

        const SizedBox(height: 24),

        // Special Darshan Timings
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Special Darshan Timings',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            TextButton.icon(
              onPressed: _addSpecialDarshanTimings,
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'VIP Darshan, Senior Citizen Darshan, etc.',
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
        const SizedBox(height: 8),
        if (_specialDarshanTimings.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text(
                'No special darshan timings added',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          ..._specialDarshanTimings.map(
            (timing) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.star, color: Colors.purple),
                title: Text(
                  timing['name']!,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(timing['time']!),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    setState(() {
                      _specialDarshanTimings.remove(timing);
                    });
                  },
                ),
              ),
            ),
          ),

        const SizedBox(height: 24),

        // Festival / Special Day Timings Note
        TextField(
          controller: TextEditingController(text: _festivalTimingsNote),
          decoration: InputDecoration(
            labelText: 'Festival / Special Day Timings (Optional)',
            prefixIcon: const Icon(Icons.celebration),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            helperText: 'e.g., "Extended hours during Diwali and Navratri"',
            helperMaxLines: 2,
          ),
          maxLines: 3,
          onChanged: (value) {
            _festivalTimingsNote = value;
          },
        ),
      ],
    );
  }

  Future<void> _selectOpeningTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _openingTime ?? const TimeOfDay(hour: 6, minute: 0),
    );
    if (time != null) {
      setState(() {
        _openingTime = time;
      });
    }
  }

  Future<void> _selectClosingTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _closingTime ?? const TimeOfDay(hour: 20, minute: 0),
    );
    if (time != null) {
      setState(() {
        _closingTime = time;
      });
    }
  }

  Future<void> _addPujaTimings() async {
    final nameController = TextEditingController();
    final timeController = TextEditingController();
    TimeOfDay? selectedTime;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Puja/Aarti Timing'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Puja/Aarti Name *',
                hintText: 'e.g., Morning Aarti, Abhishek',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.now(),
                );
                if (time != null) {
                  selectedTime = time;
                  timeController.text = time.format(context);
                }
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Time *',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.access_time),
                ),
                child: Text(
                  timeController.text.isEmpty
                      ? 'Select time'
                      : timeController.text,
                  style: TextStyle(
                    color: timeController.text.isEmpty
                        ? Colors.grey
                        : Colors.black,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty && selectedTime != null) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result == true && selectedTime != null) {
      setState(() {
        _pujaTimings.add({
          'name': nameController.text,
          'time': selectedTime!.format(context),
        });
      });
    }
  }

  Future<void> _addSpecialDarshanTimings() async {
    final nameController = TextEditingController();
    final timeController = TextEditingController();
    TimeOfDay? selectedTime;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Special Darshan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Darshan Type *',
                hintText: 'e.g., VIP Darshan, Senior Citizen',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.now(),
                );
                if (time != null) {
                  selectedTime = time;
                  timeController.text = time.format(context);
                }
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Time *',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.access_time),
                ),
                child: Text(
                  timeController.text.isEmpty
                      ? 'Select time'
                      : timeController.text,
                  style: TextStyle(
                    color: timeController.text.isEmpty
                        ? Colors.grey
                        : Colors.black,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty && selectedTime != null) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result == true && selectedTime != null) {
      setState(() {
        _specialDarshanTimings.add({
          'name': nameController.text,
          'time': selectedTime!.format(context),
        });
      });
    }
  }

  Widget _buildLiveDarshanSection() {
    return _buildSectionCard(
      title: 'Live Darshan Configuration',
      icon: Icons.live_tv,
      children: [
        // Multiple channels support
        if (_liveDarshanChannels.isNotEmpty) ...[
          Text(
            'Live Darshan Channels (${_liveDarshanChannels.length})',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 12),
          
          // List of channels
          ...List.generate(_liveDarshanChannels.length, (index) {
            final channel = _liveDarshanChannels[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Channel ${index + 1}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete,
                          color: Colors.red,
                          size: 20,
                        ),
                        onPressed: () => _removeLiveDarshanChannel(index),
                        tooltip: 'Remove Channel',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  _buildTextField(
                    controller: channel['name']!,
                    label: 'Channel Name',
                    icon: Icons.label,
                    hint: 'e.g., Main Darshan, Evening Aarti',
                  ),
                  const SizedBox(height: 12),

                  _buildTextField(
                    controller: channel['url']!,
                    label: 'YouTube Channel URL',
                    icon: Icons.link,
                    hint: 'https://www.youtube.com/@channelname',
                    onChanged: (url) =>
                        _onYouTubeUrlChanged(url, channel['channelId']!),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: channel['channelId']!,
                          label: 'Channel ID',
                          icon: Icons.tag,
                          hint: 'UCxxxxxxxxxxxxxxxxxx',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color:
                              _isValidYouTubeChannelId(
                                channel['channelId']!.text,
                              )
                              ? Colors.green.withValues(alpha: 0.1)
                              : Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _isValidYouTubeChannelId(channel['channelId']!.text)
                              ? Icons.check_circle
                              : Icons.warning,
                          color:
                              _isValidYouTubeChannelId(
                                channel['channelId']!.text,
                              )
                              ? Colors.green
                              : Colors.orange,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  _buildTextField(
                    controller: channel['keyword']!,
                    label: 'Live Stream Keyword',
                    icon: Icons.search,
                    hint: 'e.g., morning, evening, special',
                  ),
                ],
              ),
            );
          }),
        ],
        
        // Add channel button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _addLiveDarshanChannel,
            icon: const Icon(Icons.add),
            label: Text(
              _liveDarshanChannels.isEmpty
                  ? 'Add Live Darshan Channel'
                  : 'Add Another Channel',
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: BorderSide(color: Colors.orange[300]!),
              foregroundColor: Colors.orange[700],
            ),
          ),
        ),
        
        const SizedBox(height: 16),

        // Legacy single channel support (for backward compatibility)
        if (_liveDarshanChannels.isEmpty) ...[
          const Divider(),
          const SizedBox(height: 16),
          Text(
            'Legacy Single Channel (Deprecated)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.orange[700],
            ),
          ),
          const SizedBox(height: 12),

          _buildTextField(
            controller: _youtubeChannelUrlController,
            label: 'YouTube Channel URL',
            icon: Icons.link,
            hint: 'https://www.youtube.com/@channelname',
            onChanged: (url) =>
                _onYouTubeUrlChanged(url, _youtubeChannelIdController),
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _youtubeChannelIdController,
            label: 'YouTube Channel ID',
            icon: Icons.tag,
            hint: 'UCxxxxxxxxxxxxxxxxxx',
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _liveKeywordController,
            label: 'Live Stream Keyword',
            icon: Icons.search,
            hint: 'e.g., shirdi, tirupati, kashi',
          ),
        ],
      ],
    );
  }

  // Action methods
  Future<void> _pickLocationOnMap() async {
    final dynamic result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SelectLocationMapScreen()),
    );

    // SelectLocationMapScreen returns a Map<String, dynamic> with a
    // 'coordinates' key (LatLng) plus optional address fields.
    if (result == null) return;

    final LatLng? picked = result is Map<String, dynamic>
        ? result['coordinates'] as LatLng?
        : result is LatLng
        ? result
        : null;

    if (picked == null) return;

    // Use address fields already resolved by SelectLocationMapScreen when
    // available, so we avoid a redundant reverse-geocoding call.
    final String? resolvedAddress = result is Map<String, dynamic>
        ? result['address'] as String?
        : null;
    final String? resolvedState = result is Map<String, dynamic>
        ? result['state'] as String?
        : null;
    final String? resolvedCity = result is Map<String, dynamic>
        ? result['city'] as String?
        : null;

    // Gujarat-only restriction
    if (resolvedState != null && resolvedState.isNotEmpty) {
      if (resolvedState != 'Gujarat') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Please select a location within Gujarat state only',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      setState(() {
        _locationLat = picked.latitude;
        _locationLng = picked.longitude;
        _locationAddress = resolvedAddress;
        _locationTextController.text = resolvedAddress ?? '';
        _locationLinkController.text =
            'https://www.google.com/maps/search/?api=1&query=${picked.latitude},${picked.longitude}';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '📍 Location updated: ${resolvedCity ?? ''}, $resolvedState',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    // Fallback: do reverse geocoding if state wasn't provided
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        picked.latitude,
        picked.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final state = place.administrativeArea;

        if (state != 'Gujarat') {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Please select a location within Gujarat state only',
                ),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }

        setState(() {
          _locationLat = picked.latitude;
          _locationLng = picked.longitude;

          _locationAddress = [
            place.name,
            place.subLocality,
            place.locality,
            place.administrativeArea,
            place.country,
          ].where((e) => e != null && e.isNotEmpty).join(', ');

          _locationTextController.text = _locationAddress ?? '';
          _locationLinkController.text =
              'https://www.google.com/maps/search/?api=1&query=${picked.latitude},${picked.longitude}';
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '📍 Location updated: ${place.locality}, ${place.administrativeArea}',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _locationLat = picked.latitude;
        _locationLng = picked.longitude;
        _locationAddress = 'Lat: ${picked.latitude}, Lng: ${picked.longitude}';
        _locationTextController.text = _locationAddress!;
        _locationLinkController.text =
            'https://www.google.com/maps/search/?api=1&query=${picked.latitude},${picked.longitude}';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📍 Location updated with coordinates'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> pickedFiles = await _imagePicker.pickMultiImage();
      if (pickedFiles.isNotEmpty) {
        setState(() {
          _newImageFiles.addAll(pickedFiles.map((file) => File(file.path)));
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error picking images: $e')));
      }
    }
  }

  /// Extract YouTube channel ID from various YouTube URL formats
  String? _extractYouTubeChannelId(String url) {
    if (url.isEmpty) return null;

    try {
      final uri = Uri.parse(url);

      // Handle different YouTube URL formats
      if (uri.host.contains('youtube.com') || uri.host.contains('youtu.be')) {
        // Format: https://www.youtube.com/channel/UCxxxxx
        if (url.contains('/channel/')) {
          final match = RegExp(r'/channel/([a-zA-Z0-9_-]{24})').firstMatch(url);
          if (match != null) {
            return match.group(1);
          }
        }

        // Format: https://www.youtube.com/@username
        if (url.contains('/@')) {
          // For @username format, we can't directly extract channel ID
          // This would require YouTube API call to resolve username to channel ID
          return null; // Return null to indicate manual entry needed
        }

        // Format: https://www.youtube.com/c/channelname or /user/username
        if (url.contains('/c/') || url.contains('/user/')) {
          // These also require API resolution
          return null;
        }
      }
    } catch (e) {
      debugPrint('Error parsing YouTube URL: $e');
    }

    return null;
  }

  /// Validate YouTube channel ID format
  bool _isValidYouTubeChannelId(String channelId) {
    return channelId.length == 24 && channelId.startsWith('UC');
  }

  /// Add a new live darshan channel
  void _addLiveDarshanChannel() {
    setState(() {
      _liveDarshanChannels.add({
        'name': TextEditingController(),
        'url': TextEditingController(),
        'channelId': TextEditingController(),
        'keyword': TextEditingController(),
      });
    });
  }

  /// Remove a live darshan channel
  void _removeLiveDarshanChannel(int index) {
    if (index >= 0 && index < _liveDarshanChannels.length) {
      setState(() {
        // Dispose controllers to prevent memory leaks
        _liveDarshanChannels[index].values.forEach((controller) {
          controller.dispose();
        });
        _liveDarshanChannels.removeAt(index);
      });
    }
  }

  /// Auto-extract channel ID when URL changes
  void _onYouTubeUrlChanged(
    String url,
    TextEditingController channelIdController,
  ) async {
    if (url.trim().isEmpty) {
      channelIdController.clear();
      return;
    }

    try {
      // Use YouTubeChannelService for better URL handling
      final channelData = await YouTubeChannelService.getChannelDataFromUrl(url);
      
      if (channelData != null) {
        channelIdController.text = channelData.channelId;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Channel found: ${channelData.channelTitle}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        // Fallback to simple extraction
        final extractedId = _extractYouTubeChannelId(url);
        if (extractedId != null) {
          channelIdController.text = extractedId;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Channel ID auto-extracted: $extractedId'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '⚠️ Could not extract channel ID. Please enter manually.',
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error extracting channel data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error extracting channel data: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _removeImage(int index) {
    setState(() {
      if (index < _existingImageUrls.length) {
        // Mark existing image for deletion
        _imagesToDelete.add(_existingImageUrls[index]);
        _existingImageUrls.removeAt(index);
      } else {
        // Remove new image file
        _newImageFiles.removeAt(index - _existingImageUrls.length);
      }

      // Adjust primary image index
      final totalImages = _existingImageUrls.length + _newImageFiles.length;
      if (_primaryImageIndex >= totalImages && totalImages > 0) {
        _primaryImageIndex = 0;
      }
    });
  }

  void _clearAllImages() {
    setState(() {
      _imagesToDelete.addAll(_existingImageUrls);
      _existingImageUrls.clear();
      _newImageFiles.clear();
      _primaryImageIndex = 0;
    });
  }

  Future<void> _updateTemple() async {
    if (_formKey.currentState == null || !_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all required fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Upload new images
      List<String> newImageUrls = [];
      for (int i = 0; i < _newImageFiles.length; i++) {
        final imageUrl = await _uploadImage(_newImageFiles[i], i);
        if (imageUrl != null) {
          newImageUrls.add(imageUrl);
        }
      }

      // Delete removed images from storage
      final storageService = HybridStorageService();
      for (final imageUrl in _imagesToDelete) {
        try {
          await storageService.deleteTempleImage(imageUrl);
        } catch (e) {
          debugPrint('Error deleting image: $e');
        }
      }

      // Combine existing and new images
      final allImageUrls = [..._existingImageUrls, ...newImageUrls];

      // Determine primary image URL
      String? primaryImageUrl;
      if (allImageUrls.isNotEmpty && _primaryImageIndex < allImageUrls.length) {
        primaryImageUrl = allImageUrls[_primaryImageIndex];
      }

      // Create comprehensive temple update data
      final updateData = _createUpdateData(allImageUrls, primaryImageUrl);

      // Update in Firestore
      await FirebaseFirestore.instance
          .collection('temples')
          .doc(widget.temple.id)
          .update(updateData);

      // Update live detection if YouTube channels changed
      await _updateLiveDetectionAfterEdit();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Temple updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating temple: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<String?> _uploadImage(File imageFile, int index) async {
    try {
      final storageService = HybridStorageService();

      final imageUrl = await storageService.uploadTempleImage(
        imageFile: imageFile,
        templeId: widget.temple.id,
      );
      
      return imageUrl;
    } catch (e) {
      debugPrint('Error uploading image $index: $e');
      return null;
    }
  }

  Map<String, dynamic> _createUpdateData(
    List<String> imageUrls,
    String? primaryImageUrl,
  ) {
    return {
      // Basic Information
      'name': _nameController.text.trim(),
      'title': _titleController.text.trim(),
      'aboutTemple': _aboutTempleController.text.trim(),
      'mainDeity': _mainDeity == 'Other'
          ? _mainDeityController.text.trim()
          : _mainDeity,
      'history': _templeHistoryController.text.trim(),

      // Location
      'location': {
        'address': _locationTextController.text.trim(),
        'fullAddress': _locationAddress,
        'latitude': _locationLat,
        'longitude': _locationLng,
        'state': 'Gujarat',
        'country': 'India',
      },
      'locationLink': _locationLinkController.text.trim(),

      // Contact Information
      'contact': {
        'phone': _phoneController.text.trim().isNotEmpty
            ? _phoneController.text.trim()
            : null,
        'email': _emailController.text.trim().isNotEmpty
            ? _emailController.text.trim()
            : null,
        'website': _websiteController.text.trim().isNotEmpty
            ? _websiteController.text.trim()
            : null,
        'socialMedia': {
          if (_facebookController.text.trim().isNotEmpty)
            'facebook': _facebookController.text.trim(),
          if (_instagramController.text.trim().isNotEmpty)
            'instagram': _instagramController.text.trim(),
          if (_twitterController.text.trim().isNotEmpty)
            'twitter': _twitterController.text.trim(),
          if (_youtubeController.text.trim().isNotEmpty)
            'youtube': _youtubeController.text.trim(),
        },
      },

      // Features (no traditions)
      'features': _features.entries
          .where((e) => e.value)
          .map((e) => e.key)
          .toList(),

      // Timings - Comprehensive timing data
      'openingTime': _openingTime != null
          ? '${_openingTime!.hour}:${_openingTime!.minute.toString().padLeft(2, '0')}'
          : null,
      'closingTime': _closingTime != null
          ? '${_closingTime!.hour}:${_closingTime!.minute.toString().padLeft(2, '0')}'
          : null,
      'weeklyClosedDay': _weeklyClosedDay,
      'timings': () {
        if (_openingTime == null || _closingTime == null) return <String, String>{};
        final open = '${_openingTime!.hour}:${_openingTime!.minute.toString().padLeft(2, '0')}';
        final close = '${_closingTime!.hour}:${_closingTime!.minute.toString().padLeft(2, '0')}';
        final range = '$open - $close';
        if (_weeklyClosedDay == null || _weeklyClosedDay == 'None') {
          return {'Daily': range};
        }
        const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
        return <String, String>{for (final d in days) if (d != _weeklyClosedDay) d: range};
      }(),
      'pujaTimings': _pujaTimings,
      'specialDarshanTimings': _specialDarshanTimings,
      'festivalTimingsNote': _festivalTimingsNote.isNotEmpty
          ? _festivalTimingsNote
          : null,

      // Pricing
      'pujaPrice': double.tryParse(_pujaPriceController.text.trim()) ?? 0.0,

      // Images
      'images': imageUrls,
      'coverPhotoUrl': primaryImageUrl,

      // Booking System
      'acceptsBookings': _acceptsBookings,
      'availableBookingTypes': _bookingTypes.entries
          .where((e) => e.value)
          .map((e) => e.key)
          .toList(),
      'bookingSettings': _acceptsBookings
          ? {
              'advanceBookingDays': _advanceBookingDays,
              'slotsPerDay': _slotsPerDay,
              'slotDurationMinutes': _slotDurationMinutes,
            }
          : null,

      // Donation System
      'acceptsDonations': _acceptsDonations,
      'donationPurposes': _donationPurposes.entries
          .where((e) => e.value)
          .map((e) => e.key)
          .toList(),
      'minimumDonationAmount': _minDonationController.text.trim().isNotEmpty
          ? double.tryParse(_minDonationController.text.trim())
          : null,
      'suggestedDonationAmount':
          _suggestedDonationController.text.trim().isNotEmpty
          ? double.tryParse(_suggestedDonationController.text.trim())
          : null,

      // Event Management
      'hasUpcomingEvents': _hasEvents,
      'eventCategories': _eventCategories.entries
          .where((e) => e.value)
          .map((e) => e.key)
          .toList(),
      'eventSettings': _hasEvents ? {'capacity': _eventCapacity} : null,

      // Community Features
      'allowsReviews': _allowsReviews,
      'communitySettings': {
        'allowsPhotoSharing': _allowsPhotoSharing,
        'moderationEnabled': _moderationEnabled,
        'guidelines': _communityGuidelinesController.text.trim().isNotEmpty
            ? _communityGuidelinesController.text.trim()
            : null,
      },

      // Live Darshan - Support for multiple channels
      'liveDarshan': _liveDarshanChannels.isNotEmpty
          ? {
              'channels': _liveDarshanChannels.map((channel) {
                return {
                  'name': channel['name']!.text.trim(),
                  'youtubeChannelUrl': channel['url']!.text.trim().isNotEmpty
                      ? channel['url']!.text.trim()
                      : null,
                  'youtubeChannelId': channel['channelId']!.text.trim().isNotEmpty
                      ? channel['channelId']!.text.trim()
                      : null,
                  'keyword': channel['keyword']!.text.trim().isNotEmpty
                      ? channel['keyword']!.text.trim()
                      : null,
                  'isConfiguredByAdmin': true,
                  'isCurrentlyLive': false,
                };
              }).where((channel) => 
                  channel['youtubeChannelUrl'] != null || 
                  channel['youtubeChannelId'] != null
              ).toList(),
              'isConfiguredByAdmin': true,
            }
          : _youtubeChannelUrlController.text.trim().isNotEmpty ||
              _youtubeChannelIdController.text.trim().isNotEmpty
          ? {
              // Legacy single channel support
              'youtubeChannelUrl':
                  _youtubeChannelUrlController.text.trim().isNotEmpty
                  ? _youtubeChannelUrlController.text.trim()
                  : null,
              'youtubeChannelId':
                  _youtubeChannelIdController.text.trim().isNotEmpty
                  ? _youtubeChannelIdController.text.trim()
                  : null,
              'isConfiguredByAdmin': true,
              'isCurrentlyLive': false,
            }
          : null,
      'liveKeyword': _liveKeywordController.text.trim().isNotEmpty
          ? _liveKeywordController.text.trim()
          : null,

      // Accessibility
      'accessibility': {
        'wheelchairAccessible': _wheelchairAccessible,
        'parkingAvailable': _parkingAvailable,
        'parkingDetails': _parkingDetails.isNotEmpty ? _parkingDetails : null,
        'accessibilityNotes': _accessibilityNotes.isNotEmpty
            ? _accessibilityNotes
            : null,
      },

      // System fields
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Update live detection after temple edit
  Future<void> _updateLiveDetectionAfterEdit() async {
    try {
      debugPrint('🔄 Updating live detection after temple edit: ${widget.temple.id}');
      
      final detector = HybridLiveDetector();
      
      // Check if any YouTube channels are configured
      bool hasYouTubeChannels = false;
      
      if (_liveDarshanChannels.isNotEmpty) {
        // Check new multi-channel format
        for (final channel in _liveDarshanChannels) {
          if (channel['channelId']!.text.trim().isNotEmpty) {
            hasYouTubeChannels = true;
            break;
          }
        }
      } else if (_youtubeChannelIdController.text.trim().isNotEmpty) {
        // Check legacy single channel format
        hasYouTubeChannels = true;
      }
      
      // Restart monitoring if channels are configured
      if (hasYouTubeChannels) {
        await detector.restartMonitoring(widget.temple.id);
        debugPrint('✅ Live detection restarted for temple: ${widget.temple.id}');
      } else {
        detector.stopMonitoring(widget.temple.id);
        debugPrint('ℹ️ No YouTube channels configured, live detection stopped');
      }
    } catch (e) {
      debugPrint('❌ Error updating live detection: $e');
      // Don't throw error as temple update was successful
    }
  }

  Future<void> _showDeleteConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Temple'),
        content: const Text(
          'Are you sure you want to delete this temple? This action cannot be undone and will remove all related data including donations, reviews, and favorites.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _deleteTemple();
    }
  }

  Future<void> _deleteTemple() async {
    setState(() => _isLoading = true);

    try {
      // Delete all temple images from storage
      final storageService = HybridStorageService();
      final allImages = [..._existingImageUrls, ..._imagesToDelete];
      for (final imageUrl in allImages) {
        try {
          await storageService.deleteTempleImage(imageUrl);
        } catch (e) {
          debugPrint('Error deleting image: $e');
        }
      }

      // Delete temple document
      await FirebaseFirestore.instance
          .collection('temples')
          .doc(widget.temple.id)
          .delete();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Temple deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting temple: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Puja Service Helper Methods
  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Aarti':
        return Colors.orange;
      case 'Regular Puja':
        return Colors.orange;
      case 'Special Puja':
        return Colors.purple;
      case 'Abhishek':
        return Colors.teal;
      case 'Havan':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Aarti':
        return Icons.wb_sunny;
      case 'Regular Puja':
        return Icons.temple_hindu;
      case 'Special Puja':
        return Icons.auto_awesome;
      case 'Abhishek':
        return Icons.water_drop;
      case 'Havan':
        return Icons.local_fire_department;
      default:
        return Icons.category;
    }
  }

  Future<void> _addPujaService() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _PujaServiceDialog(),
    );

    if (result != null) {
      setState(() {
        _pujaServices.add(result);
      });
    }
  }

  Future<void> _editPujaService(int index) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) =>
          _PujaServiceDialog(existingService: _pujaServices[index]),
    );

    if (result != null) {
      setState(() {
        _pujaServices[index] = result;
      });
    }
  }
}


// Puja Service Dialog Widget
class _PujaServiceDialog extends StatefulWidget {
  final Map<String, dynamic>? existingService;

  const _PujaServiceDialog({this.existingService});

  @override
  State<_PujaServiceDialog> createState() => _PujaServiceDialogState();
}

class _PujaServiceDialogState extends State<_PujaServiceDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _nameHindiController = TextEditingController();
  final _nameGujaratiController = TextEditingController();
  final _priceController = TextEditingController();
  final _durationController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _descriptionHindiController = TextEditingController();
  final _descriptionGujaratiController = TextEditingController();
  final _advanceBookingDaysController = TextEditingController();
  final _maxBookingsController = TextEditingController();

  String _selectedCategory = 'Regular Puja';
  bool _requiresAdvanceBooking = false;
  List<String> _timeSlots = [];

  final List<String> _categories = [
    'Aarti',
    'Regular Puja',
    'Special Puja',
    'Abhishek',
    'Havan',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existingService != null) {
      _loadExistingService();
    }
  }

  void _loadExistingService() {
    final service = widget.existingService!;
    _nameController.text = service['name'] ?? '';
    _nameHindiController.text = service['nameHindi'] ?? '';
    _nameGujaratiController.text = service['nameGujarati'] ?? '';
    _selectedCategory = service['category'] ?? 'Regular Puja';
    _priceController.text = service['price']?.toString() ?? '';
    _durationController.text = service['duration']?.toString() ?? '';
    _descriptionController.text = service['description'] ?? '';
    _descriptionHindiController.text = service['descriptionHindi'] ?? '';
    _descriptionGujaratiController.text = service['descriptionGujarati'] ?? '';
    _requiresAdvanceBooking = service['requiresAdvanceBooking'] ?? false;
    _advanceBookingDaysController.text =
        service['advanceBookingDays']?.toString() ?? '1';
    _maxBookingsController.text =
        service['maxBookingsPerDay']?.toString() ?? '';
    _timeSlots = List<String>.from(service['timeSlots'] ?? []);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameHindiController.dispose();
    _nameGujaratiController.dispose();
    _priceController.dispose();
    _durationController.dispose();
    _descriptionController.dispose();
    _descriptionHindiController.dispose();
    _descriptionGujaratiController.dispose();
    _advanceBookingDaysController.dispose();
    _maxBookingsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.existingService == null
            ? 'Add Puja Service'
            : 'Edit Puja Service',
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Service Name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Service Name (English) *',
                  hintText: 'e.g., Morning Aarti',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.temple_hindu),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Service name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Hindi Name
              TextFormField(
                controller: _nameHindiController,
                decoration: const InputDecoration(
                  labelText: 'Service Name (Hindi)',
                  hintText: 'e.g., प्रातः आरती',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.language),
                ),
              ),
              const SizedBox(height: 12),

              // Gujarati Name
              TextFormField(
                controller: _nameGujaratiController,
                decoration: const InputDecoration(
                  labelText: 'Service Name (Gujarati)',
                  hintText: 'e.g., સવારની આરતી',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.language),
                ),
              ),
              const SizedBox(height: 12),

              // Category
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
                items: _categories.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value!;
                  });
                },
              ),
              const SizedBox(height: 12),

              // Price and Duration
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _priceController,
                      decoration: const InputDecoration(
                        labelText: 'Price (₹) *',
                        hintText: '51',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.currency_rupee),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Required';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Invalid';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _durationController,
                      decoration: const InputDecoration(
                        labelText: 'Duration (min) *',
                        hintText: '30',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.timer),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Required';
                        }
                        if (int.tryParse(value) == null) {
                          return 'Invalid';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Description
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (English)',
                  hintText: 'Brief description of the service',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),

              // Description Hindi
              TextFormField(
                controller: _descriptionHindiController,
                decoration: const InputDecoration(
                  labelText: 'Description (Hindi)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),

              // Description Gujarati
              TextFormField(
                controller: _descriptionGujaratiController,
                decoration: const InputDecoration(
                  labelText: 'Description (Gujarati)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              const Divider(),
              const SizedBox(height: 16),

              // Advanced Settings
              const Text(
                'Booking Settings',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              // Advance Booking
              SwitchListTile(
                title: const Text('Requires Advance Booking'),
                value: _requiresAdvanceBooking,
                onChanged: (value) {
                  setState(() {
                    _requiresAdvanceBooking = value;
                  });
                },
                contentPadding: EdgeInsets.zero,
              ),

              if (_requiresAdvanceBooking) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _advanceBookingDaysController,
                  decoration: const InputDecoration(
                    labelText: 'Advance Booking Days',
                    hintText: '1',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_today),
                    helperText: 'How many days in advance to book',
                  ),
                  keyboardType: TextInputType.number,
                ),
              ],
              const SizedBox(height: 12),

              // Max Bookings Per Day
              TextFormField(
                controller: _maxBookingsController,
                decoration: const InputDecoration(
                  labelText: 'Max Bookings Per Day (Optional)',
                  hintText: 'e.g., 5',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.people),
                  helperText: 'Leave empty for unlimited',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),

              // Time Slots
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Available Time Slots'),
                  TextButton.icon(
                    onPressed: _addTimeSlot,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add'),
                  ),
                ],
              ),
              if (_timeSlots.isEmpty)
                const Text(
                  'No time slots added (available all day)',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _timeSlots.map((slot) {
                    return Chip(
                      label: Text(slot),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () {
                        setState(() {
                          _timeSlots.remove(slot);
                        });
                      },
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saveService,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _addTimeSlot() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (time != null) {
      final timeString = time.format(context);
      if (!_timeSlots.contains(timeString)) {
        setState(() {
          _timeSlots.add(timeString);
          _timeSlots.sort();
        });
      }
    }
  }

  void _saveService() {
    if (!_formKey.currentState!.validate()) return;

    final service = {
      'name': _nameController.text.trim(),
      'nameHindi': _nameHindiController.text.trim(),
      'nameGujarati': _nameGujaratiController.text.trim(),
      'category': _selectedCategory,
      'price': double.parse(_priceController.text.trim()),
      'duration': int.parse(_durationController.text.trim()),
      'description': _descriptionController.text.trim(),
      'descriptionHindi': _descriptionHindiController.text.trim(),
      'descriptionGujarati': _descriptionGujaratiController.text.trim(),
      'requiresAdvanceBooking': _requiresAdvanceBooking,
      'advanceBookingDays': _requiresAdvanceBooking
          ? int.tryParse(_advanceBookingDaysController.text.trim()) ?? 1
          : 0,
      'maxBookingsPerDay': _maxBookingsController.text.trim().isNotEmpty
          ? int.tryParse(_maxBookingsController.text.trim())
          : null,
      'timeSlots': _timeSlots,
      'isActive': true,
    };

    Navigator.pop(context, service);
  }
}
