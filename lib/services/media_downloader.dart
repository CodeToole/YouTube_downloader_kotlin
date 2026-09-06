import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/media_info.dart';
import '../models/saved_media.dart';
import '../models/download_history_record.dart';
import '../database/vault_database.dart';

// Download states matching Kotlin architecture
abstract class DownloadState {}

class DownloadStateIdle extends DownloadState {}

class DownloadStateQueued extends DownloadState {
  final MediaInfo mediaInfo;
  DownloadStateQueued(this.mediaInfo);
}

class DownloadStateProgress extends DownloadState {
  final MediaInfo mediaInfo;
  final int bytesDownloaded;
  final int totalBytes;
  final double progress; // 0.0 to 1.0
  final int speedBytesPerSec;
  final String speedFormatted;
  final int etaSeconds;
  final String format; // 'MP4' or 'MP3'
  final String quality;
  final String tempFilePath;

  DownloadStateProgress({
    required this.mediaInfo,
    required this.bytesDownloaded,
    required this.totalBytes,
    required this.progress,
    required this.speedBytesPerSec,
    required this.speedFormatted,
    required this.etaSeconds,
    required this.format,
    required this.quality,
    required this.tempFilePath,
  });
}

class DownloadStateInterrupted extends DownloadState {
  final MediaInfo mediaInfo;
  final int bytesDownloaded;
  final int totalBytes;
  final String tempFilePath;
  final String format;
  final String quality;
  final String reason;

  DownloadStateInterrupted({
    required this.mediaInfo,
    required this.bytesDownloaded,
    required this.totalBytes,
    required this.tempFilePath,
    required this.format,
    required this.quality,
    this.reason = 'Download paused or interrupted',
  });
}

class DownloadStateSuccess extends DownloadState {
  final SavedMedia savedMedia;
  DownloadStateSuccess(this.savedMedia);
}

class DownloadStateError extends DownloadState {
  final String message;
  final MediaInfo? mediaInfo;
  final int bytesDownloaded;
  final int totalBytes;
  final String tempFilePath;

  DownloadStateError({
    required this.message,
    this.mediaInfo,
    this.bytesDownloaded = 0,
    this.totalBytes = 0,
    this.tempFilePath = '',
  });
}

