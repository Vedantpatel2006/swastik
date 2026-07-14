import 'package:cloud_firestore/cloud_firestore.dart';

/// Review data model for temple reviews and ratings
class Review {
  final String id;
  final String templeId;
  final String userId;
  final String userName;
  final String? userPhotoUrl;
  final double rating; // 1.0 to 5.0
  final String comment;
  final List<String> photos;
  final DateTime reviewDate;
  final int helpfulCount;
  final List<String> helpfulUserIds;
  final bool isVerifiedVisit;
  final bool isReported;
  final bool isModerated;
  final String? moderationReason;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Review({
    required this.id,
    required this.templeId,
    required this.userId,
    required this.userName,
    this.userPhotoUrl,
    required this.rating,
    required this.comment,
    this.photos = const [],
    required this.reviewDate,
    this.helpfulCount = 0,
    this.helpfulUserIds = const [],
    this.isVerifiedVisit = false,
    this.isReported = false,
    this.isModerated = false,
    this.moderationReason,
    this.metadata = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create Review from Firestore document
  factory Review.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Review.fromJson({...data, 'id': doc.id});
  }

  /// Create Review from JSON
  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id'] as String,
      templeId: json['templeId'] as String,
      userId: json['userId'] as String,
      userName: json['userName'] as String,
      userPhotoUrl: json['userPhotoUrl'] as String?,
      rating: (json['rating'] as num).toDouble(),
      comment: json['comment'] as String,
      photos: json['photos'] != null
          ? List<String>.from(json['photos'] as List)
          : [],
      reviewDate: json['reviewDate'] != null
          ? (json['reviewDate'] as Timestamp).toDate()
          : DateTime.now(),
      helpfulCount: json['helpfulCount'] as int? ?? 0,
      helpfulUserIds: json['helpfulUserIds'] != null
          ? List<String>.from(json['helpfulUserIds'] as List)
          : [],
      isVerifiedVisit: json['isVerifiedVisit'] as bool? ?? false,
      isReported: json['isReported'] as bool? ?? false,
      isModerated: json['isModerated'] as bool? ?? false,
      moderationReason: json['moderationReason'] as String?,
      metadata: json['metadata'] != null
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : {},
      createdAt: json['createdAt'] != null
          ? (json['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? (json['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  /// Convert Review to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'templeId': templeId,
      'userId': userId,
      'userName': userName,
      if (userPhotoUrl != null) 'userPhotoUrl': userPhotoUrl,
      'rating': rating,
      'comment': comment,
      'photos': photos,
      'reviewDate': Timestamp.fromDate(reviewDate),
      'helpfulCount': helpfulCount,
      'helpfulUserIds': helpfulUserIds,
      'isVerifiedVisit': isVerifiedVisit,
      'isReported': isReported,
      'isModerated': isModerated,
      if (moderationReason != null) 'moderationReason': moderationReason,
      'metadata': metadata,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Validate review data
  bool isValid() {
    return id.isNotEmpty &&
        templeId.isNotEmpty &&
        userId.isNotEmpty &&
        userName.isNotEmpty &&
        rating >= 1.0 &&
        rating <= 5.0 &&
        comment.isNotEmpty &&
        comment.length <= 1000; // Max comment length
  }

  /// Create a copy of Review with updated fields
  Review copyWith({
    String? id,
    String? templeId,
    String? userId,
    String? userName,
    String? userPhotoUrl,
    double? rating,
    String? comment,
    List<String>? photos,
    DateTime? reviewDate,
    int? helpfulCount,
    List<String>? helpfulUserIds,
    bool? isVerifiedVisit,
    bool? isReported,
    bool? isModerated,
    String? moderationReason,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Review(
      id: id ?? this.id,
      templeId: templeId ?? this.templeId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userPhotoUrl: userPhotoUrl ?? this.userPhotoUrl,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      photos: photos ?? this.photos,
      reviewDate: reviewDate ?? this.reviewDate,
      helpfulCount: helpfulCount ?? this.helpfulCount,
      helpfulUserIds: helpfulUserIds ?? this.helpfulUserIds,
      isVerifiedVisit: isVerifiedVisit ?? this.isVerifiedVisit,
      isReported: isReported ?? this.isReported,
      isModerated: isModerated ?? this.isModerated,
      moderationReason: moderationReason ?? this.moderationReason,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  /// Mark review as helpful by a user
  Review markAsHelpful(String userId) {
    if (helpfulUserIds.contains(userId)) return this;

    return copyWith(
      helpfulCount: helpfulCount + 1,
      helpfulUserIds: [...helpfulUserIds, userId],
      updatedAt: DateTime.now(),
    );
  }

  /// Remove helpful mark by a user
  Review removeHelpful(String userId) {
    if (!helpfulUserIds.contains(userId)) return this;

    final updatedUserIds = List<String>.from(helpfulUserIds);
    updatedUserIds.remove(userId);

    return copyWith(
      helpfulCount: (helpfulCount - 1).clamp(0, double.infinity).toInt(),
      helpfulUserIds: updatedUserIds,
      updatedAt: DateTime.now(),
    );
  }

  /// Report review for moderation
  Review report(String reason) {
    return copyWith(
      isReported: true,
      moderationReason: reason,
      updatedAt: DateTime.now(),
    );
  }

  /// Moderate review (admin action)
  Review moderate(bool approved, String? reason) {
    return copyWith(
      isModerated: true,
      moderationReason: approved ? null : reason,
      updatedAt: DateTime.now(),
    );
  }

  /// Check if user has marked this review as helpful
  bool isMarkedHelpfulBy(String userId) {
    return helpfulUserIds.contains(userId);
  }

  /// Get formatted rating as stars
  String get formattedRating {
    final fullStars = rating.floor();
    final hasHalfStar = (rating - fullStars) >= 0.5;

    String stars = '★' * fullStars;
    if (hasHalfStar) stars += '☆';

    final emptyStars = 5 - fullStars - (hasHalfStar ? 1 : 0);
    stars += '☆' * emptyStars;

    return stars;
  }

  /// Get review age in human readable format
  String get reviewAge {
    final now = DateTime.now();
    final difference = now.difference(reviewDate);

    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return '$years ${years == 1 ? 'year' : 'years'} ago';
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return '$months ${months == 1 ? 'month' : 'months'} ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else {
      return 'Just now';
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Review &&
        other.id == id &&
        other.templeId == templeId &&
        other.userId == userId &&
        other.userName == userName &&
        other.userPhotoUrl == userPhotoUrl &&
        other.rating == rating &&
        other.comment == comment &&
        _listEquals(other.photos, photos) &&
        other.reviewDate == reviewDate &&
        other.helpfulCount == helpfulCount &&
        _listEquals(other.helpfulUserIds, helpfulUserIds) &&
        other.isVerifiedVisit == isVerifiedVisit &&
        other.isReported == isReported &&
        other.isModerated == isModerated &&
        other.moderationReason == moderationReason &&
        _mapEquals(other.metadata, metadata) &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return Object.hashAll([
      id,
      templeId,
      userId,
      userName,
      userPhotoUrl,
      rating,
      comment,
      photos,
      reviewDate,
      helpfulCount,
      helpfulUserIds,
      isVerifiedVisit,
      isReported,
      isModerated,
      moderationReason,
      metadata,
      createdAt,
      updatedAt,
    ]);
  }

  @override
  String toString() {
    return 'Review(id: $id, templeId: $templeId, rating: $rating, userName: $userName)';
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  bool _mapEquals(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (a[key] != b[key]) return false;
    }
    return true;
  }
}
