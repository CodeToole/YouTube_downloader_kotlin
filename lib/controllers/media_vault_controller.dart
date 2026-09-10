import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart' hide Playlist;
import 'package:media_kit_video/media_kit_video.dart';
import '../models/media_info.dart';
import '../models/saved_media.dart';
import '../models/media_folder.dart';
import '../models/playlist.dart';
import '../models/download_history_record.dart';
import '../models/batch_download_item.dart';
import '../database/vault_database.dart';
import '../services/media_extractor.dart';
import '../services/media_downloader.dart';

class MediaVaultController extends ChangeNotifier {
  final VaultDatabase _db = VaultDatabase.instance;
  final MediaDownloader _downloader = MediaDownloader();
  StreamSubscription<DownloadState>? _downloadSub;

  MediaVaultController() {
    init();
  }

  Future<void> init() async {
    await loadFolders();
    await loadLibrary();
    await loadPlaylists();
    await loadHistory();
  }

  // ==========================================
  // 1. Single Downloader State
  // ==========================================
  String _inputUrl = '';
  String get inputUrl => _inputUrl;

  bool _isExtracting = false;
  bool get isExtracting => _isExtracting;

  MediaInfo? _extractedMedia;
  MediaInfo? get extractedMedia => _extractedMedia;

  String _selectedFormat = 'MP4'; // 'MP4' or 'MP3'
  String get selectedFormat => _selectedFormat;

  String _selectedQuality = 'Best';
  String get selectedQuality => _selectedQuality;

  int? _selectedFolderId;
  int? get selectedFolderId => _selectedFolderId;

  String? _selectedFolderName;
  String? get selectedFolderName => _selectedFolderName;

  DownloadState _downloadState = DownloadStateIdle();
  DownloadState get downloadState => _downloadState;

  void setUrl(String url) {
    _inputUrl = url;
    notifyListeners();
  }

  void clearUrl() {
    _inputUrl = '';
    _extractedMedia = null;
    notifyListeners();
  }

  void setFormat(String format) {
    _selectedFormat = format;
    notifyListeners();
  }

  void setQuality(String quality) {
    _selectedQuality = quality;
    notifyListeners();
  }

  void setTargetFolder(MediaFolder? folder) {
    _selectedFolderId = folder?.id;
    _selectedFolderName = folder?.name;
    notifyListeners();
  }

  MediaSourceType get currentSourceType => MediaExtractor.classifyUrl(_inputUrl);

  Future<void> extractMedia([String? urlToExtract]) async {
    final targetUrl = (urlToExtract ?? _inputUrl).trim();
    if (targetUrl.isEmpty) return;

    _isExtracting = true;
    _inputUrl = targetUrl;
    notifyListeners();

    try {
      final info = await MediaExtractor.extractMediaInfo(targetUrl);
      _extractedMedia = info;

      // Automatically align selected format with media stream type
      final lower = (info.directStreamUrl ?? targetUrl).toLowerCase();
      if (lower.endsWith('.mp3') ||
          lower.endsWith('.m4a') ||
          lower.endsWith('.wav') ||
          lower.endsWith('.aac') ||
          lower.endsWith('.flac')) {
        _selectedFormat = 'MP3';
      } else if (lower.endsWith('.mp4') ||
          lower.endsWith('.webm') ||
          lower.endsWith('.mov') ||
          lower.endsWith('.mkv')) {
        _selectedFormat = 'MP4';
      }
    } catch (e) {
      // Error handled gracefully with fallback
    } finally {
      _isExtracting = false;
      notifyListeners();
    }
  }

  void startDownload({String? savePath}) {
    if (_extractedMedia == null) return;
    final info = _extractedMedia!;

    _downloadSub?.cancel();
    _downloadSub = _downloader
        .startDownload(
          mediaInfo: info,
          format: _selectedFormat,
          quality: _selectedQuality,
          targetFolderId: _selectedFolderId,
          targetFolderName: _selectedFolderName,
          savePath: savePath,
        )
        .listen((state) {
      _downloadState = state;
      if (state is DownloadStateSuccess) {
        loadLibrary();
        loadHistory();
      }
      notifyListeners();
    });
  }

