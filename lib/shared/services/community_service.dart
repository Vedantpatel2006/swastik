import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/index.dart';
import 'storage/hybrid_storage_service.dart';

/// Service for managing community features including reviews, posts, and social interactions
class CommunityService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final HybridStorageService _storageService = HybridStorageService();

  // Collection references
  CollectionReference get _reviewsCollection =>
      _firestore.collection('reviews');
  CollectionReference get _postsCollection =>
      _firestore.collection('community_posts');
  CollectionReference get _commentsCollection =>
      _firestore.collection('community_comments');
  CollectionReference get _reportsCollection =>
      _firestore.collection('content_reports');

  /// Get temple reviews with pagination
  Future<List<Review>> getTempleReviews(
    String templeId, {
    int limit = 20,
    DocumentSnapshot? lastDocument,
    String sortBy = 'reviewDate',
    bool descending = true,
  }) async {
    try {
      Query query = _reviewsCollection
          .where('templeId', isEqualTo: templeId)
          .where('isModerated', isEqualTo: false)
          .orderBy(sortBy, descending: descending)
          .limit(limit);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final querySnapshot = await query.get();
      return querySnapshot.docs
          .map((doc) => Review.fromFirestore(doc))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Get temple reviews stream for real-time updates
  Stream<List<Review>> watchTempleReviews(
    String templeId, {
    int limit = 20,
    String sortBy = 'reviewDate',
    bool descending = true,
  }) {
    try {
      return _reviewsCollection
          .where('templeId', isEqualTo: templeId)
          .where('isModerated', isEqualTo: false)
          .orderBy(sortBy, descending: descending)
          .limit(limit)
          .snapshots()
          .map(
            (snapshot) =>
                snapshot.docs.map((doc) => Review.fromFirestore(doc)).toList(),
          );
    } catch (e) {
      rethrow;
    }
  }

  /// Submit a new review
  Future<Review> submitReview(Review review) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User must be authenticated to submit reviews');
      }

      // Validate review
      if (!review.isValid()) {
        throw Exception('Invalid review data');
      }

      // Check if user has already reviewed this temple
      final existingReviews = await _reviewsCollection
          .where('templeId', isEqualTo: review.templeId)
          .where('userId', isEqualTo: user.uid)
          .get();

      if (existingReviews.docs.isNotEmpty) {
        throw Exception('You have already reviewed this temple');
      }

      // Create review with user info
      final reviewData = review.copyWith(
        userId: user.uid,
        userName: user.displayName ?? 'Anonymous User',
        userPhotoUrl: user.photoURL,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final docRef = await _reviewsCollection.add(reviewData.toJson());
      final savedReview = reviewData.copyWith(id: docRef.id);

      // Update temple rating statistics
      await _updateTempleRatingStats(review.templeId);

      // Update user stats
      await _updateUserReviewStats(user.uid);

      return savedReview;
    } catch (e) {
      rethrow;
    }
  }

  /// Update an existing review
  Future<Review> updateReview(Review review) async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.uid != review.userId) {
        throw Exception('Unauthorized to update this review');
      }

      if (!review.isValid()) {
        throw Exception('Invalid review data');
      }

      final updatedReview = review.copyWith(updatedAt: DateTime.now());
      await _reviewsCollection.doc(review.id).update(updatedReview.toJson());

      // Update temple rating statistics
      await _updateTempleRatingStats(review.templeId);

      return updatedReview;
    } catch (e) {
      rethrow;
    }
  }

  /// Delete a review
  Future<void> deleteReview(String reviewId, String templeId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User must be authenticated to delete reviews');
      }

      // Verify ownership
      final reviewDoc = await _reviewsCollection.doc(reviewId).get();
      if (!reviewDoc.exists) {
        throw Exception('Review not found');
      }

      final review = Review.fromFirestore(reviewDoc);
      if (review.userId != user.uid) {
        throw Exception('Unauthorized to delete this review');
      }

      await _reviewsCollection.doc(reviewId).delete();

      // Update temple rating statistics
      await _updateTempleRatingStats(templeId);

      // Update user stats
      await _updateUserReviewStats(user.uid, decrement: true);
    } catch (e) {
      rethrow;
    }
  }

  /// Mark review as helpful
  Future<void> markReviewHelpful(String reviewId, String userId) async {
    try {
      final reviewDoc = await _reviewsCollection.doc(reviewId).get();
      if (!reviewDoc.exists) {
        throw Exception('Review not found');
      }

      final review = Review.fromFirestore(reviewDoc);
      final updatedReview = review.markAsHelpful(userId);

      await _reviewsCollection.doc(reviewId).update(updatedReview.toJson());
    } catch (e) {
      rethrow;
    }
  }

  /// Remove helpful mark from review
  Future<void> removeReviewHelpful(String reviewId, String userId) async {
    try {
      final reviewDoc = await _reviewsCollection.doc(reviewId).get();
      if (!reviewDoc.exists) {
        throw Exception('Review not found');
      }

      final review = Review.fromFirestore(reviewDoc);
      final updatedReview = review.removeHelpful(userId);

      await _reviewsCollection.doc(reviewId).update(updatedReview.toJson());
    } catch (e) {
      rethrow;
    }
  }

  /// Get user's reviews
  Future<List<Review>> getUserReviews(String userId) async {
    try {
      final querySnapshot = await _reviewsCollection
          .where('userId', isEqualTo: userId)
          .orderBy('reviewDate', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => Review.fromFirestore(doc))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  // Community Posts Methods

  /// Get community posts with pagination
  Future<List<CommunityPost>> getCommunityPosts({
    int limit = 20,
    DocumentSnapshot? lastDocument,
    String? templeId,
    CommunityPostType? type,
    String sortBy = 'createdAt',
    bool descending = true,
  }) async {
    try {
      Query query = _postsCollection
          .where('isModerated', isEqualTo: false)
          .where('isPublic', isEqualTo: true);

      if (templeId != null) {
        query = query.where('templeId', isEqualTo: templeId);
      }

      if (type != null) {
        query = query.where('type', isEqualTo: type.name);
      }

      query = query.orderBy(sortBy, descending: descending).limit(limit);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final querySnapshot = await query.get();
      return querySnapshot.docs
          .map((doc) => CommunityPost.fromFirestore(doc))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Get community posts stream for real-time updates
  Stream<List<CommunityPost>> watchCommunityPosts({
    int limit = 20,
    String? templeId,
    CommunityPostType? type,
    String sortBy = 'createdAt',
    bool descending = true,
  }) {
    try {
      Query query = _postsCollection
          .where('isModerated', isEqualTo: false)
          .where('isPublic', isEqualTo: true);

      if (templeId != null) {
        query = query.where('templeId', isEqualTo: templeId);
      }

      if (type != null) {
        query = query.where('type', isEqualTo: type.name);
      }

      query = query.orderBy(sortBy, descending: descending).limit(limit);

      return query.snapshots().map(
        (snapshot) => snapshot.docs
            .map((doc) => CommunityPost.fromFirestore(doc))
            .toList(),
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Create a new community post
  Future<CommunityPost> createPost(CommunityPost post) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User must be authenticated to create posts');
      }

      if (!post.isValid()) {
        throw Exception('Invalid post data');
      }

      // Create post with user info
      final postData = post.copyWith(
        userId: user.uid,
        userName: user.displayName ?? 'Anonymous User',
        userPhotoUrl: user.photoURL,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final docRef = await _postsCollection.add(postData.toJson());
      final savedPost = postData.copyWith(id: docRef.id);

      // Update user stats
      await _updateUserPostStats(user.uid);

      return savedPost;
    } catch (e) {
      rethrow;
    }
  }

  /// Update an existing post
  Future<CommunityPost> updatePost(CommunityPost post) async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.uid != post.userId) {
        throw Exception('Unauthorized to update this post');
      }

      if (!post.isValid()) {
        throw Exception('Invalid post data');
      }

      final updatedPost = post.copyWith(updatedAt: DateTime.now());
      await _postsCollection.doc(post.id).update(updatedPost.toJson());

      return updatedPost;
    } catch (e) {
      rethrow;
    }
  }

  /// Delete a post
  Future<void> deletePost(String postId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User must be authenticated to delete posts');
      }

      // Verify ownership
      final postDoc = await _postsCollection.doc(postId).get();
      if (!postDoc.exists) {
        throw Exception('Post not found');
      }

      final post = CommunityPost.fromFirestore(postDoc);
      if (post.userId != user.uid) {
        throw Exception('Unauthorized to delete this post');
      }

      // Delete associated comments
      final comments = await _commentsCollection
          .where('postId', isEqualTo: postId)
          .get();

      final batch = _firestore.batch();
      for (final comment in comments.docs) {
        batch.delete(comment.reference);
      }

      // Delete the post
      batch.delete(_postsCollection.doc(postId));
      await batch.commit();

      // Update user stats
      await _updateUserPostStats(user.uid, decrement: true);
    } catch (e) {
      rethrow;
    }
  }

  /// Like a post — atomic arrayUnion + increment
  Future<void> likePost(String postId, String userId) async {
    try {
      await _postsCollection.doc(postId).update({
        'likedByUserIds': FieldValue.arrayUnion([userId]),
        'likesCount': FieldValue.increment(1),
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      rethrow;
    }
  }

  /// Unlike a post — atomic arrayRemove + decrement
  Future<void> unlikePost(String postId, String userId) async {
    try {
      await _postsCollection.doc(postId).update({
        'likedByUserIds': FieldValue.arrayRemove([userId]),
        'likesCount': FieldValue.increment(-1),
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      rethrow;
    }
  }

  /// Share a post — atomic increment
  Future<void> sharePost(String postId) async {
    try {
      await _postsCollection.doc(postId).update({
        'sharesCount': FieldValue.increment(1),
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      rethrow;
    }
  }

  /// Get user's posts
  Future<List<CommunityPost>> getUserPosts(String userId) async {
    try {
      final querySnapshot = await _postsCollection
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => CommunityPost.fromFirestore(doc))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  // Comments Methods

  /// Get post comments with pagination
  Future<List<CommunityComment>> getPostComments(
    String postId, {
    int limit = 20,
    DocumentSnapshot? lastDocument,
    String sortBy = 'createdAt',
    bool descending = false,
  }) async {
    try {
      Query query = _commentsCollection
          .where('postId', isEqualTo: postId)
          .where('isModerated', isEqualTo: false)
          .where('parentCommentId', isNull: true) // Only top-level comments
          .orderBy(sortBy, descending: descending)
          .limit(limit);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final querySnapshot = await query.get();
      return querySnapshot.docs
          .map((doc) => CommunityComment.fromFirestore(doc))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Get comment replies
  Future<List<CommunityComment>> getCommentReplies(
    String parentCommentId,
  ) async {
    try {
      final querySnapshot = await _commentsCollection
          .where('parentCommentId', isEqualTo: parentCommentId)
          .where('isModerated', isEqualTo: false)
          .orderBy('createdAt', descending: false)
          .get();

      return querySnapshot.docs
          .map((doc) => CommunityComment.fromFirestore(doc))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Watch post comments stream
  Stream<List<CommunityComment>> watchPostComments(
    String postId, {
    int limit = 20,
    String sortBy = 'createdAt',
    bool descending = false,
  }) {
    try {
      return _commentsCollection
          .where('postId', isEqualTo: postId)
          .where('isModerated', isEqualTo: false)
          .where('parentCommentId', isNull: true)
          .orderBy(sortBy, descending: descending)
          .limit(limit)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => CommunityComment.fromFirestore(doc))
                .toList(),
          );
    } catch (e) {
      rethrow;
    }
  }

  /// Add a comment to a post
  Future<CommunityComment> addComment(CommunityComment comment) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User must be authenticated to add comments');
      }

      if (!comment.isValid()) {
        throw Exception('Invalid comment data');
      }

      // Create comment with user info
      final commentData = comment.copyWith(
        userId: user.uid,
        userName: user.displayName ?? 'Anonymous User',
        userPhotoUrl: user.photoURL,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final docRef = await _commentsCollection.add(commentData.toJson());
      final savedComment = commentData.copyWith(id: docRef.id);

      // Update post comment count
      await _updatePostCommentCount(comment.postId, increment: true);

      // If this is a reply, update parent comment reply count
      if (comment.parentCommentId != null) {
        await _updateCommentReplyCount(
          comment.parentCommentId!,
          increment: true,
        );
      }

      return savedComment;
    } catch (e) {
      rethrow;
    }
  }

  /// Convenience method to add a comment with just postId and content
  /// Creates a CommunityComment object internally
  Future<CommunityComment> addCommentSimple({
    required String postId,
    required String content,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User must be authenticated to add comments');
    }

    final comment = CommunityComment(
      id: '', // Will be generated by Firestore
      postId: postId,
      userId: user.uid,
      userName: user.displayName ?? 'Anonymous User',
      userPhotoUrl: user.photoURL,
      content: content,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      likesCount: 0,
    );

    return addComment(comment);
  }

  /// Update a comment
  Future<CommunityComment> updateComment(CommunityComment comment) async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.uid != comment.userId) {
        throw Exception('Unauthorized to update this comment');
      }

      if (!comment.isValid()) {
        throw Exception('Invalid comment data');
      }

      final updatedComment = comment.copyWith(updatedAt: DateTime.now());
      await _commentsCollection.doc(comment.id).update(updatedComment.toJson());

      return updatedComment;
    } catch (e) {
      rethrow;
    }
  }

  /// Delete a comment
  Future<void> deleteComment(String commentId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User must be authenticated to delete comments');
      }

      // Verify ownership
      final commentDoc = await _commentsCollection.doc(commentId).get();
      if (!commentDoc.exists) {
        throw Exception('Comment not found');
      }

      final comment = CommunityComment.fromFirestore(commentDoc);
      if (comment.userId != user.uid) {
        throw Exception('Unauthorized to delete this comment');
      }

      // Delete replies if this is a parent comment
      if (!comment.isReply) {
        final replies = await _commentsCollection
            .where('parentCommentId', isEqualTo: commentId)
            .get();

        final batch = _firestore.batch();
        for (final reply in replies.docs) {
          batch.delete(reply.reference);
        }
        await batch.commit();
      }

      // Delete the comment
      await _commentsCollection.doc(commentId).delete();

      // Update post comment count
      await _updatePostCommentCount(comment.postId, increment: false);

      // If this is a reply, update parent comment reply count
      if (comment.parentCommentId != null) {
        await _updateCommentReplyCount(
          comment.parentCommentId!,
          increment: false,
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Like a comment
  Future<void> likeComment(String commentId, String userId) async {
    try {
      final commentDoc = await _commentsCollection.doc(commentId).get();
      if (!commentDoc.exists) {
        throw Exception('Comment not found');
      }

      final comment = CommunityComment.fromFirestore(commentDoc);
      final updatedComment = comment.like(userId);

      await _commentsCollection.doc(commentId).update(updatedComment.toJson());
    } catch (e) {
      rethrow;
    }
  }

  /// Unlike a comment
  Future<void> unlikeComment(String commentId, String userId) async {
    try {
      final commentDoc = await _commentsCollection.doc(commentId).get();
      if (!commentDoc.exists) {
        throw Exception('Comment not found');
      }

      final comment = CommunityComment.fromFirestore(commentDoc);
      final updatedComment = comment.unlike(userId);

      await _commentsCollection.doc(commentId).update(updatedComment.toJson());
    } catch (e) {
      rethrow;
    }
  }

  // Image Upload Methods

  /// Upload images for posts or reviews
  Future<List<String>> uploadImages(List<File> images, String userId) async {
    try {
      final List<String> imageUrls = [];

      for (int i = 0; i < images.length; i++) {
        final file = images[i];

        // Use hybrid storage service to upload user images
        final imageUrl = await _storageService.uploadUserImage(
          imageFile: file,
          userId: userId,
        );

        imageUrls.add(imageUrl);
      }

      return imageUrls;
    } catch (e) {
      rethrow;
    }
  }

  /// Delete uploaded images
  Future<void> deleteImages(List<String> imageUrls) async {
    try {
      for (final url in imageUrls) {
        await _storageService.deleteTempleImage(url); // Works for any image URL
      }
    } catch (e) {
      // Log error but don't throw - image deletion is not critical
      print('Image deletion failed: $e');
    }
  }

  // Content Moderation Methods

  /// Report content for moderation
  Future<void> reportContent({
    required String contentId,
    required String contentType, // 'review', 'post', 'comment'
    required String reason,
    String? additionalInfo,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User must be authenticated to report content');
      }

      final reportData = {
        'contentId': contentId,
        'contentType': contentType,
        'reportedBy': user.uid,
        'reporterName': user.displayName ?? 'Anonymous User',
        'reason': reason,
        'additionalInfo': additionalInfo,
        'status': 'pending',
        'createdAt': Timestamp.now(),
      };

      await _reportsCollection.add(reportData);

      // Mark content as reported
      CollectionReference contentCollection;
      switch (contentType) {
        case 'review':
          contentCollection = _reviewsCollection;
          break;
        case 'post':
          contentCollection = _postsCollection;
          break;
        case 'comment':
          contentCollection = _commentsCollection;
          break;
        default:
          throw Exception('Invalid content type');
      }

      await contentCollection.doc(contentId).update({
        'isReported': true,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      rethrow;
    }
  }

  // Privacy Control Methods

  /// Update user privacy settings
  Future<void> updatePrivacySettings({
    required String userId,
    required bool showProfile,
    required bool showPosts,
    required bool allowMessages,
  }) async {
    try {
      await _firestore.collection('user_privacy').doc(userId).set({
        'showProfile': showProfile,
        'showPosts': showPosts,
        'allowMessages': allowMessages,
        'updatedAt': Timestamp.now(),
      }, SetOptions(merge: true));
    } catch (e) {
      rethrow;
    }
  }

  /// Get user privacy settings
  Future<Map<String, bool>> getUserPrivacySettings(String userId) async {
    try {
      final doc = await _firestore.collection('user_privacy').doc(userId).get();

      if (!doc.exists) {
        // Return default privacy settings
        return {'showProfile': true, 'showPosts': true, 'allowMessages': true};
      }

      final data = doc.data() ?? {};
      return {
        'showProfile': data['showProfile'] as bool? ?? true,
        'showPosts': data['showPosts'] as bool? ?? true,
        'allowMessages': data['allowMessages'] as bool? ?? true,
      };
    } catch (e) {
      rethrow;
    }
  }

  // Helper Methods

  /// Update temple rating statistics
  Future<void> _updateTempleRatingStats(String templeId) async {
    try {
      final reviews = await _reviewsCollection
          .where('templeId', isEqualTo: templeId)
          .where('isModerated', isEqualTo: false)
          .get();

      if (reviews.docs.isEmpty) {
        await _firestore.collection('temples').doc(templeId).update({
          'averageRating': 0.0,
          'totalReviews': 0,
          'ratingDistribution': {'1': 0, '2': 0, '3': 0, '4': 0, '5': 0},
        });
        return;
      }

      double totalRating = 0;
      final Map<String, int> distribution = {
        '1': 0,
        '2': 0,
        '3': 0,
        '4': 0,
        '5': 0,
      };

      for (final doc in reviews.docs) {
        final review = Review.fromFirestore(doc);
        totalRating += review.rating;
        final ratingKey = review.rating.floor().toString();
        distribution[ratingKey] = (distribution[ratingKey] ?? 0) + 1;
      }

      final averageRating = totalRating / reviews.docs.length;

      await _firestore.collection('temples').doc(templeId).update({
        'averageRating': averageRating,
        'totalReviews': reviews.docs.length,
        'ratingDistribution': distribution,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      print('Updating temple rating stats: $e');
    }
  }

  /// Update user review statistics
  Future<void> _updateUserReviewStats(
    String userId, {
    bool decrement = false,
  }) async {
    try {
      final userStatsRef = _firestore.collection('user_stats').doc(userId);

      if (decrement) {
        await userStatsRef.update({
          'totalReviews': FieldValue.increment(-1),
          'updatedAt': Timestamp.now(),
        });
      } else {
        await userStatsRef.set({
          'totalReviews': FieldValue.increment(1),
          'updatedAt': Timestamp.now(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      print('Updating user review stats: $e');
    }
  }

  /// Update user post statistics
  Future<void> _updateUserPostStats(
    String userId, {
    bool decrement = false,
  }) async {
    try {
      final userStatsRef = _firestore.collection('user_stats').doc(userId);

      if (decrement) {
        await userStatsRef.update({
          'totalPosts': FieldValue.increment(-1),
          'updatedAt': Timestamp.now(),
        });
      } else {
        await userStatsRef.set({
          'totalPosts': FieldValue.increment(1),
          'updatedAt': Timestamp.now(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      print('Updating user post stats: $e');
    }
  }

  /// Update post comment count
  Future<void> _updatePostCommentCount(
    String postId, {
    required bool increment,
  }) async {
    try {
      final postRef = _postsCollection.doc(postId);

      if (increment) {
        await postRef.update({
          'commentsCount': FieldValue.increment(1),
          'updatedAt': Timestamp.now(),
        });
      } else {
        await postRef.update({
          'commentsCount': FieldValue.increment(-1),
          'updatedAt': Timestamp.now(),
        });
      }
    } catch (e) {
      print('Updating post comment count: $e');
    }
  }

  /// Update comment reply count
  Future<void> _updateCommentReplyCount(
    String commentId, {
    required bool increment,
  }) async {
    try {
      final commentRef = _commentsCollection.doc(commentId);

      if (increment) {
        await commentRef.update({
          'repliesCount': FieldValue.increment(1),
          'updatedAt': Timestamp.now(),
        });
      } else {
        await commentRef.update({
          'repliesCount': FieldValue.increment(-1),
          'updatedAt': Timestamp.now(),
        });
      }
    } catch (e) {
      print('Updating comment reply count: $e');
    }
  }
}
