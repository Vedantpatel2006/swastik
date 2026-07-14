import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/themes/app_colors.dart';
import '../../../shared/models/booking.dart';
import '../../../shared/models/temple.dart';
import '../services/booking_service.dart';
import '../../temple/services/user_temple_service.dart';
import '../../../shared/widgets/error/animated_error_display.dart';
import '../../../shared/screens/booking_confirmation_preview_screen.dart';
import '../../../shared/widgets/dialogs/booking_cancellation_dialog.dart';
import 'booking_detail_screen.dart';

class BookingScreen extends StatefulWidget {
  final String? templeId;
  final String? bookingId; // For editing existing booking
  final String? initialBookingType; // Pre-select a booking type

  const BookingScreen({
    super.key,
    this.templeId,
    this.bookingId,
    this.initialBookingType,
  });

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen>
    with TickerProviderStateMixin {
  final BookingService _bookingService = BookingService();
  final UserTempleService _templeService = UserTempleService();
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _specialRequestsController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _contactEmailController = TextEditingController();
  final _amountController = TextEditingController();

  // Form data
  Temple? _selectedTemple;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String _bookingType = 'visit';
  int _numberOfPeople = 1;
  String _selectedCurrency = 'USD';
  Booking? _existingBooking;
  List<Temple> _availableTemples = [];

  // UI state
  bool _isLoading = false;
  String? _errorMessage;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // Apply pre-selected booking type if provided
    if (widget.initialBookingType != null) {
      _bookingType = _normalizeBookingType(widget.initialBookingType!);
    }
    _tabController = TabController(length: 2, vsync: this);
    _initializeScreen();
  }

  @override
  void dispose() {
    _specialRequestsController.dispose();
    _contactPhoneController.dispose();
    _contactEmailController.dispose();
    _amountController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initializeScreen() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Load existing booking if editing
      if (widget.bookingId != null) {
        _existingBooking = await _bookingService.getBookingById(
          widget.bookingId!,
        );
        if (_existingBooking != null) {
          await _loadTempleForBooking(_existingBooking!.templeId);
          if (mounted) _populateFormWithBooking(_existingBooking!);
        }
      } else if (widget.templeId != null) {
        // Load temple for new booking
        await _loadTempleForBooking(widget.templeId!);
      } else {
        // Load available temples for selection when no temple is provided
        final temples = await _templeService.searchTemples('');
        if (mounted) {
          setState(() {
            _availableTemples = temples.take(20).toList();
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load booking information: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadTempleForBooking(String templeId) async {
    final temple = await _templeService.getTempleDetails(templeId);
    if (mounted) {
      setState(() {
        _selectedTemple = temple;
      });
    }
  }

  void _populateFormWithBooking(Booking booking) {
    setState(() {
      _selectedDate = booking.bookingDate;
      _selectedTime = booking.bookingTime;
      // Normalize booking type to ensure it's a valid value
      _bookingType = _normalizeBookingType(booking.bookingType);
      _numberOfPeople = booking.numberOfPeople;
      _specialRequestsController.text = booking.specialRequests ?? '';
      _contactPhoneController.text = booking.contactPhone ?? '';
      _contactEmailController.text = booking.contactEmail ?? '';
    });
  }

  /// Normalize booking type to ensure it's a valid dropdown value
  String _normalizeBookingType(String type) {
    // Handle display names that might have been stored incorrectly
    switch (type.toLowerCase()) {
      case 'temple visit':
      case 'visit':
        return 'visit';
      case 'event':
        return 'event';
      case 'special service':
      case 'special_service':
        return 'special_service';
      default:
        return 'visit'; // Default fallback
    }
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final firstDate = now;
    final lastDate = now.add(const Duration(days: 90)); // 3 months ahead

    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now.add(const Duration(days: 1)),
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: AppColors.primaryOrange),
          ),
          child: child!,
        );
      },
    );

    if (date != null) {
      setState(() {
        _selectedDate = date;
        _selectedTime = null; // Reset time when date changes
      });
    }
  }

  /// Validate booking form fields
  String? _validateBookingForm() {
    if (_formKey.currentState == null || !_formKey.currentState!.validate()) {
      return 'Form validation failed';
    }
    if (_selectedTemple == null ||
        _selectedDate == null ||
        _selectedTime == null) {
      return 'Please select temple, date, and time';
    }

    // ✅ NEW: Validate booking time against temple operating hours
    final templeHoursError = _validateTempleHours(_selectedTemple!, _selectedDate!, _selectedTime!);
    if (templeHoursError != null) {
      return templeHoursError;
    }

    return null;
  }

