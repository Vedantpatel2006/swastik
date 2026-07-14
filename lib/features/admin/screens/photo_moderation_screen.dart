import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/app_spacing.dart';
import '../../../core/themes/app_radius.dart';
import '../../../shared/services/photo_gallery_service.dart';

class PhotoModerationScreen extends StatefulWidget {
  const PhotoModerationScreen({Key? key}) : super(key: key);

  @override
  State<PhotoModerationScreen> createState() => _PhotoModerationScreenState();
}

class _PhotoModerationScreenState extends State<PhotoModerationScreen> {
  final _photoGalleryService = PhotoGalleryService();
  String _filterStatus = 'pending'; // pending, approved, all

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Photo Moderation'),
        backgroundColor: AppColors.primaryOrange,
        actions: [
          PopupMenuButton<String>(
            initialValue: _filterStatus,
            onSelected: (value) {
              setState(() {
                _filterStatus = value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'pending',
                child: Text('Pending Approval'),
              ),
              const PopupMenuItem(
                value: 'approved',
                child: Text('Approved'),
              ),
              const PopupMenuItem(
                value: 'all',
                child: Text('All Photos'),
              ),
            ],
          ),
        ],
      ),
      body: _buildPhotoList(),
    );
  }

  Widget _buildPhotoList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _buildPhotoStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 64,
                  color: AppColors.errorRed,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Error loading photos',
                  style: TextStyle(
                    fontSize: 18,
                    color: AppColors.secondaryText,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final photos = snapshot.data ?? [];

        if (photos.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 64,
                  color: AppColors.successGreen,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  _filterStatus == 'pending'
                      ? 'No pending photos'
                      : 'No photos found',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _filterStatus == 'pending'
                      ? 'All photos have been reviewed'
                      : 'No photos match the current filter',
                  style: TextStyle(
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.lg),
          itemCount: photos.length,
          itemBuilder: (context, index) {
            return _buildPhotoCard(photos[index]);
          },
        );
      },
    );
  }

  Stream<List<Map<String, dynamic>>> _buildPhotoStream() {
    return _photoGalleryService
        .watchTemplePhotos(
          '', // empty templeId = all temples (service handles this)
          approvedOnly: _filterStatus == 'approved',
          sortBy: 'createdAt',
          descending: true,
        )
        .map((photos) {
          if (_filterStatus == 'pending') {
            return photos.where((p) => p['isApproved'] != true).toList();
          } else if (_filterStatus == 'approved') {
            return photos.where((p) => p['isApproved'] == true).toList();
          }
          return photos;
        });
  }

  Widget _buildPhotoCard(Map<String, dynamic> photo) {
    final photoId = photo['id'] as String;
    final imageUrl = photo['imageUrl'] as String;
    final userName = photo['userName'] as String? ?? 'Anonymous';
    final caption = photo['caption'] as String?;
    final tags = List<String>.from(photo['tags'] ?? []);
    final likes = photo['likes'] as int? ?? 0;
    final isApproved = photo['isApproved'] as bool? ?? false;
    final createdAt = photo['createdAt'];

    String formattedDate = '';
    if (createdAt != null) {
      try {
        final date = createdAt.toDate();
        formattedDate = DateFormat('MMM d, yyyy h:mm a').format(date);
      } catch (e) {
        formattedDate = 'Unknown date';
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.lg),
            ),
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              width: double.infinity,
              height: 300,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                height: 300,
                color: AppColors.lightGray,
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                height: 300,
                color: AppColors.lightGray,
                child: const Icon(
                  Icons.broken_image,
                  size: 64,
                  color: AppColors.secondaryText,
                ),
              ),
            ),
          ),

          // Photo Info
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User and Date
                Row(
                  children: [
                    const Icon(
                      Icons.person,
                      size: 16,
                      color: AppColors.secondaryText,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      userName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      formattedDate,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),

                // Caption
                if (caption != null && caption.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    caption,
                    style: const TextStyle(fontSize: 14),
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
                          color: AppColors.primaryOrange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.primaryOrange.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          tag,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.primaryOrange,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],

                // Stats
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Icon(
                      Icons.favorite,
                      size: 16,
                      color: AppColors.errorRed,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      '$likes likes',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.secondaryText,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: isApproved
                            ? AppColors.successGreen.withValues(alpha: 0.1)
                            : AppColors.warningAmber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isApproved ? 'Approved' : 'Pending',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isApproved
                              ? AppColors.successGreen
                              : AppColors.warningAmber,
                        ),
                      ),
                    ),
                  ],
                ),

                // Action Buttons
                if (!isApproved) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _approvePhoto(photoId),
                          icon: const Icon(Icons.check),
                          label: const Text('Approve'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.successGreen,
                            minimumSize: const Size(0, 44),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showRejectDialog(photoId),
                          icon: const Icon(Icons.close),
                          label: const Text('Reject'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.errorRed,
                            side: const BorderSide(color: AppColors.errorRed),
                            minimumSize: const Size(0, 44),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                // Feature Button (for approved photos)
                if (isApproved) ...[
                  const SizedBox(height: AppSpacing.lg),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _toggleFeature(photoId, photo),
                      icon: Icon(
                        photo['isFeatured'] == true
                            ? Icons.star
                            : Icons.star_border,
                      ),
                      label: Text(
                        photo['isFeatured'] == true
                            ? 'Remove from Featured'
                            : 'Feature Photo',
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primaryOrange),
                        minimumSize: const Size(0, 44),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _approvePhoto(String photoId) async {
    try {
      await _photoGalleryService.approvePhoto(photoId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo approved successfully'),
            backgroundColor: AppColors.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error approving photo: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }

  void _showRejectDialog(String photoId) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Photo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Please provide a reason for rejection:'),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Reason for rejection...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please provide a reason'),
                  ),
                );
                return;
              }

              Navigator.of(context).pop();
              await _rejectPhoto(photoId, reason);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorRed,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  Future<void> _rejectPhoto(String photoId, String reason) async {
    try {
      await _photoGalleryService.rejectPhoto(photoId, reason);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo rejected'),
            backgroundColor: AppColors.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error rejecting photo: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }

  Future<void> _toggleFeature(String photoId, Map<String, dynamic> photo) async {
    final isFeatured = photo['isFeatured'] as bool? ?? false;

    try {
      await _photoGalleryService.featurePhoto(photoId, !isFeatured);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isFeatured
                  ? 'Photo removed from featured'
                  : 'Photo featured successfully',
            ),
            backgroundColor: AppColors.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating photo: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }
}
