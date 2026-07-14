import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../shared/models/review.dart';

/// Service for managing temple reviews and ratings
class ReviewService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String _reviewsCollection = 'reviews';
  static const String _templesCollection = 'temples';

  /// Get current user ID
  String? get _currentUserId => _auth.currentUser?.uid;

  /// Get current user name
  String get _currentUserName =>
      _auth.currentUser?.displayName ?? 'Anonymous User';

  /// Get current user photo URL
  String? get _currentUserPhotoUrl => _auth.currentUser?.photoURL;

  /// Submit a new review
  Future<Review> submitReview({
    required String templeId,
    required double rating,
    required String comment,
    List<String> photoUrls = const [],
  }) async {
    if (_currentUserId == null) {
      throw Exception('User must be logged in to submit a review');
    }

    if (rating < 1.0 || rating > 5.0) {
      throw Exception('Rating must be between 1.0 and 5.0');
    }

    if (comment.trim().isEmpty) {
      throw Exception('Review comment cannot be empty');
    }

    if (comment.length > 1000) {
      throw Exception('Review comment cannot exceed 1000 characters');
    }

    // Check if user has already reviewed this temple
    final existingReview = await getUserReviewForTemple(templeId);
    if (existingReview != null) {
      throw Exception('You have already reviewed this temple');
    }

    final now = DateTime.now();
    final reviewData = {
      'templeId': templeId,
      'userId': _currentUserId,
      'userName': _currentUserName,
      'userPhotoUrl': _currentUserPhotoUrl,
      'rating': rating,
      'comment': comment.trim(),
      'photos': photoUrls,
      'reviewDate': Timestamp.fromDate(now),
      'helpfulCount': 0,
      'helpfulUserIds': [],
      'isVerifiedVisit': false,
      'isReported': false,
      'isModerated': false,
      'metadata': {},
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    };

    final docRef = await _firestore.collection(_reviewsCollection).add(reviewData);
    
    // Update temple's average rating
    await _updateTempleRating(templeId);

    return Review.fromJson({...reviewData, 'id': docRef.id});
  }

  /// Get all reviews for a temple
  Stream<List<Review>> getTempleReviews(String templeId) {
    return _firestore
        .collection(_reviewsCollection)
        .where('templeId', isEqualTo: templeId)
        .where('isModerated', isEqualTo: false)
        .orderBy('reviewDate', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Review.fromFirestore(doc)).toList();
    });
  }

  /// Get reviews with pagination
  Future<List<Review>> getTempleReviewsPaginated({
    required String templeId,
    int limit = 10,
    DocumentSnapshot? lastDocument,
  }) async {
    Query query = _firestore
        .collection(_reviewsCollection)
        .where('templeId', isEqualTo: templeId)
        .where('isModerated', isEqualTo: false)
        .orderBy('reviewDate', descending: true)
        .limit(limit);

    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }

    final snapshot = await query.get();
    return snapshot.docs.map((doc) => Review.fromFirestore(doc)).toList();
  }

  /// Get reviews filtered by rating
  Stream<List<Review>> getTempleReviewsByRating({
    required String templeId,
    required double rating,
  }) {
    return _firestore
        .collection(_reviewsCollection)
        .where('templeId', isEqualTo: templeId)
        .where('rating', isEqualTo: rating)
        .where('isModerated', isEqualTo: false)
        .orderBy('reviewDate', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Review.fromFirestore(doc)).toList();
    });
  }

  /// Get reviews with photos
  Stream<List<Review>> getTempleReviewsWithPhotos(String templeId) {
    return _firestore
        .collection(_reviewsCollection)
        .where('templeId', isEqualTo: templeId)
        .where('isModerated', isEqualTo: false)
        .orderBy('reviewDate', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Review.fromFirestore(doc))
          .where((review) => review.photos.isNotEmpty)
          .toList();
    });
  }

  /// Get user's review for a specific temple
  Future<Review?> getUserReviewForTemple(String templeId) async {
    if (_currentUserId == null) return null;

    final snapshot = await _firestore
        .collection(_reviewsCollection)
        .where('templeId', isEqualTo: templeId)
        .where('userId', isEqualTo: _currentUserId)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return Review.fromFirestore(snapshot.docs.first);
  }

  /// Update an existing review
  Future<void> updateReview({
    required String reviewId,
    double? rating,
    String? comment,
    List<String>? photoUrls,
  }) async {
    if (_currentUserId == null) {
      throw Exception('User must be logged in to update a review');
    }

    final reviewDoc = await _firestore.collection(_reviewsCollection).doc(reviewId).get();
    
    if (!reviewDoc.exists) {
      throw Exception('Review not found');
    }

    final review = Review.fromFirestore(reviewDoc);
    
    if (review.userId != _currentUserId) {
      throw Exception('You can only update your own reviews');
    }

    final updateData = <String, dynamic>{
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    };

    if (rating != null) {
      if (rating < 1.0 || rating > 5.0) {
        throw Exception('Rating must be between 1.0 and 5.0');
      }
      updateData['rating'] = rating;
    }

    if (comment != null) {
      if (comment.trim().isEmpty) {
        throw Exception('Review comment cannot be empty');
      }
      if (comment.length > 1000) {
        throw Exception('Review comment cannot exceed 1000 characters');
      }
      updateData['comment'] = comment.trim();
    }

    if (photoUrls != null) {
      updateData['photos'] = photoUrls;
    }

    await _firestore.collection(_reviewsCollection).doc(reviewId).update(updateData);

    // Update temple's average rating if rating changed
    if (rating != null) {
      await _updateTempleRating(review.templeId);
    }
  }

  /// Delete a review
  Future<void> deleteReview(String reviewId) async {
    if (_currentUserId == null) {
      throw Exception('User must be logged in to delete a review');
    }

    final reviewDoc = await _firestore.collection(_reviewsCollection).doc(reviewId).get();
    
    if (!reviewDoc.exists) {
      throw Exception('Review not found');
    }

    final review = Review.fromFirestore(reviewDoc);
    
    if (review.userId != _currentUserId) {
      throw Exception('You can only delete your own reviews');
    }

    await _firestore.collection(_reviewsCollection).doc(reviewId).delete();

    // Update temple's average rating
    await _updateTempleRating(review.templeId);
  }

  /// Mark review as helpful
  Future<void> markAsHelpful(String reviewId) async {
    if (_currentUserId == null) {
      throw Exception('User must be logged in to mark review as helpful');
    }

    final reviewDoc = await _firestore.collection(_reviewsCollection).doc(reviewId).get();
    
    if (!reviewDoc.exists) {
      throw Exception('Review not found');
    }

    final review = Review.fromFirestore(reviewDoc);

    if (review.helpfulUserIds.contains(_currentUserId)) {
      // User already marked as helpful, remove it
      await _firestore.collection(_reviewsCollection).doc(reviewId).update({
        'helpfulCount': FieldValue.increment(-1),
        'helpfulUserIds': FieldValue.arrayRemove([_currentUserId]),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } else {
      // Mark as helpful
      await _firestore.collection(_reviewsCollection).doc(reviewId).update({
        'helpfulCount': FieldValue.increment(1),
        'helpfulUserIds': FieldValue.arrayUnion([_currentUserId]),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    }
  }

  /// Report a review
  Future<void> reportReview(String reviewId, String reason) async {
    if (_currentUserId == null) {
      throw Exception('User must be logged in to report a review');
    }

    if (reason.trim().isEmpty) {
      throw Exception('Report reason cannot be empty');
    }

    await _firestore.collection(_reviewsCollection).doc(reviewId).update({
      'isReported': true,
      'moderationReason': reason.trim(),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Get review statistics for a temple
  Future<Map<String, dynamic>> getReviewStats(String templeId) async {
    final snapshot = await _firestore
        .collection(_reviewsCollection)
        .where('templeId', isEqualTo: templeId)
        .where('isModerated', isEqualTo: false)
        .get();

    if (snapshot.docs.isEmpty) {
      return {
        'totalReviews': 0,
        'averageRating': 0.0,
        'ratingDistribution': {
          5: 0,
          4: 0,
          3: 0,
          2: 0,
          1: 0,
        },
      };
    }

    final reviews = snapshot.docs.map((doc) => Review.fromFirestore(doc)).toList();
    
    final totalReviews = reviews.length;
    final totalRating = reviews.fold<double>(0, (sum, review) => sum + review.rating);
    final averageRating = totalRating / totalReviews;

    final ratingDistribution = <int, int>{
      5: 0,
      4: 0,
      3: 0,
      2: 0,
      1: 0,
    };

    for (final review in reviews) {
      final ratingKey = review.rating.round();
      ratingDistribution[ratingKey] = (ratingDistribution[ratingKey] ?? 0) + 1;
    }

    return {
      'totalReviews': totalReviews,
      'averageRating': averageRating,
      'ratingDistribution': ratingDistribution,
    };
  }

  /// Update temple's average rating
  Future<void> _updateTempleRating(String templeId) async {
    final stats = await getReviewStats(templeId);
    
    await _firestore.collection(_templesCollection).doc(templeId).update({
      'rating': stats['averageRating'],
      'reviewCount': stats['totalReviews'],
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }
}
