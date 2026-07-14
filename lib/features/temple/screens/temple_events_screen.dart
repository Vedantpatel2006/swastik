import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../shared/models/event.dart';
import '../../../shared/models/event_registration.dart';
import '../../../shared/services/event_service.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/app_spacing.dart';
import '../../../shared/widgets/loading/skeleton_loader.dart';
import 'event_registration_screen.dart';
import '../widgets/event_card_widget.dart';
import '../widgets/event_calendar_widget.dart';

class TempleEventsScreen extends StatefulWidget {
  final String templeId;
  final String templeName;

  const TempleEventsScreen({
    super.key,
    required this.templeId,
    required this.templeName,
  });

  @override
  State<TempleEventsScreen> createState() => _TempleEventsScreenState();
}

class _TempleEventsScreenState extends State<TempleEventsScreen>
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
        backgroundColor: AppColors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Events',
              style: TextStyle(
                color: AppColors.primaryText,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            Text(
              widget.templeName,
              style: const TextStyle(
                color: AppColors.secondaryText,
                fontSize: 12,
              ),
            ),
          ],
        ),
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
            tooltip: _showCalendarView ? 'List View' : 'Calendar View',
          ),
          IconButton(
            icon: const Icon(Icons.filter_list, color: AppColors.primaryOrange),
            onPressed: _showFilterDialog,
            tooltip: 'Filter Events',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primaryOrange,
          unselectedLabelColor: AppColors.secondaryText,
          indicatorColor: AppColors.primaryOrange,
          tabs: const [
            Tab(text: 'Upcoming'),
            Tab(text: 'Past'),
            Tab(text: 'My Events'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildEventsList(EventFilter.upcoming),
          _buildEventsList(EventFilter.past),
          _buildMyEventsList(),
        ],
      ),
    );
  }

  Widget _buildEventsList(EventFilter filter) {
    if (_showCalendarView && filter == EventFilter.upcoming) {
      return EventCalendarWidget(
        templeId: widget.templeId,
        onEventTap: _navigateToEventDetails,
      );
    }

    return StreamBuilder<List<Event>>(
      stream: _eventService.watchEventsForTemple(widget.templeId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SearchSkeletonLoader(itemCount: 5);
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: AppColors.errorRed),
                const SizedBox(height: 16),
                const Text(
                  'Error loading events',
                  style: TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text(
                  snapshot.error.toString(),
                  style: const TextStyle(color: AppColors.secondaryText),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final allEvents = snapshot.data ?? [];
        final filteredEvents = _filterEvents(allEvents, filter);

        if (filteredEvents.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  filter == EventFilter.upcoming
                      ? Icons.event_busy
                      : Icons.history,
                  size: 64,
                  color: AppColors.secondaryText,
                ),
                const SizedBox(height: 16),
                Text(
                  filter == EventFilter.upcoming
                      ? 'No upcoming events'
                      : 'No past events',
                  style: const TextStyle(
                    fontSize: 18,
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: AppSpacing.allLg,
          itemCount: filteredEvents.length,
          itemBuilder: (context, index) {
            final event = filteredEvents[index];
            return EventCardWidget(
              event: event,
              onTap: () => _navigateToEventDetails(event),
              onRegister: () => _navigateToRegistration(event),
            );
          },
        );
      },
    );
  }

  Widget _buildMyEventsList() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.login, size: 64, color: AppColors.secondaryText),
            SizedBox(height: 16),
            Text(
              'Please sign in to view your events',
              style: TextStyle(fontSize: 18, color: AppColors.secondaryText),
            ),
          ],
        ),
      );
    }

    return StreamBuilder<List<EventRegistration>>(
      stream: _eventService.watchUserRegistrations(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SearchSkeletonLoader(itemCount: 4);
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final registrations = snapshot.data ?? [];
        if (registrations.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.event_note,
                  size: 64,
                  color: AppColors.secondaryText,
                ),
                SizedBox(height: 16),
                Text(
                  'No registered events',
                  style: TextStyle(
                    fontSize: 18,
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: AppSpacing.allLg,
          itemCount: registrations.length,
          itemBuilder: (context, index) {
            final registration = registrations[index];
            return FutureBuilder<Event?>(
              future: _eventService.getEventById(registration.eventId),
              builder: (context, eventSnapshot) {
                if (!eventSnapshot.hasData) {
                  return const SizedBox.shrink();
                }

                final event = eventSnapshot.data!;
                return EventCardWidget(
                  event: event,
                  registration: registration,
                  onTap: () => _navigateToEventDetails(event),
                  showRegistrationStatus: true,
                );
              },
            );
          },
        );
      },
    );
  }

  List<Event> _filterEvents(List<Event> events, EventFilter filter) {
    final now = DateTime.now();
    List<Event> filtered;

    switch (filter) {
      case EventFilter.upcoming:
        filtered = events.where((e) => e.startDate.isAfter(now)).toList();
        filtered.sort((a, b) => a.startDate.compareTo(b.startDate));
        break;
      case EventFilter.past:
        filtered = events.where((e) => e.endDate.isBefore(now)).toList();
        filtered.sort((a, b) => b.endDate.compareTo(a.endDate));
        break;
      case EventFilter.ongoing:
        filtered = events
            .where((e) => e.startDate.isBefore(now) && e.endDate.isAfter(now))
            .toList();
        break;
    }

    if (_selectedCategory != null) {
      filtered = filtered.where((e) {
        final category = e.additionalInfo?['category'] as String?;
        return category == _selectedCategory!.name;
      }).toList();
    }

    return filtered;
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Events'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Category',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: _selectedCategory == null,
                  onSelected: (selected) {
                    setState(() {
                      _selectedCategory = null;
                    });
                    Navigator.pop(context);
                  },
                ),
                ...EventCategory.values.map((category) {
                  return FilterChip(
                    label: Text(category.displayName),
                    selected: _selectedCategory == category,
                    onSelected: (selected) {
                      setState(() {
                        _selectedCategory = selected ? category : null;
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

  void _navigateToEventDetails(Event event) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EventRegistrationScreen(event: event),
      ),
    );
  }

  void _navigateToRegistration(Event event) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EventRegistrationScreen(event: event),
      ),
    );

    if (result == true && mounted) {
      setState(() {});
    }
  }
}

enum EventFilter { upcoming, past, ongoing }

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
