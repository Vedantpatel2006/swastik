import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/app_spacing.dart';
import '../../../core/themes/app_radius.dart';
import '../../../shared/models/review.dart';
import '../services/review_service.dart';

/// Widget to display a single review card
class ReviewCardWidget extends StatefulWidget {
  final Review review;
  final String? currentUserId;
  final VoidCallback? onDeleted;

  const ReviewCardWidget({
    super.key,
    required this.review,
    this.currentUserId,
    this.onDeleted,
  });

  @override
  State<ReviewCardWidget> createState() => _ReviewCardWidgetState();
}

class _ReviewCardWidgetState extends State<ReviewCardWidget> {
  final _reviewService = ReviewService();
  bool _isProcessing = false;

  Future<void> _toggleHelpful() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      await _reviewService.markAsHelpful(widget.review.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _reportReview() async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Review'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Why are you reporting this review?'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: 'Enter reason...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Report'),
          ),
        ],
      ),
    );

    if (confirmed == true && reasonController.text.trim().isNotEmpty) {
      try {
        await _reviewService.reportReview(
          widget.review.id,
          reasonController.text.trim(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Review reported successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error reporting review: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteReview() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Review'),
        content: const Text('Are you sure you want to delete this review?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _reviewService.deleteReview(widget.review.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Review deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          widget.onDeleted?.call();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting review: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOwnReview = widget.currentUserId == widget.review.userId;
    final isHelpful = widget.currentUserId != null &&
        widget.review.isMarkedHelpfulBy(widget.currentUserId!);

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(isOwnReview),
            const SizedBox(height: AppSpacing.md),
            _buildRating(),
            const SizedBox(height: AppSpacing.md),
            _buildComment(),
            if (widget.review.photos.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              _buildPhotos(),
            ],
            const SizedBox(height: AppSpacing.md),
            _buildFooter(isHelpful, isOwnReview),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isOwnReview) {
    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: AppColors.primaryOrange,
          backgroundImage: widget.review.userPhotoUrl != null
              ? NetworkImage(widget.review.userPhotoUrl!)
              : null,
          child: widget.review.userPhotoUrl == null
              ? Text(
                  widget.review.userName[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    widget.review.userName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  if (widget.review.isVerifiedVisit) ...[
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.verified,
                      size: 16,
                      color: Colors.orange,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                widget.review.reviewAge,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'delete') {
              _deleteReview();
            } else if (value == 'report') {
              _reportReview();
            }
          },
          itemBuilder: (context) => [
            if (isOwnReview)
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete'),
                  ],
                ),
              ),
            if (!isOwnReview)
              const PopupMenuItem(
                value: 'report',
                child: Row(
                  children: [
                    Icon(Icons.flag, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('Report'),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildRating() {
    return Row(
      children: [
        ...List.generate(5, (index) {
          return Icon(
            index < widget.review.rating ? Icons.star : Icons.star_border,
            color: Colors.amber,
            size: 20,
          );
        }),
        const SizedBox(width: 8),
        Text(
          widget.review.rating.toStringAsFixed(1),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildComment() {
    return Text(
      widget.review.comment,
      style: const TextStyle(
        fontSize: 14,
        height: 1.5,
      ),
    );
  }

  Widget _buildPhotos() {
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: widget.review.photos.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () => _showPhotoViewer(index),
            child: Container(
              width: 100,
              height: 100,
              margin: const EdgeInsets.only(right: AppSpacing.sm),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.md),
                image: DecorationImage(
                  image: NetworkImage(widget.review.photos[index]),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showPhotoViewer(int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
          ),
          body: PageView.builder(
            controller: PageController(initialPage: initialIndex),
            itemCount: widget.review.photos.length,
            itemBuilder: (context, index) {
              return InteractiveViewer(
                child: Center(
                  child: Image.network(
                    widget.review.photos[index],
                    fit: BoxFit.contain,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(bool isHelpful, bool isOwnReview) {
    return Row(
      children: [
        if (!isOwnReview)
          TextButton.icon(
            onPressed: _isProcessing ? null : _toggleHelpful,
            icon: Icon(
              isHelpful ? Icons.thumb_up : Icons.thumb_up_outlined,
              size: 18,
              color: isHelpful ? AppColors.primaryOrange : Colors.grey,
            ),
            label: Text(
              'Helpful (${widget.review.helpfulCount})',
              style: TextStyle(
                color: isHelpful ? AppColors.primaryOrange : Colors.grey,
              ),
            ),
          ),
        const Spacer(),
        Text(
          DateFormat('MMM dd, yyyy').format(widget.review.reviewDate),
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