  void pauseDownload() {
    _downloader.pause();
  }

  void resumeDownload() {
    if (_downloadState is DownloadStateInterrupted) {
      final inter = _downloadState as DownloadStateInterrupted;
      _downloadSub?.cancel();
      _downloadSub = _downloader
          .startDownload(
            mediaInfo: inter.mediaInfo,
            format: inter.format,
            quality: inter.quality,
            resumeFromBytes: inter.bytesDownloaded,
            resumeFilePath: inter.tempFilePath,
            targetFolderId: _selectedFolderId,
            targetFolderName: _selectedFolderName,
          )
          .listen((state) {
        _downloadState = state;
        if (state is DownloadStateSuccess) {
          loadLibrary();
          loadHistory();
        }
        notifyListeners();
      });
    }
  }

  void cancelDownload() {
    _downloader.cancel();
    _downloadState = DownloadStateIdle();
    notifyListeners();
  }

  void resetDownloadState() {
    _downloadState = DownloadStateIdle();
    notifyListeners();
  }

  // ==========================================
  // 2. Batch Downloader State
  // ==========================================
  String _batchInputText = '';
  String get batchInputText => _batchInputText;

  List<BatchDownloadItem> _batchItems = [];
  List<BatchDownloadItem> get batchItems => _batchItems;

  bool _isBatchParsing = false;
  bool get isBatchParsing => _isBatchParsing;

  bool _isBatchDownloading = false;
  bool get isBatchDownloading => _isBatchDownloading;

  void setBatchInput(String text) {
    _batchInputText = text;
    notifyListeners();
  }

  void loadSampleBatch() {
    _batchInputText = [
      'https://www.youtube.com/watch?v=aqz-KE-bpKQ',
      'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
      'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
      'https://www.youtube.com/watch?v=jNQXAC9IVRw',
    ].join('\n');
    notifyListeners();
  }

