import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../shared/models/event.dart';
import '../../../shared/services/event_service.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/app_spacing.dart';
import '../../../shared/widgets/loading/skeleton_loader.dart';
import '../widgets/event_card_widget.dart';
import '../widgets/event_calendar_widget.dart';
import 'event_registration_screen.dart';

/// Event categories enum
enum EventCategory { festival, puja, celebration, workshop, charity, other }

extension EventCategoryExtension on EventCategory {
  String get displayName {
    switch (this) {
      case EventCategory.festival:
        return 'Festival';
      case EventCategory.puja:
        return 'Puja';
      case EventCategory.celebration:
        return 'Celebration';
      case EventCategory.workshop:
        return 'Workshop';
      case EventCategory.charity:
        return 'Charity';
      case EventCategory.other:
        return 'Other';
    }
  }
}

/// Screen showing all events across all temples
class AllEventsScreen extends StatefulWidget {
  const AllEventsScreen({super.key});

  @override
  State<AllEventsScreen> createState() => _AllEventsScreenState();
}

class _AllEventsScreenState extends State<AllEventsScreen>
    with SingleTickerProviderStateMixin {
  final _eventService = EventService();
  late TabController _tabController;

  EventCategory? _selectedCategory;
  bool _showCalendarView = false;

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
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text(
          'All Events',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: AppColors.scaffoldBackground,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          IconButton(
            icon: Icon(
              _showCalendarView ? Icons.list : Icons.calendar_month,
              color: AppColors.primaryOrange,
            ),
            onPressed: () {
              setState(() {
                _showCalendarView = !_showCalendarView;
              });
            },
          ),
          PopupMenuButton<EventCategory?>(
            icon: const Icon(Icons.filter_list, color: AppColors.primaryOrange),
            onSelected: (category) {
              setState(() {
                _selectedCategory = category;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: null,
                child: Text('All Categories'),
              ),
              ...EventCategory.values.map(
                (category) => PopupMenuItem(
                  value: category,
                  child: Text(category.displayName),
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primaryOrange,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primaryOrange,
          tabs: const [
            Tab(text: 'Upcoming'),
            Tab(text: 'Past'),
            Tab(text: 'My Events'),
          ],
        ),
      ),
      body: _showCalendarView
          ? _buildCalendarView()
          : TabBarView(
              controller: _tabController,
              children: [
                _buildUpcomingEvents(),
                _buildPastEvents(),
                _buildMyEvents(),
              ],
            ),
    );
  }

  Widget _buildCalendarView() {
    return FutureBuilder<List<Event>>(
      future: _eventService.getAllEvents(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: AppColors.textSecondary,
                ),
                AppSpacing.verticalSpaceMedium,
                Text(
                  'Error loading events',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
                AppSpacing.verticalSpaceSmall,
                Text(
                  snapshot.error.toString(),
                  style: TextStyle(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return EventCalendarWidget(
          templeId: 'all', // Use 'all' to indicate all temples
          onEventTap: _navigateToEventRegistration,
        );
      },
    );
  }

  Widget _buildUpcomingEvents() {
    return FutureBuilder<List<Event>>(
      future: _eventService.getAllEvents(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingSkeleton();
        }

        if (snapshot.hasError) {
          return _buildErrorWidget(snapshot.error.toString());
        }

        final events = snapshot.data ?? [];
        final upcomingEvents = _filterEvents(events)
            .where((event) => event.startDate.isAfter(DateTime.now()))
            .toList()
          ..sort((a, b) => a.startDate.compareTo(b.startDate));

        if (upcomingEvents.isEmpty) {
          return _buildEmptyState('No upcoming events found');
        }

        return _buildEventsList(upcomingEvents);
      },
    );
  }

  Widget _buildPastEvents() {
    return FutureBuilder<List<Event>>(
      future: _eventService.getAllEvents(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingSkeleton();
        }

        if (snapshot.hasError) {
          return _buildErrorWidget(snapshot.error.toString());
        }

        final events = snapshot.data ?? [];
        final pastEvents = _filterEvents(events)
            .where((event) => event.endDate.isBefore(DateTime.now()))
            .toList()
          ..sort((a, b) => b.startDate.compareTo(a.startDate));

        if (pastEvents.isEmpty) {
          return _buildEmptyState('No past events found');
        }

        return _buildEventsList(pastEvents);
      },
    );
  }

  Widget _buildMyEvents() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return _buildAuthRequiredWidget();
    }

    return FutureBuilder<List<Event>>(
      future: _eventService.getUserRegisteredEvents(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingSkeleton();
        }

        if (snapshot.hasError) {
          return _buildErrorWidget(snapshot.error.toString());
        }

        final events = snapshot.data ?? [];
        final filteredEvents = _filterEvents(events);

        if (filteredEvents.isEmpty) {
          return _buildEmptyState('No registered events found');
        }

        return _buildEventsList(filteredEvents);
      },
    );
  }

  Widget _buildEventsList(List<Event> events) {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() {});
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: events.length,
        itemBuilder: (context, index) {
          final event = events[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: EventCardWidget(
              event: event,
              onTap: () => _navigateToEventRegistration(event),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: SkeletonWidget(
            height: 120,
            borderRadius: BorderRadius.circular(12),
          ),
        );
      },
    );
  }

  Widget _buildErrorWidget(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: AppColors.textSecondary,
          ),
          AppSpacing.verticalSpaceMedium,
          Text(
            'Error loading events',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          AppSpacing.verticalSpaceSmall,
          Text(
            error,
            style: TextStyle(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          AppSpacing.verticalSpaceMedium,
          ElevatedButton(
            onPressed: () => setState(() {}),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_busy,
            size: 64,
            color: AppColors.textSecondary,
          ),
          AppSpacing.verticalSpaceMedium,
          Text(
            message,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthRequiredWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.login,
            size: 64,
            color: AppColors.textSecondary,
          ),
          AppSpacing.verticalSpaceMedium,
          Text(
            'Login Required',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          AppSpacing.verticalSpaceSmall,
          Text(
            'Please login to view your registered events',
            style: TextStyle(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  List<Event> _filterEvents(List<Event> events) {
    if (_selectedCategory == null) return events;
    
    return events.where((event) {
      final categoryString = event.additionalInfo?['category'] as String?;
      if (categoryString == null) return _selectedCategory == EventCategory.other;
      
      // Convert string to EventCategory enum
      try {
        final eventCategory = EventCategory.values.firstWhere(
          (category) => category.name.toLowerCase() == categoryString.toLowerCase(),
          orElse: () => EventCategory.other,
        );
        return eventCategory == _selectedCategory;
      } catch (e) {
        return _selectedCategory == EventCategory.other;
      }
    }).toList();
  }

  void _navigateToEventRegistration(Event event) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EventRegistrationScreen(event: event),
      ),
    );
  }
}