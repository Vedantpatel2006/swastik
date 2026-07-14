import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/themes/app_colors.dart';
import '../../../shared/models/temple.dart';
import '../services/live_darshan_service.dart';
import '../services/live_stream_service.dart';

/// Live darshan widget.
///
/// Strategy:
/// - Reads live status from Firestore (no YouTube API on build).
/// - When temple IS live  → shows thumbnail preview + "Watch on YouTube" + "Share".
/// - When temple NOT live → shows "Watch Channel" link so users can browse
///   past recordings or check manually.
/// - All playback happens in the YouTube app/browser via launchUrl().
/// - No in-app video player, no embed URLs.
class AutoLiveDarshanWidget extends StatefulWidget {
  final Temple temple;

  const AutoLiveDarshanWidget({super.key, required this.temple});

  @override
  State<AutoLiveDarshanWidget> createState() => _AutoLiveDarshanWidgetState();
}

class _AutoLiveDarshanWidgetState extends State<AutoLiveDarshanWidget> {
  final LiveDarshanService _liveDarshanService = LiveDarshanService();
  final LiveStreamService _liveStreamService = LiveStreamService();

  bool _isLoading = true;
  bool _isLive = false;
  bool _isLaunching = false;
  String? _errorMessage;

  // Thumbnail shown as preview card before user taps
  String? _thumbnailUrl;
  String? _streamTitle;

  // Fetched live darshan info — used for URL building (not the stale temple model)
  LiveDarshanInfo? _liveDarshanInfo;

  @override
  void initState() {
    super.initState();
    _loadLiveStatus();
  }

  // ─── Data loading ──────────────────────────────────────────────────────────

  Future<void> _loadLiveStatus() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _liveDarshanService.initialize();

      final liveDarshanInfo = await _liveDarshanService.getLiveDarshanInfo(
        widget.temple.id,
      );

      if (!mounted) return;

      final isLive = liveDarshanInfo?.isCurrentlyLive ?? false;

      // If live and we have a video ID, fetch thumbnail + title
      String? thumbnailUrl;
      String? streamTitle;

      if (isLive) {
        // Always prefer the freshly fetched info over the stale temple model
        final videoId = liveDarshanInfo?.currentLiveVideoId;

        if (videoId != null && videoId.isNotEmpty) {
          // YouTube thumbnail is free — no API quota used
          thumbnailUrl =
              'https://img.youtube.com/vi/$videoId/maxresdefault.jpg';

          // Only fetch title if we have a confirmed channel ID from the
          // fetched info — never use a fallback channel ID here, as that
          // would cause the singleton LiveStreamService cache to return
          // another temple's stream title.
          final channelId = liveDarshanInfo?.youtubeChannelId;
          if (channelId != null && channelId.isNotEmpty) {
            try {
              final info = await _liveStreamService.getLiveStreamInfo(
                channelId,
              );
              if (info.isLive && info.title != null) {
                streamTitle = info.title;
              }
            } catch (_) {
              // Title is optional — silently ignore
            }
          }
        }
      }

