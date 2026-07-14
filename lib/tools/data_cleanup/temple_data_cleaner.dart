import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Utility for cleaning up duplicate and invalid temple entries
class TempleDataCleaner {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Finds and removes duplicate temple entries
  Future<CleanupResult> findAndRemoveDuplicates() async {
    final result = CleanupResult();

    try {
      final temples = await _getAllTemples();
      final duplicateGroups = _findDuplicateGroups(temples);

      for (final group in duplicateGroups) {
        await _processDuplicateGroup(group, result);
      }

      result.success = true;
      result.completedAt = DateTime.now();
    } catch (e) {
      result.success = false;
      result.error = e.toString();
    }

    return result;
  }

  /// Removes invalid temple entries based on validation criteria
  Future<CleanupResult> removeInvalidEntries() async {
    final result = CleanupResult();

    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('temples')
          .get();

      for (final doc in snapshot.docs) {
        final docData = doc.data();
        if (docData == null || docData is! Map<String, dynamic>) {
          if (kDebugMode) {
            debugPrint(
              'TempleDataCleaner: Skipping document ${doc.id} with invalid data',
            );
          }
          continue;
        }
        final data = docData;

        if (_isInvalidEntry(data)) {
          await _removeInvalidEntry(doc.id, data, result);
        }
      }

      result.success = true;
      result.completedAt = DateTime.now();
    } catch (e) {
      result.success = false;
      result.error = e.toString();
    }

