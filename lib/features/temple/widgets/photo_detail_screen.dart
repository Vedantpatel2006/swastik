import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/app_spacing.dart';
import '../../../shared/services/photo_gallery_service.dart';

class PhotoDetailScreen extends StatefulWidget {
  final String photoId;
  final Map<String, dynamic> photoData;

  const PhotoDetailScreen({
    Key? key,
    required this.photoId,
    required this.photoData,
  }) : super(key: key);

  @override
  State<PhotoDetailScreen> createState() => _PhotoDetailScreenState();
}

class _PhotoDetailScreenState extends State<PhotoDetailScreen> {
  final _photoGalleryService = PhotoGalleryService();
  final _currentUser = FirebaseAuth.instance.currentUser;
  bool _isLiked = false;
  int _likes = 0;

  @override
  void initState() {
    super.initState();
    _initializeLikeState();
  }

  void _initializeLikeState() {
    final likedBy = List<String>.from(widget.photoData['likedBy'] ?? []);
    setState(() {
      _likes = widget.photoData['likes'] as int? ?? 0;
      _isLiked = _currentUser != null && likedBy.contains(_currentUser.uid);
    });
  }

  Future<void> _toggleLike() async {
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to like photos')),
      );
      return;
    }

    final previousLiked = _isLiked;
    final previousLikes = _likes;

    // Optimistic update
    setState(() {
      _isLiked = !_isLiked;
      _likes = _isLiked ? _likes + 1 : _likes - 1;
    });

    try {
      if (_isLiked) {
        await _photoGalleryService.likePhoto(widget.photoId, _currentUser.uid);
      } else {
        await _photoGalleryService.unlikePhoto(
          widget.photoId,
          _currentUser.uid,
        );
      }
    } catch (e) {
      // Revert on error
      setState(() {
        _isLiked = previousLiked;
        _likes = previousLikes;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showReportDialog() {
    final reasons = [
      'Inappropriate content',
      'Spam',
      'Not related to temple',
      'Copyright violation',
      'Other',
    ];

    String? selectedReason;
    final additionalInfoController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Report Photo'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Why are you reporting this photo?'),
                const SizedBox(height: AppSpacing.md),
                ...reasons.map(
                  (reason) => RadioListTile<String>(
                    title: Text(reason),
                    value: reason,
                    groupValue: selectedReason,
                    onChanged: (value) {
                      setDialogState(() {
                        selectedReason = value;
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: additionalInfoController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Additional information (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: selectedReason == null
                  ? null
                  : () async {
                      Navigator.of(context).pop();
                      try {
                        await _photoGalleryService.reportPhoto(
                          photoId: widget.photoId,
                          reason: selectedReason!,
                          additionalInfo: additionalInfoController.text.trim(),
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Photo reported successfully'),
                              backgroundColor: AppColors.successGreen,
                            ),
                          );
                          Navigator.of(context).pop();
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error reporting photo: $e'),
                              backgroundColor: AppColors.errorRed,
                            ),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.errorRed,
              ),
              child: const Text('Report'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Photo'),
        content: const Text(
          'Are you sure you want to delete this photo? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await _photoGalleryService.deletePhoto(widget.photoId);
                if (mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Photo deleted successfully'),
                      backgroundColor: AppColors.successGreen,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error deleting photo: $e'),
                      backgroundColor: AppColors.errorRed,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorRed,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = widget.photoData['imageUrl'] as String;
    final userName = widget.photoData['userName'] as String? ?? 'Anonymous';
    final userPhotoUrl = widget.photoData['userPhotoUrl'] as String?;
    final caption = widget.photoData['caption'] as String?;
    final tags = List<String>.from(widget.photoData['tags'] ?? []);
    final createdAt = widget.photoData['createdAt'];
    final userId = widget.photoData['userId'] as String;
    final isOwnPhoto = _currentUser?.uid == userId;

    String formattedDate = '';
    if (createdAt != null) {
      try {
        final date = createdAt.toDate();
        formattedDate = DateFormat('MMM d, yyyy').format(date);
      } catch (e) {
        formattedDate = 'Unknown date';
      }
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (isOwnPhoto)
            IconButton(
              onPressed: _showDeleteDialog,
              icon: const Icon(Icons.delete),
              tooltip: 'Delete',
            )
          else
            IconButton(
              onPressed: _showReportDialog,
              icon: const Icon(Icons.flag),
              tooltip: 'Report',
            ),
        ],
      ),
      body: Column(
        children: [
          // Image
          Expanded(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  errorWidget: (context, url, error) => const Center(
                    child: Icon(
                      Icons.broken_image,
                      color: Colors.white,
                      size: 64,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Photo Info
          Container(
            color: Colors.black,
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User Info and Like Button
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.primaryOrange,
                      backgroundImage: userPhotoUrl != null
                          ? NetworkImage(userPhotoUrl)
                          : null,
                      child: userPhotoUrl == null
                          ? Text(
                              userName[0].toUpperCase(),
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
                          Text(
                            userName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            formattedDate,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _toggleLike,
                      icon: Icon(
                        _isLiked ? Icons.favorite : Icons.favorite_border,
                        color: _isLiked ? AppColors.errorRed : Colors.white,
                      ),
                    ),
                    Text(
                      _likes.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),

                // Caption
                if (caption != null && caption.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    caption,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ],

                // Tags
                if (tags.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: tags.map((tag) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryOrange.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.primaryOrange.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ),
                        child: Text(
                          tag,
                          style: const TextStyle(
                            color: AppColors.primaryOrange,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
