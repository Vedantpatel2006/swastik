import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import '../../shared/models/community_post.dart';
import '../../shared/models/community_comment.dart';
import '../../shared/services/community_service.dart';
import '../../shared/services/community_interaction_service.dart';
import '../../core/themes/app_colors.dart';

/// Community Post Detail Screen - Shows full post with comments
class CommunityPostDetailScreen extends StatefulWidget {
  final CommunityPost post;

  const CommunityPostDetailScreen({super.key, required this.post});

  @override
  State<CommunityPostDetailScreen> createState() =>
      _CommunityPostDetailScreenState();
}

class _CommunityPostDetailScreenState extends State<CommunityPostDetailScreen> {
  final _communityService = CommunityService();
  final _interactionService = CommunityInteractionService();
  final _commentController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSubmittingComment = false;
  bool _isTogglingLike = false;
  bool _isSharing = false;
  late CommunityPost _currentPost;
  bool _isLiked = false;

  @override
  void initState() {
    super.initState();
    _currentPost = widget.post;
    _checkInitialLikeState();
  }

  Future<void> _checkInitialLikeState() async {
    final liked = await _interactionService.hasLiked(widget.post.id);
    if (mounted) {
      setState(() {
        _isLiked = liked;
      });
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Post Details',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              controller: _scrollController,
              children: [
                _buildPostHeader(),
                _buildPostContent(),
                _buildPostActions(),
                _buildCommentsSection(),
              ],
            ),
          ),
          _buildCommentInput(),
        ],
      ),
    );
  }

  Widget _buildPostHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.grey[300],
            backgroundImage: widget.post.userPhotoUrl != null
                ? CachedNetworkImageProvider(widget.post.userPhotoUrl!)
                : null,
            child: widget.post.userPhotoUrl == null
                ? const Icon(Icons.person, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.post.userName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  _formatDate(widget.post.createdAt),
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
          PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                child: const Text('Report'),
                onTap: () => _showReportDialog(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPostContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.post.title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                widget.post.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          Text(
            widget.post.content,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: Colors.black87,
            ),
          ),
          if (widget.post.photos.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: widget.post.photos.first,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Shimmer.fromColors(
                    baseColor: Colors.grey[300]!,
                    highlightColor: Colors.grey[100]!,
                    child: Container(height: 200, color: Colors.grey[300]),
                  ),
                  errorWidget: (context, url, error) => Container(
                    height: 200,
                    color: Colors.grey[200],
                    child: const Icon(Icons.image_not_supported),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPostActions() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildActionButton(
            icon: _isLiked ? Icons.favorite : Icons.favorite_outline,
            label: '${_currentPost.likesCount}',
            color: _isLiked ? Colors.red : Colors.grey[600],
            onTap: () => _toggleLike(),
          ),
          _buildActionButton(
            icon: Icons.comment_outlined,
            label: '${_currentPost.commentsCount}',
            onTap: () => _scrollToComments(),
          ),
          _buildActionButton(
            icon: Icons.share_outlined,
            label: '${_currentPost.sharesCount}',
            onTap: () => _sharePost(),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    Color? color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: color ?? Colors.grey[600], size: 20),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: color ?? Colors.grey[600],
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsSection() {
    return StreamBuilder<List<CommunityComment>>(
      stream: _communityService.watchPostComments(widget.post.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildCommentsLoading();
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Text('Error loading comments: ${snapshot.error}'),
            ),
          );
        }

        final comments = snapshot.data ?? [];

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Divider(color: Colors.grey[300]),
              const SizedBox(height: 12),
              Text(
                'Comments (${comments.length})',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
              if (comments.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'No comments yet. Be the first to comment!',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: comments.length,
                  itemBuilder: (context, index) =>
                      _buildCommentCard(comments[index]),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCommentsLoading() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Column(
          children: [
            Divider(color: Colors.grey[300]),
            const SizedBox(height: 12),
            Container(height: 16, width: 150, color: Colors.white),
            const SizedBox(height: 16),
            ...[0, 1, 2].map((_) => _buildCommentSkeletonLoader()),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentSkeletonLoader() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 12, width: 100, color: Colors.white),
                const SizedBox(height: 8),
                Container(height: 12, width: 200, color: Colors.white),
                const SizedBox(height: 8),
                Container(height: 12, width: 150, color: Colors.white),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentCard(CommunityComment comment) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.grey[300],
            backgroundImage: comment.userPhotoUrl != null
                ? CachedNetworkImageProvider(comment.userPhotoUrl!)
                : null,
            child: comment.userPhotoUrl == null
                ? const Icon(Icons.person, size: 16, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      comment.userName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      _formatDate(comment.createdAt),
                      style: TextStyle(color: Colors.grey[500], fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  comment.content,
                  style: const TextStyle(fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentInput() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
        color: Colors.white,
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _commentController,
                enabled: !_isSubmittingComment,
                decoration: InputDecoration(
                  hintText: 'Add a comment...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                maxLines: 1,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: _isSubmittingComment
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primaryOrange,
                        ),
                      ),
                    )
                  : const Icon(Icons.send),
              color: AppColors.primaryOrange,
              onPressed: _isSubmittingComment ? null : _submitComment,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleLike() async {
    if (_isTogglingLike) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to like posts')),
      );
      return;
    }

    setState(() {
      _isTogglingLike = true;
    });

    try {
      // Use CommunityInteractionService (subcollection-based) — same as CommunityPostCard
      final newLikeState = await _interactionService.toggleLike(
        _currentPost.id,
      );

      if (mounted) {
        setState(() {
          _isLiked = newLikeState;
          _currentPost = _currentPost.copyWith(
            likesCount: _currentPost.likesCount + (newLikeState ? 1 : -1),
          );
          _isTogglingLike = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTogglingLike = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update like: $e')));
      }
    }
  }

  void _scrollToComments() {
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _sharePost() async {
    if (_isSharing) return;

    setState(() {
      _isSharing = true;
    });

    try {
      final text =
          '''
${_currentPost.title}

${_currentPost.content}

Check out this post in Swastik app!
''';

      final result = await Share.shareWithResult(text);

      // Only record and update count if user actually shared
      if (result.status == ShareResultStatus.success) {
        try {
          await _communityService.sharePost(_currentPost.id);
        } catch (_) {
          // Ignore share count sync errors
        }
        if (mounted) {
          setState(() {
            _currentPost = _currentPost.copyWith(
              sharesCount: _currentPost.sharesCount + 1,
            );
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to share: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSharing = false;
        });
      }
    }
  }

  Future<void> _submitComment() async {
    final trimmed = _commentController.text.trim();
    if (trimmed.isEmpty) return;

    setState(() {
      _isSubmittingComment = true;
    });

    try {
      await _communityService.addCommentSimple(
        postId: widget.post.id,
        content: trimmed,
      );

      _commentController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Comment posted!'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to post comment: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingComment = false;
        });
      }
    }
  }

  void _showReportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Post'),
        content: const Text(
          'Are you sure you want to report this post? Our team will review it shortly.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _communityService.reportContent(
                contentId: widget.post.id,
                contentType: 'post',
                reason: 'Inappropriate content',
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Post reported. Thank you!')),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Report'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) return 'just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';

    return '${date.day}/${date.month}/${date.year}';
  }
}
