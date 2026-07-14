import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/themes/app_colors.dart';
import '../models/community_post.dart';
import '../services/community_interaction_service.dart';

/// Card widget for displaying community post information
class CommunityPostCard extends StatefulWidget {
  final CommunityPost post;
  final VoidCallback? onTap;
  final bool showActions;
  final CommunityInteractionService? interactionService;

  const CommunityPostCard({
    super.key,
    required this.post,
    this.onTap,
    this.showActions = true,
    this.interactionService,
  });

  @override
  State<CommunityPostCard> createState() => _CommunityPostCardState();
}

class _CommunityPostCardState extends State<CommunityPostCard> {
  late CommunityInteractionService _interactionService;
  bool _isLiked = false;
  int _likesCount = 0;
  int _commentsCount = 0;
  int _sharesCount = 0;
  bool _isLiking = false; // independent flag for like
  bool _isSharing = false; // independent flag for share

  @override
  void initState() {
    super.initState();
    _interactionService =
        widget.interactionService ?? CommunityInteractionService();
    _likesCount = widget.post.likesCount;
    _commentsCount = widget.post.commentsCount;
    _sharesCount = widget.post.sharesCount;
    _checkIfLiked();
  }

  Future<void> _checkIfLiked() async {
    try {
      final liked = await _interactionService.hasLiked(widget.post.id);
      if (mounted) {
        setState(() {
          _isLiked = liked;
        });
      }
    } catch (e) {
      // Silently fail - user can still interact
    }
  }

  Future<void> _handleLike() async {
    if (_isLiking) return;

    setState(() {
      _isLiking = true;
    });

    try {
      final newLikeState = await _interactionService.toggleLike(widget.post.id);
      if (mounted) {
        setState(() {
          _isLiked = newLikeState;
          _likesCount += newLikeState ? 1 : -1;
          _isLiking = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLiking = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to like post: $e')));
      }
    }
  }

  void _handleComment() {
    if (widget.onTap != null) {
      widget.onTap!(); // Navigate to post detail with comments
    } else {
      _showCommentDialog();
    }
  }

  void _showCommentDialog() {
    final commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Comment'),
        content: TextField(
          controller: commentController,
          decoration: const InputDecoration(
            hintText: 'Write your comment...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
          maxLength: 500,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final text = commentController.text.trim();
              if (text.isEmpty) return;

              try {
                await _interactionService.addComment(widget.post.id, text);
                if (mounted) {
                  setState(() {
                    _commentsCount++;
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Comment added successfully')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to add comment: $e')),
                  );
                }
              }
            },
            child: const Text('Post'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleShare() async {
    if (_isSharing) return;

    setState(() {
      _isSharing = true;
    });

    try {
      // Create share text
      final shareText =
          '''
${widget.post.title}

${widget.post.content}

${widget.post.hasTempleAssociation ? 'Temple: ${widget.post.templeName}' : ''}

Shared from Swastik Temple App
''';

      // Share using share_plus — check result to avoid counting cancellations
      final result = await Share.shareWithResult(
        shareText,
        subject: widget.post.title,
      );

      // Only record and count if the user actually shared (not dismissed)
      if (result.status == ShareResultStatus.success) {
        await _interactionService.sharePost(
          widget.post.id,
          shareMethod: 'native_share',
        );

        if (mounted) {
          setState(() {
            _sharesCount++;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to share post: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSharing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 12),
              _buildContent(),
              if (widget.post.photos.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildPhotos(),
              ],
              if (widget.showActions) ...[
                const SizedBox(height: 12),
                _buildActions(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _getTypeColor().withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            widget.post.typeDisplayName.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: _getTypeColor(),
            ),
          ),
        ),
        const Spacer(),
        CircleAvatar(
          radius: 16,
          backgroundColor: AppColors.primaryOrange.withValues(alpha: 0.15),
          backgroundImage: widget.post.userPhotoUrl != null
              ? NetworkImage(widget.post.userPhotoUrl!)
              : null,
          child: widget.post.userPhotoUrl == null
              ? Text(
                  widget.post.userName.isNotEmpty
                      ? widget.post.userName[0].toUpperCase()
                      : 'U',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryOrange,
                  ),
                )
              : null,
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              widget.post.userName,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.primaryText,
              ),
            ),
            Text(
              widget.post.postAge,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.secondaryText,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.post.title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.primaryText,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        Text(
          widget.post.content,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.secondaryText,
            height: 1.4,
          ),
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
        ),
        if (widget.post.hasTempleAssociation) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.coralOrange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.temple_hindu,
                  size: 12,
                  color: AppColors.coralOrange,
                ),
                const SizedBox(width: 4),
                Text(
                  widget.post.templeName ?? 'Temple',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: AppColors.coralOrange,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPhotos() {
    if (widget.post.photos.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: widget.post.photos.length > 3
            ? 3
            : widget.post.photos.length,
        itemBuilder: (context, index) {
          if (index == 2 && widget.post.photos.length > 3) {
            return Container(
              width: 80,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.black54,
                image: DecorationImage(
                  image: NetworkImage(widget.post.photos[index]),
                  fit: BoxFit.cover,
                ),
              ),
              child: Center(
                child: Text(
                  '+${widget.post.photos.length - 2}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
            );
          }

          return Container(
            width: 80,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              image: DecorationImage(
                image: NetworkImage(widget.post.photos[index]),
                fit: BoxFit.cover,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildActions() {
    return Row(
      children: [
        _buildActionButton(
          icon: _isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
          count: _likesCount,
          onTap: _handleLike,
          isActive: _isLiked,
          isDisabled: _isLiking,
        ),
        const SizedBox(width: 16),
        _buildActionButton(
          icon: Icons.comment_outlined,
          count: _commentsCount,
          onTap: _handleComment,
        ),
        const SizedBox(width: 16),
        _buildActionButton(
          icon: Icons.share_outlined,
          count: _sharesCount,
          onTap: _handleShare,
          isDisabled: _isSharing,
        ),
        const Spacer(),
        if (widget.post.tags.isNotEmpty)
          Wrap(
            spacing: 4,
            children: widget.post.tags.take(2).map((tag) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.mediumGray,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '#$tag',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.secondaryText,
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required int count,
    required VoidCallback onTap,
    bool isActive = false,
    bool isDisabled = false,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: isDisabled ? null : onTap,
      child: Opacity(
        opacity: isDisabled ? 0.5 : 1.0,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive ? AppColors.coralOrange : AppColors.secondaryText,
            ),
            const SizedBox(width: 4),
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 12,
                color: isActive
                    ? AppColors.coralOrange
                    : AppColors.secondaryText,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getTypeColor() {
    switch (widget.post.type) {
      case CommunityPostType.story:
        return AppColors.infoPurple;
      case CommunityPostType.photo:
        return const Color(0xFF06B6D4);
      case CommunityPostType.experience:
        return AppColors.successGreen;
      case CommunityPostType.question:
        return AppColors.warningAmber;
      case CommunityPostType.announcement:
        return AppColors.errorRed;
    }
  }
}
