import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../shared/models/booking.dart';
import '../services/booking_service.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/app_spacing.dart';
import '../../../shared/widgets/loading/skeleton_loader.dart';
import '../../../shared/widgets/dialogs/booking_cancellation_dialog.dart';
import '../widgets/booking_card_widget.dart';
import 'booking_detail_screen.dart';
import 'booking_screen.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen>
    with SingleTickerProviderStateMixin {
  final _bookingService = BookingService();
  late TabController _tabController;

  BookingStatusFilter? _statusFilter;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'My Bookings',
            style: TextStyle(
              color: AppColors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: AppColors.primaryOrange,
          foregroundColor: AppColors.white,
          elevation: 0,
        ),
        backgroundColor: AppColors.scaffoldBackground,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.primaryOrange.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.login,
                    size: 40,
                    color: AppColors.primaryOrange,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Sign in to view bookings',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryText,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please sign in to see your temple bookings',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.secondaryText,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.primaryOrange,
        foregroundColor: AppColors.white,
        elevation: 0,
        title: const Text(
          'My Bookings',
          style: TextStyle(
            color: AppColors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list, color: AppColors.white),
            onPressed: _showFilterDialog,
            tooltip: 'Filter Bookings',
          ),
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.white),
            onPressed: () => _navigateToNewBooking(),
            tooltip: 'New Booking',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.white,
          unselectedLabelColor: AppColors.white.withValues(alpha: 0.7),
          indicatorColor: AppColors.white,
          indicatorWeight: 2.5,
          labelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          tabs: const [
            Tab(text: 'Upcoming'),
            Tab(text: 'Past'),
            Tab(text: 'All'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBookingsList(user.uid, BookingFilter.upcoming),
          _buildBookingsList(user.uid, BookingFilter.past),
          _buildBookingsList(user.uid, BookingFilter.all),
        ],
      ),
    );
  }

  Widget _buildBookingsList(String userId, BookingFilter filter) {
    return StreamBuilder<List<Booking>>(
      stream: _bookingService.watchUserBookings(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SearchSkeletonLoader(itemCount: 6);
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.errorRed.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.error_outline,
                      size: 40,
                      color: AppColors.errorRed,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Error loading bookings',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.secondaryText,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        final allBookings = snapshot.data ?? [];
        final filteredBookings = _filterBookings(allBookings, filter);

        if (filteredBookings.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.primaryOrange.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      filter == BookingFilter.upcoming
                          ? Icons.event_available
                          : Icons.history,
                      size: 40,
                      color: AppColors.primaryOrange,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    filter == BookingFilter.upcoming
                        ? 'No upcoming bookings'
                        : filter == BookingFilter.past
                        ? 'No past bookings'
                        : 'No bookings yet',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Book a temple visit to get started',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.secondaryText,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _navigateToNewBooking(),
                    icon: const Icon(Icons.add),
                    label: const Text('New Booking'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryOrange,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {});
          },
          child: ListView.builder(
            padding: AppSpacing.allLg,
            itemCount: filteredBookings.length,
            itemBuilder: (context, index) {
              final booking = filteredBookings[index];
              return BookingCardWidget(
                booking: booking,
                onTap: () => _navigateToBookingDetail(booking),
                onCancel: booking.canBeCancelled
                    ? () => _showCancelDialog(booking)
                    : null,
                onModify: booking.canBeModified
                    ? () => _navigateToModifyBooking(booking)
                    : null,
              );
            },
          ),
        );
      },
    );
  }

  List<Booking> _filterBookings(List<Booking> bookings, BookingFilter filter) {
    List<Booking> filtered;

    switch (filter) {
      case BookingFilter.upcoming:
        filtered = bookings
            .where(
              (b) =>
                  b.isFuture &&
                  (b.status == BookingStatus.pending ||
                      b.status == BookingStatus.confirmed),
            )
            .toList();
        filtered.sort((a, b) => a.bookingDateTime.compareTo(b.bookingDateTime));
        break;
      case BookingFilter.past:
        filtered = bookings
            .where(
              (b) =>
                  b.isPast ||
                  b.status == BookingStatus.completed ||
                  b.status == BookingStatus.cancelled ||
                  b.status == BookingStatus.noShow,
            )
            .toList();
        filtered.sort((a, b) => b.bookingDateTime.compareTo(a.bookingDateTime));
        break;
      case BookingFilter.all:
        filtered = bookings;
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
    }

    if (_statusFilter != null) {
      filtered = filtered.where((b) {
        switch (_statusFilter!) {
          case BookingStatusFilter.pending:
            return b.status == BookingStatus.pending;
          case BookingStatusFilter.confirmed:
            return b.status == BookingStatus.confirmed;
          case BookingStatusFilter.cancelled:
            return b.status == BookingStatus.cancelled;
          case BookingStatusFilter.completed:
            return b.status == BookingStatus.completed;
        }
      }).toList();
    }

    return filtered;
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Bookings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Status',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: _statusFilter == null,
                  selectedColor: AppColors.primaryOrange.withValues(
                    alpha: 0.15,
                  ),
                  checkmarkColor: AppColors.primaryOrange,
                  labelStyle: TextStyle(
                    color: _statusFilter == null
                        ? AppColors.primaryOrange
                        : AppColors.primaryText,
                    fontWeight: _statusFilter == null
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                  side: BorderSide(
                    color: _statusFilter == null
                        ? AppColors.primaryOrange
                        : AppColors.borderGray,
                  ),
                  onSelected: (selected) {
                    setState(() {
                      _statusFilter = null;
                    });
                    Navigator.pop(context);
                  },
                ),
                ...BookingStatusFilter.values.map((status) {
                  final isSelected = _statusFilter == status;
                  return FilterChip(
                    label: Text(status.displayName),
                    selected: isSelected,
                    selectedColor: AppColors.primaryOrange.withValues(
                      alpha: 0.15,
                    ),
                    checkmarkColor: AppColors.primaryOrange,
                    labelStyle: TextStyle(
                      color: isSelected
                          ? AppColors.primaryOrange
                          : AppColors.primaryText,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                    side: BorderSide(
                      color: isSelected
                          ? AppColors.primaryOrange
                          : AppColors.borderGray,
                    ),
                    onSelected: (selected) {
                      setState(() {
                        _statusFilter = selected ? status : null;
                      });
                      Navigator.pop(context);
                    },
                  );
                }),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _navigateToBookingDetail(Booking booking) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookingDetailScreen(booking: booking),
      ),
    ).then((_) => setState(() {}));
  }

  void _navigateToModifyBooking(Booking booking) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookingScreen(bookingId: booking.id),
      ),
    ).then((_) => setState(() {}));
  }

  void _navigateToNewBooking() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const BookingScreen(),
      ),
    ).then((_) => setState(() {}));
  }

  void _showCancelDialog(Booking booking) {
    showBookingCancellationDialog(
      context: context,
      bookingId: booking.id,
      onConfirm: (reason) async {
        await _bookingService.cancelBooking(booking.id);
      },
    ).then((confirmed) {
      if (confirmed == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              booking.requiresPayment && booking.isPaymentCompleted
                  ? 'Booking cancelled. Refund will be processed.'
                  : 'Booking cancelled successfully',
            ),
            backgroundColor: AppColors.successGreen,
          ),
        );
      }
    });
  }

}

enum BookingFilter {
  upcoming,
  past,
  all,
}

enum BookingStatusFilter {
  pending,
  confirmed,
  cancelled,
  completed,
}

extension BookingStatusFilterExtension on BookingStatusFilter {
  String get displayName {
    switch (this) {
      case BookingStatusFilter.pending:
        return 'Pending';
      case BookingStatusFilter.confirmed:
        return 'Confirmed';
      case BookingStatusFilter.cancelled:
        return 'Cancelled';
      case BookingStatusFilter.completed:
        return 'Completed';
    }
  }
}
