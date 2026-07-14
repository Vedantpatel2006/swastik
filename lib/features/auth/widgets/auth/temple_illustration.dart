import 'package:flutter/material.dart';
import 'package:swastik/core/themes/app_colors.dart';

class TempleIllustration extends StatelessWidget {
  final double width;
  final double height;

  const TempleIllustration({
    super.key,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFE4CC), Color(0xFFFFF8F0)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        children: [
          // Background temple silhouette
          Positioned(
            bottom: height * 0.1,
            left: width * 0.2,
            child: Container(
              width: width * 0.6,
              height: height * 0.4,
              decoration: BoxDecoration(
                color: AppColors.primaryOrange.withValues(alpha: 0.2),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
            ),
          ),

          // Temple icon in center
          Center(
            child: Container(
              width: width * 0.3,
              height: width * 0.3,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primaryOrange, AppColors.lightOrange],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.temple_hindu,
                color: Colors.white,
                size: width * 0.15,
              ),
            ),
          ),

          // Decorative elements
          Positioned(
            top: height * 0.2,
            right: width * 0.1,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: const Color(0xFF00B3AC).withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
            ),
          ),

          Positioned(
            top: height * 0.3,
            left: width * 0.1,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: const Color(0xFFFFB366).withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
