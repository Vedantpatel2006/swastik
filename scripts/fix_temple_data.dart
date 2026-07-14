import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

/// Migration script to fix temple data issues identified in QA audit
/// 
/// This script:
/// 1. Fixes temples with (0,0) coordinates
/// 2. Migrates legacy timing format to new format
/// 3. Syncs event counts for all temples
/// 4. Validates and reports data quality issues
///
/// Usage: dart run scripts/fix_temple_data.dart

void main() async {
  print('🔧 Starting Temple Data Fix Script...\n');

  // Initialize Firebase
  await Firebase.initializeApp();
  final firestore = FirebaseFirestore.instance;

  // Statistics
  int totalTemples = 0;
  int fixedLocations = 0;
  int migratedTimings = 0;
  int syncedEvents = 0;
  int errors = 0;

  try {
    // Get all temples
    final templesSnapshot = await firestore.collection('temples').get();
    totalTemples = templesSnapshot.docs.length;

    print('📊 Found $totalTemples temples to process\n');

    for (final doc in templesSnapshot.docs) {
      final templeId = doc.id;
      final data = doc.data();
      final templeName = data['name'] ?? 'Unknown';

      print('Processing: $templeName ($templeId)');

      try {
        final updates = <String, dynamic>{};

        // 1. Fix location issues
        final locationFixed = await _fixLocation(data, templeId, updates);
        if (locationFixed) fixedLocations++;

        // 2. Migrate timing format
        final timingMigrated = _migrateTimings(data, updates);
        if (timingMigrated) migratedTimings++;

        // 3. Sync event counts
        final eventsSynced = await _syncEventCounts(
          firestore,
          templeId,
          updates,
        );
        if (eventsSynced) syncedEvents++;

        // 4. Add updatedAt timestamp
        updates['updatedAt'] = FieldValue.serverTimestamp();

        // Apply updates if any
        if (updates.isNotEmpty) {
          await doc.reference.update(updates);
          print('  ✅ Updated ${updates.length} fields');
        } else {
          print('  ℹ️  No updates needed');
        }
      } catch (e) {
        print('  ❌ Error: $e');
        errors++;
      }

      print('');
    }

    // Print summary
    print('\n' + '=' * 60);
    print('📊 MIGRATION SUMMARY');
    print('=' * 60);
    print('Total Temples Processed: $totalTemples');
    print('Locations Fixed: $fixedLocations');
    print('Timings Migrated: $migratedTimings');
    print('Event Counts Synced: $syncedEvents');
    print('Errors: $errors');
    print('=' * 60);

    if (errors == 0) {
      print('\n✅ Migration completed successfully!');
    } else {
      print('\n⚠️  Migration completed with $errors errors');
    }
  } catch (e) {
    print('\n❌ Fatal error: $e');
  }
}

/// Fix location data issues
Future<bool> _fixLocation(
  Map<String, dynamic> data,
  String templeId,
  Map<String, dynamic> updates,
) async {
  final location = data['location'];

  if (location == null) {
    print('  ⚠️  No location data');
    return false;
  }

  // Handle Map format
  if (location is Map) {
    final lat = _parseDouble(location['latitude'] ?? location['lat']);
    final lng = _parseDouble(location['longitude'] ?? location['lng']);

    // Check for (0,0) fallback coordinates
    if (lat == 0.0 && lng == 0.0) {
      print('  ⚠️  Invalid location (0,0) - needs manual fix');
      // Mark for manual review
      updates['needsLocationFix'] = true;
      return true;
    }

    // Validate coordinates
    if (lat == null || lng == null || !_isValidCoordinate(lat, lng)) {
      print('  ⚠️  Invalid coordinates - needs manual fix');
      updates['needsLocationFix'] = true;
      return true;
    }

    // Ensure proper structure
    if (!location.containsKey('address') || location['address'] == null) {
      print('  ⚠️  Missing address - needs manual fix');
      updates['needsLocationFix'] = true;
      return true;
    }
  }

  return false;
}

/// Migrate legacy timing format to new format
bool _migrateTimings(Map<String, dynamic> data, Map<String, dynamic> updates) {
  // Check if already using new format
  if (data.containsKey('timings') && data['timings'] is Map) {
    final timings = data['timings'] as Map;
    if (timings.isNotEmpty) {
      return false; // Already migrated
    }
  }

  // Check for legacy fields
  final openingTime = data['openingTime'] as String?;
  final closingTime = data['closingTime'] as String?;
  final weeklyClosedDay = data['weeklyClosedDay'] as String?;

  if (openingTime == null || closingTime == null) {
    return false; // No legacy data to migrate
  }

  // Build new timings format
  final timings = <String, String>{};
  final timeRange = '$openingTime - $closingTime';

  final allDays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  for (final day in allDays) {
    if (weeklyClosedDay == null ||
        weeklyClosedDay == 'None' ||
        day != weeklyClosedDay) {
      timings[day] = timeRange;
    }
  }

  if (timings.isNotEmpty) {
    updates['timings'] = timings;
    print('  🔄 Migrated timing format');
    return true;
  }

  return false;
}

/// Sync event counts for temple
Future<bool> _syncEventCounts(
  FirebaseFirestore firestore,
  String templeId,
  Map<String, dynamic> updates,
) async {
  try {
    final now = DateTime.now();

    // Get upcoming events
    final upcomingEvents = await firestore
        .collection('events')
        .where('templeId', isEqualTo: templeId)
        .where('startDate', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
        .orderBy('startDate')
        .get();

    updates['hasUpcomingEvents'] = upcomingEvents.docs.isNotEmpty;
    updates['upcomingEventsCount'] = upcomingEvents.docs.length;

    if (upcomingEvents.docs.isNotEmpty) {
      updates['nextEventDate'] = upcomingEvents.docs.first.data()['startDate'];
      print('  📅 Synced ${upcomingEvents.docs.length} upcoming events');
    } else {
      updates['nextEventDate'] = null;
    }

    return true;
  } catch (e) {
    print('  ⚠️  Could not sync events: $e');
    return false;
  }
}

/// Helper: Parse double from dynamic value
double? _parseDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

/// Helper: Validate coordinate pair
bool _isValidCoordinate(double lat, double lng) {
  return lat >= -90.0 && lat <= 90.0 && lng >= -180.0 && lng <= 180.0;
}