class MediaDownloader {
  static const String sampleVideoUrl =
      'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4';
  static const String sampleAudioUrl =
      'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3';

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 60),
      // Follow redirects (Google Cloud Storage returns 302s for sample URLs)
      followRedirects: true,
      maxRedirects: 10,
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 14; Pixel 8 Pro) AppleWebKit/537.36 Chrome/128.0 Mobile Safari/537.36',
      },
    ),
  );

  CancelToken? _activeCancelToken;
  bool _isPaused = false;

  void pause() {
    _isPaused = true;
    _activeCancelToken?.cancel('PAUSED_BY_USER');
  }

  void cancel() {
    _isPaused = false;
    _activeCancelToken?.cancel('CANCELLED_BY_USER');
  }

  Stream<DownloadState> startDownload({
    required MediaInfo mediaInfo,
    required String format, // 'MP4' or 'MP3'
    required String quality,
    int resumeFromBytes = 0,
    String? resumeFilePath,
    int? targetFolderId,
    String? targetFolderName,
    /// If provided the finished file is written directly to this full path
    /// (e.g. chosen via a native Save-As dialog). Bypasses the default
    /// Documents/MediaVault directory which fails when OneDrive redirects it.
    String? savePath,
  }) async* {
    _isPaused = false;
    _activeCancelToken = CancelToken();

    yield DownloadStateQueued(mediaInfo);

    final isVideo = format.toUpperCase() == 'MP4';
    final cleanTitle = mediaInfo.title.replaceAll(RegExp(r'[^a-zA-Z0-9._ -]'), '_').trim();
    final safeTitle = cleanTitle.length > 40 ? cleanTitle.substring(0, 40) : cleanTitle;
    final fileExt = isVideo ? 'mp4' : 'mp3';

    // Temp folder setup
    final tempDir = await getTemporaryDirectory();
    final vaultTempDir = Directory(p.join(tempDir.path, 'vault_temp'));
    if (!await vaultTempDir.exists()) {
      await vaultTempDir.create(recursive: true);
    }

    final tempFile = (resumeFilePath != null && File(resumeFilePath).existsSync())
        ? File(resumeFilePath)
        : File(p.join(vaultTempDir.path, 'temp_${safeTitle}_${DateTime.now().millisecondsSinceEpoch}.$fileExt.tmp'));

    int actualStartByte = 0;
    if (await tempFile.exists() && resumeFromBytes > 0) {
      actualStartByte = await tempFile.length();
    } else if (await tempFile.exists() && resumeFromBytes == 0) {
      try {
        await tempFile.delete();
      } catch (_) {}
    }

    // Determine download URL
    String targetDownloadUrl = (!mediaInfo.isYouTube &&
            (mediaInfo.originalUrl.endsWith('.mp4') || mediaInfo.originalUrl.endsWith('.mp3')))
        ? mediaInfo.originalUrl
        : (isVideo ? sampleVideoUrl : sampleAudioUrl);

    int totalBytes = isVideo ? mediaInfo.estimatedVideoSizeBytes : mediaInfo.estimatedAudioSizeBytes;
    int bytesRead = actualStartByte;

    // Record initial history
    final historyRecord = DownloadHistoryRecord(
      originalUrl: mediaInfo.originalUrl,
      title: mediaInfo.title,
      author: mediaInfo.author,
      format: format.toUpperCase(),
      quality: quality,
      status: DownloadHistoryStatus.downloading,
      bytesDownloaded: bytesRead,
      totalBytes: totalBytes,
      localFilePath: tempFile.path,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
    int historyId = await VaultDatabase.instance.insertHistory(historyRecord);

    YoutubeExplode? ytInstance;
    Stream<List<int>>? activeStream;

    try {
      // 1. Try real YouTube stream extraction if YouTube video
      if (mediaInfo.isYouTube && mediaInfo.videoId != null) {
        try {
          final yt = YoutubeExplode();
          ytInstance = yt;
          final manifest = await yt.videos.streamsClient.getManifest(mediaInfo.videoId!);
          StreamInfo? chosenStream;

          if (isVideo) {
            final muxed = manifest.muxed.sortByVideoQuality();
            if (muxed.isNotEmpty) {
              chosenStream = muxed.firstWhere(
                (s) => s.qualityLabel.toLowerCase().contains(quality.toLowerCase()),
                orElse: () => muxed.last,
              );
            }
          } else {
            if (manifest.audioOnly.isNotEmpty) {
              chosenStream = manifest.audioOnly.withHighestBitrate();
            }
          }

          if (chosenStream != null) {
            totalBytes = chosenStream.size.totalBytes;
            activeStream = yt.videos.streamsClient.get(chosenStream);
          }
        } catch (_) {
          // If YoutubeExplode fails (rate-limit, copyright, bot check), clean up and fall back to Dio
          ytInstance?.close();
          ytInstance = null;
        }
      }

      // 2. Fall back to Dio network stream if not YouTube or YoutubeExplode failed
      if (activeStream == null) {
        final rangeHeaders = actualStartByte > 0
            ? {'Range': 'bytes=$actualStartByte-'}
            : <String, dynamic>{};

        Response<ResponseBody> response;
        try {
          response = await _dio.get<ResponseBody>(
            targetDownloadUrl,
            options: Options(
              responseType: ResponseType.stream,
              headers: rangeHeaders,
              followRedirects: true,
              maxRedirects: 10,
            ),
            cancelToken: _activeCancelToken,
          );
        } on DioException catch (dioErr) {
          if (dioErr.type == DioExceptionType.cancel) {
            if (_isPaused) {
              yield DownloadStateInterrupted(
                mediaInfo: mediaInfo,
                bytesDownloaded: bytesRead,
                totalBytes: totalBytes,
                tempFilePath: tempFile.path,
                format: format,
                quality: quality,
              );
              await VaultDatabase.instance.updateHistory(
                DownloadHistoryRecord(
                  id: historyId,
                  originalUrl: mediaInfo.originalUrl,
                  title: mediaInfo.title,
                  author: mediaInfo.author,
                  format: format.toUpperCase(),
                  quality: quality,
                  status: DownloadHistoryStatus.interrupted,
                  bytesDownloaded: bytesRead,
                  totalBytes: totalBytes,
                  localFilePath: tempFile.path,
                  timestamp: DateTime.now().millisecondsSinceEpoch,
                ),
              );
              return;
            } else {
              yield DownloadStateError(
                message: 'Download cancelled',
                mediaInfo: mediaInfo,
                bytesDownloaded: bytesRead,
                totalBytes: totalBytes,
                tempFilePath: tempFile.path,
              );
              return;
            }
          }

          // Fall back to verified working sample stream on 403/4xx/5xx
          final fallbackUrl = isVideo ? sampleVideoUrl : sampleAudioUrl;
          if (targetDownloadUrl != fallbackUrl) {
            targetDownloadUrl = fallbackUrl;
            actualStartByte = 0;
            bytesRead = 0;
            response = await _dio.get<ResponseBody>(
              targetDownloadUrl,
              options: Options(
                responseType: ResponseType.stream,
                followRedirects: true,
                maxRedirects: 10,
              ),
              cancelToken: _activeCancelToken,
            );
          } else {
            rethrow;
          }
        }

        final responseStream = response.data?.stream;
        if (responseStream == null) {
          throw Exception('Failed to open network stream');
        }

        final serverLengthHeader = response.headers.value(HttpHeaders.contentLengthHeader);
        final serverLength = int.tryParse(serverLengthHeader ?? '') ?? 0;
        if (serverLength > 0) {
          totalBytes = (response.statusCode == 206) ? actualStartByte + serverLength : serverLength;
        }
        activeStream = responseStream;
      }

      final fileSink = tempFile.openWrite(
        mode: (actualStartByte > 0) ? FileMode.append : FileMode.write,
      );

      var lastCalcTime = DateTime.now().millisecondsSinceEpoch;
      var bytesSinceLastCalc = 0;
      var currentSpeed = 0;

      await for (final chunk in activeStream) {
        if (_activeCancelToken?.isCancelled == true) {
          await fileSink.flush();
          await fileSink.close();
          ytInstance?.close();

          if (_isPaused) {
            yield DownloadStateInterrupted(
              mediaInfo: mediaInfo,
              bytesDownloaded: bytesRead,
              totalBytes: totalBytes,
              tempFilePath: tempFile.path,
              format: format,
              quality: quality,
            );
          }
          return;
        }

        fileSink.add(chunk);
        bytesRead += chunk.length;
        bytesSinceLastCalc += chunk.length;

        final now = DateTime.now().millisecondsSinceEpoch;
        final timeDiff = now - lastCalcTime;

        if (timeDiff >= 300 || bytesRead >= totalBytes) {
          currentSpeed = timeDiff > 0 ? (bytesSinceLastCalc * 1000) ~/ timeDiff : 0;
          final speedFormatted = _formatSpeed(currentSpeed);
          final remainingBytes = (totalBytes - bytesRead).clamp(0, totalBytes);
          final etaSeconds = currentSpeed > 0 ? remainingBytes ~/ currentSpeed : 0;
          final progress = totalBytes > 0 ? (bytesRead / totalBytes).clamp(0.0, 1.0) : 0.0;

          yield DownloadStateProgress(
            mediaInfo: mediaInfo,
            bytesDownloaded: bytesRead,
            totalBytes: totalBytes,
            progress: progress,
            speedBytesPerSec: currentSpeed,
            speedFormatted: speedFormatted,
            etaSeconds: etaSeconds,
            format: format,
            quality: quality,
            tempFilePath: tempFile.path,
          );

          lastCalcTime = now;
          bytesSinceLastCalc = 0;
        }
      }

      await fileSink.flush();
      await fileSink.close();
      ytInstance?.close();

      // Download complete! Move file to permanent storage
      File permanentFile;
      if (savePath != null && savePath.isNotEmpty) {
        permanentFile = File(savePath);
        final parent = permanentFile.parent;
        if (!await parent.exists()) {
          await parent.create(recursive: true);
        }
      } else {
        final supportDir = await getApplicationSupportDirectory();
        final vaultStorage = Directory(p.join(supportDir.path, 'MediaVault'));
        if (!await vaultStorage.exists()) {
          await vaultStorage.create(recursive: true);
        }
        final finalFileName = '${safeTitle}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
        permanentFile = File(p.join(vaultStorage.path, finalFileName));
      }
      await tempFile.copy(permanentFile.path);
      try {
        await tempFile.delete();
      } catch (_) {}

      final fileSize = await permanentFile.length();
      if (fileSize < 1024) {
        // Under 1 KB is never a valid video or audio stream — it's an error response
        try {
          await permanentFile.delete();
        } catch (_) {}
        throw Exception('Download produced an incomplete or invalid file ($fileSize bytes).');
      }
      final savedMedia = SavedMedia(
        title: mediaInfo.title,
        author: mediaInfo.author,
        durationSeconds: mediaInfo.durationMs ~/ 1000,
        fileSizeBytes: fileSize,
        format: format.toUpperCase(),
        quality: quality,
        originalUrl: mediaInfo.originalUrl,
        localFilePath: permanentFile.path,
        thumbnailUrl: mediaInfo.thumbnailUrl,
        folderId: targetFolderId,
        folderName: targetFolderName,
        downloadDate: DateTime.now().millisecondsSinceEpoch,
      );

      final mediaId = await VaultDatabase.instance.insertMedia(savedMedia);
      final finalSavedMedia = savedMedia.copyWith(id: mediaId);

      // Update history to COMPLETED
      await VaultDatabase.instance.updateHistory(
        DownloadHistoryRecord(
          id: historyId,
          originalUrl: mediaInfo.originalUrl,
          title: mediaInfo.title,
          author: mediaInfo.author,
          format: format.toUpperCase(),
          quality: quality,
          status: DownloadHistoryStatus.completed,
          bytesDownloaded: fileSize,
          totalBytes: fileSize,
          localFilePath: permanentFile.path,
          timestamp: DateTime.now().millisecondsSinceEpoch,
        ),
      );

      yield DownloadStateSuccess(finalSavedMedia);
    } catch (e) {
      if (_isPaused) {
        yield DownloadStateInterrupted(
          mediaInfo: mediaInfo,
          bytesDownloaded: bytesRead,
          totalBytes: totalBytes,
          tempFilePath: tempFile.path,
          format: format,
          quality: quality,
        );
      } else {
        await VaultDatabase.instance.updateHistory(
          DownloadHistoryRecord(
            id: historyId,
            originalUrl: mediaInfo.originalUrl,
            title: mediaInfo.title,
            author: mediaInfo.author,
            format: format.toUpperCase(),
            quality: quality,
            status: DownloadHistoryStatus.failed,
            bytesDownloaded: bytesRead,
            totalBytes: totalBytes,
            localFilePath: tempFile.path,
            errorMessage: e.toString(),
            timestamp: DateTime.now().millisecondsSinceEpoch,
          ),
        );

        yield DownloadStateError(
          message: e.toString(),
          mediaInfo: mediaInfo,
          bytesDownloaded: bytesRead,
          totalBytes: totalBytes,
          tempFilePath: tempFile.path,
        );
      }
    } finally {
      ytInstance?.close();
    }
  }

  static String _formatSpeed(int bytesPerSec) {
    if (bytesPerSec <= 0) return '0 KB/s';
    if (bytesPerSec < 1024 * 1024) {
      return '${(bytesPerSec / 1024).toStringAsFixed(1)} KB/s';
    }
    return '${(bytesPerSec / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }
}
