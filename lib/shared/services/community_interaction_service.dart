import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Service for handling community post interactions (likes, comments, shares)
class CommunityInteractionService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CommunityInteractionService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  /// Toggle like on a post
  Future<bool> toggleLike(String postId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User must be logged in to like posts');
      }

      final postRef = _firestore.collection('community_posts').doc(postId);
      final likeRef = postRef.collection('likes').doc(userId);

      // Check if already liked
      final likeDoc = await likeRef.get();
      final isLiked = likeDoc.exists;

      // Use batch for atomic operation
      final batch = _firestore.batch();

      if (isLiked) {
        // Unlike: remove like document and decrement counter
        batch.delete(likeRef);
        batch.update(postRef, {
          'likesCount': FieldValue.increment(-1),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Like: add like document and increment counter
        batch.set(likeRef, {
          'userId': userId,
          'likedAt': FieldValue.serverTimestamp(),
        });
        batch.update(postRef, {
          'likesCount': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      if (kDebugMode) {
        debugPrint(
          'CommunityInteractionService: ${isLiked ? "Unliked" : "Liked"} post $postId',
        );
      }

      return !isLiked; // Return new like state
    } catch (e) {
      if (kDebugMode) {
        debugPrint('CommunityInteractionService: Error toggling like - $e');
      }
      rethrow;
    }
  }

  /// Check if current user has liked a post
  Future<bool> hasLiked(String postId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return false;

      final likeDoc = await _firestore
          .collection('community_posts')
          .doc(postId)
          .collection('likes')
          .doc(userId)
          .get();

      return likeDoc.exists;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('CommunityInteractionService: Error checking like - $e');
      }
      return false;
    }
  }

  /// Add a comment to a post
  Future<String> addComment(String postId, String commentText) async {
    try {
      final userId = _auth.currentUser?.uid;
      final userName = _auth.currentUser?.displayName ?? 'Anonymous';
      final userPhotoUrl = _auth.currentUser?.photoURL;

      if (userId == null) {
        throw Exception('User must be logged in to comment');
      }

      if (commentText.trim().isEmpty) {
        throw Exception('Comment cannot be empty');
      }

      final postRef = _firestore.collection('community_posts').doc(postId);
      final commentRef = postRef.collection('comments').doc();

      // Use batch for atomic operation
      final batch = _firestore.batch();

      // Add comment
      batch.set(commentRef, {
        'id': commentRef.id,
        'postId': postId,
        'userId': userId,
        'userName': userName,
        'userPhotoUrl': userPhotoUrl,
        'text': commentText.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'likesCount': 0,
      });

      // Increment comment counter
      batch.update(postRef, {
        'commentsCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (kDebugMode) {
        debugPrint(
          'CommunityInteractionService: Added comment to post $postId',
        );
      }

      return commentRef.id;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('CommunityInteractionService: Error adding comment - $e');
      }
      rethrow;
    }
  }

  /// Share a post (increment share counter and optionally create share record)
  Future<void> sharePost(String postId, {String? shareMethod}) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User must be logged in to share posts');
      }

      final postRef = _firestore.collection('community_posts').doc(postId);
      final shareRef = postRef.collection('shares').doc();

      // Use batch for atomic operation
      final batch = _firestore.batch();

      // Record share
      batch.set(shareRef, {
        'id': shareRef.id,
        'userId': userId,
        'sharedAt': FieldValue.serverTimestamp(),
        'shareMethod': shareMethod ?? 'unknown',
      });

      // Increment share counter
      batch.update(postRef, {
        'sharesCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (kDebugMode) {
        debugPrint('CommunityInteractionService: Shared post $postId');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('CommunityInteractionService: Error sharing post - $e');
      }
      rethrow;
    }
  }

  /// Get comments for a post
  Stream<List<Map<String, dynamic>>> getComments(String postId) {
    return _firestore
        .collection('community_posts')
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => doc.data())
            .toList());
  }

  /// Delete a comment (only by comment author or post author)
  Future<void> deleteComment(String postId, String commentId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User must be logged in to delete comments');
      }

      final postRef = _firestore.collection('community_posts').doc(postId);
      final commentRef = postRef.collection('comments').doc(commentId);

      // Check if user is comment author or post author
      final commentDoc = await commentRef.get();
      final postDoc = await postRef.get();

      if (!commentDoc.exists) {
        throw Exception('Comment not found');
      }

      final commentData = commentDoc.data()!;
      final postData = postDoc.data()!;

      if (commentData['userId'] != userId && postData['userId'] != userId) {
        throw Exception('Not authorized to delete this comment');
      }

      // Use batch for atomic operation
      final batch = _firestore.batch();

      batch.delete(commentRef);
      batch.update(postRef, {
        'commentsCount': FieldValue.increment(-1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (kDebugMode) {
        debugPrint(
          'CommunityInteractionService: Deleted comment $commentId from post $postId',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('CommunityInteractionService: Error deleting comment - $e');
      }
      rethrow;
    }
  }
}
