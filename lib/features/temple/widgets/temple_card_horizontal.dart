import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../../shared/models/temple.dart';
import '../../../core/themes/app_colors.dart';
import '../services/temple_status_service.dart';
import 'pulsing_live_badge.dart';

/// Horizontal temple card for scrolling lists
class TempleCardHorizontal extends StatelessWidget {
  final Temple temple;
  final VoidCallback onTap;
  final bool showMargin;

  const TempleCardHorizontal({
    super.key,
    required this.temple,
    required this.onTap,
    this.showMargin = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 205,
        margin: EdgeInsets.only(right: showMargin ? 16 : 0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Image with badges
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(15),
                  ),
                  child: temple.images.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: temple.images.first,
                          height: 120,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Shimmer.fromColors(
                            baseColor: AppColors.lightGray,
                            highlightColor: AppColors.white,
                            child: Container(
                              height: 120,
                              color: AppColors.lightGray,
                            ),
                          ),
                          errorWidget: (context, url, error) =>
                              _buildPlaceholderImage(120),
                        )
                      : _buildPlaceholderImage(120),
                ),

                // Pulsing LIVE badge
                if (temple.liveDarshan?.isCurrentlyLive == true)
                  const Positioned(
                    top: 8,
                    left: 8,
                    child: PulsingLiveBadge(asOverlay: true),
                  ),
              ],
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Temple Name
                  Text(
                    temple.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryText,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // Deity name
                  if (temple.mainDeity != null &&
                      temple.mainDeity!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(
                          Icons.auto_awesome,
                          size: 11,
                          color: AppColors.primaryOrange,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            temple.mainDeity!,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.primaryOrange,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 6),

                  // Location
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 12,
                        color: AppColors.secondaryText,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _locationText(),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.secondaryText,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Status Badge
                  _buildStatusBadge(),

                  const SizedBox(height: 8),

                  // Distance
                  Row(
                    children: [
                      const Icon(
                        Icons.navigation,
                        size: 12,
                        color: AppColors.primaryOrange,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${(temple.distanceFromUser ?? 0).toStringAsFixed(1)} km',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.primaryText,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    final status = TempleStatusService.getTempleStatus(temple);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: status.isOpen ? AppColors.successGreen : AppColors.errorRed,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status.getStatusWithTime(),
        style: const TextStyle(
          fontSize: 10,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  String _locationText() {
    final parts = <String>[];
    if (temple.location.city?.isNotEmpty == true)
      parts.add(temple.location.city!);
    if (temple.location.state?.isNotEmpty == true)
      parts.add(temple.location.state!);
    return parts.isEmpty ? 'Location not available' : parts.join(', ');
  }

  Widget _buildPlaceholderImage(double height) {
    final placeholderImages = [
      'assets/images/deities/ganesha.png',
      'assets/images/deities/krishna.png',
      'assets/images/deities/hanuman.png',
      'assets/images/deities/durga.png',
      'assets/images/deities/lakshmi.png',
      'assets/images/deities/vishnu.png',
      'assets/images/deities/temple.png',
    ];
    final imageIndex = temple.id.hashCode % placeholderImages.length;
    return Image.asset(
      placeholderImages[imageIndex],
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Container(
        height: height,
        color: AppColors.lightGray,
        child: const Icon(
          Icons.temple_hindu,
          size: 50,
          color: AppColors.secondaryText,
        ),
      ),
    );
  }
}
