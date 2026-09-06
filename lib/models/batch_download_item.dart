import 'media_info.dart';

enum BatchItemStatus {
  queued,
  extracting,
  ready,
  downloading,
  paused,
  completed,
  failed;

  String get displayName {
    switch (this) {
      case BatchItemStatus.queued:
        return 'Queued';
      case BatchItemStatus.extracting:
        return 'Analyzing...';
      case BatchItemStatus.ready:
        return 'Ready';
      case BatchItemStatus.downloading:
        return 'Downloading';
      case BatchItemStatus.paused:
        return 'Paused';
      case BatchItemStatus.completed:
        return 'Done';
      case BatchItemStatus.failed:
        return 'Failed';
    }
  }
}

class BatchDownloadItem {
  final String id;
  final String originalUrl;
  final BatchItemStatus status;
  final double progress; // 0.0 to 1.0
  final int bytesDownloaded;
  final int totalBytes;
  final String speedFormatted;
  final int etaSeconds;
  final MediaInfo? mediaInfo;
  final String format; // 'MP4' or 'MP3'
  final String quality; // '1080p', etc.
  final bool isSelected;
  final String? errorMessage;
  final String? tempFilePath;

  BatchDownloadItem({
    required this.id,
    required this.originalUrl,
    this.status = BatchItemStatus.queued,
    this.progress = 0.0,
    this.bytesDownloaded = 0,
    this.totalBytes = 0,
    this.speedFormatted = '0 KB/s',
    this.etaSeconds = 0,
    this.mediaInfo,
    this.format = 'MP4',
    this.quality = 'Best',
    this.isSelected = true,
    this.errorMessage,
    this.tempFilePath,
  });

  String get title => mediaInfo?.title ?? (originalUrl.isNotEmpty ? originalUrl : 'Media Item');
  String get author => mediaInfo?.author ?? 'Online Source';
  String get thumbnailUrl => mediaInfo?.thumbnailUrl ?? '';

  BatchDownloadItem copyWith({
    String? id,
    String? originalUrl,
    BatchItemStatus? status,
    double? progress,
    int? bytesDownloaded,
    int? totalBytes,
    String? speedFormatted,
    int? etaSeconds,
    MediaInfo? mediaInfo,
    String? format,
    String? quality,
    bool? isSelected,
    String? errorMessage,
    String? tempFilePath,
  }) =>
      BatchDownloadItem(
        id: id ?? this.id,
        originalUrl: originalUrl ?? this.originalUrl,
        status: status ?? this.status,
        progress: progress ?? this.progress,
        bytesDownloaded: bytesDownloaded ?? this.bytesDownloaded,
        totalBytes: totalBytes ?? this.totalBytes,
        speedFormatted: speedFormatted ?? this.speedFormatted,
        etaSeconds: etaSeconds ?? this.etaSeconds,
        mediaInfo: mediaInfo ?? this.mediaInfo,
        format: format ?? this.format,
        quality: quality ?? this.quality,
        isSelected: isSelected ?? this.isSelected,
        errorMessage: errorMessage ?? this.errorMessage,
        tempFilePath: tempFilePath ?? this.tempFilePath,
      );
}