  /// ✅ NEW: Validate that booking time is within temple's operating hours
  String? _validateTempleHours(Temple temple, DateTime bookingDate, TimeOfDay bookingTime) {
    // Get day name (Monday, Tuesday, etc.)
    final dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final dayName = dayNames[bookingDate.weekday - 1];

    // Get temple timings for this day (format: "06:00 - 21:00")
    final timing = temple.timings[dayName] ?? temple.timings['Daily'];
    if (timing == null || timing.isEmpty) {
      return 'Temple is closed on $dayName';
    }

    // Parse timing string: "06:00 - 21:00"
    final parts = timing.split('-');
    if (parts.length != 2) {
      return 'Invalid temple hours format';
    }

    final openingTime = _parseTimeString(parts[0].trim());
    final closingTime = _parseTimeString(parts[1].trim());

    if (openingTime == null || closingTime == null) {
      return 'Could not parse temple hours';
    }

    // Handle next-day closing (e.g., 22:00 - 06:00)
    if (closingTime.hour < openingTime.hour) {
      // Valid booking if: time >= opening OR time < closing (wraps to next day)
      final isValid = bookingTime.hour >= openingTime.hour || bookingTime.hour < closingTime.hour;
      if (!isValid) {
        return 'Temple is closed at ${bookingTime.hour}:${bookingTime.minute.toString().padLeft(2, '0')}. Hours: $timing';
      }
    } else {
      // Normal hours (e.g., 06:00 - 21:00)
      final isValid = bookingTime.hour >= openingTime.hour && bookingTime.hour < closingTime.hour;
      if (!isValid) {
        return 'Temple is closed at ${bookingTime.hour}:${bookingTime.minute.toString().padLeft(2, '0')}. Hours: $timing';
      }
    }

    return null;
  }

