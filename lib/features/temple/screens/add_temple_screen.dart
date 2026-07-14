import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../core/themes/app_colors.dart';
import '../../../shared/services/storage/hybrid_storage_service.dart';
import 'select_location_map.dart';
import '../services/youtube_channel_service.dart';
import '../services/hybrid_live_detector.dart';

class AddTempleScreen extends StatefulWidget {
  const AddTempleScreen({super.key});

  @override
  State<AddTempleScreen> createState() => _AddTempleScreenState();
}

class _AddTempleScreenState extends State<AddTempleScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _imagePicker = ImagePicker();
  bool _isLoading = false;
  bool _isCheckingPermissions = true;

  // Tab controller for organized sections
  late TabController _tabController;

  // Basic Information Controllers
  final _nameController = TextEditingController();
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

  // Live Darshan Controllers
  final _youtubeChannelUrlController = TextEditingController();
  final _youtubeChannelIdController = TextEditingController();
  final _liveKeywordController = TextEditingController();

  // YouTube channel data
  YouTubeChannelData? _youtubeChannelData;
  bool _isLoadingYouTubeData = false;

  // Deity Information Controllers
  final _mainDeityController = TextEditingController();
  final _templeHistoryController = TextEditingController();

  // Community Controllers
  final _communityGuidelinesController = TextEditingController();

  // Location data
  String? _locationAddress;
  String? _city;
  String? _state;
  String? _country;
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
  List<File> _imageFiles = [];
  int _primaryImageIndex = 0;

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
  bool _specialEventStreaming = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _checkAdminPermissions();
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

  @override
  void dispose() {
    _tabController.dispose();
    // Dispose all controllers
    _nameController.dispose();
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingPermissions) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('Add Temple'),
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
          'Add Temple',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        elevation: 2,
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
                onPressed: _isLoading ? null : _handleNextOrSubmit,
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
                        _tabController.index == 5 ? 'Add Temple' : 'Next',
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

  void _handleNextOrSubmit() {
    if (_tabController.index == 5) {
      _submitForm();
    } else {
      _tabController.animateTo(_tabController.index + 1);
    }
  }

  Widget _buildBasicInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
                  label: const Text('Pick Location on Map'),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green[700]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Location Selected',
                              style: TextStyle(
                                color: Colors.green[900],
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _locationAddress!,
                        style: TextStyle(
                          color: Colors.green[800],
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                      if (_city != null || _state != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (_city != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange[100],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _city!,
                                  style: TextStyle(
                                    color: Colors.orange[800],
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            if (_state != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange[100],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _state!,
                                  style: TextStyle(
                                    color: Colors.orange[800],
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
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
                    // If "Other" is selected, clear the text controller for custom input
                    if (_mainDeity == 'Other') {
                      _mainDeityController.text = '';
                    } else {
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
              if (_imageFiles.isEmpty) ...[
                Container(
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
                        Icon(
                          Icons.add_photo_alternate,
                          size: 48,
                          color: Colors.grey,
                        ),
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
                ),
              ] else ...[
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: _imageFiles.length + 1,
                  itemBuilder: (context, index) {
                    if (index == _imageFiles.length) {
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
                              Text(
                                'Add More',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: _primaryImageIndex == index
                                ? Border.all(color: Colors.orange, width: 3)
                                : null,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              _imageFiles[index],
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                            ),
                          ),
                        ),
                        if (_primaryImageIndex == index)
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
                              if (_primaryImageIndex != index)
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
                                onTap: () {
                                  setState(() {
                                    _imageFiles.removeAt(index);
                                    if (_primaryImageIndex >=
                                        _imageFiles.length) {
                                      _primaryImageIndex = 0;
                                    }
                                  });
                                },
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
                ),
              ],
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _pickImages,
                icon: const Icon(Icons.add_photo_alternate),
                label: Text(
                  _imageFiles.isEmpty ? 'Add Images' : 'Add More Images',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
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
    bool readOnly = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      onChanged: onChanged,
      readOnly: readOnly,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.orange, width: 2),
        ),
        filled: readOnly,
        fillColor: readOnly ? Colors.grey[100] : null,
      ),
    );
  }

  // Implementation of missing methods (placeholder for now)
  Future<void> _pickLocationOnMap() async {
    final dynamic picked = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SelectLocationMapScreen()),
    );
    if (picked != null && picked is Map<String, dynamic>) {
      final LatLng coordinates = picked['coordinates'] as LatLng;
      final String? address = picked['address'] as String?;
      final String? city = picked['city'] as String?;
      final String? state = picked['state'] as String?;
      final String? country = picked['country'] as String?;

      setState(() {
        _locationLat = coordinates.latitude;
        _locationLng = coordinates.longitude;
        _locationAddress = address;
        _city = city;
        _state = state;
        _country = country;

        // Auto-fill the address text field if we have a proper address
        if (address != null &&
            address.isNotEmpty &&
            !address.startsWith('Lat:')) {
          _locationTextController.text = address;
        }

        _locationLinkController.text =
            'https://www.google.com/maps/search/?api=1&query=${coordinates.latitude},${coordinates.longitude}';
      });
    }
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> pickedFiles = await _imagePicker.pickMultiImage();
      if (pickedFiles.isNotEmpty) {
        setState(() {
          _imageFiles.addAll(pickedFiles.map((file) => File(file.path)));
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

  Future<void> _extractYouTubeChannelData(String url) async {
    if (url.trim().isEmpty) {
      setState(() {
        _youtubeChannelData = null;
        _youtubeChannelIdController.clear();
      });
      return;
    }

    setState(() {
      _isLoadingYouTubeData = true;
    });

    try {
      final channelData = await YouTubeChannelService.getChannelDataFromUrl(
        url,
      );

      if (mounted) {
        setState(() {
          _youtubeChannelData = channelData;
          _isLoadingYouTubeData = false;

          if (channelData != null) {
            _youtubeChannelIdController.text = channelData.channelId;

            // Auto-suggest live keyword based on channel title
            if (_liveKeywordController.text.isEmpty) {
              final suggestion = _generateLiveKeywordSuggestion(
                channelData.channelTitle,
              );
              if (suggestion.isNotEmpty) {
                _liveKeywordController.text = suggestion;
              }
            }
          } else {
            _youtubeChannelIdController.clear();
          }
        });

        // Show feedback to user
        if (channelData != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Channel found: ${channelData.channelTitle}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '⚠️ Could not fetch channel details (API limit reached). You can still manually enter the Channel ID.',
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingYouTubeData = false;
          _youtubeChannelData = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error extracting channel data: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  String _generateLiveKeywordSuggestion(String channelTitle) {
    final title = channelTitle.toLowerCase();

    // Common temple/spiritual keywords
    final keywords = [
      'temple',
      'mandir',
      'darshan',
      'live',
      'aarti',
      'bhajan',
      'shiva',
      'vishnu',
      'krishna',
      'rama',
      'hanuman',
      'ganesha',
      'mata',
      'devi',
      'durga',
      'kali',
      'lakshmi',
      'saraswati',
      'shirdi',
      'tirupati',
      'kashi',
      'varanasi',
      'haridwar',
      'rishikesh',
    ];

    for (final keyword in keywords) {
      if (title.contains(keyword)) {
        return keyword;
      }
    }

    // Extract first meaningful word (not common words)
    final words = title.split(' ');
    final commonWords = ['the', 'of', 'and', 'in', 'at', 'by', 'for', 'with'];

    for (final word in words) {
      if (word.length > 3 && !commonWords.contains(word)) {
        return word;
      }
    }

    return '';
  }

  /// Initialize live detection for newly created temple
  Future<void> _initializeLiveDetectionForNewTemple(String templeId) async {
    try {
      debugPrint('🎯 Initializing live detection for new temple: $templeId');

      final channelId = _youtubeChannelIdController.text.trim();
      if (channelId.isEmpty) return;

      // Initialize the hybrid detector
      final detector = HybridLiveDetector();

      // Start smart monitoring for the new temple
      detector.startSmartMonitoring(templeId, channelId);

      debugPrint('✅ Live detection initialized for temple: $templeId');
    } catch (e) {
      debugPrint('❌ Error initializing live detection: $e');
      // Don't throw error as temple creation was successful
    }
  }

  Widget _buildLiveDarshanSection() {
    return _buildSectionCard(
      title: 'Live Darshan Configuration',
      icon: Icons.live_tv,
      children: [
        _buildTextField(
          controller: _youtubeChannelUrlController,
          label: 'YouTube Channel URL',
          icon: Icons.link,
          hint: 'https://www.youtube.com/@channelname',
          onChanged: (value) {
            // Debounce the API call
            Future.delayed(const Duration(milliseconds: 500), () {
              if (_youtubeChannelUrlController.text == value) {
                _extractYouTubeChannelData(value);
              }
            });
          },
        ),
        
        // Loading indicator
        if (_isLoadingYouTubeData) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange[200]!),
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Text(
                  'Extracting channel information...',
                  style: TextStyle(color: Colors.orange[800], fontSize: 14),
                ),
              ],
            ),
          ),
        ],

        // Channel data display
        if (_youtubeChannelData != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Colors.green[700],
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Channel Found',
                        style: TextStyle(
                          color: Colors.green[900],
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _youtubeChannelData!.channelTitle,
                  style: TextStyle(
                    color: Colors.green[800],
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'ID: ${_youtubeChannelData!.channelId}',
                  style: TextStyle(
                    color: Colors.green[700],
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
                if (_youtubeChannelData!.subscriberCount != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Subscribers: ${_formatSubscriberCount(_youtubeChannelData!.subscriberCount!)}',
                    style: TextStyle(color: Colors.green[700], fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ],

        const SizedBox(height: 16),
        _buildTextField(
          controller: _youtubeChannelIdController,
          label: 'YouTube Channel ID',
          icon: Icons.tag,
          hint: 'UCxxxxxxxxxxxxxxxxxx',
          // Always allow manual editing — admin must be able to correct or
          // enter the real ID when the YouTube API is unavailable.
          readOnly: false,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _liveKeywordController,
          label: 'Live Stream Keyword',
          icon: Icons.search,
          hint: 'e.g., shirdi, tirupati, kashi',
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          title: const Text('Special Event Streaming'),
          subtitle: const Text('Enable streaming for special events'),
          value: _specialEventStreaming,
          onChanged: (value) {
            setState(() {
              _specialEventStreaming = value;
            });
          },
        ),
      ],
    );
  }

  String _formatSubscriberCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    } else {
      return count.toString();
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState == null || !_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all required fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_locationLat == null || _locationLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select temple location on map'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_imageFiles.isEmpty) {
      final shouldContinue = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('No Images'),
          content: const Text(
            'Are you sure you want to add temple without any images?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      if (shouldContinue != true) return;
    }

    setState(() => _isLoading = true);

    try {
      // Upload images
      List<String> imageUrls = [];
      for (int i = 0; i < _imageFiles.length; i++) {
        final imageUrl = await _uploadImage(_imageFiles[i], i);
        if (imageUrl != null) {
          imageUrls.add(imageUrl);
        }
      }

      // Create comprehensive temple data
      final templeData = _createTempleData(imageUrls);

      // Save to Firestore
      final docRef = await FirebaseFirestore.instance
          .collection('temples')
          .add(templeData);
      final templeId = docRef.id;

      // Initialize live detection if YouTube channel is configured
      if (_youtubeChannelIdController.text.trim().isNotEmpty) {
        await _initializeLiveDetectionForNewTemple(templeId);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Temple added successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding temple: $e'),
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
      final templeId = 'temp_${DateTime.now().millisecondsSinceEpoch}';

      final imageUrl = await storageService.uploadTempleImage(
        imageFile: imageFile,
        templeId: templeId,
      );
      
      return imageUrl;
    } catch (e) {
      debugPrint('Error uploading image $index: $e');
      return null;
    }
  }

  Map<String, dynamic> _createTempleData(List<String> imageUrls) {
    return {
      // Basic Information
      'name': _nameController.text.trim(),
      'aboutTemple': _aboutTempleController.text.trim(),
      'description': _aboutTempleController.text.trim(), // mirrors 'aboutTemple' for Temple.fromFirestore compatibility
      'mainDeity': _mainDeity == 'Other'
          ? _mainDeityController.text.trim()
          : _mainDeity,
      'history': _templeHistoryController.text.trim(),

      // Location
      'location': {
        'address': _locationTextController.text.trim(),
        'fullAddress': _locationAddress,
        'city': _city,
        'state': _state,
        'country': _country ?? 'India',
        'latitude': _locationLat,
        'longitude': _locationLng,
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

      // Pricing - Enhanced with puja services
      'pujaPrice': double.tryParse(_pujaPriceController.text.trim()) ?? 0.0,
      'pujaServices': _pujaServices
          .map(
            (service) => {
              'name': service['name'],
              'nameHindi': service['nameHindi'] ?? '',
              'nameGujarati': service['nameGujarati'] ?? '',
              'category': service['category'],
              'price': service['price'],
              'duration': service['duration'],
              'description': service['description'] ?? '',
              'descriptionHindi': service['descriptionHindi'] ?? '',
              'descriptionGujarati': service['descriptionGujarati'] ?? '',
              'requiresAdvanceBooking':
                  service['requiresAdvanceBooking'] ?? false,
              'advanceBookingDays': service['advanceBookingDays'] ?? 0,
              'maxBookingsPerDay': service['maxBookingsPerDay'],
              'timeSlots': service['timeSlots'] ?? [],
              'isActive': service['isActive'] ?? true,
            },
          )
          .toList(),

      // Images
      'images': imageUrls,
      'primaryImageIndex': _primaryImageIndex,
      'coverPhotoUrl': imageUrls.isNotEmpty
          ? imageUrls[_primaryImageIndex]
          : null,

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

      // Live Darshan
      'liveDarshan':
          _youtubeChannelUrlController.text.trim().isNotEmpty ||
              _youtubeChannelIdController.text.trim().isNotEmpty
          ? {
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
              'specialEventStreaming': _specialEventStreaming,
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
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'isActive': true,
      'rating': 0.0,
      'averageRating': 0.0, // mirrors 'rating' for Temple.fromFirestore compatibility
      'reviewCount': 0,
      'totalReviews': 0, // mirrors 'reviewCount' for Temple.fromFirestore compatibility
      'totalPhotosShared': 0,
    };
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
