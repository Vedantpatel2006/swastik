import 'package:cloud_firestore/cloud_firestore.dart';

/// Community post types
enum CommunityPostType { story, photo, experience, question, announcement }

/// Community post data model for user-generated content
class CommunityPost {
  final String id;
  final String userId;
  final String userName;
  final String? userPhotoUrl;
  final String? templeId;
  final String? templeName;
  final CommunityPostType type;
  final String title;
  final String content;
  final List<String> photos;
  final List<String> tags;
  final int likesCount;
  final List<String> likedByUserIds;
  final int commentsCount;
  final int sharesCount;
  final bool isReported;
  final bool isModerated;
  final String? moderationReason;
  final bool isPublic;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CommunityPost({
    required this.id,
    required this.userId,
    required this.userName,
    this.userPhotoUrl,
    this.templeId,
    this.templeName,
    required this.type,
    required this.title,
    required this.content,
    this.photos = const [],
    this.tags = const [],
    this.likesCount = 0,
    this.likedByUserIds = const [],
    this.commentsCount = 0,
    this.sharesCount = 0,
    this.isReported = false,
    this.isModerated = false,
    this.moderationReason,
    this.isPublic = true,
    this.metadata = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create CommunityPost from Firestore document
  factory CommunityPost.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return CommunityPost.fromJson({...data, 'id': doc.id});
  }

  /// Create CommunityPost from JSON
  factory CommunityPost.fromJson(Map<String, dynamic> json) {
    return CommunityPost(
      id: json['id'] as String,
      userId: json['userId'] as String,
      userName: json['userName'] as String,
      userPhotoUrl: json['userPhotoUrl'] as String?,
      templeId: json['templeId'] as String?,
      templeName: json['templeName'] as String?,
      type: CommunityPostType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => CommunityPostType.story,
      ),
      title: json['title'] as String,
      content: json['content'] as String,
      photos: json['photos'] != null
          ? List<String>.from(json['photos'] as List)
          : [],
      tags: json['tags'] != null ? List<String>.from(json['tags'] as List) : [],
      likesCount: json['likesCount'] as int? ?? 0,
      likedByUserIds: json['likedByUserIds'] != null
          ? List<String>.from(json['likedByUserIds'] as List)
          : [],
      commentsCount: json['commentsCount'] as int? ?? 0,
      sharesCount: json['sharesCount'] as int? ?? 0,
      isReported: json['isReported'] as bool? ?? false,
      isModerated: json['isModerated'] as bool? ?? false,
      moderationReason: json['moderationReason'] as String?,
      isPublic: json['isPublic'] as bool? ?? true,
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

  /// Convert CommunityPost to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      if (userPhotoUrl != null) 'userPhotoUrl': userPhotoUrl,
      if (templeId != null) 'templeId': templeId,
      if (templeName != null) 'templeName': templeName,
      'type': type.name,
      'title': title,
      'content': content,
      'photos': photos,
      'tags': tags,
      'likesCount': likesCount,
      'likedByUserIds': likedByUserIds,
      'commentsCount': commentsCount,
      'sharesCount': sharesCount,
      'isReported': isReported,
      'isModerated': isModerated,
      if (moderationReason != null) 'moderationReason': moderationReason,
      'isPublic': isPublic,
      'metadata': metadata,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Validate community post data
  bool isValid() {
    return userId.isNotEmpty &&
        userName.isNotEmpty &&
        title.isNotEmpty &&
        content.isNotEmpty &&
        title.length <= 200 && // Max title length
        content.length <= 5000; // Max content length (matches UI)
  }

  /// Create a copy of CommunityPost with updated fields
  CommunityPost copyWith({
    String? id,
    String? userId,
    String? userName,
    String? userPhotoUrl,
    String? templeId,
    String? templeName,
    CommunityPostType? type,
    String? title,
    String? content,
    List<String>? photos,
    List<String>? tags,
    int? likesCount,
    List<String>? likedByUserIds,
    int? commentsCount,
    int? sharesCount,
    bool? isReported,
    bool? isModerated,
    String? moderationReason,
    bool? isPublic,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CommunityPost(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userPhotoUrl: userPhotoUrl ?? this.userPhotoUrl,
      templeId: templeId ?? this.templeId,
      templeName: templeName ?? this.templeName,
      type: type ?? this.type,
      title: title ?? this.title,
      content: content ?? this.content,
      photos: photos ?? this.photos,
      tags: tags ?? this.tags,
      likesCount: likesCount ?? this.likesCount,
      likedByUserIds: likedByUserIds ?? this.likedByUserIds,
      commentsCount: commentsCount ?? this.commentsCount,
      sharesCount: sharesCount ?? this.sharesCount,
      isReported: isReported ?? this.isReported,
      isModerated: isModerated ?? this.isModerated,
      moderationReason: moderationReason ?? this.moderationReason,
      isPublic: isPublic ?? this.isPublic,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  /// Like post by a user
  CommunityPost like(String userId) {
    if (likedByUserIds.contains(userId)) return this;

    return copyWith(
      likesCount: likesCount + 1,
      likedByUserIds: [...likedByUserIds, userId],
      updatedAt: DateTime.now(),
    );
  }

  /// Unlike post by a user
  CommunityPost unlike(String userId) {
    if (!likedByUserIds.contains(userId)) return this;

    final updatedUserIds = List<String>.from(likedByUserIds);
    updatedUserIds.remove(userId);

    return copyWith(
      likesCount: (likesCount - 1).clamp(0, double.infinity).toInt(),
      likedByUserIds: updatedUserIds,
      updatedAt: DateTime.now(),
    );
  }

  /// Increment comments count
  CommunityPost incrementComments() {
    return copyWith(
      commentsCount: commentsCount + 1,
      updatedAt: DateTime.now(),
    );
  }

  /// Decrement comments count
  CommunityPost decrementComments() {
    return copyWith(
      commentsCount: (commentsCount - 1).clamp(0, double.infinity).toInt(),
      updatedAt: DateTime.now(),
    );
  }

  /// Increment shares count
  CommunityPost incrementShares() {
    return copyWith(sharesCount: sharesCount + 1, updatedAt: DateTime.now());
  }

  /// Report post for moderation
  CommunityPost report(String reason) {
    return copyWith(
      isReported: true,
      moderationReason: reason,
      updatedAt: DateTime.now(),
    );
  }

  /// Moderate post (admin action)
  CommunityPost moderate(bool approved, String? reason) {
    return copyWith(
      isModerated: true,
      moderationReason: approved ? null : reason,
      updatedAt: DateTime.now(),
    );
  }

  /// Check if user has liked this post
  bool isLikedBy(String userId) {
    return likedByUserIds.contains(userId);
  }

  /// Get post type display name
  String get typeDisplayName {
    switch (type) {
      case CommunityPostType.story:
        return 'Story';
      case CommunityPostType.photo:
        return 'Photo';
      case CommunityPostType.experience:
        return 'Experience';
      case CommunityPostType.question:
        return 'Question';
      case CommunityPostType.announcement:
        return 'Announcement';
    }
  }

  /// Get post age in human readable format
  String get postAge {
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

  /// Get engagement rate (likes + comments + shares)
  int get engagementCount {
    return likesCount + commentsCount + sharesCount;
  }

  /// Check if post has temple association
  bool get hasTempleAssociation {
    return templeId != null && templeId!.isNotEmpty;
  }

  /// Get content preview (first 100 characters)
  String get contentPreview {
    if (content.length <= 100) return content;
    return '${content.substring(0, 97)}...';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CommunityPost &&
        other.id == id &&
        other.userId == userId &&
        other.userName == userName &&
        other.userPhotoUrl == userPhotoUrl &&
        other.templeId == templeId &&
        other.templeName == templeName &&
        other.type == type &&
        other.title == title &&
        other.content == content &&
        _listEquals(other.photos, photos) &&
        _listEquals(other.tags, tags) &&
        other.likesCount == likesCount &&
        _listEquals(other.likedByUserIds, likedByUserIds) &&
        other.commentsCount == commentsCount &&
        other.sharesCount == sharesCount &&
        other.isReported == isReported &&
        other.isModerated == isModerated &&
        other.moderationReason == moderationReason &&
        other.isPublic == isPublic &&
        _mapEquals(other.metadata, metadata) &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return Object.hashAll([
      id,
      userId,
      userName,
      userPhotoUrl,
      templeId,
      templeName,
      type,
      title,
      content,
      photos,
      tags,
      likesCount,
      likedByUserIds,
      commentsCount,
      sharesCount,
      isReported,
      isModerated,
      moderationReason,
      isPublic,
      metadata,
      createdAt,
      updatedAt,
    ]);
  }

  @override
  String toString() {
    return 'CommunityPost(id: $id, type: $type, title: $title, userName: $userName)';
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
