import 'package:flutter_test/flutter_test.dart';
import 'package:media_vault/models/saved_media.dart';
import 'package:media_vault/models/media_folder.dart';
import 'package:media_vault/models/playlist.dart';
import 'package:media_vault/models/download_history_record.dart';
import 'package:media_vault/services/media_extractor.dart';

void main() {
  group('MediaExtractor Unit Tests', () {
    test('extracts YouTube ID from various YouTube URL formats', () {
      expect(
        MediaExtractor.extractYouTubeId('https://youtu.be/dQw4w9WgXcQ'),
        equals('dQw4w9WgXcQ'),
      );
      expect(
        MediaExtractor.extractYouTubeId('https://www.youtube.com/watch?v=aqz-KE-bpKQ'),
        equals('aqz-KE-bpKQ'),
      );
      expect(
        MediaExtractor.extractYouTubeId('https://youtube.com/shorts/abcdefghijk'),
        equals('abcdefghijk'),
      );
      expect(
        MediaExtractor.extractYouTubeId('https://music.youtube.com/watch?v=12345678901'),
        equals('12345678901'),
      );
    });

    test('cleans raw URL shared with extra message text', () {
      const rawText = 'Watch this cool video: https://youtu.be/dQw4w9WgXcQ it is awesome!';
      expect(
        MediaExtractor.cleanUrl(rawText),
        equals('https://youtu.be/dQw4w9WgXcQ'),
      );
      expect(
        MediaExtractor.extractYouTubeId(rawText),
        equals('dQw4w9WgXcQ'),
      );
    });

    test('detects supported URLs correctly', () {
      expect(MediaExtractor.isSupportedUrl('https://youtu.be/dQw4w9WgXcQ'), isTrue);
      expect(MediaExtractor.isSupportedUrl('https://example.com/video.mp4'), isTrue);
      expect(MediaExtractor.isSupportedUrl('not a url'), isFalse);
    });
  });

  group('Data Models Unit Tests', () {
    test('SavedMedia serialization and helper getters', () {
      final media = SavedMedia(
        id: 1,
        title: 'Big Buck Bunny',
        author: 'Blender Foundation',
        durationSeconds: 596,
        fileSizeBytes: 158008374,
        format: 'MP4',
        quality: '1080p',
        originalUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
        localFilePath: '/storage/BigBuckBunny.mp4',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        downloadDate: 1700000000000,
      );

      expect(media.isVideo, isTrue);
      expect(media.isAudio, isFalse);
      expect(media.formattedDuration, equals('09:56'));
      expect(media.formattedSize, contains('MB'));

      final map = media.toMap();
      expect(map['title'], equals('Big Buck Bunny'));
      final restored = SavedMedia.fromMap(map);
      expect(restored.id, equals(1));
      expect(restored.title, equals('Big Buck Bunny'));
    });

    test('MediaFolder serialization', () {
      final folder = MediaFolder(
        id: 10,
        name: 'Podcasts',
        color: 0xFF6750A4,
        iconName: 'folder',
        description: 'My favorite podcasts',
      );

      final map = folder.toMap();
      expect(map['name'], equals('Podcasts'));
      final restored = MediaFolder.fromMap(map);
      expect(restored.id, equals(10));
      expect(restored.name, equals('Podcasts'));
    });

    test('Playlist serialization', () {
      final playlist = Playlist(
        id: 5,
        name: 'Workout Beats',
        description: 'High energy tracks',
        iconColor: 0xFFFF8A80,
        itemCount: 12,
      );

      final map = playlist.toMap();
      final restored = Playlist.fromMap(map, itemCount: 12);
      expect(restored.id, equals(5));
      expect(restored.name, equals('Workout Beats'));
      expect(restored.itemCount, equals(12));
    });

    test('DownloadHistoryRecord formatting and status parsing', () {
      final history = DownloadHistoryRecord(
        id: 1,
        originalUrl: 'https://youtu.be/dQw4w9WgXcQ',
        title: 'Never Gonna Give You Up',
        author: 'Rick Astley',
        format: 'MP4',
        quality: 'Best',
        status: DownloadHistoryStatus.completed,
        bytesDownloaded: 25000000,
        totalBytes: 25000000,
        localFilePath: '/storage/media.mp4',
        timestamp: 1700000000000,
      );

      expect(history.status, equals(DownloadHistoryStatus.completed));
      expect(history.formattedSize, contains('MB'));
      expect(history.toMap()['status'], equals('COMPLETED'));
    });
  });
}
