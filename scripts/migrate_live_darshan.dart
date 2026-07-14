import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

/// Migration script for live darshan data
class LiveDarshanMigration {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Run the migration
  Future<void> migrate() async {
    print('Starting live darshan migration...');
    
    try {
      final temples = await _firestore.collection('temples').get();
      int processedCount = 0;
      int errorCount = 0;
      
      for (final doc in temples.docs) {
        try {
          await _migrateTemple(doc);
          processedCount++;
          print('Processed temple: ${doc.id}');
        } catch (e) {
          errorCount++;
          print('Error processing temple ${doc.id}: $e');
        }
      }
      
      print('Migration completed!');
      print('Processed: $processedCount temples');
      print('Errors: $errorCount temples');
    } catch (e) {
      print('Migration failed: $e');
      rethrow;
    }
  }
  
  /// Migrate individual temple
  Future<void> _migrateTemple(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return;
    
    // Check if migration is needed
    if (data.containsKey('liveDarshan')) {
      print('Temple ${doc.id} already has liveDarshan data');
      return;
    }
    
    // Create default live darshan structure
    final liveDarshanData = {
      'youtubeChannelUrl': null,
      'youtubeChannelId': null,
      'currentLiveVideoId': null,
      'isCurrentlyLive': false,
      'schedule': [],
      'streamQuality': null,
      'lastStreamDate': null,
      'streamMetadata': null,
      'isConfiguredByAdmin': false,
      'currentViewerCount': null,
    };
    
    // Update the document
    await doc.reference.update({
      'liveDarshan': liveDarshanData,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

/// Main function to run the migration
Future<void> main() async {
  try {
    // Initialize Firebase
    await Firebase.initializeApp();
    
    final migration = LiveDarshanMigration();
    await migration.migrate();
    
    print('Migration completed successfully!');
    exit(0);
  } catch (e) {
    print('Migration failed: $e');
    exit(1);
  }
}