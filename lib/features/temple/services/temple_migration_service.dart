import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Service for migrating temple data to fix image visibility issues
class TempleMigrationService {
  static final TempleMigrationService _instance =
      TempleMigrationService._internal();
  factory TempleMigrationService() => _instance;
  TempleMigrationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Migrate temples to ensure coverPhotoUrl is also in images array
  /// This fixes the issue where admin can see images but users cannot
  Future<MigrationResult> migrateTempleImages({
    Function(String status)? onStatusUpdate,
    Function(double progress)? onProgress,
  }) async {
    try {
      onStatusUpdate?.call('Fetching temples...');

      // Get all temples
      final templesSnapshot = await _firestore.collection('temples').get();
      final totalTemples = templesSnapshot.docs.length;

      if (totalTemples == 0) {
        return MigrationResult(
          success: true,
          totalProcessed: 0,
          updated: 0,
          skipped: 0,
          errors: 0,
        );
      }

      int updated = 0;
      int skipped = 0;
      int errors = 0;

      onStatusUpdate?.call('Migrating $totalTemples temples...');

      for (int i = 0; i < templesSnapshot.docs.length; i++) {
        final doc = templesSnapshot.docs[i];
        final data = doc.data();

        try {
          // Check if temple has coverPhotoUrl but images is empty or missing
          final coverPhotoUrl = data['coverPhotoUrl'] as String?;
          final images = data['images'] as List?;

          if (coverPhotoUrl != null &&
              coverPhotoUrl.isNotEmpty &&
              (images == null || images.isEmpty)) {
            // Update the temple to add coverPhotoUrl to images array
            await doc.reference.update({
              'images': [coverPhotoUrl],
            });

            updated++;
            if (kDebugMode) {
              debugPrint(
                'TempleMigrationService: Updated temple ${doc.id} with image URL',
              );
            }
          } else {
            skipped++;
          }
        } catch (e) {
          errors++;
          if (kDebugMode) {
            debugPrint(
              'TempleMigrationService: Error migrating temple ${doc.id}: $e',
            );
          }
        }

        // Update progress
        final progress = (i + 1) / totalTemples;
        onProgress?.call(progress);
        onStatusUpdate?.call(
          'Processed ${i + 1}/$totalTemples temples (Updated: $updated, Skipped: $skipped, Errors: $errors)',
        );
      }

      onProgress?.call(1.0);
      onStatusUpdate?.call('Migration completed!');

      return MigrationResult(
        success: true,
        totalProcessed: totalTemples,
        updated: updated,
        skipped: skipped,
        errors: errors,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('TempleMigrationService: Migration failed: $e');
      }
      return MigrationResult(
        success: false,
        totalProcessed: 0,
        updated: 0,
        skipped: 0,
        errors: 1,
        errorMessage: e.toString(),
      );
    }
  }

  /// Check how many temples need migration
  Future<int> countTemplesNeedingMigration() async {
    try {
      final templesSnapshot = await _firestore.collection('temples').get();
      int count = 0;

      for (final doc in templesSnapshot.docs) {
        final data = doc.data();
        final coverPhotoUrl = data['coverPhotoUrl'] as String?;
        final images = data['images'] as List?;

        if (coverPhotoUrl != null &&
            coverPhotoUrl.isNotEmpty &&
            (images == null || images.isEmpty)) {
          count++;
        }
      }

      return count;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('TempleMigrationService: Error counting temples: $e');
      }
      return 0;
    }
  }
}

/// Result of temple migration operation
class MigrationResult {
  final bool success;
  final int totalProcessed;
  final int updated;
  final int skipped;
  final int errors;
  final String? errorMessage;

  MigrationResult({
    required this.success,
    required this.totalProcessed,
    required this.updated,
    required this.skipped,
    required this.errors,
    this.errorMessage,
  });

  @override
  String toString() {
    if (!success) {
      return 'Migration failed: $errorMessage';
    }
    return 'Migration completed: $totalProcessed processed, $updated updated, $skipped skipped, $errors errors';
  }
}