  /// ✅ NEW: Parse time string (HH:MM or H:MM) to TimeOfDay, returns null if invalid
  TimeOfDay? _parseTimeString(String timeStr) {
    try {
      // Handle both "06:00" and "6:00" formats
      final cleanStr = timeStr.replaceAll(RegExp(r'[^0-9:]'), '').trim();
      final parts = cleanStr.split(':');
      if (parts.length < 2) return null;

      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);

      if (hour == null || minute == null || hour < 0 || hour > 23 || minute < 0 || minute > 59) {
        return null;
      }

      return TimeOfDay(hour: hour, minute: minute);
    } catch (e) {
      return null;
    }
  }

  /// Build booking object from form inputs
  Booking _buildBookingObject(double amount, String userId) {
    return Booking(
      id: '',
      templeId: _selectedTemple!.id,
      userId: userId,
      bookingType: _bookingType,
      bookingDate: _selectedDate!,
      bookingTime: _selectedTime!,
      numberOfPeople: _numberOfPeople,
      specialRequests: _specialRequestsController.text.trim().isEmpty
          ? null
          : _specialRequestsController.text.trim(),
      contactPhone: _contactPhoneController.text.trim().isEmpty
          ? null
          : _contactPhoneController.text.trim(),
      contactEmail: _contactEmailController.text.trim().isEmpty
          ? null
          : _contactEmailController.text.trim(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      amount: amount,
      currency: _selectedCurrency,
      paymentStatus: BookingPaymentStatus.pending,
    );
  }

  /// Build customer info for payment
  Map<String, dynamic> _buildBookingCustomerInfo(User user) {
    return {
      'name': user.displayName ?? 'User',
      'email': user.email ?? '',
      'phone': _contactPhoneController.text.trim(),
      'customer_id': user.uid,
    };
  }

  /// Show booking confirmation preview before processing payment
  void _showBookingPreview() {
    final validationError = _validateBookingForm();
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(validationError)),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please sign in to book')));
      return;
    }

    final amount = double.tryParse(_amountController.text) ?? 0.0;
    final previewBooking = _buildBookingObject(amount, user.uid);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BookingConfirmationPreviewScreen(
          booking: previewBooking,
          temple: _selectedTemple!,
          onEdit: () => Navigator.of(context).pop(),
          onConfirm: () {
            Navigator.of(context).pop();
            _submitBookingWithPayment();
          },
        ),
      ),
    );
  }

  Future<void> _submitBookingWithPayment() async {
    // Validate form
    final validationError = _validateBookingForm();
    if (validationError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(validationError)));
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final amount = double.tryParse(_amountController.text) ?? 0.0;
      final booking = _buildBookingObject(amount, user.uid);
      final customerInfo = _buildBookingCustomerInfo(user);

      // Process booking with payment
      final createdBooking = await _bookingService.createBookingWithPayment(
        booking: booking,
        customerInfo: customerInfo,
      );

      if (mounted) {
        _showBookingConfirmation(createdBooking, isUpdate: false);
      }
    } catch (e) {
      final msg = e.toString();
      // User dismissed the payment sheet — clear error and return silently
      if (msg.contains('canceled') ||
          msg.contains('cancelled') ||
          msg.contains('Canceled') ||
          msg.contains('Cancelled')) {
        if (mounted)
          setState(() {
            _isLoading = false;
            _errorMessage = null;
          });
        return;
      }
      if (mounted) {
        setState(() {
          _errorMessage = msg;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment failed: $msg'),
            backgroundColor: AppColors.errorRed,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted)
        setState(() {
          _isLoading = false;
        });
    }
  }

  // Keep old method for editing bookings (no payment required)
  Future<void> _submitBooking() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedTemple == null ||
        _selectedDate == null ||
        _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select temple, date, and time')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final booking = Booking(
        id: _existingBooking?.id ?? '',
        templeId: _selectedTemple!.id,
        userId: user.uid,
        bookingType: _bookingType,
        bookingDate: _selectedDate!,
        bookingTime: _selectedTime!,
        numberOfPeople: _numberOfPeople,
        specialRequests: _specialRequestsController.text.trim().isEmpty
            ? null
            : _specialRequestsController.text.trim(),
        contactPhone: _contactPhoneController.text.trim().isEmpty
            ? null
            : _contactPhoneController.text.trim(),
        contactEmail: _contactEmailController.text.trim().isEmpty
            ? null
            : _contactEmailController.text.trim(),
        createdAt: _existingBooking?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (_existingBooking != null) {
        // Update existing booking
        await _bookingService.modifyBooking(_existingBooking!.id, booking);
        if (mounted) {
          _showBookingConfirmation(booking, isUpdate: true);
        }
      } else {
        // Create new booking
        await _bookingService.createBooking(booking);
        if (mounted) {
          _showBookingConfirmation(booking, isUpdate: false);
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.primaryOrange,
        foregroundColor: AppColors.white,
        elevation: 0,
        title: Text(
          _existingBooking != null ? 'Edit Booking' : 'New Booking',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.white,
          unselectedLabelColor: AppColors.white.withValues(alpha: 0.7),
          indicatorColor: AppColors.white,
          tabs: const [
            Tab(text: 'Booking Details'),
            Tab(text: 'My Bookings'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading booking information...'),
                ],
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [_buildBookingForm(), _buildMyBookings()],
            ),
    );
  }

  Widget _buildBookingForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_errorMessage != null)
              AnimatedErrorDisplay(
                message: _errorMessage!,
                onRetry: _initializeScreen,
              ),

            // Temple Selection (if not pre-selected)
            if (_selectedTemple == null && _availableTemples.isNotEmpty) ...[
              Text(
                'Select Temple',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryText,
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<Temple>(
                value: _selectedTemple,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.borderGray),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: AppColors.primaryOrange,
                      width: 2,
                    ),
                  ),
                  labelText: 'Choose a temple',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                isExpanded: true,
                items: _availableTemples.map((temple) {
                  return DropdownMenuItem(
                    value: temple,
                    child: Text(temple.name, overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: (temple) {
                  setState(() {
                    _selectedTemple = temple;
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return 'Please select a temple';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
            ],

            // Temple Information
            if (_selectedTemple != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primaryOrange.withValues(alpha: 0.1),
                      AppColors.primaryOrange.withValues(alpha: 0.2),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primaryOrange.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primaryOrange,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.temple_hindu,
                        color: AppColors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedTemple!.name,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.coralOrange,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 14,
                                color: AppColors.primaryOrange,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  _selectedTemple!.location.address ??
                                      'Location not specified',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.secondaryText,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Booking Type
            Text(
              'Booking Type',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryText,
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _bookingType,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppColors.lightGray),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppColors.lightGray),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: AppColors.primaryOrange,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'visit',
                  child: Text('🙏 Temple Visit'),
                ),
                DropdownMenuItem(value: 'event', child: Text('🎉 Event')),
                DropdownMenuItem(
                  value: 'special_service',
                  child: Text('✨ Special Service'),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _bookingType = value!;
                });
              },
            ),
            const SizedBox(height: 20),

            // Date Selection
            Text(
              'Select Date',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryText,
              ),
            ),
            const SizedBox(height: 10),

            // ── Quick-date chips: Today / Tomorrow / +2 / +3 ──────────────
            _buildQuickDateChips(),
            const SizedBox(height: 10),

            // ── Full date picker button ────────────────────────────────────
            InkWell(
              onTap: _selectDate,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _selectedDate != null
                        ? AppColors.primaryOrange
                        : AppColors.lightGray,
                    width: _selectedDate != null ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  color: _selectedDate != null
                      ? AppColors.primaryOrange.withValues(alpha: 0.1)
                      : AppColors.white,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      color: _selectedDate != null
                          ? AppColors.primaryOrange
                          : AppColors.lightGray,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _selectedDate != null
                            ? _formatDateFull(_selectedDate!)
                            : 'Or tap to pick another date',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: _selectedDate != null
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: _selectedDate != null
                              ? AppColors.coralOrange
                              : AppColors.lightGray,
                        ),
                      ),
                    ),
                    if (_selectedDate != null)
                      Icon(
                        Icons.edit_calendar_outlined,
                        size: 18,
                        color: AppColors.primaryOrange,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Time Selection
            Text(
              'Select Time',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryText,
              ),
            ),
            const SizedBox(height: 10),
            // Real-time available slots with StreamBuilder.
            // ValueKey forces a full rebuild (new stream) whenever temple,
            // date, or bookingType changes — prevents stale slots.
            if (_selectedTemple != null && _selectedDate != null)
              StreamBuilder<List<TimeOfDay>>(
                key: ValueKey(
                  '${_selectedTemple!.id}_'
                  '${_selectedDate!.toIso8601String()}_'
                  '$_bookingType',
                ),
                stream: _bookingService.watchAvailableSlots(
                  templeId: _selectedTemple!.id,
                  date: _selectedDate!,
                  bookingType: _bookingType,
                ),
                builder: (context, snapshot) {
                  // Show spinner only on first load (no data yet)
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      snapshot.data == null) {
                    return Container(
                      padding: const EdgeInsets.all(20),
                      alignment: Alignment.center,
                      child: CircularProgressIndicator(
                        color: AppColors.primaryOrange,
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.errorRed.withValues(alpha: 0.1),
                        border: Border.all(
                          color: AppColors.errorRed.withValues(alpha: 0.3),
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: AppColors.errorRed),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Error loading slots: ${snapshot.error}',
                              style: TextStyle(color: AppColors.errorRed),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final slots = snapshot.data ?? [];

                  // If selected slot was booked by someone else, clear it
                  if (_selectedTime != null &&
                      slots.isNotEmpty &&
                      !slots.any(
                        (s) =>
                            s.hour == _selectedTime!.hour &&
                            s.minute == _selectedTime!.minute,
                      )) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) setState(() => _selectedTime = null);
                    });
                  }

                  if (slots.isEmpty) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.lightGray.withValues(alpha: 0.5),
                        border: Border.all(color: AppColors.lightGray),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: AppColors.lightGray),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'No available time slots for selected date',
                              style: TextStyle(color: AppColors.secondaryText),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${slots.length} slot${slots.length == 1 ? '' : 's'} available',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.secondaryText,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: slots.map((time) {
                          final isSelected =
                              _selectedTime != null &&
                              _selectedTime!.hour == time.hour &&
                              _selectedTime!.minute == time.minute;
                          return InkWell(
                            onTap: () {
                              setState(() {
                                _selectedTime = isSelected ? null : time;
                              });
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primaryOrange
                                    : AppColors.white,
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primaryOrange
                                      : AppColors.lightGray,
                                  width: isSelected ? 2 : 1,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.access_time,
                                    size: 16,
                                    color: isSelected
                                        ? AppColors.white
                                        : AppColors.secondaryText,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _formatTime(time),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: isSelected
                                          ? AppColors.white
                                          : AppColors.secondaryText,
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
                },
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.lightGray.withValues(alpha: 0.5),
                  border: Border.all(color: AppColors.lightGray),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_month, color: AppColors.lightGray),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _selectedTemple == null
                            ? 'Please select a temple to view available slots'
                            : 'Please select a date to view available slots',
                        style: const TextStyle(color: AppColors.secondaryText),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),

            // Number of People
            Text(
              'Number of People',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryText,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.borderGray),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: _numberOfPeople > 1
                        ? () => setState(() => _numberOfPeople--)
                        : null,
                    icon: const Icon(Icons.remove_circle),
                    color: _numberOfPeople > 1
                        ? AppColors.primaryOrange
                        : AppColors.lightGray,
                    iconSize: 32,
                  ),
                  const SizedBox(width: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryOrange.withValues(alpha: 0.1),
                      border: Border.all(
                        color: AppColors.primaryOrange,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.people, color: AppColors.primaryOrange),
                        const SizedBox(width: 8),
                        Text(
                          _numberOfPeople.toString(),
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryOrange,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  IconButton(
                    onPressed: _numberOfPeople < 10
                        ? () => setState(() => _numberOfPeople++)
                        : null,
                    icon: const Icon(Icons.add_circle),
                    color: _numberOfPeople < 10
                        ? AppColors.primaryOrange
                        : AppColors.lightGray,
                    iconSize: 32,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Booking Amount
            Text(
              'Booking Fee',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryText,
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _amountController,
              decoration: InputDecoration(
                hintText: 'Enter booking amount',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.borderGray),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: AppColors.primaryOrange,
                    width: 2,
                  ),
                ),
                prefixIcon: const Icon(
                  Icons.attach_money,
                  color: AppColors.primaryOrange,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter booking amount';
                }
                final amount = double.tryParse(value);
                if (amount == null || amount < 10) {
                  return 'Minimum amount is 10';
                }
                if (amount > 50000) {
                  return 'Maximum amount is 50,000';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                'Booking fee varies by temple and service type',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.secondaryText,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Contact Information
            const Text(
              'Contact Information',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryText,
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _contactPhoneController,
              decoration: InputDecoration(
                labelText: 'Phone Number',
                hintText: 'Enter your phone number',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.borderGray),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: AppColors.primaryOrange,
                    width: 2,
                  ),
                ),
                prefixIcon: const Icon(
                  Icons.phone,
                  color: AppColors.primaryOrange,
                ),
              ),
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  if (value.length < 10) {
                    return 'Please enter a valid phone number';
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _contactEmailController,
              decoration: InputDecoration(
                labelText: 'Email Address',
                hintText: 'Enter your email address',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.borderGray),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: AppColors.primaryOrange,
                    width: 2,
                  ),
                ),
                prefixIcon: const Icon(
                  Icons.email,
                  color: AppColors.primaryOrange,
                ),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  if (!value.contains('@')) {
                    return 'Please enter a valid email address';
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Special Requests
            const Text(
              'Special Requests (Optional)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryText,
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _specialRequestsController,
              decoration: InputDecoration(
                labelText: 'Any special requests or requirements',
                hintText: 'e.g., wheelchair access, dietary requirements...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.borderGray),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: AppColors.primaryOrange,
                    width: 2,
                  ),
                ),
                alignLabelWithHint: true,
                prefixIcon: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Icon(Icons.note_alt, color: AppColors.primaryOrange),
                  ),
                ),
              ),
              maxLines: 4,
              maxLength: 500,
            ),
            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading
                    ? null
                    : (_existingBooking != null
                          ? _submitBooking
                          : _showBookingPreview),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryOrange,
                  foregroundColor: Colors.white,
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  disabledBackgroundColor: AppColors.lightGray,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.payment, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            _existingBooking != null
                                ? 'Update Booking'
                                : 'Pay & Book',
                            style: const TextStyle(
                              fontSize: 16,
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
    );
  }

  Widget _buildMyBookings() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Please log in to view your bookings'));
    }

    return StreamBuilder<List<Booking>>(
      stream: _bookingService.watchUserBookings(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return AnimatedErrorDisplay(
            message: 'Failed to load bookings: ${snapshot.error}',
            onRetry: () => setState(() {}),
          );
        }

        final bookings = snapshot.data ?? [];
        if (bookings.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.event_busy,
                  size: 64,
                  color: AppColors.secondaryText,
                ),
                const SizedBox(height: 16),
                const Text(
                  'No bookings found',
                  style: TextStyle(
                    fontSize: 18,
                    color: AppColors.secondaryText,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Create your first booking using the form',
                  style: TextStyle(color: AppColors.secondaryText),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: bookings.length,
          itemBuilder: (context, index) {
            final booking = bookings[index];
            return _buildBookingCard(booking);
          },
          // Performance optimizations
          addAutomaticKeepAlives: true,
          addRepaintBoundaries: true,
          cacheExtent: 1000,
          semanticChildCount: bookings.length,
          physics: const AlwaysScrollableScrollPhysics(),
        );
      },
    );
  }

  Widget _buildBookingCard(Booking booking) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BookingDetailScreen(booking: booking),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                  Expanded(
                    child: Text(
                      booking.bookingTypeDisplayName,
                      style: Theme.of(context).textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(booking.status),
                    borderRadius: BorderRadius.circular(12),
                  ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getStatusIcon(booking.status),
                          size: 11,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          booking.statusDisplayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              booking.formattedDateTime,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            Text(
              '${booking.numberOfPeople} ${booking.numberOfPeople == 1 ? 'person' : 'people'}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (booking.hasSpecialRequests) ...[
              const SizedBox(height: 8),
              Text(
                'Special Requests: ${booking.specialRequests}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (booking.isFuture &&
                (booking.status == BookingStatus.pending ||
                    booking.status == BookingStatus.confirmed)) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.notifications,
                    size: 16,
                    color: AppColors.primaryOrange,
                  ),
                  const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Reminders will be sent 24h and 1h before your booking',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.primaryOrange,
                          fontStyle: FontStyle.italic,
                        ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (booking.canBeModified)
                  TextButton(
                    onPressed: () => _editBooking(booking),
                    child: const Text('Edit'),
                  ),
                if (booking.canBeCancelled)
                  TextButton(
                    onPressed: () => _cancelBooking(booking),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.errorRed,
                      ),
                    child: const Text('Cancel'),
                  ),
              ],
            ),
          ],
        ),
      ),
      ),
    );
  }

  Color _getStatusColor(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending:
        return AppColors.warningAmber;
      case BookingStatus.confirmed:
        return AppColors.successGreen;
      case BookingStatus.cancelled:
        return AppColors.errorRed;
      case BookingStatus.completed:
        return AppColors.primaryOrange;
      case BookingStatus.noShow:
        return AppColors.secondaryText;
    }
  }

  IconData _getStatusIcon(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending:
        return Icons.hourglass_top_rounded;
      case BookingStatus.confirmed:
        return Icons.check_circle_rounded;
      case BookingStatus.cancelled:
        return Icons.cancel_rounded;
      case BookingStatus.completed:
        return Icons.verified_rounded;
      case BookingStatus.noShow:
        return Icons.event_busy_rounded;
    }
  }

  void _editBooking(Booking booking) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BookingScreen(bookingId: booking.id),
      ),
    );
  }

  Future<void> _cancelBooking(Booking booking) async {
    final confirmed = await showBookingCancellationDialog(
      context: context,
      bookingId: booking.id,
      onConfirm: (reason) async {
        await _bookingService.cancelBooking(booking.id);
      },
    );

    if (confirmed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Booking cancelled successfully')),
      );
    }
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  /// Full date string with day-of-week: "Mon, 5 Jan 2026"
  String _formatDateFull(DateTime date) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${days[date.weekday - 1]}, ${date.day} ${months[date.month - 1]} ${date.year}';
  }

  /// Quick-date chip strip: Today / Tomorrow / +2 days / +3 days
  Widget _buildQuickDateChips() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final chips = [
      (label: 'Today', date: today),
      (label: 'Tomorrow', date: today.add(const Duration(days: 1))),
      (
        label: _shortDay(today.add(const Duration(days: 2))),
        date: today.add(const Duration(days: 2)),
      ),
      (
        label: _shortDay(today.add(const Duration(days: 3))),
        date: today.add(const Duration(days: 3)),
      ),
    ];

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final chip = chips[i];
          final isSelected =
              _selectedDate != null &&
              _selectedDate!.year == chip.date.year &&
              _selectedDate!.month == chip.date.month &&
              _selectedDate!.day == chip.date.day;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedDate = chip.date;
                _selectedTime = null; // reset slot on date change
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primaryOrange
                    : AppColors.primaryOrange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primaryOrange
                      : AppColors.primaryOrange.withValues(alpha: 0.30),
                  width: 1.5,
                ),
              ),
              child: Text(
                chip.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : AppColors.primaryOrange,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Short day name for quick-date chips: "Wed 7"
  String _shortDay(DateTime date) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[date.weekday - 1]} ${date.day}';
  }

  void _showBookingConfirmation(Booking booking, {required bool isUpdate}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => BookingConfirmationDialog(
        booking: booking,
        temple: _selectedTemple!,
        isUpdate: isUpdate,
        onDone: () {
          // Close the confirmation dialog
          Navigator.of(dialogContext).pop();

          // Only pop the BookingScreen if it was pushed as a route (not a tab).
          // Popping a tab root causes a black screen because there's nothing behind it.
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop(true);
          } else {
            // We're a tab root — reset the form so the user can make another booking
            _resetForm();
          }
        },
      ),
    );
  }

  /// Reset all form fields after a successful booking
  void _resetForm() {
    _amountController.clear();
    _specialRequestsController.clear();
    _contactPhoneController.clear();
    _contactEmailController.clear();
    setState(() {
      _selectedDate = null;
      _selectedTime = null;
      _numberOfPeople = 1;
      _bookingType = 'visit';
      _selectedCurrency = 'USD';
      _errorMessage = null;
      // Keep the selected temple so the user can book again easily
    });
  }
}

