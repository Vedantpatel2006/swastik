import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../shared/models/temple.dart';
import '../services/live_darshan_service.dart';
import '../widgets/darshan_schedule_widget.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/loading_widget.dart';

/// Live Darshan screen — shows live status and opens the stream on YouTube.
/// No in-app player is used; YouTube handles the playback.
class LiveDarshanScreen extends StatefulWidget {
  final String templeId;
  final String templeName;
  final String? videoId;
  final LiveDarshanInfo? liveDarshanInfo;
  final LiveDarshanService? liveDarshanService;

  const LiveDarshanScreen({
    super.key,
    required this.templeId,
    required this.templeName,
    this.videoId,
    this.liveDarshanInfo,
    this.liveDarshanService,
  });

  @override
  State<LiveDarshanScreen> createState() => _LiveDarshanScreenState();
}

class _LiveDarshanScreenState extends State<LiveDarshanScreen> {
  late final LiveDarshanService _liveDarshanService;
  LiveDarshanInfo? _liveDarshanInfo;
  bool _isLoading = true;
  bool _isOpening = false;

  @override
  void initState() {
    super.initState();
    _liveDarshanService = widget.liveDarshanService ?? LiveDarshanService();
    _loadInfo();
  }

  Future<void> _loadInfo() async {
    try {
      final info =
          widget.liveDarshanInfo ??
          await _liveDarshanService.getLiveDarshanInfo(widget.templeId);
      if (!mounted) return;
      setState(() {
        _liveDarshanInfo = info;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  String? get _youtubeUrl {
    final videoId = widget.videoId ?? _liveDarshanInfo?.currentLiveVideoId;
    if (videoId != null) {
      return 'https://www.youtube.com/watch?v=$videoId';
    }
    final channelUrl = _liveDarshanInfo?.youtubeChannelUrl;
    if (channelUrl != null) return channelUrl;
    final channelId = _liveDarshanInfo?.youtubeChannelId;
    if (channelId != null) {
      return 'https://www.youtube.com/channel/$channelId';
    }
    return null;
  }

  Future<void> _openYouTube() async {
    final url = _youtubeUrl;
    if (url == null) return;
    setState(() => _isOpening = true);
    try {
      final uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open YouTube: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isOpening = false);
    }
  }

  void _share() {
    final url = _youtubeUrl;
    if (url == null) return;
    final text = 'Watch live darshan at ${widget.templeName}: $url';
    SystemChannels.platform.invokeMethod('Share.share', {
      'text': text,
      'subject': 'Live Darshan — ${widget.templeName}',
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLive = _liveDarshanInfo?.isCurrentlyLive ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text('Live Darshan — ${widget.templeName}'),
        actions: [
          if (_youtubeUrl != null)
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: _share,
              tooltip: 'Share',
            ),
        ],
      ),
      body: _isLoading
          ? LoadingStates.liveDarshan()
          : _liveDarshanInfo?.isConfiguredByAdmin != true
          ? EmptyStateWidget(
              title: 'Live Darshan Not Available',
              subtitle:
                  'This temple has not set up live darshan yet. Check back later.',
              icon: Icons.videocam_off,
              iconColor: Colors.orange[400],
              onAction: () => Navigator.of(context).pop(),
              actionText: 'Go Back',
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Status card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isLive
                          ? Colors.red.shade50
                          : colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isLive
                            ? Colors.red.shade200
                            : colorScheme.outlineVariant,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: isLive ? Colors.red : Colors.grey.shade400,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.live_tv,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isLive
                                    ? 'Currently Live'
                                    : 'Not Live Right Now',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isLive
                                      ? Colors.red.shade700
                                      : Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isLive
                                    ? 'Stream is active on YouTube'
                                    : 'Check the schedule below for upcoming darhans',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isLive)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.circle,
                                  color: Colors.white,
                                  size: 7,
                                ),
                                SizedBox(width: 5),
                                Text(
                                  'LIVE',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Watch on YouTube button
                  if (_youtubeUrl != null)
                    FilledButton.icon(
                      onPressed: _isOpening ? null : _openYouTube,
                      icon: _isOpening
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.play_circle_outline),
                      label: Text(
                        isLive
                            ? 'Watch Live on YouTube'
                            : 'Open YouTube Channel',
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: isLive
                            ? Colors.red
                            : colorScheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                  // Schedule
                  if (_liveDarshanInfo!.schedule.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    const Text(
                      'Darshan Schedule',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DarshanScheduleWidget(
                      schedules: _liveDarshanInfo!.schedule,
                      showCurrentTime: true,
                      highlightCurrentSchedule: true,
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
    // Do NOT dispose the singleton LiveDarshanService here.
    super.dispose();
  }
}
