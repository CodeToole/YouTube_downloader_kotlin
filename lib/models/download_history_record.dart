enum DownloadHistoryStatus {
  completed,
  failed,
  interrupted,
  downloading;

  static DownloadHistoryStatus fromString(String val) {
    switch (val.toUpperCase()) {
      case 'COMPLETED':
        return DownloadHistoryStatus.completed;
      case 'FAILED':
        return DownloadHistoryStatus.failed;
      case 'INTERRUPTED':
        return DownloadHistoryStatus.interrupted;
      case 'DOWNLOADING':
      default:
        return DownloadHistoryStatus.downloading;
    }
  }

  String get nameUpper => name.toUpperCase();
}

class DownloadHistoryRecord {
  final int? id;
  final String originalUrl;
  final String title;
  final String author;
  final String format;
  final String quality;
  final DownloadHistoryStatus status;
  final int bytesDownloaded;
  final int totalBytes;
  final String localFilePath;
  final String? errorMessage;
  final int timestamp;

  DownloadHistoryRecord({
    this.id,
    required this.originalUrl,
    required this.title,
    required this.author,
    required this.format,
    required this.quality,
    required this.status,
    required this.bytesDownloaded,
    required this.totalBytes,
    required this.localFilePath,
    this.errorMessage,
    required this.timestamp,
  });

  String get formattedSize {
    final size = totalBytes > 0 ? totalBytes : bytesDownloaded;
    if (size <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB'];
    int digitGroups = 0;
    double dSize = size.toDouble();
    while (dSize >= 1024 && digitGroups < units.length - 1) {
      dSize /= 1024;
      digitGroups++;
    }
    return '${dSize.toStringAsFixed(1)} ${units[digitGroups]}';
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'originalUrl': originalUrl,
        'title': title,
        'author': author,
        'format': format,
        'quality': quality,
        'status': status.nameUpper,
        'bytesDownloaded': bytesDownloaded,
        'totalBytes': totalBytes,
        'localFilePath': localFilePath,
        'errorMessage': errorMessage,
        'timestamp': timestamp,
      };

  factory DownloadHistoryRecord.fromMap(Map<String, dynamic> map) =>
      DownloadHistoryRecord(
        id: map['id'],
        originalUrl: map['originalUrl'] ?? '',
        title: map['title'] ?? 'Unknown',
        author: map['author'] ?? 'Unknown',
        format: map['format'] ?? 'MP4',
        quality: map['quality'] ?? 'Best',
        status: DownloadHistoryStatus.fromString(map['status'] ?? 'DOWNLOADING'),
        bytesDownloaded: map['bytesDownloaded'] ?? 0,
        totalBytes: map['totalBytes'] ?? 0,
        localFilePath: map['localFilePath'] ?? '',
        errorMessage: map['errorMessage'],
        timestamp: map['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
      );
}