class BookingConfirmationDialog extends StatelessWidget {
  final Booking booking;
  final Temple temple;
  final bool isUpdate;
  final VoidCallback onDone;

  const BookingConfirmationDialog({
    super.key,
    required this.booking,
    required this.temple,
    required this.isUpdate,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.successGreen.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle,
              color: AppColors.successGreen,
              size: 32,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isUpdate ? 'Booking Updated!' : 'Booking Confirmed!',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.successGreen,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isUpdate
                  ? 'Your booking has been successfully updated.'
                  : 'Your booking has been confirmed. You will receive a confirmation email shortly.',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.veryLightGray,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderGray),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Booking Details',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    'Booking ID',
                    booking.id.isNotEmpty ? booking.id : 'Generated',
                  ),
                  _buildDetailRow('Temple', temple.name),
                  _buildDetailRow('Date', _formatDate(booking.bookingDate)),
                  _buildDetailRow('Time', _formatTime(booking.bookingTime)),
                  _buildDetailRow(
                    'Type',
                    _formatBookingType(booking.bookingType),
                  ),
                  _buildDetailRow('People', booking.numberOfPeople.toString()),
                  if (booking.specialRequests != null)
                    _buildDetailRow(
                      'Special Requests',
                      booking.specialRequests!,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryOrange.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.primaryOrange.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppColors.primaryOrange.withValues(alpha: 0.8),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Please arrive 15 minutes before your scheduled time.',
                      style: TextStyle(
                        color: AppColors.coralOrange,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            // Share booking details
            _shareBookingDetails();
          },
          child: const Text('Share'),
        ),
        ElevatedButton(
          onPressed: onDone,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.successGreen,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('Done'),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: AppColors.secondaryText,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  String _formatBookingType(String type) {
    switch (type) {
      case 'visit':
        return 'Temple Visit';
      case 'event':
        return 'Event';
      case 'special_service':
        return 'Special Service';
      default:
        return type.toUpperCase();
    }
  }

  void _shareBookingDetails() {
    final details =
        '''
Booking Confirmed!

Temple: ${temple.name}
Date: ${_formatDate(booking.bookingDate)}
Time: ${_formatTime(booking.bookingTime)}
Type: ${_formatBookingType(booking.bookingType)}
People: ${booking.numberOfPeople}
Booking ID: ${booking.id}

Please arrive 15 minutes before your scheduled time.
''';

    Share.share(details, subject: 'Temple Booking Confirmation');
  }
}
