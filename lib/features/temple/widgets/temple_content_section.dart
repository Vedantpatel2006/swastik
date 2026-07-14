import 'package:flutter/material.dart';
import '../../../core/themes/app_colors.dart';
import '../../../shared/models/temple.dart';
import '../../../shared/widgets/safe_widgets.dart';

/// Optimized temple content section widget
/// Separated from TempleCard to improve performance and reusability
class TempleContentSection extends StatelessWidget {
  final Temple temple;
  final bool showLiveIndicator;
  final bool showDistance;
  final dynamic currentLiveDarshanInfo;
  final bool isLive;
  final AnimationController? liveIndicatorController;
  final VoidCallback? onLiveDarshanTap;

  const TempleContentSection({
    super.key,
    required this.temple,
    required this.showLiveIndicator,
    required this.showDistance,
    this.currentLiveDarshanInfo,
    this.isLive = false,
    this.liveIndicatorController,
    this.onLiveDarshanTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TempleNameWidget(templeName: temple.name.split(' ').map((word) => word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1)}' : '').join(' ')),
          const SizedBox(height: 4),
          TempleLocationWidget(location: temple.location),
          const SizedBox(height: 8),
          if (temple.traditions.isNotEmpty)
            TempleTraditionsWidget(traditions: temple.traditions),
          const SizedBox(height: 8),
          if (showLiveIndicator &&
              currentLiveDarshanInfo?.isConfiguredByAdmin == true)
            LiveDarshanSectionWidget(
              isLive: isLive,
              currentLiveDarshanInfo: currentLiveDarshanInfo,
              liveIndicatorController: liveIndicatorController,
              onLiveDarshanTap: onLiveDarshanTap,
              getNextDarshanTime: _getNextDarshanTime,
            ),
          TempleFooterWidget(temple: temple, showDistance: showDistance),
        ],
      ),
    );
  }

  String _getNextDarshanTime() {
    if (currentLiveDarshanInfo?.schedule.isEmpty == true) {
      return 'Check schedule';
    }

    final now = DateTime.now();
    final today = [
      'MON',
      'TUE',
      'WED',
      'THU',
      'FRI',
      'SAT',
      'SUN',
    ][now.weekday - 1];

    // Find today's schedules
    final todaySchedules = currentLiveDarshanInfo!.schedule
        .where(
          (schedule) =>
              schedule.daysOfWeek.contains(today) && schedule.isActive,
        )
        .toList();

    if (todaySchedules.isNotEmpty) {
      // Find the next schedule for today
      for (final schedule in todaySchedules) {
        final startTimeParts = schedule.startTime.split(':');
        final startHour = int.parse(startTimeParts[0]);
        final startMinute = int.parse(startTimeParts[1]);

        final scheduleTime = DateTime(
          now.year,
          now.month,
          now.day,
          startHour,
          startMinute,
        );

        if (scheduleTime.isAfter(now)) {
          return 'Next: ${schedule.name} at ${schedule.startTime}';
        }
      }
    }

    // If no schedule today, show next available
    return 'View schedule';
  }
}

/// Optimized temple name widget
class TempleNameWidget extends StatelessWidget {
  final String templeName;

  const TempleNameWidget({super.key, required this.templeName});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Temple name: $templeName',
      header: true,
      child: Text(
        templeName,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1F2937),
          letterSpacing: -0.3,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// Optimized temple location widget
class TempleLocationWidget extends StatelessWidget {
  final Location location;

  const TempleLocationWidget({super.key, required this.location});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Location: ${location.city ?? ''}, ${location.state ?? ''}',
      child: Row(
        children: [
          Icon(
            Icons.location_on,
            size: 15,
            color: const Color(0xFFFF6B35).withValues(alpha: 0.8),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              '${location.city ?? ''}, ${location.state ?? ''}',
              style: TextStyle(
                fontSize: 13,
                color: const Color(0xFF6B7280),
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Optimized live darshan section widget
class LiveDarshanSectionWidget extends StatelessWidget {
  final bool isLive;
  final dynamic currentLiveDarshanInfo;
  final AnimationController? liveIndicatorController;
  final VoidCallback? onLiveDarshanTap;
  final String Function() getNextDarshanTime;

  const LiveDarshanSectionWidget({
    super.key,
    required this.isLive,
    this.currentLiveDarshanInfo,
    this.liveIndicatorController,
    this.onLiveDarshanTap,
    required this.getNextDarshanTime,
  });

  @override
  Widget build(BuildContext context) {
    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isLive
            ? const Color(0xFFFF4444).withValues(alpha: 0.1)
            : AppColors.mediumGray,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isLive
              ? const Color(0xFFFF4444).withValues(alpha: 0.3)
              : Theme.of(context).dividerColor,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          LiveDarshanIconWidget(
            isLive: isLive,
            liveIndicatorController: liveIndicatorController,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: LiveDarshanInfoWidget(
              isLive: isLive,
              currentLiveDarshanInfo: currentLiveDarshanInfo,
              getNextDarshanTime: getNextDarshanTime,
            ),
          ),
          Icon(
            Icons.arrow_forward_ios,
            size: 12,
            color: AppColors.secondaryText,
          ),
        ],
      ),
    );

    if (onLiveDarshanTap == null) {
      return Padding(padding: const EdgeInsets.only(bottom: 8), child: content);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onLiveDarshanTap,
        child: content,
      ),
    );
  }
}

/// Optimized live darshan icon widget
class LiveDarshanIconWidget extends StatelessWidget {
  final bool isLive;
  final AnimationController? liveIndicatorController;

