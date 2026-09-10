import '../models/media_info.dart';
import 'extractors/media_source_extractor.dart';
import 'extractors/youtube_extractor.dart';
import 'extractors/direct_link_extractor.dart';
import 'extractors/generic_web_extractor.dart';

export 'extractors/media_source_extractor.dart';
export 'extractors/youtube_extractor.dart';
export 'extractors/direct_link_extractor.dart';
export 'extractors/generic_web_extractor.dart';

class MediaExtractor {
  static final List<MediaSourceExtractor> _extractors = [
    YouTubeExtractor(),
    DirectLinkExtractor(),
    GenericWebExtractor(),
  ];

  /// Allows registering custom backend or platform extractors
  static void registerExtractor(MediaSourceExtractor extractor,
      {bool atBeginning = true}) {
    if (atBeginning) {
      _extractors.insert(0, extractor);
    } else {
      _extractors.add(extractor);
    }
  }

  /// Classifies the URL into a MediaSourceType (youtube, directMedia, genericWeb, unsupported)
  static MediaSourceType classifyUrl(String rawUrl) {
    final clean = cleanUrl(rawUrl);
    for (final extractor in _extractors) {
      if (extractor.canHandle(clean)) {
        return extractor.sourceType;
      }
    }
    return MediaSourceType.unsupported;
  }

  /// Cleans raw text shared from other apps and extracts the URL
  static String cleanUrl(String rawUrl) {
    var clean = rawUrl.trim();
    final urlRegex = RegExp(r'https?://[^\s<>"]+');
    final match = urlRegex.firstMatch(clean);
    if (match != null) {
      clean = match.group(0) ?? clean;
    }
    return clean;
  }

  /// Extracts YouTube video ID if matching YouTube patterns
  static String? extractYouTubeId(String url) {
    return YouTubeExtractor.extractYouTubeId(cleanUrl(url));
  }

  /// Checks if the URL is supported by any registered extractor
  static bool isSupportedUrl(String url) {
    final clean = cleanUrl(url);
    for (final extractor in _extractors) {
      if (extractor.canHandle(clean)) {
        return true;
      }
    }
    return false;
  }

  /// Delegates media info extraction to the first matching MediaSourceExtractor strategy
  static Future<MediaInfo> extractMediaInfo(String rawUrl) async {
    final clean = cleanUrl(rawUrl);
    for (final extractor in _extractors) {
      if (extractor.canHandle(clean)) {
        return await extractor.extract(clean);
      }
    }
    throw UnsupportedError('No suitable extractor found for URL: $rawUrl');
  }
}
