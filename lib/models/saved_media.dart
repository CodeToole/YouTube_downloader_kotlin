class SavedMedia {
  final int? id;
  final String title;
  final String author;
  final int durationSeconds;
  final int fileSizeBytes;
  final String format; // 'MP4' or 'MP3'
  final String quality; // '1080p', '720p', etc.
  final String originalUrl;
  final String localFilePath;
  final String thumbnailUrl;
  final int? folderId;
  final String? folderName;
  final int downloadDate;

  SavedMedia({
    this.id,
    required this.title,
    required this.author,
    required this.durationSeconds,
    required this.fileSizeBytes,
    required this.format,
    required this.quality,
    required this.originalUrl,
    required this.localFilePath,
    required this.thumbnailUrl,
    this.folderId,
    this.folderName,
    required this.downloadDate,
  });

  bool get isVideo => format.toUpperCase() == 'MP4';
  bool get isAudio => format.toUpperCase() == 'MP3';

  String get formattedDuration {
    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String get formattedSize {
    if (fileSizeBytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB'];
    int digitGroups = 0;
    double size = fileSizeBytes.toDouble();
    while (size >= 1024 && digitGroups < units.length - 1) {
      size /= 1024;
      digitGroups++;
    }
    return '${size.toStringAsFixed(1)} ${units[digitGroups]}';
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'author': author,
        'durationSeconds': durationSeconds,
        'fileSizeBytes': fileSizeBytes,
        'format': format,
        'quality': quality,
        'originalUrl': originalUrl,
        'localFilePath': localFilePath,
        'thumbnailUrl': thumbnailUrl,
        'folderId': folderId,
        'folderName': folderName,
        'downloadDate': downloadDate,
      };

  factory SavedMedia.fromMap(Map<String, dynamic> map) => SavedMedia(
        id: map['id'],
        title: map['title'] ?? '',
        author: map['author'] ?? '',
        durationSeconds: map['durationSeconds'] ?? 0,
        fileSizeBytes: map['fileSizeBytes'] ?? 0,
        format: map['format'] ?? 'MP4',
        quality: map['quality'] ?? 'Best',
        originalUrl: map['originalUrl'] ?? '',
        localFilePath: map['localFilePath'] ?? '',
        thumbnailUrl: map['thumbnailUrl'] ?? '',
        folderId: map['folderId'],
        folderName: map['folderName'],
        downloadDate: map['downloadDate'] ?? DateTime.now().millisecondsSinceEpoch,
      );

  SavedMedia copyWith({
    int? id,
    String? title,
    String? author,
    int? durationSeconds,
    int? fileSizeBytes,
    String? format,
    String? quality,
    String? originalUrl,
    String? localFilePath,
    String? thumbnailUrl,
    int? folderId,
    String? folderName,
    int? downloadDate,
  }) =>
      SavedMedia(
        id: id ?? this.id,
        title: title ?? this.title,
        author: author ?? this.author,
        durationSeconds: durationSeconds ?? this.durationSeconds,
        fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
        format: format ?? this.format,
        quality: quality ?? this.quality,
        originalUrl: originalUrl ?? this.originalUrl,
        localFilePath: localFilePath ?? this.localFilePath,
        thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
        folderId: folderId ?? this.folderId,
        folderName: folderName ?? this.folderName,
        downloadDate: downloadDate ?? this.downloadDate,
      );
}
