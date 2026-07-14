import 'package:flutter/material.dart';
import '../constants/deity_assets.dart';

/// Widget for displaying deity images with fallback to icons
class DeityImageWidget extends StatelessWidget {
  final String deityName;
  final double size;
  final Color? iconColor;
  final bool isSelected;

  const DeityImageWidget({
    super.key,
    required this.deityName,
    this.size = 28,
    this.iconColor,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final imagePath = DeityAssets.getDeityImagePath(deityName);
    final fallbackIconName = DeityAssets.getDeityFallbackIcon(deityName);
    
    // Try to load deity image first
    if (imagePath != null) {
      return Image.asset(
        imagePath,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          // Fallback to icon if image fails to load
          return _buildFallbackIcon(fallbackIconName);
        },
      );
    }
    
    // Use fallback icon if no image path
    return _buildFallbackIcon(fallbackIconName);
  }

  Widget _buildFallbackIcon(String? iconName) {
    IconData iconData;
    
    switch (iconName) {
      case 'temple_hindu':
        iconData = Icons.temple_hindu;
        break;
      case 'self_improvement':
        iconData = Icons.self_improvement;
        break;
      case 'fitness_center':
        iconData = Icons.fitness_center;
        break;
      case 'female':
        iconData = Icons.female;
        break;
      case 'spa':
        iconData = Icons.spa;
        break;
      case 'music_note':
        iconData = Icons.music_note;
        break;
      case 'architecture':
        iconData = Icons.architecture;
        break;
      case 'water_drop':
        iconData = Icons.water_drop;
        break;
      default:
        iconData = Icons.temple_hindu;
    }

    return Icon(
      iconData,
      color: iconColor ?? (isSelected ? Colors.white : Colors.grey[600]),
      size: size,
    );
  }
}