  Future<void> parseBatchUrls() async {
    final lines = _batchInputText
        .split(RegExp(r'[\r\n,]+'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && (l.startsWith('http://') || l.startsWith('https://')))
        .toList();

    if (lines.isEmpty) return;

    _isBatchParsing = true;
    notifyListeners();

    for (final url in lines) {
      final id = UniqueKey().toString();
      final newItem = BatchDownloadItem(
        id: id,
        originalUrl: url,
        status: BatchItemStatus.extracting,
      );
      _batchItems.add(newItem);
      notifyListeners();

      try {
        final info = await MediaExtractor.extractMediaInfo(url);
        final index = _batchItems.indexWhere((it) => it.id == id);
        if (index != -1) {
          _batchItems[index] = _batchItems[index].copyWith(
            status: BatchItemStatus.ready,
            mediaInfo: info,
          );
        }
      } catch (_) {
        final index = _batchItems.indexWhere((it) => it.id == id);
        if (index != -1) {
          _batchItems[index] = _batchItems[index].copyWith(
            status: BatchItemStatus.failed,
            errorMessage: 'Failed to extract metadata',
          );
        }
      }
      notifyListeners();
    }

    _isBatchParsing = false;
    _batchInputText = '';
    notifyListeners();
  }

  void toggleItemSelection(String id) {
    final index = _batchItems.indexWhere((it) => it.id == id);
    if (index != -1) {
      _batchItems[index] = _batchItems[index].copyWith(
        isSelected: !_batchItems[index].isSelected,
      );
      notifyListeners();
    }
  }

  void selectAllBatchItems(bool select) {
    _batchItems = _batchItems.map((e) => e.copyWith(isSelected: select)).toList();
    notifyListeners();
  }

  void removeBatchItem(String id) {
    _batchItems.removeWhere((it) => it.id == id);
    notifyListeners();
  }

  void clearCompletedBatchItems() {
    _batchItems.removeWhere((it) => it.status == BatchItemStatus.completed);
    notifyListeners();
  }

  Future<void> startBatchDownload() async {
    if (_isBatchDownloading) return;
    _isBatchDownloading = true;
    notifyListeners();

    final queue = _batchItems
        .where((it) => it.isSelected && it.status != BatchItemStatus.completed)
        .toList();

    for (final item in queue) {
      if (!_isBatchDownloading) break;

      final index = _batchItems.indexWhere((it) => it.id == item.id);
      if (index == -1) continue;

      if (_batchItems[index].mediaInfo == null) {
        try {
          final info = await MediaExtractor.extractMediaInfo(_batchItems[index].originalUrl);
          _batchItems[index] = _batchItems[index].copyWith(mediaInfo: info);
        } catch (_) {
          _batchItems[index] = _batchItems[index].copyWith(status: BatchItemStatus.failed);
          notifyListeners();
          continue;
        }
      }

      final info = _batchItems[index].mediaInfo!;
      _batchItems[index] = _batchItems[index].copyWith(status: BatchItemStatus.downloading);
      notifyListeners();

      final itemDownloader = MediaDownloader();
      final completer = Completer<void>();

      itemDownloader
          .startDownload(
        mediaInfo: info,
        format: _batchItems[index].format,
        quality: _batchItems[index].quality,
      )
          .listen((st) {
        final curIdx = _batchItems.indexWhere((it) => it.id == item.id);
        if (curIdx != -1) {
          if (st is DownloadStateProgress) {
            _batchItems[curIdx] = _batchItems[curIdx].copyWith(
              progress: st.progress,
              bytesDownloaded: st.bytesDownloaded,
              totalBytes: st.totalBytes,
              speedFormatted: st.speedFormatted,
              etaSeconds: st.etaSeconds,
            );
          } else if (st is DownloadStateSuccess) {
            _batchItems[curIdx] = _batchItems[curIdx].copyWith(
              status: BatchItemStatus.completed,
              progress: 1.0,
            );
            loadLibrary();
            loadHistory();
            if (!completer.isCompleted) completer.complete();
          } else if (st is DownloadStateError) {
            _batchItems[curIdx] = _batchItems[curIdx].copyWith(
              status: BatchItemStatus.failed,
              errorMessage: st.message,
            );
            if (!completer.isCompleted) completer.complete();
          }
          notifyListeners();
        }
      }, onError: (_) {
        if (!completer.isCompleted) completer.complete();
      });

      await completer.future;
    }

    _isBatchDownloading = false;
    notifyListeners();
  }

  void pauseBatchDownload() {
    _isBatchDownloading = false;
    notifyListeners();
  }

  // ==========================================
  // 3. Library State
  // ==========================================
  List<SavedMedia> _libraryMedia = [];
  List<SavedMedia> get libraryMedia => _libraryMedia;

  String _libraryMediaType = 'ALL'; // 'ALL', 'VIDEOS', 'AUDIO'
  String get libraryMediaType => _libraryMediaType;

  int? _libraryFolderFilter; // null = all, -1 = uncategorized, >0 = folderId
  int? get libraryFolderFilter => _libraryFolderFilter;

  String _librarySearchQuery = '';
  String get librarySearchQuery => _librarySearchQuery;

  String _librarySortBy = 'DATE_DESC';
  String get librarySortBy => _librarySortBy;

  Future<void> loadLibrary() async {
    _libraryMedia = await _db.getAllMedia(
      folderId: _libraryFolderFilter,
      mediaType: _libraryMediaType,
      searchQuery: _librarySearchQuery,
      sortBy: _librarySortBy,
    );
    notifyListeners();
  }

  void setLibraryMediaType(String type) {
    _libraryMediaType = type;
    loadLibrary();
  }

  void setLibraryFolderFilter(int? folderId) {
    _libraryFolderFilter = folderId;
    loadLibrary();
  }

  void setLibrarySearchQuery(String query) {
    _librarySearchQuery = query;
    loadLibrary();
  }

  void setLibrarySortBy(String sort) {
    _librarySortBy = sort;
    loadLibrary();
  }

  Future<void> deleteMedia(SavedMedia media) async {
    if (media.id != null) {
      await _db.deleteMedia(media.id!);
      await loadLibrary();
      await loadPlaylists();
    }
  }

  Future<void> renameMedia(SavedMedia media, String newTitle) async {
    if (media.id != null && newTitle.trim().isNotEmpty) {
      await _db.renameMedia(media.id!, newTitle.trim());
      await loadLibrary();
    }
  }

  Future<void> moveMediaToFolder(SavedMedia media, MediaFolder? folder) async {
    if (media.id != null) {
      await _db.updateMediaFolder(media.id!, folder?.id, folder?.name);
      await loadLibrary();
    }
  }

  // ==========================================
  // 4. Folder Operations
  // ==========================================
  List<MediaFolder> _folders = [];
  List<MediaFolder> get folders => _folders;

  Future<void> loadFolders() async {
    _folders = await _db.getAllFolders();
    notifyListeners();
  }

  Future<void> createFolder({
    required String name,
    int color = 0xFF6750A4,
    String iconName = 'folder',
    String description = '',
  }) async {
    final newFolder = MediaFolder(
      name: name.trim(),
      color: color,
      iconName: iconName,
      description: description.trim(),
    );
    await _db.insertFolder(newFolder);
    await loadFolders();
  }

  Future<void> updateFolder(MediaFolder folder) async {
    await _db.updateFolder(folder);
    await loadFolders();
    await loadLibrary();
  }

  Future<void> deleteFolder(int folderId, {bool deleteFiles = false}) async {
    await _db.deleteFolder(folderId, deleteMediaFiles: deleteFiles);
    if (_libraryFolderFilter == folderId) {
      _libraryFolderFilter = null;
    }
    await loadFolders();
    await loadLibrary();
  }

  // ==========================================
  // 5. Playlists State
  // ==========================================
  List<Playlist> _playlists = [];
  List<Playlist> get playlists => _playlists;

  Playlist? _selectedPlaylist;
  Playlist? get selectedPlaylist => _selectedPlaylist;

  List<SavedMedia> _selectedPlaylistMedia = [];
  List<SavedMedia> get selectedPlaylistMedia => _selectedPlaylistMedia;

  Future<void> loadPlaylists() async {
    _playlists = await _db.getAllPlaylists();
    if (_selectedPlaylist != null) {
      await selectPlaylist(_selectedPlaylist);
    }
    notifyListeners();
  }

  Future<void> createPlaylist({
    required String name,
    String description = '',
    int color = 0xFFD0BCFF,
  }) async {
    final newPlaylist = Playlist(
      name: name.trim(),
      description: description.trim(),
      iconColor: color,
    );
    await _db.insertPlaylist(newPlaylist);
    await loadPlaylists();
  }

  Future<void> updatePlaylist(Playlist playlist) async {
    await _db.updatePlaylist(playlist);
    await loadPlaylists();
  }

  Future<void> deletePlaylist(int playlistId) async {
    await _db.deletePlaylist(playlistId);
    if (_selectedPlaylist?.id == playlistId) {
      _selectedPlaylist = null;
      _selectedPlaylistMedia = [];
    }
    await loadPlaylists();
  }

  Future<void> selectPlaylist(Playlist? playlist) async {
    _selectedPlaylist = playlist;
    if (playlist?.id != null) {
      _selectedPlaylistMedia = await _db.getMediaForPlaylist(playlist!.id!);
    } else {
      _selectedPlaylistMedia = [];
    }
    notifyListeners();
  }

  Future<void> addMediaToPlaylist(int playlistId, int mediaId) async {
    await _db.addMediaToPlaylist(playlistId, mediaId);
    await loadPlaylists();
  }

  Future<void> removeMediaFromPlaylist(int playlistId, int mediaId) async {
    await _db.removeMediaFromPlaylist(playlistId, mediaId);
    await loadPlaylists();
  }

  // ==========================================
  // 6. Download History State
  // ==========================================
  List<DownloadHistoryRecord> _historyList = [];
  List<DownloadHistoryRecord> get historyList => _historyList;

  DownloadHistoryStatus? _historyStatusFilter;
  DownloadHistoryStatus? get historyStatusFilter => _historyStatusFilter;

  Future<void> loadHistory() async {
    _historyList = await _db.getAllHistory(statusFilter: _historyStatusFilter);
    notifyListeners();
  }

  void setHistoryFilter(DownloadHistoryStatus? status) {
    _historyStatusFilter = status;
    loadHistory();
  }

  Future<void> deleteHistoryRecord(int id) async {
    await _db.deleteHistory(id);
    await loadHistory();
  }

  Future<void> clearAllHistory() async {
    await _db.clearAllHistory();
    await loadHistory();
  }

  void retryDownloadFromHistory(DownloadHistoryRecord record) {
    setUrl(record.originalUrl);
    setFormat(record.format);
    setQuality(record.quality);
    extractMedia(record.originalUrl);
  }

  // ==========================================
  // 7. In-App Playback State (media_kit)
  // ==========================================
  Player? _player;
  VideoController? _videoController;

  Player get player {
    _ensurePlayer();
    return _player!;
  }

  VideoController get videoController {
    _ensurePlayer();
    return _videoController!;
  }

  void _ensurePlayer() {
    if (_player == null) {
      _player = Player();
      _videoController = VideoController(_player!);
      _initPlayerListeners();
    }
  }

  SavedMedia? _currentlyPlayingMedia;
  SavedMedia? get currentlyPlayingMedia => _currentlyPlayingMedia;

  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  Duration _playbackPosition = Duration.zero;
  Duration get playbackPosition => _playbackPosition;

  Duration _playbackDuration = Duration.zero;
  Duration get playbackDuration => _playbackDuration;

  double _playbackSpeed = 1.0;
  double get playbackSpeed => _playbackSpeed;

  StreamSubscription? _playingSub;
  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _completedSub;

  void _initPlayerListeners() {
    final p = _player;
    if (p == null) return;
    _playingSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _completedSub?.cancel();

    _playingSub = p.stream.playing.listen((playing) {
      _isPlaying = playing;
      notifyListeners();
    });
    _positionSub = p.stream.position.listen((pos) {
      _playbackPosition = pos;
      notifyListeners();
    });
    _durationSub = p.stream.duration.listen((dur) {
      _playbackDuration = dur;
      notifyListeners();
    });
    _completedSub = p.stream.completed.listen((completed) {
      if (completed) {
        _isPlaying = false;
        notifyListeners();
      }
    });
  }

  void playMedia(SavedMedia media) {
    _currentlyPlayingMedia = media;
    _playbackPosition = Duration.zero;
    _playbackDuration = Duration.zero;
    _playbackSpeed = 1.0;

    _ensurePlayer();

    // Open the local file
    _player!.open(Media(media.localFilePath));
    _player!.setRate(1.0);
    notifyListeners();
  }

  void togglePlayPause() {
    _player?.playOrPause();
  }

  void seekTo(Duration pos) {
    _player?.seek(pos);
  }

  void skipSeconds(int seconds) {
    if (_player == null) return;
    final newPos = _playbackPosition + Duration(seconds: seconds);
    if (newPos < Duration.zero) {
      _player!.seek(Duration.zero);
    } else if (newPos > _playbackDuration) {
      _player!.seek(_playbackDuration);
    } else {
      _player!.seek(newPos);
    }
  }

  void setPlaybackSpeed(double speed) {
    _playbackSpeed = speed;
    _player?.setRate(speed);
    notifyListeners();
  }

  void onPlayerDisposed() {
    _playingSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _completedSub?.cancel();
    _playingSub = null;
    _positionSub = null;
    _durationSub = null;
    _completedSub = null;
    _player = null;
    _videoController = null;
    _currentlyPlayingMedia = null;
    _isPlaying = false;
    _playbackPosition = Duration.zero;
    _playbackDuration = Duration.zero;
    notifyListeners();
  }

  void closePlayer() {
    if (_player != null) {
      try {
        _player!.stop();
      } catch (_) {}
      try {
        _player!.dispose();
      } catch (_) {}
    }
    onPlayerDisposed();
  }

  @override
  void dispose() {
    _downloadSub?.cancel();
    _playingSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _completedSub?.cancel();
    _player?.dispose();
    _player = null;
    _videoController = null;
    super.dispose();
  }
}

