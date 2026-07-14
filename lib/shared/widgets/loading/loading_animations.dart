import 'package:flutter/material.dart';
import 'package:swastik/core/themes/app_colors.dart';

class LoadingAnimations {
  static Widget shimmerLoading({
    double? width,
    double? height,
    BorderRadius? borderRadius,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: borderRadius ?? BorderRadius.circular(4),
      ),
    );
  }

  static Widget circularProgress({Color? color, double? size}) {
    return SizedBox(
      width: size ?? 24,
      height: size ?? 24,
      child: CircularProgressIndicator(
        color: color ?? AppColors.primaryOrange,
        strokeWidth: 2,
      ),
    );
  }

  static Widget linearProgress({Color? color, double? value}) {
    return LinearProgressIndicator(
      color: color ?? AppColors.primaryOrange,
      backgroundColor: Colors.grey[200],
      value: value,
    );
  }

  static Widget pulsingDot({Color? color, double? size}) {
    return Container(
      width: size ?? 8,
      height: size ?? 8,
      decoration: BoxDecoration(
        color: color ?? AppColors.primaryOrange,
        shape: BoxShape.circle,
      ),
    );
  }
}
