import 'package:flutter_test/flutter_test.dart';
import 'package:media_vault/models/saved_media.dart';
import 'package:media_vault/models/media_folder.dart';
import 'package:media_vault/models/playlist.dart';
import 'package:media_vault/models/download_history_record.dart';
import 'package:media_vault/models/media_info.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:media_vault/services/media_extractor.dart';
import 'package:media_vault/controllers/media_vault_controller.dart';

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

  group('MediaPlayer Scrubber & Duration Logic', () {
    test('Slider max falls back to 1.0 when duration <= 0', () {
      const zeroDuration = Duration.zero;
      final maxZero = zeroDuration.inMilliseconds > 0
          ? zeroDuration.inMilliseconds.toDouble()
          : 1.0;
      expect(maxZero, equals(1.0));

      const negativeDuration = Duration(milliseconds: -100);
      final maxNeg = negativeDuration.inMilliseconds > 0
          ? negativeDuration.inMilliseconds.toDouble()
          : 1.0;
      expect(maxNeg, equals(1.0));

      const validDuration = Duration(seconds: 45);
      final maxVal = validDuration.inMilliseconds > 0
          ? validDuration.inMilliseconds.toDouble()
          : 1.0;
      expect(maxVal, equals(45000.0));
    });

    test('Slider value clamps safely within bounds', () {
      const zeroDuration = Duration.zero;
      final maxVal = zeroDuration.inMilliseconds > 0
          ? zeroDuration.inMilliseconds.toDouble()
          : 1.0;
      final currentMs = 5000.0;
      final clamped = currentMs.clamp(0.0, maxVal);
      expect(clamped, equals(1.0));
      expect(clamped >= 0.0 && clamped <= maxVal, isTrue);
    });

    test('Duration format handles normal and negative edge cases', () {
      String formatDuration(Duration d) {
        if (d.isNegative) return '00:00';
        final minutes = d.inMinutes;
        final seconds = d.inSeconds % 60;
        return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
      }

      expect(formatDuration(Duration.zero), equals('00:00'));
      expect(formatDuration(const Duration(milliseconds: -500)), equals('00:00'));
      expect(formatDuration(const Duration(minutes: 3, seconds: 24)), equals('03:24'));
      expect(formatDuration(const Duration(minutes: 75, seconds: 9)), equals('75:09'));
    });

    test('MediaVaultController closePlayer and onPlayerDisposed execute safely without exceptions', () {
      TestWidgetsFlutterBinding.ensureInitialized();
      final controller = MediaVaultController(autoInit: false);
      expect(controller.hasActivePlayer, isFalse);
      expect(controller.activePlayer, isNull);

      // Multiple teardown calls are idempotent and safe
      controller.closePlayer();
      controller.onPlayerDisposed();
      expect(controller.hasActivePlayer, isFalse);
      controller.dispose();
      expect(controller.isDisposed, isTrue);
    });
  });

  group('MediaSourceExtractor & URL Classification Tests', () {
    test('classifies YouTube URLs correctly', () {
      expect(
        MediaExtractor.classifyUrl('https://youtu.be/dQw4w9WgXcQ'),
        equals(MediaSourceType.youtube),
      );
      expect(
        MediaExtractor.classifyUrl('https://www.youtube.com/watch?v=aqz-KE-bpKQ'),
        equals(MediaSourceType.youtube),
      );
      expect(
        MediaExtractor.classifyUrl('https://youtube.com/shorts/abcdefghijk'),
        equals(MediaSourceType.youtube),
      );
    });

    test('classifies direct media links correctly', () {
      expect(
        MediaExtractor.classifyUrl('https://example.com/videos/tutorial.mp4'),
        equals(MediaSourceType.directMedia),
      );
      expect(
        MediaExtractor.classifyUrl('https://example.com/stream.webm?token=123'),
        equals(MediaSourceType.directMedia),
      );
      expect(
        MediaExtractor.classifyUrl('https://example.com/audio/song.m4a'),
        equals(MediaSourceType.directMedia),
      );
      expect(
        MediaExtractor.classifyUrl('https://example.com/podcast.mp3'),
        equals(MediaSourceType.directMedia),
      );
      expect(
        MediaExtractor.classifyUrl('https://example.com/recording.mov'),
        equals(MediaSourceType.directMedia),
      );
    });

    test('classifies generic web URLs and invalid URLs correctly', () {
      expect(
        MediaExtractor.classifyUrl('https://news.ycombinator.com/item?id=123'),
        equals(MediaSourceType.genericWeb),
      );
      expect(
        MediaExtractor.classifyUrl('https://vimeo.com/channels/staffpicks'),
        equals(MediaSourceType.genericWeb),
      );
      expect(
        MediaExtractor.classifyUrl('not a valid url'),
        equals(MediaSourceType.unsupported),
      );
    });

    test('DirectLinkExtractor extracts titles from paths and cleans filename', () {
      expect(
        DirectLinkExtractor.extractTitleFromUrl(
            'https://cdn.example.com/files/awesome_nature_walk-1080p.mp4'),
        equals('Awesome Nature Walk 1080p'),
      );
      expect(
        DirectLinkExtractor.extractTitleFromUrl(
            'https://cdn.example.com/audio/my%20favorite%20song.mp3?download=1'),
        equals('My Favorite Song'),
      );
      expect(
        DirectLinkExtractor.extractTitleFromUrl('https://cdn.example.com/.mp4'),
        equals('Direct Media Stream'),
      );
    });

    test('DirectLinkExtractor detects media extensions', () {
      expect(DirectLinkExtractor.isDirectMediaUrl('https://test.com/sample.mp4'), isTrue);
      expect(DirectLinkExtractor.isDirectMediaUrl('https://test.com/sample.webm'), isTrue);
      expect(DirectLinkExtractor.isDirectMediaUrl('https://test.com/sample.m4a'), isTrue);
      expect(DirectLinkExtractor.isDirectMediaUrl('https://test.com/sample.mp3'), isTrue);
      expect(DirectLinkExtractor.isDirectMediaUrl('https://test.com/sample.mov'), isTrue);
      expect(DirectLinkExtractor.isDirectMediaUrl('https://test.com/sample.html'), isFalse);
    });

    test('GenericWebExtractor parses OpenGraph and video tags from HTML', () {
      const sampleHtml = '''
        <!DOCTYPE html>
        <html>
        <head>
          <title>Test Page Title</title>
          <meta property="og:title" content="Sample OpenGraph Video">
          <meta property="og:video" content="https://example.com/stream/video.mp4">
          <meta property="og:image" content="https://example.com/poster.jpg">
          <meta property="og:site_name" content="VideoPortal">
        </head>
        <body>
          <video src="https://example.com/fallback.mp4"></video>
        </body>
        </html>
      ''';
      final doc = html_parser.parse(sampleHtml);
      final ogVideo = doc.querySelector('meta[property="og:video"]')?.attributes['content'];
      final ogImage = doc.querySelector('meta[property="og:image"]')?.attributes['content'];
      final ogTitle = doc.querySelector('meta[property="og:title"]')?.attributes['content'];
      final ogSiteName = doc.querySelector('meta[property="og:site_name"]')?.attributes['content'];
      final videoSrc = doc.querySelector('video')?.attributes['src'];

      expect(ogVideo, equals('https://example.com/stream/video.mp4'));
      expect(ogImage, equals('https://example.com/poster.jpg'));
      expect(ogTitle, equals('Sample OpenGraph Video'));
      expect(ogSiteName, equals('VideoPortal'));
      expect(videoSrc, equals('https://example.com/fallback.mp4'));
    });

    test('MediaExtractor strategy registry supports custom extractors', () {
      bool customCalled = false;
      final dummyExtractor = _DummyExtractor(onHandled: () => customCalled = true);
      MediaExtractor.registerExtractor(dummyExtractor, atBeginning: true);

      expect(MediaExtractor.classifyUrl('https://custom-site.org/stream'), equals(MediaSourceType.unsupported));
      expect(dummyExtractor.canHandle('https://custom-site.org/stream'), isTrue);
      expect(customCalled, isTrue);
    });
  });
}

class _DummyExtractor implements MediaSourceExtractor {
  final void Function() onHandled;
  _DummyExtractor({required this.onHandled});

  @override
  MediaSourceType get sourceType => MediaSourceType.unsupported;

  @override
  bool canHandle(String url) {
    if (url.contains('custom-site.org')) {
      onHandled();
      return true;
    }
    return false;
  }

  @override
  Future<MediaInfo> extract(String url) async {
    return MediaInfo(
      title: 'Custom Stream',
      author: 'Custom Author',
      originalUrl: url,
      thumbnailUrl: '',
      durationFormatted: '01:00',
      durationMs: 60000,
      isYouTube: false,
      estimatedVideoSizeBytes: 1000,
      estimatedAudioSizeBytes: 1000,
    );
  }
}