    return result;
  }

  /// Cleans up orphaned data and broken references
  Future<CleanupResult> cleanupOrphanedData() async {
    final result = CleanupResult();

    try {
      // Clean up orphaned images
      await _cleanupOrphanedImages(result);

      // Clean up broken event references
      await _cleanupBrokenEventReferences(result);

      // Clean up invalid user references
      await _cleanupInvalidUserReferences(result);

      result.success = true;
      result.completedAt = DateTime.now();
    } catch (e) {
      result.success = false;
      result.error = e.toString();
    }

    return result;
  }

  Future<List<TempleData>> _getAllTemples() async {
    final QuerySnapshot snapshot = await _firestore.collection('temples').get();

    return snapshot.docs
        .where((doc) {
          final data = doc.data();
          return data != null && data is Map<String, dynamic>;
        })
        .map(
          (doc) =>
              TempleData(id: doc.id, data: doc.data() as Map<String, dynamic>),
        )
        .toList();
  }

  List<List<TempleData>> _findDuplicateGroups(List<TempleData> temples) {
    final duplicateGroups = <List<TempleData>>[];
    final processed = <String>{};

    for (int i = 0; i < temples.length; i++) {
      if (processed.contains(temples[i].id)) continue;

      final duplicates = <TempleData>[temples[i]];
      processed.add(temples[i].id);

      for (int j = i + 1; j < temples.length; j++) {
        if (processed.contains(temples[j].id)) continue;

        if (_areTemplesIdentical(temples[i], temples[j])) {
          duplicates.add(temples[j]);
          processed.add(temples[j].id);
        }
      }

      if (duplicates.length > 1) {
        duplicateGroups.add(duplicates);
      }
    }

    return duplicateGroups;
  }

  bool _areTemplesIdentical(TempleData temple1, TempleData temple2) {
    // Check name similarity
    final name1 = (temple1.data['name'] as String? ?? '').toLowerCase().trim();
    final name2 = (temple2.data['name'] as String? ?? '').toLowerCase().trim();

    if (name1 == name2 && name1.isNotEmpty) return true;

    // Check location proximity (within 100 meters)
    final lat1 = temple1.data['latitude']?.toDouble();
    final lng1 = temple1.data['longitude']?.toDouble();
    final lat2 = temple2.data['latitude']?.toDouble();
    final lng2 = temple2.data['longitude']?.toDouble();

    if (lat1 != null && lng1 != null && lat2 != null && lng2 != null) {
      final distance = _calculateDistance(lat1, lng1, lat2, lng2);
      if (distance < 0.1) {
        // Less than 100 meters
        // Also check name similarity for nearby temples
        return _calculateStringSimilarity(name1, name2) > 0.8;
      }
    }

    return false;
  }

  double _calculateDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const double earthRadius = 6371; // Earth's radius in kilometers

    final dLat = _degreesToRadians(lat2 - lat1);
    final dLng = _degreesToRadians(lng2 - lng1);

    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLng / 2) *
            sin(dLng / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (pi / 180);
  }

  double _calculateStringSimilarity(String str1, String str2) {
    if (str1.isEmpty && str2.isEmpty) return 1.0;
    if (str1.isEmpty || str2.isEmpty) return 0.0;

    final longer = str1.length > str2.length ? str1 : str2;
    final shorter = str1.length > str2.length ? str2 : str1;

    if (longer.length == 0) return 1.0;

    final editDistance = _calculateLevenshteinDistance(longer, shorter);
    return (longer.length - editDistance) / longer.length;
  }

  int _calculateLevenshteinDistance(String str1, String str2) {
    final matrix = List.generate(
      str1.length + 1,
      (i) => List.filled(str2.length + 1, 0),
    );

    for (int i = 0; i <= str1.length; i++) {
      matrix[i][0] = i;
    }

    for (int j = 0; j <= str2.length; j++) {
      matrix[0][j] = j;
    }

    for (int i = 1; i <= str1.length; i++) {
      for (int j = 1; j <= str2.length; j++) {
        final cost = str1[i - 1] == str2[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1, // deletion
          matrix[i][j - 1] + 1, // insertion
          matrix[i - 1][j - 1] + cost, // substitution
        ].reduce(min);
      }
    }

    return matrix[str1.length][str2.length];
  }

  Future<void> _processDuplicateGroup(
    List<TempleData> duplicates,
    CleanupResult result,
  ) async {
    // Keep the temple with the most complete data
    final bestTemple = _selectBestTemple(duplicates);

    for (final temple in duplicates) {
      if (temple.id != bestTemple.id) {
        await _firestore.collection('temples').doc(temple.id).delete();
        result.duplicatesRemoved++;
        result.removedTempleIds.add(temple.id);
      }
    }
  }

  TempleData _selectBestTemple(List<TempleData> duplicates) {
    return duplicates.reduce((best, current) {
      final bestScore = _calculateCompletenessScore(best.data);
      final currentScore = _calculateCompletenessScore(current.data);
      return currentScore > bestScore ? current : best;
    });
  }

  int _calculateCompletenessScore(Map<String, dynamic> data) {
    int score = 0;

    // Basic fields
    if (data['name']?.toString().isNotEmpty == true) score += 10;
    if (data['description']?.toString().isNotEmpty == true) score += 5;
    if (data['latitude'] != null && data['longitude'] != null) score += 10;

    // Gujarat-specific fields
    if (data['nameGujarati']?.toString().isNotEmpty == true) score += 5;
    if (data['nameHindi']?.toString().isNotEmpty == true) score += 5;
    if (data['district']?.toString().isNotEmpty == true) score += 3;
    if (data['taluka']?.toString().isNotEmpty == true) score += 2;

    // Media and additional data
    if (data['images'] is List && (data['images'] as List).isNotEmpty)
      score += 8;
    if (data['phoneNumber']?.toString().isNotEmpty == true) score += 3;
    if (data['website']?.toString().isNotEmpty == true) score += 2;

    return score;
  }

  bool _isInvalidEntry(Map<String, dynamic> data) {
    // Check for completely empty entries
    if (data.isEmpty) return true;

    // Check for entries without name
    final name = data['name']?.toString().trim();
    if (name == null || name.isEmpty) return true;

    // Check for entries with invalid coordinates
    final lat = data['latitude']?.toDouble();
    final lng = data['longitude']?.toDouble();

    if (lat != null && lng != null) {
      // Check if coordinates are obviously invalid
      if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return true;

      // Check if coordinates are null island (0,0)
      if (lat == 0 && lng == 0) return true;
    }

    // Check for test entries
    if (name.toLowerCase().contains('test') ||
        name.toLowerCase().contains('dummy') ||
        name.toLowerCase().contains('sample')) {
      return true;
    }

    return false;
  }

  Future<void> _removeInvalidEntry(
    String templeId,
    Map<String, dynamic> data,
    CleanupResult result,
  ) async {
    await _firestore.collection('temples').doc(templeId).delete();
    result.invalidEntriesRemoved++;
    result.removedTempleIds.add(templeId);
  }

  Future<void> _cleanupOrphanedImages(CleanupResult result) async {
    try {
      debugPrint('Starting orphaned image cleanup...');

      // Get all image URLs from temples collection
      final templesSnapshot = await _firestore.collection('temples').get();
      final usedImageUrls = <String>{};

      for (final doc in templesSnapshot.docs) {
        final data = doc.data();

        // Collect image URLs from various fields
        if (data['coverPhotoUrl'] != null) {
          usedImageUrls.add(data['coverPhotoUrl'] as String);
        }

        if (data['images'] is List) {
          final images = data['images'] as List;
          for (final imageUrl in images) {
            if (imageUrl is String) {
              usedImageUrls.add(imageUrl);
            }
          }
        }

        if (data['galleryImages'] is List) {
          final galleryImages = data['galleryImages'] as List;
          for (final imageUrl in galleryImages) {
            if (imageUrl is String) {
              usedImageUrls.add(imageUrl);
            }
          }
        }
      }

      // Note: Firebase Storage cleanup would require additional permissions
      // For now, we'll just count the orphaned images
      result.orphanedImagesRemoved = 0; // Would be actual count after cleanup

      debugPrint(
        'Orphaned image cleanup completed. Found ${usedImageUrls.length} used images.',
      );
    } catch (e) {
      debugPrint('Error during orphaned image cleanup: $e');
      result.orphanedImagesRemoved = 0;
    }
  }

  Future<void> _cleanupBrokenEventReferences(CleanupResult result) async {
    // Clean up events that reference non-existent temples
    final eventsSnapshot = await _firestore.collection('events').get();

    for (final doc in eventsSnapshot.docs) {
      final data = doc.data();
      final templeId = data['templeId'] as String?;

      if (templeId != null) {
        final templeExists = await _firestore
            .collection('temples')
            .doc(templeId)
            .get()
            .then((doc) => doc.exists);

        if (!templeExists) {
          await _firestore.collection('events').doc(doc.id).delete();
          result.brokenReferencesFixed++;
        }
      }
    }
  }

  Future<void> _cleanupInvalidUserReferences(CleanupResult result) async {
    try {
      debugPrint('Starting invalid user references cleanup...');
      int fixedCount = 0;

      // Clean up reviews with invalid user references
      final reviewsSnapshot = await _firestore.collection('reviews').get();
      for (final doc in reviewsSnapshot.docs) {
        final data = doc.data();
        final userId = data['userId'] as String?;

        if (userId != null) {
          // Check if user exists in user_preferences (more accessible than users collection)
          final userExists = await _firestore
              .collection('user_preferences')
              .doc(userId)
              .get()
              .then((doc) => doc.exists);

          if (!userExists) {
            // Mark review as anonymous or delete it
            await doc.reference.update({
              'userId': 'anonymous',
              'userName': 'Anonymous User',
              'userPhotoUrl': null,
              'updatedAt': FieldValue.serverTimestamp(),
            });
            fixedCount++;
          }
        }
      }

      // NOTE: Bookings are stored in Supabase (public.bookings), not Firestore.
      // Orphaned booking cleanup is handled by Supabase RLS and cascade deletes.

      // Clean up donations with invalid user references
      final donationsSnapshot = await _firestore.collection('donations').get();
      for (final doc in donationsSnapshot.docs) {
        final data = doc.data();
        final userId = data['userId'] as String?;

        if (userId != null) {
          final userExists = await _firestore
              .collection('user_preferences')
              .doc(userId)
              .get()
              .then((doc) => doc.exists);

          if (!userExists) {
            // Mark donation as anonymous but keep the record for accounting
            await doc.reference.update({
              'userId': 'anonymous',
              'updatedAt': FieldValue.serverTimestamp(),
            });
            fixedCount++;
          }
        }
      }

      result.invalidUserReferencesFixed = fixedCount;
      debugPrint(
        'Invalid user references cleanup completed. Fixed $fixedCount references.',
      );
    } catch (e) {
      debugPrint('Error during invalid user references cleanup: $e');
      result.invalidUserReferencesFixed = 0;
    }
  }
}

/// Data structure for temple information during cleanup
class TempleData {
  final String id;
  final Map<String, dynamic> data;

  TempleData({required this.id, required this.data});
}

/// Result of cleanup operations
class CleanupResult {
  bool success = false;
  int duplicatesRemoved = 0;
  int invalidEntriesRemoved = 0;
  int orphanedImagesRemoved = 0;
  int brokenReferencesFixed = 0;
  int invalidUserReferencesFixed = 0;
  List<String> removedTempleIds = [];
  String? error;
  DateTime? completedAt;

  Map<String, dynamic> toMap() {
    return {
      'success': success,
      'duplicatesRemoved': duplicatesRemoved,
      'invalidEntriesRemoved': invalidEntriesRemoved,
      'orphanedImagesRemoved': orphanedImagesRemoved,
      'brokenReferencesFixed': brokenReferencesFixed,
      'invalidUserReferencesFixed': invalidUserReferencesFixed,
      'removedTempleIds': removedTempleIds,
      'error': error,
      'completedAt': completedAt?.toIso8601String(),
    };
  }
}
