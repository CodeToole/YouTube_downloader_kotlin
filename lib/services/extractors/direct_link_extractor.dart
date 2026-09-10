import 'dart:io';
import 'package:dio/dio.dart';
import '../../models/media_info.dart';
import 'media_source_extractor.dart';

class DirectLinkExtractor implements MediaSourceExtractor {
  final Dio _dio;

  static const List<String> supportedExtensions = [
    '.mp4',
    '.webm',
    '.m4a',
    '.mp3',
    '.mov',
    '.mkv',
    '.wav',
    '.aac',
    '.ogg',
    '.flac',
  ];

  DirectLinkExtractor({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 15),
                headers: {
                  'User-Agent':
                      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36',
                },
              ),
            );

  @override
  MediaSourceType get sourceType => MediaSourceType.directMedia;

  @override
  bool canHandle(String url) {
    return isDirectMediaUrl(url);
  }

  static bool isDirectMediaUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || (!uri.isScheme('http') && !uri.isScheme('https'))) {
      return false;
    }
    final path = uri.path.toLowerCase();
    return supportedExtensions.any((ext) => path.endsWith(ext));
  }

  static String extractTitleFromUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    final path = uri?.path ?? '';
    var filename = path.isNotEmpty ? path.split('/').last : 'Media Stream';
    if (filename.contains('?')) {
      filename = filename.split('?').first;
    }

    // Strip extension if present
    for (final ext in supportedExtensions) {
      if (filename.toLowerCase().endsWith(ext)) {
        filename = filename.substring(0, filename.length - ext.length);
        break;
      }
    }

    // Replace URL-encoded spaces and separators with spaces
    filename = filename
        .replaceAll('%20', ' ')
        .replaceAll(RegExp(r'[_+\-]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (filename.isEmpty) {
      filename = 'Direct Media Stream';
    }

    return _capitalizeWords(filename);
  }

  static String _capitalizeWords(String str) {
    return str
        .split(' ')
        .map((w) =>
            w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
        .join(' ');
  }

  @override
  Future<MediaInfo> extract(String url) async {
    final cleanUrl = url.trim();
    final uri = Uri.tryParse(cleanUrl);
    final title = extractTitleFromUrl(cleanUrl);
    final author =
        uri?.host.isNotEmpty == true ? uri!.host : 'Direct Stream';

    final lower = cleanUrl.toLowerCase();
    final isAudio = lower.contains('.mp3') ||
        lower.contains('.m4a') ||
        lower.contains('.wav') ||
        lower.contains('.aac') ||
        lower.contains('.flac');

    int fileSize = 0;
    String? probedContentType;

    // Probe file size via HTTP HEAD
    try {
      final headResponse = await _dio.head(
        cleanUrl,
        options: Options(
          followRedirects: true,
          maxRedirects: 5,
        ),
      );

      final contentLength =
          headResponse.headers.value(HttpHeaders.contentLengthHeader);
      if (contentLength != null) {
        fileSize = int.tryParse(contentLength) ?? 0;
      }
      probedContentType =
          headResponse.headers.value(HttpHeaders.contentTypeHeader);
    } catch (_) {
      // If HEAD fails (e.g. 405 Method Not Allowed), try GET Range: bytes=0-0
      try {
        final rangeResponse = await _dio.get(
          cleanUrl,
          options: Options(
            headers: {'Range': 'bytes=0-0'},
            followRedirects: true,
            maxRedirects: 5,
          ),
        );
        final contentRange = rangeResponse.headers.value('content-range');
        if (contentRange != null && contentRange.contains('/')) {
          final totalStr = contentRange.split('/').last;
          fileSize = int.tryParse(totalStr) ?? 0;
        } else {
          final contentLength =
              rangeResponse.headers.value(HttpHeaders.contentLengthHeader);
          if (contentLength != null) {
            fileSize = int.tryParse(contentLength) ?? 0;
          }
        }
        probedContentType =
            rangeResponse.headers.value(HttpHeaders.contentTypeHeader);
      } catch (_) {}
    }

    final isDetectedAudio = isAudio ||
        (probedContentType != null &&
            probedContentType.toLowerCase().startsWith('audio/'));

    final defaultVideoSize = 15000000;
    final defaultAudioSize = 3500000;
    final finalSize = fileSize > 0
        ? fileSize
        : (isDetectedAudio ? defaultAudioSize : defaultVideoSize);

    return MediaInfo(
      title: title,
      author: author,
      originalUrl: cleanUrl,
      videoId: null,
      thumbnailUrl: isDetectedAudio
          ? 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=600'
          : 'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=600',
      durationFormatted: isDetectedAudio ? '03:15' : '02:45',
      durationMs: isDetectedAudio ? 195000 : 165000,
      isYouTube: false,
      estimatedVideoSizeBytes: isDetectedAudio ? 0 : finalSize,
      estimatedAudioSizeBytes: isDetectedAudio ? finalSize : defaultAudioSize,
      directStreamUrl: cleanUrl,
      sourceName: 'Direct Media Link',
    );
  }
}
