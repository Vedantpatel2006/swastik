import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/app_spacing.dart';
import '../../../shared/services/photo_gallery_service.dart';
import 'photo_detail_screen.dart';

class CommunityPhotoGrid extends StatefulWidget {
  final String templeId;

  const CommunityPhotoGrid({Key? key, required this.templeId})
    : super(key: key);

  @override
  State<CommunityPhotoGrid> createState() => _CommunityPhotoGridState();
}

class _CommunityPhotoGridState extends State<CommunityPhotoGrid> {
  final _photoGalleryService = PhotoGalleryService();
  final _currentUser = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _photoGalleryService.watchTemplePhotos(
        widget.templeId,
        limit: 50,
        approvedOnly: true,
        sortBy: 'createdAt',
        descending: true,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingGrid();
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 48,
                  color: AppColors.errorRed,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Error loading photos',
                  style: TextStyle(color: AppColors.secondaryText),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextButton(
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
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.photo_library_outlined,
                    size: 64,
                    color: AppColors.secondaryText.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'No community photos yet',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.secondaryText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Be the first to share your temple visit!',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.secondaryText.withValues(alpha: 0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
          ),
          itemCount: photos.length,
          itemBuilder: (context, index) {
            final photo = photos[index];
            return _buildPhotoTile(photo);
          },
        );
      },
    );
  }

  Widget _buildPhotoTile(Map<String, dynamic> photo) {
    final photoId = photo['id'] as String;
    final imageUrl = photo['imageUrl'] as String;
    final likes = photo['likes'] as int? ?? 0;
    final likedBy = List<String>.from(photo['likedBy'] ?? []);
    final isLiked = _currentUser != null && likedBy.contains(_currentUser.uid);

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) =>
                PhotoDetailScreen(photoId: photoId, photoData: photo),
          ),
        );
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            placeholder: (context, url) => Shimmer.fromColors(
              baseColor: AppColors.lightGray,
              highlightColor: AppColors.white,
              child: Container(color: AppColors.lightGray),
            ),
            errorWidget: (context, url, error) => Container(
              color: AppColors.lightGray,
              child: const Icon(
                Icons.broken_image,
                color: AppColors.secondaryText,
              ),
            ),
          ),
          // Gradient overlay for likes
          if (likes > 0)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.6),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isLiked ? Icons.favorite : Icons.favorite_border,
                      color: isLiked ? AppColors.errorRed : Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      likes.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLoadingGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: 9,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: AppColors.lightGray,
          highlightColor: AppColors.white,
          child: Container(color: AppColors.lightGray),
        );
      },
    );
  }
}
