import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'storage/hybrid_storage_service.dart';

/// Service for managing photo gallery and user-uploaded photos
class PhotoGalleryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final HybridStorageService _storageService = HybridStorageService();

  // Collection references
  CollectionReference get _photosCollection =>
      _firestore.collection('temple_photos');
  CollectionReference get _photoReportsCollection =>
      _firestore.collection('photo_reports');

  /// Upload photos to a temple gallery
  Future<List<String>> uploadTemplePhotos({
    required String templeId,
    required List<File> photos,
    String? caption,
    List<String>? tags,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User must be authenticated to upload photos');
      }

      if (photos.isEmpty) {
        throw Exception('No photos provided');
      }

      if (photos.length > 10) {
        throw Exception('Maximum 10 photos can be uploaded at once');
      }

      final List<String> photoIds = [];

      for (int i = 0; i < photos.length; i++) {
        final file = photos[i];

        // Upload image to storage
        final imageUrl = await _storageService.uploadUserImage(
          imageFile: file,
          userId: user.uid,
        );

        // Create photo document
        final photoData = {
          'templeId': templeId,
          'userId': user.uid,
          'userName': user.displayName ?? 'Anonymous User',
          'userPhotoUrl': user.photoURL,
          'imageUrl': imageUrl,
          'caption': caption,
          'tags': tags ?? [],
          'likes': 0,
          'likedBy': [],
          'isApproved': false, // Requires admin approval
          'isReported': false,
          'isFeatured': false,
          'createdAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
        };

        final docRef = await _photosCollection.add(photoData);
        photoIds.add(docRef.id);
      }

      // Update temple photo count
      await _updateTemplePhotoCount(templeId, photos.length);

      // Update user stats
      await _updateUserPhotoStats(user.uid, photos.length);

      return photoIds;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error uploading temple photos: $e');
      }
      rethrow;
    }
  }

  /// Get photos for a temple
  Future<List<Map<String, dynamic>>> getTemplePhotos(
    String templeId, {
    int limit = 20,
    DocumentSnapshot? lastDocument,
    bool approvedOnly = true,
    String sortBy = 'createdAt',
    bool descending = true,
  }) async {
    try {
      // Simple query on templeId + orderBy to avoid composite index requirement.
      // isApproved and isReported are filtered client-side.
      Query query = _photosCollection
          .where('templeId', isEqualTo: templeId)
          .orderBy(sortBy, descending: descending)
          .limit(limit * 3);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final querySnapshot = await query.get();
      return querySnapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
          .where((data) {
            if (approvedOnly && data['isApproved'] != true) return false;
            if (data['isReported'] == true) return false;
            return true;
          })
          .take(limit)
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting temple photos: $e');
      }
      rethrow;
    }
  }

  /// Watch temple photos stream for real-time updates
  Stream<List<Map<String, dynamic>>> watchTemplePhotos(
    String templeId, {
    int limit = 20,
    bool approvedOnly = true,
    String sortBy = 'createdAt',
    bool descending = true,
  }) {
    try {
      // Use a simple single-field query to avoid requiring a composite index.
      // Additional filters (isApproved, isReported) are applied client-side.
      final query = _photosCollection
          .where('templeId', isEqualTo: templeId)
          .orderBy(sortBy, descending: descending)
          .limit(limit * 3); // fetch extra to account for client-side filtering

      return query.snapshots().map((snapshot) {
        final docs = snapshot.docs
            .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
            .where((data) {
              if (approvedOnly && data['isApproved'] != true) return false;
              if (data['isReported'] == true) return false;
              return true;
            })
            .take(limit)
            .toList();
        return docs;
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error watching temple photos: $e');
      }
      rethrow;
    }
  }

  /// Get user's uploaded photos
  Future<List<Map<String, dynamic>>> getUserPhotos(
    String userId, {
    int limit = 20,
    DocumentSnapshot? lastDocument,
  }) async {
    try {
      Query query = _photosCollection
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final querySnapshot = await query.get();
      return querySnapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting user photos: $e');
      }
      rethrow;
    }
  }

  /// Like a photo
  Future<void> likePhoto(String photoId, String userId) async {
    try {
      final photoDoc = await _photosCollection.doc(photoId).get();
      if (!photoDoc.exists) {
        throw Exception('Photo not found');
      }

      final data = photoDoc.data() as Map<String, dynamic>;
      final likedBy = List<String>.from(data['likedBy'] ?? []);

      if (likedBy.contains(userId)) {
        return; // Already liked
      }

      likedBy.add(userId);

      await _photosCollection.doc(photoId).update({
        'likes': FieldValue.increment(1),
        'likedBy': likedBy,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error liking photo: $e');
      }
      rethrow;
    }
  }

  /// Unlike a photo
  Future<void> unlikePhoto(String photoId, String userId) async {
    try {
      final photoDoc = await _photosCollection.doc(photoId).get();
      if (!photoDoc.exists) {
        throw Exception('Photo not found');
      }

      final data = photoDoc.data() as Map<String, dynamic>;
      final likedBy = List<String>.from(data['likedBy'] ?? []);

      if (!likedBy.contains(userId)) {
        return; // Not liked
      }

      likedBy.remove(userId);

      await _photosCollection.doc(photoId).update({
        'likes': FieldValue.increment(-1),
        'likedBy': likedBy,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error unliking photo: $e');
      }
      rethrow;
    }
  }

  /// Delete a photo
  Future<void> deletePhoto(String photoId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User must be authenticated to delete photos');
      }

      final photoDoc = await _photosCollection.doc(photoId).get();
      if (!photoDoc.exists) {
        throw Exception('Photo not found');
      }

      final data = photoDoc.data() as Map<String, dynamic>;
      final photoUserId = data['userId'] as String;
      final templeId = data['templeId'] as String;
      final imageUrl = data['imageUrl'] as String;

      // Verify ownership
      if (photoUserId != user.uid) {
        throw Exception('Unauthorized to delete this photo');
      }

      // Delete from storage
      await _storageService.deleteTempleImage(imageUrl);

      // Delete from Firestore
      await _photosCollection.doc(photoId).delete();

      // Update temple photo count
      await _updateTemplePhotoCount(templeId, -1);

      // Update user stats
      await _updateUserPhotoStats(user.uid, -1);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error deleting photo: $e');
      }
      rethrow;
    }
  }

  /// Report a photo
  Future<void> reportPhoto({
    required String photoId,
    required String reason,
    String? additionalInfo,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User must be authenticated to report photos');
      }

      final reportData = {
        'photoId': photoId,
        'reportedBy': user.uid,
        'reporterName': user.displayName ?? 'Anonymous User',
        'reason': reason,
        'additionalInfo': additionalInfo,
        'status': 'pending',
        'createdAt': Timestamp.now(),
      };

      await _photoReportsCollection.add(reportData);

      // Mark photo as reported
      await _photosCollection.doc(photoId).update({
        'isReported': true,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error reporting photo: $e');
      }
      rethrow;
    }
  }

  /// Update photo caption
  Future<void> updatePhotoCaption(String photoId, String caption) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User must be authenticated to update photos');
      }

      final photoDoc = await _photosCollection.doc(photoId).get();
      if (!photoDoc.exists) {
        throw Exception('Photo not found');
      }

      final data = photoDoc.data() as Map<String, dynamic>;
      final photoUserId = data['userId'] as String;

      // Verify ownership
      if (photoUserId != user.uid) {
        throw Exception('Unauthorized to update this photo');
      }

      await _photosCollection.doc(photoId).update({
        'caption': caption,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error updating photo caption: $e');
      }
      rethrow;
    }
  }

  /// Update photo tags
  Future<void> updatePhotoTags(String photoId, List<String> tags) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User must be authenticated to update photos');
      }

      final photoDoc = await _photosCollection.doc(photoId).get();
      if (!photoDoc.exists) {
        throw Exception('Photo not found');
      }

      final data = photoDoc.data() as Map<String, dynamic>;
      final photoUserId = data['userId'] as String;

      // Verify ownership
      if (photoUserId != user.uid) {
        throw Exception('Unauthorized to update this photo');
      }

      await _photosCollection.doc(photoId).update({
        'tags': tags,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error updating photo tags: $e');
      }
      rethrow;
    }
  }

  /// Get featured photos for a temple
  Future<List<Map<String, dynamic>>> getFeaturedPhotos(
    String templeId, {
    int limit = 10,
  }) async {
    try {
      final querySnapshot = await _photosCollection
          .where('templeId', isEqualTo: templeId)
          .where('isFeatured', isEqualTo: true)
          .where('isApproved', isEqualTo: true)
          .where('isReported', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return querySnapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting featured photos: $e');
      }
      rethrow;
    }
  }

  /// Search photos by tags
  Future<List<Map<String, dynamic>>> searchPhotosByTags(
    List<String> tags, {
    String? templeId,
    int limit = 20,
  }) async {
    try {
      Query query = _photosCollection
          .where('isApproved', isEqualTo: true)
          .where('isReported', isEqualTo: false);

      if (templeId != null) {
        query = query.where('templeId', isEqualTo: templeId);
      }

      query = query.where('tags', arrayContainsAny: tags).limit(limit);

      final querySnapshot = await query.get();
      return querySnapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error searching photos by tags: $e');
      }
      rethrow;
    }
  }

  /// Get photo statistics for a temple
  Future<Map<String, dynamic>> getPhotoStatistics(String templeId) async {
    try {
      final allPhotos = await _photosCollection
          .where('templeId', isEqualTo: templeId)
          .get();

      final approvedPhotos = allPhotos.docs
          .where((doc) => (doc.data() as Map<String, dynamic>)['isApproved'] == true)
          .length;

      final pendingPhotos = allPhotos.docs
          .where((doc) => (doc.data() as Map<String, dynamic>)['isApproved'] == false)
          .length;

      int totalLikes = 0;
      for (final doc in allPhotos.docs) {
        final data = doc.data() as Map<String, dynamic>;
        totalLikes += (data['likes'] as int?) ?? 0;
      }

      return {
        'totalPhotos': allPhotos.docs.length,
        'approvedPhotos': approvedPhotos,
        'pendingPhotos': pendingPhotos,
        'totalLikes': totalLikes,
        'averageLikesPerPhoto':
            allPhotos.docs.isEmpty ? 0 : totalLikes / allPhotos.docs.length,
      };
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting photo statistics: $e');
      }
      rethrow;
    }
  }

  // Helper Methods

  /// Update temple photo count
  Future<void> _updateTemplePhotoCount(String templeId, int increment) async {
    try {
      await _firestore.collection('temples').doc(templeId).update({
        'totalPhotosShared': FieldValue.increment(increment),
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error updating temple photo count: $e');
      }
    }
  }

  /// Update user photo statistics
  Future<void> _updateUserPhotoStats(String userId, int increment) async {
    try {
      await _firestore.collection('user_stats').doc(userId).set({
        'totalPhotosUploaded': FieldValue.increment(increment),
        'updatedAt': Timestamp.now(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error updating user photo stats: $e');
      }
    }
  }

  // Admin Methods (for photo approval)

  /// Approve a photo (admin only)
  Future<void> approvePhoto(String photoId) async {
    try {
      await _photosCollection.doc(photoId).update({
        'isApproved': true,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error approving photo: $e');
      }
      rethrow;
    }
  }

  /// Reject a photo (admin only)
  Future<void> rejectPhoto(String photoId, String reason) async {
    try {
      final photoDoc = await _photosCollection.doc(photoId).get();
      if (!photoDoc.exists) {
        throw Exception('Photo not found');
      }

      final data = photoDoc.data() as Map<String, dynamic>;
      final imageUrl = data['imageUrl'] as String;
      final templeId = data['templeId'] as String;
      final userId = data['userId'] as String;

      // Delete from storage
      await _storageService.deleteTempleImage(imageUrl);

      // Delete from Firestore
      await _photosCollection.doc(photoId).delete();

      // Update counts
      await _updateTemplePhotoCount(templeId, -1);
      await _updateUserPhotoStats(userId, -1);

      // Log rejection reason
      await _firestore.collection('photo_rejections').add({
        'photoId': photoId,
        'userId': userId,
        'templeId': templeId,
        'reason': reason,
        'rejectedAt': Timestamp.now(),
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error rejecting photo: $e');
      }
      rethrow;
    }
  }

  /// Feature a photo (admin only)
  Future<void> featurePhoto(String photoId, bool featured) async {
    try {
      await _photosCollection.doc(photoId).update({
        'isFeatured': featured,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error featuring photo: $e');
      }
      rethrow;
    }
  }
}
