/// Lightweight live darshan info model used in shared contexts.
///
/// Note: viewerCount and availableQualities are intentionally removed.
/// - viewerCount requires the quota-heavy liveStreamingDetails YouTube API
///   part and was previously mocked. It is not shown in the UI.
/// - availableQualities is irrelevant — there is no in-app video player.
///   Quality is managed natively by the YouTube app/browser.
///
/// The canonical full model is LiveDarshanInfo in shared/models/temple.dart.
class LiveDarshanInfo {
  final String? youtubeChannelId;
  final String? currentLiveVideoId;
  final bool isConfiguredByAdmin;

  const LiveDarshanInfo({
    this.youtubeChannelId,
    this.currentLiveVideoId,
    this.isConfiguredByAdmin = false,
  });

  factory LiveDarshanInfo.fromJson(Map<String, dynamic> json) {
    return LiveDarshanInfo(
      youtubeChannelId: json['youtubeChannelId'] as String?,
      currentLiveVideoId: json['currentLiveVideoId'] as String?,
      isConfiguredByAdmin: json['isConfiguredByAdmin'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'youtubeChannelId': youtubeChannelId,
    'currentLiveVideoId': currentLiveVideoId,
    'isConfiguredByAdmin': isConfiguredByAdmin,
  };
}
