import 'package:flutter/material.dart';

/// A widget that wraps temple images with Hero animation support
class TempleHeroImage extends StatelessWidget {
  final String heroTag;
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;
  final VoidCallback? onTap;

  const TempleHeroImage({
    super.key,
    required this.heroTag,
    this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget imageWidget;

    if (imageUrl != null && imageUrl!.isNotEmpty) {
      imageWidget = Image.network(
        imageUrl!,
        width: width,
        height: height,
        fit: fit,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return placeholder ?? _buildDefaultPlaceholder();
        },
        errorBuilder: (context, error, stackTrace) {
          return errorWidget ?? _buildDefaultErrorWidget();
        },
      );
    } else {
      imageWidget = errorWidget ?? _buildDefaultErrorWidget();
    }

    // Wrap with ClipRRect if borderRadius is provided
    if (borderRadius != null) {
      imageWidget = ClipRRect(borderRadius: borderRadius!, child: imageWidget);
    }

    // Wrap with Hero animation
    imageWidget = Hero(
      tag: heroTag,
      child: imageWidget,
      flightShuttleBuilder:
          (
            BuildContext flightContext,
            Animation<double> animation,
            HeroFlightDirection flightDirection,
            BuildContext fromHeroContext,
            BuildContext toHeroContext,
          ) {
            return AnimatedBuilder(
              animation: animation,
              builder: (context, child) {
                return Transform.scale(
                  scale: 1.0 + (animation.value * 0.1),
                  child: Material(
                    color: Colors.transparent,
                    child: imageWidget,
                  ),
                );
              },
            );
          },
    );

    // Add tap functionality if provided
    if (onTap != null) {
      imageWidget = GestureDetector(onTap: onTap, child: imageWidget);
    }

    return imageWidget;
  }

  Widget _buildDefaultPlaceholder() {
    return Container(
      width: width,
      height: height,
      color: const Color(0xFFF3F4F6),
      child: const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF7A00)),
        ),
      ),
    );
  }

  Widget _buildDefaultErrorWidget() {
    return Container(
      width: width,
      height: height,
      color: const Color(0xFFF3F4F6),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.temple_hindu, size: 48, color: Color(0xFF6B7280)),
          SizedBox(height: 8),
          Text('No Image', style: TextStyle(color: Color(0xFF6B7280))),
        ],
      ),
    );
  }
}

/// Extension to create hero tags for temple images
extension TempleHeroTags on String {
  String get templeImageHeroTag => 'temple_image_$this';
  String get templeCardHeroTag => 'temple_card_$this';
}
