import '../../models/media_info.dart';

enum MediaSourceType {
  youtube,
  directMedia,
  genericWeb,
  unsupported,
}

abstract class MediaSourceExtractor {
  MediaSourceType get sourceType;

  /// Determines whether this extractor is suitable for handling the given URL.
  bool canHandle(String url);

  /// Extracts metadata and stream information for the provided URL.
  Future<MediaInfo> extract(String url);
}
