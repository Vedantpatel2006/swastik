import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/event.dart';
import '../models/event_registration.dart';
import 'cache/data_cache_manager.dart';

/// Service for managing temple events and registrations
class EventService {
  final DataCacheManager _cacheManager;

  // Collection references
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final CollectionReference _eventsCollection;
  late final CollectionReference _registrationsCollection;

  // Cache keys
  static const String _eventsCacheKey = 'events';
  static const String _templeEventsCachePrefix = 'temple_events_';

  EventService({DataCacheManager? cacheManager})
    : _cacheManager = cacheManager ?? DataCacheManager() {
    _eventsCollection = _firestore.collection('events');
    _registrationsCollection = _firestore.collection('event_registrations');
  }

  /// Initialize the service
  Future<void> initialize() async {
    // Any initialization logic can go here
  }

  /// Get all events
  Future<List<Event>> getAllEvents() async {
    try {
      // Try to get from cache first
      final cachedData = await _cacheManager.getCachedDataList(_eventsCacheKey);
      if (cachedData != null) {
        return cachedData.map((e) => Event.fromJson(e)).toList();
      }

      // If not in cache, fetch from Firestore
      final snapshot = await _eventsCollection.get();
      final events = snapshot.docs
          .map(
            (doc) => Event.fromJson({
              'id': doc.id,
              ...(doc.data() as Map<String, dynamic>? ?? {}),
            }),
          )
          .toList();

      // Cache the results
      await _cacheManager.cacheDataList(
        _eventsCacheKey,
        events.map((e) => e.toJson()).toList(),
      );

      return events;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting all events: $e');
      }
      rethrow;
    }
  }

  /// Get events for a specific temple
  Future<List<Event>> getEventsForTemple(String templeId) async {
    try {
      final cacheKey = '$_templeEventsCachePrefix$templeId';

      // Try to get from cache first
      final cachedData = await _cacheManager.getCachedDataList(cacheKey);
      if (cachedData != null) {
        return cachedData.map((e) => Event.fromJson(e)).toList();
      }

      // If not in cache, fetch from Firestore
      final snapshot = await _eventsCollection
          .where('templeId', isEqualTo: templeId)
          .get();

      final events = snapshot.docs
          .map(
            (doc) => Event.fromJson({
              'id': doc.id,
              ...(doc.data() as Map<String, dynamic>? ?? {}),
            }),
          )
          .toList();

      // Cache the results
      await _cacheManager.cacheDataList(
        cacheKey,
        events.map((e) => e.toJson()).toList(),
      );

      return events;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting events for temple $templeId: $e');
      }
      rethrow;
    }
  }

  /// Get events for a specific date range
  Future<List<Event>> getEventsInDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final snapshot = await _eventsCollection
          .where(
            'startDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
          )
          .where('startDate', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .get();

      return snapshot.docs
          .map(
            (doc) => Event.fromJson({
              'id': doc.id,
              ...(doc.data() as Map<String, dynamic>? ?? {}),
            }),
          )
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting events in date range: $e');
      }
      rethrow;
    }
  }

  /// Get a specific event by ID
  Future<Event?> getEventById(String eventId) async {
    try {
      final doc = await _eventsCollection.doc(eventId).get();
      if (!doc.exists) return null;

      return Event.fromJson({
        'id': doc.id,
        ...(doc.data() as Map<String, dynamic>? ?? {}),
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error getting event $eventId: $e');
      }
      rethrow;
    }
  }

  /// Create a new event
  /// ✅ FIXED: Now updates temple document with event counts
  Future<String> createEvent(Event event) async {
    try {
      // Remove the ID from the event data as Firestore will generate one
      final eventData = event.toJson();
      eventData.remove('id');

      final docRef = await _eventsCollection.add(eventData);

      // ✅ Update temple document with event stats
      await _updateTempleEventStats(event.templeId);

      // Clear cache to ensure fresh data on next fetch
      await _clearEventCache(event.templeId);

      return docRef.id;
    } catch (e) {
      if (kDebugMode) {
        print('Error creating event: $e');
      }
      rethrow;
    }
  }

  /// Update an existing event
  /// ✅ FIXED: Now updates temple document with event counts
  Future<void> updateEvent(Event event) async {
    try {
      // Remove the ID from the event data as it's part of the document path
      final eventData = event.toJson();
      eventData.remove('id');

      await _eventsCollection.doc(event.id).update(eventData);

      // ✅ Update temple document with event stats
      await _updateTempleEventStats(event.templeId);

      // Clear cache to ensure fresh data on next fetch
      await _clearEventCache(event.templeId);
    } catch (e) {
      if (kDebugMode) {
        print('Error updating event ${event.id}: $e');
      }
      rethrow;
    }
  }

  /// Delete an event
  /// ✅ FIXED: Now updates temple document with event counts
  Future<void> deleteEvent(String eventId, String templeId) async {
    try {
      await _eventsCollection.doc(eventId).delete();

      // ✅ Update temple document with event stats
      await _updateTempleEventStats(templeId);

      // Clear cache to ensure fresh data on next fetch
      await _clearEventCache(templeId);
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting event $eventId: $e');
      }
      rethrow;
    }
  }

  /// ✅ NEW: Update temple document with event statistics
  Future<void> _updateTempleEventStats(String templeId) async {
    try {
      final now = DateTime.now();

      // Get upcoming events
      final upcomingEvents = await _eventsCollection
          .where('templeId', isEqualTo: templeId)
          .where('startDate', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
          .orderBy('startDate')
          .get();

      // Update temple document
      await _firestore.collection('temples').doc(templeId).update({
        'hasUpcomingEvents': upcomingEvents.docs.isNotEmpty,
        'upcomingEventsCount': upcomingEvents.docs.length,
        'nextEventDate': upcomingEvents.docs.isNotEmpty
            ? (upcomingEvents.docs.first.data() as Map<String, dynamic>)['startDate']
            : null,
        'updatedAt': Timestamp.now(),
      });

      if (kDebugMode) {
        print(
          '✅ Updated temple $templeId event stats: ${upcomingEvents.docs.length} upcoming events',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Failed to update temple event stats: $e');
      }
      // Don't throw - this is a non-critical operation
    }
  }

  /// Generate recurring event instances based on recurrence pattern
  List<DateTime> generateRecurringEventDates(Event event, DateTime until) {
    if (!event.isRecurring || event.recurrencePattern == null) {
      return [event.startDate];
    }

    final pattern = event.recurrencePattern!;
    final dates = <DateTime>[];
    var currentDate = event.startDate;

    // Determine end condition
    final endDate = pattern.until ?? until;
    final maxCount =
        pattern.count ?? 100; // Default max to prevent infinite loops

    // Generate dates based on recurrence pattern
    while (currentDate.isBefore(endDate) && dates.length < maxCount) {
      dates.add(currentDate);

      switch (pattern.type) {
        case RecurrenceType.daily:
          currentDate = currentDate.add(Duration(days: pattern.interval));
          break;
        case RecurrenceType.weekly:
          if (pattern.daysOfWeek != null && pattern.daysOfWeek!.isNotEmpty) {
            // Handle specific days of week
            // This is a simplified implementation
            currentDate = currentDate.add(Duration(days: 7 * pattern.interval));
          } else {
            currentDate = currentDate.add(Duration(days: 7 * pattern.interval));
          }
          break;
        case RecurrenceType.monthly:
          // Simple implementation - just add months
          currentDate = DateTime(
            currentDate.year,
            currentDate.month + pattern.interval,
            pattern.dayOfMonth ?? currentDate.day,
          );
          break;
        case RecurrenceType.yearly:
          currentDate = DateTime(
            currentDate.year + pattern.interval,
            currentDate.month,
            currentDate.day,
          );
          break;
      }
    }

    return dates;
  }

  /// Clear event-related caches
  Future<void> _clearEventCache(String templeId) async {
    await _cacheManager.remove(_eventsCacheKey);
    await _cacheManager.remove('$_templeEventsCachePrefix$templeId');
  }

  /// Stream events for a specific temple
  Stream<List<Event>> watchEventsForTemple(String templeId) {
    return _eventsCollection
        .where('templeId', isEqualTo: templeId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => Event.fromJson({
                  'id': doc.id,
                  ...(doc.data() as Map<String, dynamic>? ?? {}),
                }),
              )
              .toList(),
        );
  }

  /// Stream all events
  Stream<List<Event>> watchAllEvents() {
    return _eventsCollection.snapshots().map(
      (snapshot) => snapshot.docs
          .map(
            (doc) => Event.fromJson({
              'id': doc.id,
              ...(doc.data() as Map<String, dynamic>? ?? {}),
            }),
          )
          .toList(),
    );
  }

  /// Get upcoming events for a temple
  Future<List<Event>> getUpcomingEventsForTemple(
    String templeId, {
    int limit = 10,
  }) async {
    try {
      final now = DateTime.now();
      final snapshot = await _eventsCollection
          .where('templeId', isEqualTo: templeId)
          .where('startDate', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
          .orderBy('startDate')
          .limit(limit)
          .get();

      return snapshot.docs
          .map(
            (doc) => Event.fromJson({
              'id': doc.id,
              ...(doc.data() as Map<String, dynamic>? ?? {}),
            }),
          )
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting upcoming events for temple $templeId: $e');
      }
      rethrow;
    }
  }

  /// Get past events for a temple
  Future<List<Event>> getPastEventsForTemple(
    String templeId, {
    int limit = 10,
  }) async {
    try {
      final now = DateTime.now();
      final snapshot = await _eventsCollection
          .where('templeId', isEqualTo: templeId)
          .where('endDate', isLessThan: Timestamp.fromDate(now))
          .orderBy('endDate', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map(
            (doc) => Event.fromJson({
              'id': doc.id,
              ...(doc.data() as Map<String, dynamic>? ?? {}),
            }),
          )
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting past events for temple $templeId: $e');
      }
      rethrow;
    }
  }

  /// Search events by name or description
  Future<List<Event>> searchEvents(String query, {String? templeId}) async {
    try {
      Query queryRef = _eventsCollection;

      if (templeId != null) {
        queryRef = queryRef.where('templeId', isEqualTo: templeId);
      }

      final snapshot = await queryRef.get();

      final allEvents = snapshot.docs
          .map(
            (doc) => Event.fromJson({
              'id': doc.id,
              ...(doc.data() as Map<String, dynamic>? ?? {}),
            }),
          )
          .toList();

      // Filter by query (case-insensitive search in name and description)
      final filteredEvents = allEvents.where((event) {
        final lowerQuery = query.toLowerCase();
        return event.name.toLowerCase().contains(lowerQuery) ||
            event.description.toLowerCase().contains(lowerQuery);
      }).toList();

      return filteredEvents;
    } catch (e) {
      if (kDebugMode) {
        print('Error searching events: $e');
      }
      rethrow;
    }
  }

  /// Get events by category (using additionalInfo)
  Future<List<Event>> getEventsByCategory(
    String category, {
    String? templeId,
  }) async {
    try {
      Query queryRef = _eventsCollection;

      if (templeId != null) {
        queryRef = queryRef.where('templeId', isEqualTo: templeId);
      }

      queryRef = queryRef.where('additionalInfo.category', isEqualTo: category);

      final snapshot = await queryRef.get();

      return snapshot.docs
          .map(
            (doc) => Event.fromJson({
              'id': doc.id,
              ...(doc.data() as Map<String, dynamic>? ?? {}),
            }),
          )
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting events by category $category: $e');
      }
      rethrow;
    }
  }

  /// Get event statistics for a temple
  Future<Map<String, dynamic>> getEventStatistics(String templeId) async {
    try {
      final allEvents = await getEventsForTemple(templeId);
      final now = DateTime.now();

      final upcomingEvents = allEvents
          .where((event) => event.startDate.isAfter(now))
          .toList();
      final pastEvents = allEvents
          .where((event) => event.endDate.isBefore(now))
          .toList();
      final ongoingEvents = allEvents
          .where(
            (event) =>
                event.startDate.isBefore(now) && event.endDate.isAfter(now),
          )
          .toList();
      final recurringEvents = allEvents
          .where((event) => event.isRecurring)
          .toList();

      // Get events by month for the current year
      final currentYear = now.year;
      final eventsByMonth = <String, int>{};

      for (int month = 1; month <= 12; month++) {
        final monthKey = '$currentYear-${month.toString().padLeft(2, '0')}';
        final monthEvents = allEvents
            .where(
              (event) =>
                  event.startDate.year == currentYear &&
                  event.startDate.month == month,
            )
            .length;
        eventsByMonth[monthKey] = monthEvents;
      }

      return {
        'totalEvents': allEvents.length,
        'upcomingEvents': upcomingEvents.length,
        'pastEvents': pastEvents.length,
        'ongoingEvents': ongoingEvents.length,
        'recurringEvents': recurringEvents.length,
        'eventsByMonth': eventsByMonth,
        'averageEventsPerMonth': allEvents.length / 12,
      };
    } catch (e) {
      if (kDebugMode) {
        print('Error getting event statistics for temple $templeId: $e');
      }
      rethrow;
    }
  }

  /// Check if an event conflicts with existing events
  Future<List<Event>> checkEventConflicts(Event event) async {
    try {
      final existingEvents = await getEventsForTemple(event.templeId);

      final conflicts = existingEvents.where((existingEvent) {
        // Skip checking against the same event (for updates)
        if (existingEvent.id == event.id) return false;

        // Check for time overlap
        return (event.startDate.isBefore(existingEvent.endDate) &&
            event.endDate.isAfter(existingEvent.startDate));
      }).toList();

      return conflicts;
    } catch (e) {
      if (kDebugMode) {
        print('Error checking event conflicts: $e');
      }
      rethrow;
    }
  }

  /// Validate event data
  bool validateEvent(Event event) {
    // Basic validation
    if (event.name.trim().isEmpty) return false;
    if (event.description.trim().isEmpty) return false;
    if (event.templeId.trim().isEmpty) return false;
    if (event.startDate.isAfter(event.endDate)) return false;

    // Validate recurrence pattern if event is recurring
    if (event.isRecurring && event.recurrencePattern == null) return false;

    return true;
  }

  /// Get event categories from all events
  Future<List<String>> getEventCategories({String? templeId}) async {
    try {
      final events = templeId != null
          ? await getEventsForTemple(templeId)
          : await getAllEvents();

      final categories = <String>{};

      for (final event in events) {
        final category = event.additionalInfo?['category'] as String?;
        if (category != null && category.isNotEmpty) {
          categories.add(category);
        }
      }

      return categories.toList()..sort();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting event categories: $e');
      }
      rethrow;
    }
  }

  /// Bulk create events
  Future<List<String>> createEvents(List<Event> events) async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      final eventIds = <String>[];

      for (final event in events) {
        if (!validateEvent(event)) {
          throw ArgumentError('Invalid event data: ${event.name}');
        }

        final eventData = event.toJson();
        eventData.remove('id');

        final docRef = _eventsCollection.doc();
        batch.set(docRef, eventData);
        eventIds.add(docRef.id);
      }

      await batch.commit();

      // Clear cache for affected temples
      final templeIds = events.map((e) => e.templeId).toSet();
      for (final templeId in templeIds) {
        await _clearEventCache(templeId);
      }

      return eventIds;
    } catch (e) {
      if (kDebugMode) {
        print('Error creating events: $e');
      }
      rethrow;
    }
  }

  /// Bulk delete events
  Future<void> deleteEvents(List<String> eventIds, String templeId) async {
    try {
      final batch = FirebaseFirestore.instance.batch();

      for (final eventId in eventIds) {
        batch.delete(_eventsCollection.doc(eventId));
      }

      await batch.commit();
      await _clearEventCache(templeId);
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting events: $e');
      }
      rethrow;
    }
  }

  // ==================== EVENT REGISTRATION METHODS ====================

  /// Register a user for an event
  Future<String> registerForEvent(EventRegistration registration) async {
    try {
      final registrationData = registration.toJson();
      registrationData.remove('id');

      final docRef = await _registrationsCollection.add(registrationData);
      return docRef.id;
    } catch (e) {
      if (kDebugMode) {
        print('Error registering for event: $e');
      }
      rethrow;
    }
  }

  /// Get user's registration for a specific event
  Future<EventRegistration?> getUserEventRegistration(
    String userId,
    String eventId,
  ) async {
    try {
      final snapshot = await _registrationsCollection
          .where('userId', isEqualTo: userId)
          .where('eventId', isEqualTo: eventId)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;

      return EventRegistration.fromFirestore(snapshot.docs.first);
    } catch (e) {
      if (kDebugMode) {
        print('Error getting user event registration: $e');
      }
      rethrow;
    }
  }

  /// Get all registrations for an event
  Future<List<EventRegistration>> getEventRegistrations(String eventId) async {
    try {
      final snapshot = await _registrationsCollection
          .where('eventId', isEqualTo: eventId)
          .orderBy('registeredAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => EventRegistration.fromFirestore(doc))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting event registrations: $e');
      }
      rethrow;
    }
  }

  /// Get user's all event registrations
  Future<List<EventRegistration>> getUserRegistrations(String userId) async {
    try {
      final snapshot = await _registrationsCollection
          .where('userId', isEqualTo: userId)
          .orderBy('registeredAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => EventRegistration.fromFirestore(doc))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting user registrations: $e');
      }
      rethrow;
    }
  }

  /// Get events that a user is registered for
  Future<List<Event>> getUserRegisteredEvents(String userId) async {
    try {
      // First get user's registrations
      final registrations = await getUserRegistrations(userId);
      
      // Filter only active registrations
      final activeRegistrations = registrations
          .where((r) => r.isActive)
          .toList();

      if (activeRegistrations.isEmpty) {
        return [];
      }

      // Get event IDs
      final eventIds = activeRegistrations
          .map((r) => r.eventId)
          .toSet()
          .toList();

      // Fetch events in batches (Firestore 'in' query limit is 10)
      final events = <Event>[];
      for (int i = 0; i < eventIds.length; i += 10) {
        final batchIds = eventIds.skip(i).take(10).toList();
        
        final snapshot = await _eventsCollection
            .where(FieldPath.documentId, whereIn: batchIds)
            .get();

        final batchEvents = snapshot.docs
            .map(
              (doc) => Event.fromJson({
                'id': doc.id,
                ...(doc.data() as Map<String, dynamic>? ?? {}),
              }),
            )
            .toList();

        events.addAll(batchEvents);
      }

      // Sort by start date
      events.sort((a, b) => a.startDate.compareTo(b.startDate));

      return events;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting user registered events: $e');
      }
      rethrow;
    }
  }

  /// Cancel event registration
  Future<void> cancelRegistration(
    String registrationId,
    String cancellationReason,
  ) async {
    try {
      await _registrationsCollection.doc(registrationId).update({
        'status': RegistrationStatus.cancelled.name,
        'cancelledAt': Timestamp.fromDate(DateTime.now()),
        'cancellationReason': cancellationReason,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error cancelling registration: $e');
      }
      rethrow;
    }
  }

  /// Check in a user for an event
  Future<void> checkInRegistration(String registrationId) async {
    try {
      await _registrationsCollection.doc(registrationId).update({
        'checkedIn': true,
        'checkInTime': Timestamp.fromDate(DateTime.now()),
        'status': RegistrationStatus.checkedIn.name,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error checking in registration: $e');
      }
      rethrow;
    }
  }

  /// Get registration count for an event
  Future<int> getEventRegistrationCount(String eventId) async {
    try {
      final snapshot = await _registrationsCollection
          .where('eventId', isEqualTo: eventId)
          .where(
            'status',
            whereIn: [
              RegistrationStatus.confirmed.name,
              RegistrationStatus.checkedIn.name,
            ],
          )
          .get();

      return snapshot.docs.fold<int>(0, (sum, doc) {
        final data = doc.data() as Map<String, dynamic>;
        return sum + (data['numberOfAttendees'] as int? ?? 1);
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error getting event registration count: $e');
      }
      rethrow;
    }
  }

  /// Check if user is registered for an event
  Future<bool> isUserRegistered(String userId, String eventId) async {
    try {
      final registration = await getUserEventRegistration(userId, eventId);
      return registration != null && registration.isActive;
    } catch (e) {
      if (kDebugMode) {
        print('Error checking user registration: $e');
      }
      return false;
    }
  }

  /// Stream event registrations
  Stream<List<EventRegistration>> watchEventRegistrations(String eventId) {
    return _registrationsCollection
        .where('eventId', isEqualTo: eventId)
        .orderBy('registeredAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => EventRegistration.fromFirestore(doc))
              .toList(),
        );
  }

  /// Stream user registrations
  Stream<List<EventRegistration>> watchUserRegistrations(String userId) {
    return _registrationsCollection
        .where('userId', isEqualTo: userId)
        .orderBy('registeredAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => EventRegistration.fromFirestore(doc))
              .toList(),
        );
  }

  /// Get registration statistics for an event
  Future<Map<String, dynamic>> getRegistrationStatistics(String eventId) async {
    try {
      final registrations = await getEventRegistrations(eventId);

      final confirmed = registrations
          .where((r) => r.status == RegistrationStatus.confirmed)
          .length;
      final checkedIn = registrations
          .where((r) => r.status == RegistrationStatus.checkedIn)
          .length;
      final cancelled = registrations
          .where((r) => r.status == RegistrationStatus.cancelled)
          .length;
      final waitlisted = registrations
          .where((r) => r.status == RegistrationStatus.waitlisted)
          .length;

      final totalAttendees = registrations
          .where(
            (r) =>
                r.status == RegistrationStatus.confirmed ||
                r.status == RegistrationStatus.checkedIn,
          )
          .fold<int>(0, (sum, r) => sum + r.numberOfAttendees);

      return {
        'totalRegistrations': registrations.length,
        'confirmed': confirmed,
        'checkedIn': checkedIn,
        'cancelled': cancelled,
        'waitlisted': waitlisted,
        'totalAttendees': totalAttendees,
        'checkInRate': confirmed > 0 ? (checkedIn / confirmed) * 100 : 0,
      };
    } catch (e) {
      if (kDebugMode) {
        print('Error getting registration statistics: $e');
      }
      rethrow;
    }
  }
}