      setState(() {
        _isLoading = false;
        _isLive = isLive;
        _liveDarshanInfo = liveDarshanInfo;
        _thumbnailUrl = thumbnailUrl;
        _streamTitle = streamTitle;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Could not check live status. Tap to retry.';
      });
    }
  }

  // ─── URL helpers ───────────────────────────────────────────────────────────

  /// Returns the best available YouTube URL for this temple.
  /// Priority: live video > channel URL > channel ID fallback.
  /// Always uses the freshly fetched [_liveDarshanInfo], never the stale
  /// temple model, so two temples with different channels never share a URL.
  String? _buildYouTubeUrl({bool preferChannel = false}) {
    // Use fetched info first; fall back to temple model only if fetch hasn't
    // completed yet (e.g. still loading).
    final channelId =
        _liveDarshanInfo?.youtubeChannelId ??
        widget.temple.liveDarshan?.youtubeChannelId;
    final channelUrl =
        _liveDarshanInfo?.youtubeChannelUrl ??
        widget.temple.liveDarshan?.youtubeChannelUrl;
    final liveVideoId = _liveDarshanInfo?.currentLiveVideoId;

    if (!preferChannel && liveVideoId != null && liveVideoId.isNotEmpty) {
      return _liveStreamService.getYouTubeWatchUrl(liveVideoId);
    }

    if (channelUrl != null && channelUrl.isNotEmpty) {
      return channelUrl;
    }

    if (channelId != null && channelId.isNotEmpty) {
      return _liveStreamService.getYouTubeChannelUrl(channelId);
    }

    return null;
  }

  // ─── Actions ───────────────────────────────────────────────────────────────

  Future<void> _openYouTube({bool preferChannel = false}) async {
    final url = _buildYouTubeUrl(preferChannel: preferChannel);

    if (url == null) {
      _showSnackBar(
        'No YouTube channel configured for this temple.',
        isError: true,
      );
      return;
    }

    setState(() => _isLaunching = true);

    try {
      final uri = Uri.parse(url);
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && mounted) {
        // YouTube app not installed — try browser
        final browserLaunched = await launchUrl(
          uri,
          mode: LaunchMode.platformDefault,
        );
        if (!browserLaunched && mounted) {
          _showSnackBar(
            'Could not open YouTube. Please install the YouTube app.',
            isError: true,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Could not open YouTube: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLaunching = false);
    }
  }

  Future<void> _shareLiveLink() async {
    final url = _buildYouTubeUrl();
    if (url == null) {
      _showSnackBar('No YouTube link available to share.', isError: true);
      return;
    }

    HapticFeedback.lightImpact();

    final templeName = widget.temple.name;
    final message = _isLive
        ? '🔴 $templeName is LIVE on YouTube!\nWatch darshan now: $url'
        : '🙏 Watch $templeName on YouTube: $url';

    await Share.share(message, subject: '$templeName — Live Darshan');
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.errorRed : AppColors.successGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Use fetched info once available; fall back to temple model while loading.
    final isConfigured =
        _liveDarshanInfo?.isConfiguredByAdmin ??
        widget.temple.liveDarshan?.isConfiguredByAdmin ??
        false;

    // Only render if admin has configured live darshan
    if (!_isLoading && !isConfigured) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isLive
              ? AppColors.liveRed.withValues(alpha: 0.3)
              : AppColors.borderGray,
        ),
        boxShadow: [
          BoxShadow(
            color: (_isLive ? AppColors.liveRed : Colors.black).withValues(
              alpha: 0.06,
            ),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          _buildHeader(),

          // Thumbnail preview (only when live and thumbnail available)
          if (_isLive && _thumbnailUrl != null) _buildThumbnailPreview(),

          // Action buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _buildActionButtons(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (_isLive ? AppColors.liveRed : AppColors.primaryOrange)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _isLive ? Icons.live_tv : Icons.tv,
              color: _isLive ? AppColors.liveRed : AppColors.primaryOrange,
              size: 22,
            ),
          ),

          const SizedBox(width: 12),

          // Title + subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isLive ? 'Live Darshan' : 'Live Darshan',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _isLive ? AppColors.liveRed : AppColors.primaryText,
                  ),
                ),
                const SizedBox(height: 2),
                _buildSubtitle(),
              ],
            ),
          ),

          // Loading indicator
          if (_isLoading)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }

  Widget _buildSubtitle() {
    if (_isLoading) {
      return Text(
        'Checking live status…',
        style: TextStyle(fontSize: 12, color: AppColors.secondaryText),
      );
    }

    if (_errorMessage != null) {
      return GestureDetector(
        onTap: _loadLiveStatus,
        child: Text(
          _errorMessage!,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.errorRed,
            decoration: TextDecoration.underline,
          ),
        ),
      );
    }

    if (_isLive) {
      return Text(
        _streamTitle ?? 'Streaming now on YouTube',
        style: TextStyle(
          fontSize: 12,
          color: AppColors.liveRed.withValues(alpha: 0.8),
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    return Text(
      'Not live right now — channel available',
      style: TextStyle(fontSize: 12, color: AppColors.secondaryText),
    );
  }

  /// Thumbnail preview card shown before the user taps Watch.
  Widget _buildThumbnailPreview() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: GestureDetector(
        onTap: _isLaunching ? null : () => _openYouTube(),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            children: [
              // Thumbnail image
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  _thumbnailUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: AppColors.lightGray,
                    child: const Center(
                      child: Icon(
                        Icons.temple_hindu,
                        size: 48,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ),
                  loadingBuilder: (_, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      color: AppColors.lightGray,
                      child: const Center(child: CircularProgressIndicator()),
                    );
                  },
                ),
              ),

              // Dark overlay + play icon
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.5),
                      ],
                    ),
                  ),
                ),
              ),

              // Play button
              const Positioned.fill(
                child: Center(
                  child: Icon(
                    Icons.play_circle_filled,
                    size: 56,
                    color: Colors.white,
                  ),
                ),
              ),

              // "Opens in YouTube" label
              const Positioned(
                bottom: 10,
                right: 10,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.open_in_new, color: Colors.white, size: 13),
                    SizedBox(width: 4),
                    Text(
                      'Opens in YouTube',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    if (_isLoading) {
      return const SizedBox(
        height: 44,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_isLive) {
      // Live: primary = Watch on YouTube, secondary = Share
      return Row(
        children: [
          Expanded(
            flex: 3,
            child: _PrimaryButton(
              label: 'Watch on YouTube',
              icon: Icons.play_arrow_rounded,
              color: AppColors.liveRed,
              isLoading: _isLaunching,
              onTap: () => _openYouTube(),
            ),
          ),
          const SizedBox(width: 10),
          _IconActionButton(
            icon: Icons.share_rounded,
            tooltip: 'Share live link',
            color: AppColors.liveRed,
            onTap: _shareLiveLink,
          ),
        ],
      );
    }

    // Not live: show Watch Channel + Share
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: _PrimaryButton(
            label: 'Watch Channel',
            icon: Icons.subscriptions_outlined,
            color: AppColors.primaryOrange,
            isLoading: _isLaunching,
            onTap: () => _openYouTube(preferChannel: true),
          ),
        ),
        const SizedBox(width: 10),
        _IconActionButton(
          icon: Icons.share_rounded,
          tooltip: 'Share channel link',
          color: AppColors.primaryOrange,
          onTap: _shareLiveLink,
        ),
      ],
    );
  }

  @override
  void dispose() {
    // Do NOT call _liveDarshanService.dispose() — it is a singleton shared
    // across all widgets. Disposing it here would break other temple widgets
    // that are still alive on the same screen.
    super.dispose();
  }
}

// ─── Small reusable button widgets ────────────────────────────────────────────

class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isLoading;
  final VoidCallback onTap;

  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: ElevatedButton.icon(
        onPressed: isLoading ? null : onTap,
        icon: isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(icon, size: 20),
        label: Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: color.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 0,
        ),
      ),
    );
  }
}

class _IconActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  const _IconActionButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            border: Border.all(color: color.withValues(alpha: 0.4)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }
}
