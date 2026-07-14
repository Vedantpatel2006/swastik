import 'package:cloud_firestore/cloud_firestore.dart';

/// Community comment data model for post comments
class CommunityComment {
  final String id;
  final String postId;
  final String userId;
  final String userName;
  final String? userPhotoUrl;
  final String content;
  final String? parentCommentId; // For nested replies
  final int likesCount;
  final List<String> likedByUserIds;
  final int repliesCount;
  final bool isReported;
  final bool isModerated;
  final String? moderationReason;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CommunityComment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.userName,
    this.userPhotoUrl,
    required this.content,
    this.parentCommentId,
    this.likesCount = 0,
    this.likedByUserIds = const [],
    this.repliesCount = 0,
    this.isReported = false,
    this.isModerated = false,
    this.moderationReason,
    this.metadata = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create CommunityComment from Firestore document
  factory CommunityComment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return CommunityComment.fromJson({...data, 'id': doc.id});
  }

  /// Create CommunityComment from JSON
  factory CommunityComment.fromJson(Map<String, dynamic> json) {
    return CommunityComment(
      id: json['id'] as String,
      postId: json['postId'] as String,
      userId: json['userId'] as String,
      userName: json['userName'] as String,
      userPhotoUrl: json['userPhotoUrl'] as String?,
      content: json['content'] as String,
      parentCommentId: json['parentCommentId'] as String?,
      likesCount: json['likesCount'] as int? ?? 0,
      likedByUserIds: json['likedByUserIds'] != null
          ? List<String>.from(json['likedByUserIds'] as List)
          : [],
      repliesCount: json['repliesCount'] as int? ?? 0,
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

  /// Convert CommunityComment to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'postId': postId,
      'userId': userId,
      'userName': userName,
      if (userPhotoUrl != null) 'userPhotoUrl': userPhotoUrl,
      'content': content,
      if (parentCommentId != null) 'parentCommentId': parentCommentId,
      'likesCount': likesCount,
      'likedByUserIds': likedByUserIds,
      'repliesCount': repliesCount,
      'isReported': isReported,
      'isModerated': isModerated,
      if (moderationReason != null) 'moderationReason': moderationReason,
      'metadata': metadata,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Validate comment data
  bool isValid() {
    return id.isNotEmpty &&
        postId.isNotEmpty &&
        userId.isNotEmpty &&
        userName.isNotEmpty &&
        content.isNotEmpty &&
        content.length <= 500; // Max comment length
  }

  /// Create a copy of CommunityComment with updated fields
  CommunityComment copyWith({
    String? id,
    String? postId,
    String? userId,
    String? userName,
    String? userPhotoUrl,
    String? content,
    String? parentCommentId,
    int? likesCount,
    List<String>? likedByUserIds,
    int? repliesCount,
    bool? isReported,
    bool? isModerated,
    String? moderationReason,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CommunityComment(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userPhotoUrl: userPhotoUrl ?? this.userPhotoUrl,
      content: content ?? this.content,
      parentCommentId: parentCommentId ?? this.parentCommentId,
      likesCount: likesCount ?? this.likesCount,
      likedByUserIds: likedByUserIds ?? this.likedByUserIds,
      repliesCount: repliesCount ?? this.repliesCount,
      isReported: isReported ?? this.isReported,
      isModerated: isModerated ?? this.isModerated,
      moderationReason: moderationReason ?? this.moderationReason,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  /// Like comment by a user
  CommunityComment like(String userId) {
    if (likedByUserIds.contains(userId)) return this;

    return copyWith(
      likesCount: likesCount + 1,
      likedByUserIds: [...likedByUserIds, userId],
      updatedAt: DateTime.now(),
    );
  }

  /// Unlike comment by a user
  CommunityComment unlike(String userId) {
    if (!likedByUserIds.contains(userId)) return this;

    final updatedUserIds = List<String>.from(likedByUserIds);
    updatedUserIds.remove(userId);

    return copyWith(
      likesCount: (likesCount - 1).clamp(0, double.infinity).toInt(),
      likedByUserIds: updatedUserIds,
      updatedAt: DateTime.now(),
    );
  }

  /// Increment replies count
  CommunityComment incrementReplies() {
    return copyWith(repliesCount: repliesCount + 1, updatedAt: DateTime.now());
  }

  /// Decrement replies count
  CommunityComment decrementReplies() {
    return copyWith(
      repliesCount: (repliesCount - 1).clamp(0, double.infinity).toInt(),
      updatedAt: DateTime.now(),
    );
  }

  /// Report comment for moderation
  CommunityComment report(String reason) {
    return copyWith(
      isReported: true,
      moderationReason: reason,
      updatedAt: DateTime.now(),
    );
  }

  /// Moderate comment (admin action)
  CommunityComment moderate(bool approved, String? reason) {
    return copyWith(
      isModerated: true,
      moderationReason: approved ? null : reason,
      updatedAt: DateTime.now(),
    );
  }

  /// Check if user has liked this comment
  bool isLikedBy(String userId) {
    return likedByUserIds.contains(userId);
  }

  /// Check if this is a reply to another comment
  bool get isReply {
    return parentCommentId != null && parentCommentId!.isNotEmpty;
  }

  /// Get comment age in human readable format
  String get commentAge {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

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
    return other is CommunityComment &&
        other.id == id &&
        other.postId == postId &&
        other.userId == userId &&
        other.userName == userName &&
        other.userPhotoUrl == userPhotoUrl &&
        other.content == content &&
        other.parentCommentId == parentCommentId &&
        other.likesCount == likesCount &&
        _listEquals(other.likedByUserIds, likedByUserIds) &&
        other.repliesCount == repliesCount &&
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
      postId,
      userId,
      userName,
      userPhotoUrl,
      content,
      parentCommentId,
      likesCount,
      likedByUserIds,
      repliesCount,
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
    return 'CommunityComment(id: $id, postId: $postId, userName: $userName, isReply: $isReply)';
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
