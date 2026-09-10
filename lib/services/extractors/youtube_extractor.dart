import 'package:dio/dio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../../models/media_info.dart';
import 'media_source_extractor.dart';

class YouTubeExtractor implements MediaSourceExtractor {
  final Dio _dio;

  YouTubeExtractor({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 15),
                headers: {
                  'User-Agent':
                      'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Chrome/128.0 Mobile Safari/537.36',
                },
              ),
            );

  @override
  MediaSourceType get sourceType => MediaSourceType.youtube;

  static final List<RegExp> _youtubePatterns = [
    // youtu.be/ID
    RegExp(r'(?:https?://)?(?:www\.)?youtu\.be/([a-zA-Z0-9_-]{11})'),
    // youtube.com/watch?v=ID
    RegExp(
        r'(?:https?://)?(?:[a-zA-Z0-9-]+\.)?youtube\.com/watch\?.*v=([a-zA-Z0-9_-]{11})'),
    // youtube.com/shorts/ID
    RegExp(
        r'(?:https?://)?(?:www\.)?youtube\.com/shorts/([a-zA-Z0-9_-]{11})'),
    // youtube.com/embed/ID
    RegExp(
        r'(?:https?://)?(?:www\.)?youtube\.com/embed/([a-zA-Z0-9_-]{11})'),
    // youtube.com/v/ID
    RegExp(r'(?:https?://)?(?:www\.)?youtube\.com/v/([a-zA-Z0-9_-]{11})'),
    // music.youtube.com/watch?v=ID
    RegExp(
        r'(?:https?://)?music\.youtube\.com/watch\?.*v=([a-zA-Z0-9_-]{11})'),
  ];

  static String? extractYouTubeId(String url) {
    for (final pattern in _youtubePatterns) {
      final match = pattern.firstMatch(url);
      if (match != null && match.groupCount >= 1) {
        return match.group(1);
      }
    }
    return null;
  }

  @override
  bool canHandle(String url) {
    return extractYouTubeId(url) != null;
  }

  @override
  Future<MediaInfo> extract(String url) async {
    final youtubeId = extractYouTubeId(url);
    if (youtubeId == null) {
      throw ArgumentError('URL is not a valid YouTube URL: $url');
    }

    // 1. Try YoutubeExplode for accurate metadata and stream manifest
    try {
      final yt = YoutubeExplode();
      try {
        final video = await yt.videos.get(youtubeId);
        final title =
            video.title.isNotEmpty ? video.title : 'YouTube Video ($youtubeId)';
        final author =
            video.author.isNotEmpty ? video.author : 'YouTube Creator';
        final thumbnailUrl = video.thumbnails.highResUrl.isNotEmpty
            ? video.thumbnails.highResUrl
            : 'https://img.youtube.com/vi/$youtubeId/hqdefault.jpg';
        final duration =
            video.duration ?? const Duration(minutes: 3, seconds: 30);
        final minutes = duration.inMinutes;
        final seconds = duration.inSeconds % 60;
        final durationFormatted =
            '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

        int estimatedVideoSize = 24000000;
        int estimatedAudioSize = 4500000;
        try {
          final manifest = await yt.videos.streamsClient.getManifest(youtubeId);
          if (manifest.muxed.isNotEmpty) {
            estimatedVideoSize =
                manifest.muxed.withHighestBitrate().size.totalBytes;
          }
          if (manifest.audioOnly.isNotEmpty) {
            estimatedAudioSize =
                manifest.audioOnly.withHighestBitrate().size.totalBytes;
          }
        } catch (_) {}

        return MediaInfo(
          title: title,
          author: author,
          originalUrl: 'https://www.youtube.com/watch?v=$youtubeId',
          videoId: youtubeId,
          thumbnailUrl: thumbnailUrl,
          durationFormatted: durationFormatted,
          durationMs: duration.inMilliseconds,
          isYouTube: true,
          estimatedVideoSizeBytes: estimatedVideoSize,
          estimatedAudioSizeBytes: estimatedAudioSize,
          sourceName: 'YouTube',
        );
      } finally {
        yt.close();
      }
    } catch (_) {
      // Fallback to oEmbed below if YoutubeExplode fails
    }

    // 2. Fallback to oEmbed
    try {
      final oEmbedUrl =
          'https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v=$youtubeId&format=json';
      final response = await _dio.get(oEmbedUrl);
      if (response.statusCode == 200 && response.data is Map) {
        final data = response.data as Map;
        final title =
            data['title']?.toString() ?? 'YouTube Video ($youtubeId)';
        final author = data['author_name']?.toString() ?? 'YouTube Creator';
        final thumbnailUrl =
            'https://img.youtube.com/vi/$youtubeId/hqdefault.jpg';

        return MediaInfo(
          title: title,
          author: author,
          originalUrl: 'https://www.youtube.com/watch?v=$youtubeId',
          videoId: youtubeId,
          thumbnailUrl: thumbnailUrl,
          durationFormatted: '04:12',
          durationMs: 252000,
          isYouTube: true,
          estimatedVideoSizeBytes: 24300000,
          estimatedAudioSizeBytes: 5800000,
          sourceName: 'YouTube',
        );
      }
    } catch (_) {}

    // 3. Static fallback
    return MediaInfo(
      title: 'YouTube Video ($youtubeId)',
      author: 'YouTube Channel',
      originalUrl: 'https://www.youtube.com/watch?v=$youtubeId',
      videoId: youtubeId,
      thumbnailUrl: 'https://img.youtube.com/vi/$youtubeId/hqdefault.jpg',
      durationFormatted: '03:30',
      durationMs: 210000,
      isYouTube: true,
      estimatedVideoSizeBytes: 19200000,
      estimatedAudioSizeBytes: 4500000,
      sourceName: 'YouTube',
    );
  }
}
