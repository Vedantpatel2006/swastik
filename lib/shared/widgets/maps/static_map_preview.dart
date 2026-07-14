import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Static map preview widget for temple locations
/// Requirement 5.4: Static map images for temple previews
class StaticMapPreview extends StatelessWidget {
  final double latitude;
  final double longitude;
  final int zoom;
  final double width;
  final double height;
  final String? apiKey;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;
  final String? fallbackText;

  const StaticMapPreview({
    super.key,
    required this.latitude,
    required this.longitude,
    this.zoom = 15,
    this.width = 300,
    this.height = 200,
    this.apiKey,
    this.onTap,
    this.borderRadius,
    this.fallbackText,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = _getStaticMapImageUrl(
      latitude: latitude,
      longitude: longitude,
      zoom: zoom,
      width: width.toInt(),
      height: height.toInt(),
      apiKey: apiKey,
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: borderRadius ?? BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: ClipRRect(
          borderRadius: borderRadius ?? BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            width: width,
            height: height,
            fit: BoxFit.cover,
            placeholder: (context, url) => _buildPlaceholder(),
            errorWidget: (context, url, error) => _buildErrorWidget(),
            // Memory optimization settings
            memCacheWidth: width.toInt(),
            memCacheHeight: height.toInt(),
            maxWidthDiskCache: width.toInt(),
            maxHeightDiskCache: height.toInt(),
          ),
        ),
      ),
    );
  }

  String _getStaticMapImageUrl({
    required double latitude,
    required double longitude,
    required int zoom,
    required int width,
    required int height,
    String? apiKey,
  }) {
    // Read from dotenv; caller can override via the apiKey parameter
    final key = apiKey ?? dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
    if (key.isEmpty) {
      // Return a placeholder URL that will trigger the error widget
      return 'https://maps.googleapis.com/maps/api/staticmap?key=MISSING';
    }
    return 'https://maps.googleapis.com/maps/api/staticmap?'
        'center=$latitude,$longitude'
        '&zoom=$zoom'
        '&size=${width}x$height'
        '&markers=color:red%7C$latitude,$longitude'
        '&key=$key';
  }

  Widget _buildPlaceholder() {
    return Container(
      width: width,
      height: height,
      color: Colors.grey.shade200,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map, size: 32, color: Colors.grey),
            SizedBox(height: 8),
            Text(
              'Loading map...',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      width: width,
      height: height,
      color: Colors.grey.shade100,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_on, size: 32, color: Colors.grey),
            const SizedBox(height: 8),
            Text(
              fallbackText ?? 'Map unavailable',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            if (onTap != null) ...[
              const SizedBox(height: 4),
              const Text(
                'Tap to view location',
                style: TextStyle(color: Colors.orange, fontSize: 10),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Compact static map preview for cards and lists
class CompactStaticMapPreview extends StatelessWidget {
  final double latitude;
  final double longitude;
  final double size;
  final VoidCallback? onTap;

  const CompactStaticMapPreview({
    super.key,
    required this.latitude,
    required this.longitude,
    this.size = 60,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return StaticMapPreview(
      latitude: latitude,
      longitude: longitude,
      width: size,
      height: size,
      zoom: 16,
      onTap: onTap,
      borderRadius: BorderRadius.circular(size / 2),
      fallbackText: 'Location',
    );
  }
}

/// Static map preview with temple marker overlay
class TempleStaticMapPreview extends StatelessWidget {
  final double latitude;
  final double longitude;
  final String templeName;
  final bool isLive;
  final double width;
  final double height;
  final VoidCallback? onTap;

  const TempleStaticMapPreview({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.templeName,
    this.isLive = false,
    this.width = 300,
    this.height = 200,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        StaticMapPreview(
          latitude: latitude,
          longitude: longitude,
          width: width,
          height: height,
          onTap: onTap,
          fallbackText: templeName,
        ),

        // Live indicator overlay
        if (isLive)
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: const Text(
                'LIVE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

        // Temple name overlay
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
            ),
            child: Text(
              templeName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),

        // Tap indicator
        if (onTap != null)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: const Icon(
                Icons.open_in_new,
                size: 12,
                color: Colors.grey,
              ),
            ),
          ),
      ],
    );
  }
}
