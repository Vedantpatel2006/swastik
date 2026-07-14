import 'package:flutter/material.dart';
import '../../../shared/models/temple.dart';
import '../../../core/themes/app_colors.dart';

/// Simple temple card widget with better error handling
class TempleCard extends StatelessWidget {
  final Temple temple;
  final VoidCallback? onTap;
  final bool showDistance;

  const TempleCard({
    super.key,
    required this.temple,
    this.onTap,
    this.showDistance = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SimpleTempleImageWidget(temple: temple),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SimpleTempleHeaderWidget(temple: temple),
                  const SizedBox(height: 8),
                  SimpleTempleDescriptionWidget(temple: temple),
                  const SizedBox(height: 12),
                  SimpleTempleFooterWidget(
                    temple: temple,
                    showDistance: showDistance,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Optimized simple temple image widget
class SimpleTempleImageWidget extends StatelessWidget {
  final Temple temple;

  const SimpleTempleImageWidget({super.key, required this.temple});

  @override
  Widget build(BuildContext context) {
    if (temple.images.isEmpty) {
      return const SimpleTempleImagePlaceholder();
    }

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      child: Image.network(
        temple.images.first,
        height: 200,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            const SimpleTempleImageError(),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return SimpleTempleImageLoading(loadingProgress: loadingProgress);
        },
      ),
    );
  }
}

/// Optimized simple temple image placeholder widget
class SimpleTempleImagePlaceholder extends StatelessWidget {
  const SimpleTempleImagePlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: AppColors.lightGray,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: const Center(
        child: Icon(
          Icons.temple_hindu,
          size: 48,
          color: AppColors.secondaryText,
        ),
      ),
    );
  }
}

/// Optimized simple temple image error widget
class SimpleTempleImageError extends StatelessWidget {
  const SimpleTempleImageError({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      color: AppColors.lightGray,
      child: const Center(
        child: Icon(
          Icons.temple_hindu,
          size: 48,
          color: AppColors.secondaryText,
        ),
      ),
    );
  }
}

/// Optimized simple temple image loading widget
class SimpleTempleImageLoading extends StatelessWidget {
  final ImageChunkEvent loadingProgress;

  const SimpleTempleImageLoading({super.key, required this.loadingProgress});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      color: AppColors.lightGray,
      child: Center(
        child: CircularProgressIndicator(
          value: loadingProgress.expectedTotalBytes != null
              ? loadingProgress.cumulativeBytesLoaded /
                    loadingProgress.expectedTotalBytes!
              : null,
          color: AppColors.primaryOrange,
        ),
      ),
    );
  }
}

/// Optimized simple temple header widget
class SimpleTempleHeaderWidget extends StatelessWidget {
  final Temple temple;

  const SimpleTempleHeaderWidget({super.key, required this.temple});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            temple.name,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (temple.liveDarshan?.isCurrentlyLive == true) ...[
          const SizedBox(width: 8),
          const SimpleTempleLiveIndicator(),
        ],
      ],
    );
  }
}

/// Optimized simple temple live indicator widget
class SimpleTempleLiveIndicator extends StatelessWidget {
  const SimpleTempleLiveIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.liveRed,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, color: Colors.white, size: 8),
          SizedBox(width: 4),
          Text(
            'LIVE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Optimized simple temple description widget
class SimpleTempleDescriptionWidget extends StatelessWidget {
  final Temple temple;

  const SimpleTempleDescriptionWidget({super.key, required this.temple});

  @override
  Widget build(BuildContext context) {
    return Text(
      temple.description.isNotEmpty
          ? temple.description
          : 'No description available',
      style: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(color: AppColors.secondaryText),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// Optimized simple temple footer widget
class SimpleTempleFooterWidget extends StatelessWidget {
  final Temple temple;
  final bool showDistance;

  const SimpleTempleFooterWidget({
    super.key,
    required this.temple,
    required this.showDistance,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.location_on, size: 16, color: AppColors.secondaryText),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            temple.location.address ??
                '${temple.location.city ?? ''}, ${temple.location.state ?? ''}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.secondaryText),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (showDistance && temple.distanceFromUser != null) ...[
          const SizedBox(width: 8),
          SimpleTempleDistanceBadge(distance: temple.distanceFromUser!),
        ],
      ],
    );
  }
}

/// Optimized simple temple distance badge widget
class SimpleTempleDistanceBadge extends StatelessWidget {
  final double distance;

  const SimpleTempleDistanceBadge({super.key, required this.distance});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primaryOrange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '${distance.toStringAsFixed(1)} km',
        style: const TextStyle(
          fontSize: 12,
          color: AppColors.primaryOrange,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