  const LiveDarshanIconWidget({
    super.key,
    required this.isLive,
    this.liveIndicatorController,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: liveIndicatorController ?? kAlwaysCompleteAnimation,
      builder: (context, child) {
        if (isLive && liveIndicatorController != null) {
          final pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
            CurvedAnimation(
              parent: liveIndicatorController!,
              curve: Curves.easeInOut,
            ),
          );

          return Transform.scale(
            scale: pulseAnimation.value,
            child: const Icon(
              Icons.videocam,
              size: 16,
              color: Color(0xFFFF4444),
            ),
          );
        } else {
          return Icon(
            Icons.videocam_outlined,
            size: 16,
            color: AppColors.secondaryText,
          );
        }
      },
    );
  }
}

/// Optimized live darshan info widget
class LiveDarshanInfoWidget extends StatelessWidget {
  final bool isLive;
  final dynamic currentLiveDarshanInfo;
  final String Function() getNextDarshanTime;

  const LiveDarshanInfoWidget({
    super.key,
    required this.isLive,
    this.currentLiveDarshanInfo,
    required this.getNextDarshanTime,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isLive ? 'Live Darshan Available' : 'Live Darshan Scheduled',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isLive ? const Color(0xFFFF4444) : AppColors.secondaryText,
          ),
        ),
        if (isLive && currentLiveDarshanInfo?.currentViewerCount != null)
          LiveViewerCountWidget(
            viewerCount: currentLiveDarshanInfo!.currentViewerCount,
          )
        else if (!isLive && currentLiveDarshanInfo?.schedule.isNotEmpty == true)
          NextDarshanTimeWidget(nextDarshanTime: getNextDarshanTime()),
      ],
    );
  }
}

/// Optimized live viewer count widget
class LiveViewerCountWidget extends StatelessWidget {
  final int viewerCount;

  const LiveViewerCountWidget({super.key, required this.viewerCount});

  @override
  Widget build(BuildContext context) {
    return Text(
      '$viewerCount watching now',
      style: const TextStyle(fontSize: 10, color: AppColors.secondaryText),
    );
  }
}

/// Optimized next darshan time widget
class NextDarshanTimeWidget extends StatelessWidget {
  final String nextDarshanTime;

  const NextDarshanTimeWidget({super.key, required this.nextDarshanTime});

  @override
  Widget build(BuildContext context) {
    return Text(
      nextDarshanTime,
      style: const TextStyle(fontSize: 10, color: AppColors.secondaryText),
    );
  }
}

/// Optimized temple footer widget
class TempleFooterWidget extends StatelessWidget {
  final Temple temple;
  final bool showDistance;

  const TempleFooterWidget({
    super.key,
    required this.temple,
    required this.showDistance,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (showDistance && temple.distanceFromUser != null) ...[
          SafeDistanceWidget(distance: temple.distanceFromUser),
          const Spacer(),
        ],
        if (temple.visitCount > 0)
          TempleVisitCountWidget(visitCount: temple.visitCount),
      ],
    );
  }
}

/// Optimized temple distance widget
class TempleDistanceWidget extends StatelessWidget {
  final double distance;

  const TempleDistanceWidget({super.key, required this.distance});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Distance: ${distance.toStringAsFixed(1)} kilometers',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.directions_walk, size: 14, color: AppColors.secondaryText),
          const SizedBox(width: 4),
          Text(
            '${distance.toStringAsFixed(1)} km',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.secondaryText,
            ),
          ),
        ],
      ),
    );
  }
}

/// Optimized temple visit count widget
class TempleVisitCountWidget extends StatelessWidget {
  final int visitCount;

  const TempleVisitCountWidget({super.key, required this.visitCount});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$visitCount visits recorded',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.people, size: 14, color: AppColors.secondaryText),
          const SizedBox(width: 4),
          Text(
            '$visitCount visits',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.secondaryText,
            ),
          ),
        ],
      ),
    );
  }
}

/// Optimized temple traditions widget
class TempleTraditionsWidget extends StatelessWidget {
  final List<String> traditions;

  const TempleTraditionsWidget({super.key, required this.traditions});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Spiritual traditions: ${traditions.take(2).join(', ')}',
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: traditions.take(3).map((tradition) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFFF6B35).withValues(alpha: 0.15),
                  const Color(0xFFFF6B35).withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFFF6B35).withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Text(
              tradition,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFFFF6B35),
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
