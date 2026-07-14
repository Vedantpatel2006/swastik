import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../../shared/models/temple.dart';
import '../../../core/themes/app_colors.dart';
import '../services/temple_status_service.dart';
import 'pulsing_live_badge.dart';

/// Grid temple card for grid layouts
class TempleCardGrid extends StatelessWidget {
  final Temple temple;
  final VoidCallback onTap;

  const TempleCardGrid({super.key, required this.temple, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: AppColors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildImage(),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildImage() {
    return SizedBox(
      width: 120,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(15),
            ),
            child: temple.images.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: temple.images.first,
                    height: 130,
                    width: 120,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Shimmer.fromColors(
                      baseColor: AppColors.lightGray,
                      highlightColor: AppColors.white,
                      child: Container(
                        width: 120,
                        height: 130,
                        color: AppColors.lightGray,
                      ),
                    ),
                    errorWidget: (context, url, error) =>
                        _buildPlaceholderImage(),
                  )
                : _buildPlaceholderImage(),
          ),
          if (temple.liveDarshan?.isCurrentlyLive == true)
            const Positioned(
              top: 8,
              left: 8,
              child: PulsingLiveBadge(asOverlay: true),
            ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildNameSection(),
          const SizedBox(height: 4),
          _buildLocationRow(),
          const SizedBox(height: 6),
          _buildStatusBadge(),
          const SizedBox(height: 6),
          _buildDistance(),
        ],
      ),
    );
  }

  Widget _buildNameSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          temple.name,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.primaryText,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (temple.mainDeity != null && temple.mainDeity!.isNotEmpty) ...[
          const SizedBox(height: 2),
          Row(
            children: [
              const Icon(
                Icons.auto_awesome,
                size: 10,
                color: AppColors.primaryOrange,
              ),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  temple.mainDeity!,
                  style: const TextStyle(
                    fontSize: 10,
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
      ],
    );
  }

  Widget _buildLocationRow() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.location_on, size: 11, color: AppColors.secondaryText),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            _locationText(),
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.secondaryText,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildDistance() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.navigation, size: 11, color: AppColors.primaryOrange),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            '${(temple.distanceFromUser ?? 0).toStringAsFixed(1)} km',
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.primaryText,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge() {
    final status = TempleStatusService.getTempleStatus(temple);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: status.isOpen ? AppColors.successGreen : AppColors.errorRed,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status.getStatusWithTime(),
        style: const TextStyle(
          fontSize: 9,
          color: AppColors.white,
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

  Widget _buildPlaceholderImage() {
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
      height: 130,
      width: 120,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Container(
        height: 130,
        width: 120,
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
