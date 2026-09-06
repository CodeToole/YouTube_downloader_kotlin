class MediaInfo {
  final String title;
  final String author;
  final String originalUrl;
  final String? videoId;
  final String thumbnailUrl;
  final String durationFormatted;
  final int durationMs;
  final bool isYouTube;
  final int estimatedVideoSizeBytes;
  final int estimatedAudioSizeBytes;

  MediaInfo({
    required this.title,
    required this.author,
    required this.originalUrl,
    this.videoId,
    required this.thumbnailUrl,
    required this.durationFormatted,
    required this.durationMs,
    required this.isYouTube,
    required this.estimatedVideoSizeBytes,
    required this.estimatedAudioSizeBytes,
  });

  Map<String, dynamic> toMap() => {
        'title': title,
        'author': author,
        'originalUrl': originalUrl,
        'videoId': videoId,
        'thumbnailUrl': thumbnailUrl,
        'durationFormatted': durationFormatted,
        'durationMs': durationMs,
        'isYouTube': isYouTube ? 1 : 0,
        'estimatedVideoSizeBytes': estimatedVideoSizeBytes,
        'estimatedAudioSizeBytes': estimatedAudioSizeBytes,
      };

  factory MediaInfo.fromMap(Map<String, dynamic> map) => MediaInfo(
        title: map['title'] ?? 'Unknown Media',
        author: map['author'] ?? 'Unknown Author',
        originalUrl: map['originalUrl'] ?? '',
        videoId: map['videoId'],
        thumbnailUrl: map['thumbnailUrl'] ?? '',
        durationFormatted: map['durationFormatted'] ?? '00:00',
        durationMs: map['durationMs'] ?? 0,
        isYouTube: map['isYouTube'] == 1 || map['isYouTube'] == true,
        estimatedVideoSizeBytes: map['estimatedVideoSizeBytes'] ?? 0,
        estimatedAudioSizeBytes: map['estimatedAudioSizeBytes'] ?? 0,
      );
}
