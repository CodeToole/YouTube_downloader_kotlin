import 'dart:io';
import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;
import '../../models/media_info.dart';
import 'media_source_extractor.dart';

class GenericWebExtractor implements MediaSourceExtractor {
  final Dio _dio;

  GenericWebExtractor({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 12),
                receiveTimeout: const Duration(seconds: 15),
                headers: {
                  'User-Agent':
                      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36',
                  'Accept':
                      'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
                  'Accept-Language': 'en-US,en;q=0.9',
                },
              ),
            );

  @override
  MediaSourceType get sourceType => MediaSourceType.genericWeb;

  @override
  bool canHandle(String url) {
    final uri = Uri.tryParse(url.trim());
    return uri != null && (uri.isScheme('http') || uri.isScheme('https'));
  }

  @override
  Future<MediaInfo> extract(String url) async {
    final cleanUrl = url.trim();
    final pageUri = Uri.parse(cleanUrl);

    String? htmlContent;
    try {
      final response = await _dio.get<String>(
        cleanUrl,
        options: Options(
          responseType: ResponseType.plain,
          followRedirects: true,
          maxRedirects: 5,
        ),
      );
      htmlContent = response.data;
    } catch (e) {
      // If page fetch fails, fallback to basic web stream metadata
      return _buildFallback(pageUri, cleanUrl);
    }

    if (htmlContent == null || htmlContent.trim().isEmpty) {
      return _buildFallback(pageUri, cleanUrl);
    }

    final document = html_parser.parse(htmlContent);

    // 1. Extract Direct Video Stream Link
    String? streamUrl;

    // Check OpenGraph video meta tags
    final ogVideoTags = [
      'og:video',
      'og:video:url',
      'og:video:secure_url',
      'twitter:player:stream',
    ];

    for (final tag in ogVideoTags) {
      final meta = document.querySelector('meta[property="$tag"]') ??
          document.querySelector('meta[name="$tag"]');
      final content = meta?.attributes['content']?.trim();
      if (content != null && content.isNotEmpty) {
        streamUrl = content;
        break;
      }
    }

    // Check <video> and <source> tags if not found in meta tags
    if (streamUrl == null || streamUrl.isEmpty) {
      final videoElements = document.querySelectorAll('video');
      for (final video in videoElements) {
        final src = video.attributes['src']?.trim();
        if (src != null && src.isNotEmpty) {
          streamUrl = src;
          break;
        }

        final sourceElements = video.querySelectorAll('source');
        for (final source in sourceElements) {
          final sSrc = source.attributes['src']?.trim();
          if (sSrc != null && sSrc.isNotEmpty) {
            streamUrl = sSrc;
            break;
          }
        }
        if (streamUrl != null) break;
      }
    }

    // Resolve relative stream URL to absolute
    if (streamUrl != null && streamUrl.isNotEmpty) {
      try {
        streamUrl = pageUri.resolve(streamUrl).toString();
      } catch (_) {}
    }

    // 2. Extract Thumbnail Art
    String? thumbnailUrl;
    final ogImageTags = [
      'og:image',
      'og:image:url',
      'og:image:secure_url',
      'twitter:image',
      'twitter:image:src',
    ];

    for (final tag in ogImageTags) {
      final meta = document.querySelector('meta[property="$tag"]') ??
          document.querySelector('meta[name="$tag"]');
      final content = meta?.attributes['content']?.trim();
      if (content != null && content.isNotEmpty) {
        thumbnailUrl = content;
        break;
      }
    }

    // Also check <video poster="...">
    if (thumbnailUrl == null || thumbnailUrl.isEmpty) {
      final videoPoster =
          document.querySelector('video')?.attributes['poster']?.trim();
      if (videoPoster != null && videoPoster.isNotEmpty) {
        thumbnailUrl = videoPoster;
      }
    }

    if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
      try {
        thumbnailUrl = pageUri.resolve(thumbnailUrl).toString();
      } catch (_) {}
    } else {
      thumbnailUrl =
          'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=600';
    }

    // 3. Extract Title
    String? title;
    final ogTitleTags = [
      'og:title',
      'twitter:title',
    ];

    for (final tag in ogTitleTags) {
      final meta = document.querySelector('meta[property="$tag"]') ??
          document.querySelector('meta[name="$tag"]');
      final content = meta?.attributes['content']?.trim();
      if (content != null && content.isNotEmpty) {
        title = content;
        break;
      }
    }

    if (title == null || title.isEmpty) {
      final titleElem = document.querySelector('title');
      if (titleElem != null && titleElem.text.trim().isNotEmpty) {
        title = titleElem.text.trim();
      }
    }

    if (title == null || title.isEmpty) {
      final pathPart = pageUri.pathSegments.isNotEmpty
          ? pageUri.pathSegments.last
          : pageUri.host;
      title = pathPart
          .replaceAll('%20', ' ')
          .replaceAll(RegExp(r'[_+\-]+'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (title.isEmpty) title = 'Web Video Stream';
    }

    // 4. Extract Author / Site Name
    String? author;
    final siteNameMeta = document.querySelector('meta[property="og:site_name"]');
    if (siteNameMeta?.attributes['content'] != null) {
      author = siteNameMeta!.attributes['content']!.trim();
    }
    author ??= pageUri.host;

    // 5. Probe file size of extracted stream if available
    int estimatedSizeBytes = 18000000;
    if (streamUrl != null && streamUrl.isNotEmpty) {
      try {
        final headRes = await _dio.head(
          streamUrl,
          options: Options(
            followRedirects: true,
            maxRedirects: 5,
          ),
        );
        final length = headRes.headers.value(HttpHeaders.contentLengthHeader);
        if (length != null) {
          final parsed = int.tryParse(length);
          if (parsed != null && parsed > 0) {
            estimatedSizeBytes = parsed;
          }
        }
      } catch (_) {}
    }

    return MediaInfo(
      title: title,
      author: author,
      originalUrl: cleanUrl,
      videoId: null,
      thumbnailUrl: thumbnailUrl ??
          'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=600',
      durationFormatted: '03:00',
      durationMs: 180000,
      isYouTube: false,
      estimatedVideoSizeBytes: estimatedSizeBytes,
      estimatedAudioSizeBytes: (estimatedSizeBytes * 0.25).toInt(),
      directStreamUrl: streamUrl,
      sourceName: 'Web Video (${pageUri.host})',
    );
  }

  MediaInfo _buildFallback(Uri pageUri, String cleanUrl) {
    return MediaInfo(
      title: pageUri.pathSegments.isNotEmpty
          ? pageUri.pathSegments.last
          : 'Web Media Stream',
      author: pageUri.host,
      originalUrl: cleanUrl,
      videoId: null,
      thumbnailUrl:
          'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=600',
      durationFormatted: '03:00',
      durationMs: 180000,
      isYouTube: false,
      estimatedVideoSizeBytes: 18000000,
      estimatedAudioSizeBytes: 4500000,
      directStreamUrl: null,
      sourceName: 'Web Stream (${pageUri.host})',
    );
  }
}
