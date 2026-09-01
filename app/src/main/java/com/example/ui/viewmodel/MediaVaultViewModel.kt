package com.example.ui.viewmodel

import android.app.Application
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.example.data.db.MediaDatabase
import com.example.data.model.BatchDownloadItem
import com.example.data.model.BatchItemStatus
import com.example.data.model.DownloadHistoryRecord
import com.example.data.model.DownloadStatus
import com.example.data.model.MediaFolder
import com.example.data.model.MediaFormat
import com.example.data.model.MediaInfo
import com.example.data.model.MediaQuality
import com.example.data.model.MediaType
import com.example.data.model.Playlist
import com.example.data.model.SavedMedia
import com.example.data.repository.MediaRepository
import com.example.downloader.DownloadState
import com.example.downloader.MediaDownloader
import com.example.extractor.MediaExtractor
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Semaphore
import kotlinx.coroutines.sync.withPermit
import java.io.File
import java.util.UUID

enum class LibraryTabFilter {
    ALL,
    VIDEOS,
    AUDIO
}

enum class HistoryFilter {
    ALL,
    COMPLETED,
    FAILED_OR_INTERRUPTED
}

data class SampleMediaLink(
    val title: String,
    val description: String,
    val url: String,
    val type: String
)

class MediaVaultViewModel(application: Application) : AndroidViewModel(application) {

    private val repository: MediaRepository
    private val downloader = MediaDownloader(application)

    init {
        val db = MediaDatabase.getDatabase(application)
        repository = MediaRepository(
            context = application,
            mediaDao = db.mediaDao(),
            historyDao = db.downloadHistoryDao(),
            playlistDao = db.playlistDao(),
            folderDao = db.mediaFolderDao()
        )
    }

    // ==========================================
    // 1. Single URL Input & Extraction State
    // ==========================================
    private val _inputUrl = MutableStateFlow("")
    val inputUrl: StateFlow<String> = _inputUrl.asStateFlow()

    private val _isExtracting = MutableStateFlow(false)
    val isExtracting: StateFlow<Boolean> = _isExtracting.asStateFlow()

    private val _extractedMedia = MutableStateFlow<MediaInfo?>(null)
    val extractedMedia: StateFlow<MediaInfo?> = _extractedMedia.asStateFlow()

    private val _selectedFormat = MutableStateFlow(MediaFormat.MP4)
    val selectedFormat: StateFlow<MediaFormat> = _selectedFormat.asStateFlow()

    private val _selectedQuality = MutableStateFlow(MediaQuality.BEST)
    val selectedQuality: StateFlow<MediaQuality> = _selectedQuality.asStateFlow()

    // Download state for active single download
    private val _downloadState = MutableStateFlow<DownloadState>(DownloadState.Idle)
    val downloadState: StateFlow<DownloadState> = _downloadState.asStateFlow()

    private var activeDownloadJob: Job? = null
    private var currentDownloadHistoryId: Long? = null

    // ==========================================
    // 2. Download History State
    // ==========================================
    private val _historyFilter = MutableStateFlow(HistoryFilter.ALL)
    val historyFilter: StateFlow<HistoryFilter> = _historyFilter.asStateFlow()

    val historyList: StateFlow<List<DownloadHistoryRecord>> = combine(
        repository.allHistory,
        _historyFilter
    ) { allHistory, filter ->
        when (filter) {
            HistoryFilter.ALL -> allHistory
            HistoryFilter.COMPLETED -> allHistory.filter { it.status == DownloadStatus.COMPLETED }
            HistoryFilter.FAILED_OR_INTERRUPTED -> allHistory.filter {
                it.status == DownloadStatus.FAILED || it.status == DownloadStatus.INTERRUPTED
            }
        }
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5000),
        initialValue = emptyList()
    )

    // ==========================================
    // 3. Playlists State
    // ==========================================
    val allPlaylists: StateFlow<List<Playlist>> = repository.allPlaylists.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5000),
        initialValue = emptyList()
    )

    private val _selectedPlaylist = MutableStateFlow<Playlist?>(null)
    val selectedPlaylist: StateFlow<Playlist?> = _selectedPlaylist.asStateFlow()

    val selectedPlaylistMedia: StateFlow<List<SavedMedia>> = _selectedPlaylist.flatMapLatest { playlist ->
        if (playlist == null) flowOf(emptyList())
        else repository.getMediaForPlaylist(playlist.id)
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5000),
        initialValue = emptyList()
    )

    // Target media for "Add to Playlist" sheet
    private val _addToPlaylistTargetMedia = MutableStateFlow<SavedMedia?>(null)
    val addToPlaylistTargetMedia: StateFlow<SavedMedia?> = _addToPlaylistTargetMedia.asStateFlow()

    val playlistsForTargetMedia: StateFlow<List<Long>> = _addToPlaylistTargetMedia.flatMapLatest { media ->
        if (media == null) flowOf(emptyList())
        else repository.getPlaylistIdsForMedia(media.id)
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5000),
        initialValue = emptyList()
    )

    // ==========================================
    // 4. Folder State & Management
    // ==========================================
    val allFolders: StateFlow<List<MediaFolder>> = repository.allFolders.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5000),
        initialValue = emptyList()
    )

    // null = All Folders, -1L = Uncategorized (No Folder), > 0L = Specific Folder ID
    private val _selectedFolderId = MutableStateFlow<Long?>(null)
    val selectedFolderId: StateFlow<Long?> = _selectedFolderId.asStateFlow()

    private val _targetFolderForDownload = MutableStateFlow<MediaFolder?>(null)
    val targetFolderForDownload: StateFlow<MediaFolder?> = _targetFolderForDownload.asStateFlow()

    private val _moveToFolderTargetMedia = MutableStateFlow<SavedMedia?>(null)
    val moveToFolderTargetMedia: StateFlow<SavedMedia?> = _moveToFolderTargetMedia.asStateFlow()

    // ==========================================
    // 5. Batch / Multi-Link Downloader State
    // ==========================================
    private val _batchInputText = MutableStateFlow("")
    val batchInputText: StateFlow<String> = _batchInputText.asStateFlow()

    private val _batchItems = MutableStateFlow<List<BatchDownloadItem>>(emptyList())
    val batchItems: StateFlow<List<BatchDownloadItem>> = _batchItems.asStateFlow()

    private val _isBatchParsing = MutableStateFlow(false)
    val isBatchParsing: StateFlow<Boolean> = _isBatchParsing.asStateFlow()

    private val _isBatchDownloading = MutableStateFlow(false)
    val isBatchDownloading: StateFlow<Boolean> = _isBatchDownloading.asStateFlow()

    private val batchDownloadJobs = mutableMapOf<String, Job>()
    private val batchConcurrencySemaphore = Semaphore(2) // 2 concurrent downloads

    // ==========================================
    // 6. Library Search & Filter State
    // ==========================================
    private val _libraryFilter = MutableStateFlow(LibraryTabFilter.ALL)
    val libraryFilter: StateFlow<LibraryTabFilter> = _libraryFilter.asStateFlow()

    private val _searchQuery = MutableStateFlow("")
    val searchQuery: StateFlow<String> = _searchQuery.asStateFlow()

    // Currently playing media and queue
    private val _currentPlayingMedia = MutableStateFlow<SavedMedia?>(null)
    val currentPlayingMedia: StateFlow<SavedMedia?> = _currentPlayingMedia.asStateFlow()

    private val _playbackQueue = MutableStateFlow<List<SavedMedia>>(emptyList())
    val playbackQueue: StateFlow<List<SavedMedia>> = _playbackQueue.asStateFlow()

    private val _playbackQueueIndex = MutableStateFlow(0)
    val playbackQueueIndex: StateFlow<Int> = _playbackQueueIndex.asStateFlow()

    private val _currentPlaylistName = MutableStateFlow<String?>(null)
    val currentPlaylistName: StateFlow<String?> = _currentPlaylistName.asStateFlow()

    // Snackbar message
    private val _userMessage = MutableStateFlow<String?>(null)
    val userMessage: StateFlow<String?> = _userMessage.asStateFlow()

    // Sample links for instant quick testing
    val sampleLinks = listOf(
        SampleMediaLink(
            title = "YouTube Video",
            description = "Nature 4K Wildlife Documentary",
            url = "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
            type = "MP4 / MP3"
        ),
        SampleMediaLink(
            title = "YouTube Shorts",
            description = "High Energy Motion Clip",
            url = "https://youtube.com/shorts/kJQP7kiw5Fk?si=MediaVault",
            type = "Shorts"
        ),
        SampleMediaLink(
            title = "Lofi Hip Hop Stream",
            description = "Chill Beats to Relax & Study",
            url = "https://youtu.be/jfKfPfyJRdk",
            type = "Audio M4A"
        ),
        SampleMediaLink(
            title = "Direct Open Video",
            description = "Big Buck Bunny Open Source Film",
            url = "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4",
            type = "Direct MP4"
        )
    )

    // Saved media list with search, format filter, and folder filter applied
    val savedMediaList: StateFlow<List<SavedMedia>> = combine(
        repository.allMedia,
        _libraryFilter,
        _selectedFolderId,
        _searchQuery
    ) { allMedia, typeFilter, folderId, query ->
        val filteredByType = when (typeFilter) {
            LibraryTabFilter.ALL -> allMedia
            LibraryTabFilter.VIDEOS -> allMedia.filter { it.mediaType == MediaType.VIDEO }
            LibraryTabFilter.AUDIO -> allMedia.filter { it.mediaType == MediaType.AUDIO }
        }

        val filteredByFolder = when {
            folderId == null -> filteredByType
            folderId == -1L -> filteredByType.filter { it.folderId == null || it.folderId == 0L }
            else -> filteredByType.filter { it.folderId == folderId }
        }

        if (query.isBlank()) {
            filteredByFolder
        } else {
            filteredByFolder.filter {
                it.title.contains(query, ignoreCase = true) ||
                it.author.contains(query, ignoreCase = true) ||
                it.format.extension.contains(query, ignoreCase = true) ||
                (it.folderName != null && it.folderName.contains(query, ignoreCase = true))
            }
        }
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5000),
        initialValue = emptyList()
    )

    // ==========================================
    // Single Link Actions
    // ==========================================
    fun onUrlInputChanged(newUrl: String) {
        _inputUrl.value = newUrl
        if (newUrl.isNotBlank() && MediaExtractor.isSupportedUrl(newUrl)) {
            extractMediaInfo(newUrl)
        } else if (newUrl.isBlank()) {
            _extractedMedia.value = null
        }
    }

    fun pasteFromClipboard() {
        val clipboard = getApplication<Application>().getSystemService(Context.CLIPBOARD_SERVICE) as? ClipboardManager
        if (clipboard != null && clipboard.hasPrimaryClip()) {
            val clipData = clipboard.primaryClip
            if (clipData != null && clipData.itemCount > 0) {
                val text = clipData.getItemAt(0).text?.toString()?.trim() ?: ""
                if (text.isNotEmpty()) {
                    val cleanUrl = MediaExtractor.cleanUrl(text)
                    _inputUrl.value = cleanUrl
                    extractMediaInfo(cleanUrl)
                    _userMessage.value = "Pasted link from clipboard"
                } else {
                    _userMessage.value = "Clipboard is empty"
                }
            }
        }
    }

    fun handleSharedUrl(sharedText: String) {
        val cleaned = MediaExtractor.cleanUrl(sharedText)
        _inputUrl.value = cleaned
        extractMediaInfo(cleaned)
        _userMessage.value = "Received shared link: $cleaned"
    }

    fun extractMediaInfo(url: String) {
        viewModelScope.launch {
            _isExtracting.value = true
            val result = MediaExtractor.extractMediaInfo(url)
            _isExtracting.value = false
            result.onSuccess { info ->
                _extractedMedia.value = info
            }.onFailure { err ->
                _userMessage.value = "Could not parse link: ${err.localizedMessage}"
            }
        }
    }

    fun setFormat(format: MediaFormat) {
        _selectedFormat.value = format
        if (format.mediaType == MediaType.AUDIO && (_selectedQuality.value == MediaQuality.BEST || _selectedQuality.value == MediaQuality.STANDARD)) {
            _selectedQuality.value = MediaQuality.AUDIO_ONLY
        } else if (format.mediaType == MediaType.VIDEO && (_selectedQuality.value == MediaQuality.AUDIO_ONLY || _selectedQuality.value == MediaQuality.AUDIO_COMPACT)) {
            _selectedQuality.value = MediaQuality.BEST
        }
    }

    fun setQuality(quality: MediaQuality) {
        _selectedQuality.value = quality
        if (quality == MediaQuality.AUDIO_ONLY || quality == MediaQuality.AUDIO_COMPACT) {
            _selectedFormat.value = if (quality == MediaQuality.AUDIO_ONLY) MediaFormat.MP3 else MediaFormat.M4A
        } else {
            _selectedFormat.value = MediaFormat.MP4
        }
    }

    fun startDownload(
        mediaInfo: MediaInfo? = _extractedMedia.value,
        format: MediaFormat = _selectedFormat.value,
        quality: MediaQuality = _selectedQuality.value,
        resumeFromBytes: Long = 0L,
        resumeFilePath: String? = null
    ) {
        val media = mediaInfo ?: return

        activeDownloadJob?.cancel()
        activeDownloadJob = viewModelScope.launch {
            // Create or update history record
            val historyRecord = DownloadHistoryRecord(
                title = media.title,
                author = media.author,
                sourceUrl = media.originalUrl,
                videoId = media.videoId,
                mediaType = format.mediaType,
                format = format,
                quality = quality,
                status = DownloadStatus.INTERRUPTED, // initial until complete/failed
                bytesDownloaded = resumeFromBytes,
                totalBytes = if (format.mediaType == MediaType.VIDEO) media.estimatedVideoSizeBytes else media.estimatedAudioSizeBytes,
                durationFormatted = media.durationFormatted,
                durationMs = media.durationMs,
                thumbnailUrl = media.thumbnailUrl,
                filePath = resumeFilePath ?: ""
            )
            val historyId = repository.insertHistory(historyRecord)
            currentDownloadHistoryId = historyId

            downloader.downloadMedia(
                mediaInfo = media,
                format = format,
                quality = quality,
                resumeFromBytes = resumeFromBytes,
                resumeFilePath = resumeFilePath,
                targetFolderId = _targetFolderForDownload.value?.id,
                targetFolderName = _targetFolderForDownload.value?.name
            ).collect { state ->
                _downloadState.value = state
                when (state) {
                    is DownloadState.Success -> {
                        val savedId = repository.insertMedia(state.savedMedia)
                        repository.updateHistory(
                            historyRecord.copy(
                                id = historyId,
                                status = DownloadStatus.COMPLETED,
                                bytesDownloaded = state.savedMedia.fileSizeBytes,
                                totalBytes = state.savedMedia.fileSizeBytes,
                                filePath = state.savedMedia.filePath,
                                mediaStoreUri = state.savedMedia.mediaStoreUri
                            )
                        )
                        _userMessage.value = "Saved \"${state.savedMedia.title}\" to Media Vault & Gallery!"
                    }
                    is DownloadState.Interrupted -> {
                        repository.updateHistory(
                            historyRecord.copy(
                                id = historyId,
                                status = DownloadStatus.INTERRUPTED,
                                bytesDownloaded = state.bytesDownloaded,
                                totalBytes = state.totalBytes,
                                filePath = state.tempFilePath,
                                errorMessage = state.reason
                            )
                        )
                        _userMessage.value = "Download paused / saved progress (${state.bytesDownloaded / 1024} KB)"
                    }
                    is DownloadState.Error -> {
                        repository.updateHistory(
                            historyRecord.copy(
                                id = historyId,
                                status = DownloadStatus.FAILED,
                                bytesDownloaded = state.bytesDownloaded,
                                totalBytes = state.totalBytes,
                                filePath = state.tempFilePath,
                                errorMessage = state.message
                            )
                        )
                        _userMessage.value = "Download error: ${state.message}"
                    }
                    else -> {}
                }
            }
        }
    }

    fun cancelDownload() {
        activeDownloadJob?.cancel()
        _downloadState.value = DownloadState.Idle
        _userMessage.value = "Download cancelled"
    }

    fun clearDownloadState() {
        _downloadState.value = DownloadState.Idle
    }

    fun clearInput() {
        _inputUrl.value = ""
        _extractedMedia.value = null
    }

    // ==========================================
    // History Actions & Retry / Resume
    // ==========================================
    fun setHistoryFilter(filter: HistoryFilter) {
        _historyFilter.value = filter
    }

    fun retryDownloadFromHistory(record: DownloadHistoryRecord) {
        viewModelScope.launch {
            _userMessage.value = "Retrying \"${record.title}\"..."
            val mediaInfo = MediaInfo(
                title = record.title,
                author = record.author,
                originalUrl = record.sourceUrl,
                videoId = record.videoId,
                thumbnailUrl = record.thumbnailUrl,
                durationFormatted = record.durationFormatted,
                durationMs = record.durationMs
            )

            val resumeBytes = if (record.status == DownloadStatus.INTERRUPTED && record.filePath.isNotEmpty() && File(record.filePath).exists()) {
                record.bytesDownloaded
            } else {
                0L
            }

            startDownload(
                mediaInfo = mediaInfo,
                format = record.format,
                quality = record.quality,
                resumeFromBytes = resumeBytes,
                resumeFilePath = record.filePath.takeIf { resumeBytes > 0 }
            )
        }
    }

    fun resumeInterruptedDownload(record: DownloadHistoryRecord) {
        retryDownloadFromHistory(record)
    }

    fun deleteHistoryRecord(id: Long) {
        viewModelScope.launch {
            repository.deleteHistoryById(id)
            _userMessage.value = "History entry removed"
        }
    }

    fun clearAllHistory() {
        viewModelScope.launch {
            repository.clearAllHistory()
            _userMessage.value = "Download history cleared"
        }
    }

    // ==========================================
    // Playlists Actions
    // ==========================================
    fun selectPlaylist(playlist: Playlist?) {
        _selectedPlaylist.value = playlist
    }

    fun createPlaylist(name: String, description: String = "", color: Long = 0xFFD0BCFF) {
        if (name.isBlank()) return
        viewModelScope.launch {
            val id = repository.createPlaylist(name.trim(), description.trim(), color)
            _userMessage.value = "Created playlist \"${name.trim()}\""
        }
    }

    fun renamePlaylist(id: Long, newName: String, newDescription: String) {
        if (newName.isBlank()) return
        viewModelScope.launch {
            val existing = repository.allPlaylists
            val current = _selectedPlaylist.value
            if (current != null && current.id == id) {
                val updated = current.copy(name = newName.trim(), description = newDescription.trim())
                repository.updatePlaylist(updated)
                _selectedPlaylist.value = updated
            } else {
                repository.updatePlaylist(
                    Playlist(id = id, name = newName.trim(), description = newDescription.trim())
                )
            }
            _userMessage.value = "Playlist updated"
        }
    }

    fun deletePlaylist(id: Long) {
        viewModelScope.launch {
            if (_selectedPlaylist.value?.id == id) {
                _selectedPlaylist.value = null
            }
            repository.deletePlaylist(id)
            _userMessage.value = "Playlist deleted"
        }
    }

    fun openAddToPlaylistDialog(media: SavedMedia) {
        _addToPlaylistTargetMedia.value = media
    }

    fun closeAddToPlaylistDialog() {
        _addToPlaylistTargetMedia.value = null
    }

    fun toggleMediaInPlaylist(playlist: Playlist, media: SavedMedia, isCurrentlyIn: Boolean) {
        viewModelScope.launch {
            if (isCurrentlyIn) {
                repository.removeMediaFromPlaylist(playlist.id, media.id)
                _userMessage.value = "Removed from \"${playlist.name}\""
            } else {
                repository.addMediaToPlaylist(playlist.id, media.id)
                _userMessage.value = "Added to \"${playlist.name}\""
            }
        }
    }

    fun removeMediaFromCurrentPlaylist(media: SavedMedia) {
        val playlist = _selectedPlaylist.value ?: return
        viewModelScope.launch {
            repository.removeMediaFromPlaylist(playlist.id, media.id)
            _userMessage.value = "Removed \"${media.title}\" from ${playlist.name}"
        }
    }

    fun playPlaylist(playlist: Playlist, startIndex: Int = 0) {
        viewModelScope.launch {
            val list = repository.getMediaForPlaylist(playlist.id).first()
            if (list.isNotEmpty()) {
                _playbackQueue.value = list
                _playbackQueueIndex.value = startIndex.coerceIn(0, list.lastIndex)
                _currentPlaylistName.value = playlist.name
                _currentPlayingMedia.value = list[_playbackQueueIndex.value]
            } else {
                _userMessage.value = "Playlist is empty"
            }
        }
    }

    fun shufflePlaylist(playlist: Playlist) {
        viewModelScope.launch {
            val list = repository.getMediaForPlaylist(playlist.id).first()
            if (list.isNotEmpty()) {
                val shuffled = list.shuffled()
                _playbackQueue.value = shuffled
                _playbackQueueIndex.value = 0
                _currentPlaylistName.value = "${playlist.name} (Shuffled)"
                _currentPlayingMedia.value = shuffled[0]
            } else {
                _userMessage.value = "Playlist is empty"
            }
        }
    }

    fun playQueueItem(index: Int) {
        val queue = _playbackQueue.value
        if (index in queue.indices) {
            _playbackQueueIndex.value = index
            _currentPlayingMedia.value = queue[index]
        }
    }

    fun playNextInQueue() {
        val queue = _playbackQueue.value
        val nextIndex = _playbackQueueIndex.value + 1
        if (nextIndex < queue.size) {
            _playbackQueueIndex.value = nextIndex
            _currentPlayingMedia.value = queue[nextIndex]
        } else {
            _userMessage.value = "Reached end of playlist"
        }
    }

    fun playPreviousInQueue() {
        val queue = _playbackQueue.value
        val prevIndex = _playbackQueueIndex.value - 1
        if (prevIndex >= 0) {
            _playbackQueueIndex.value = prevIndex
            _currentPlayingMedia.value = queue[prevIndex]
        }
    }

    // ==========================================
    // Folder Actions
    // ==========================================
    fun selectFolder(folderId: Long?) {
        _selectedFolderId.value = folderId
    }

    fun setTargetFolderForDownload(folder: MediaFolder?) {
        _targetFolderForDownload.value = folder
    }

    fun setMoveToFolderTargetMedia(media: SavedMedia?) {
        _moveToFolderTargetMedia.value = media
    }

    fun createFolder(name: String, color: Long = 0xFF6750A4, iconName: String = "folder", description: String = "") {
        if (name.isBlank()) {
            _userMessage.value = "Folder name cannot be empty"
            return
        }
        viewModelScope.launch {
            val folderId = repository.createFolder(name, color, iconName, description)
            _userMessage.value = "Created folder \"$name\""
        }
    }

    fun updateFolder(folder: MediaFolder) {
        if (folder.name.isBlank()) {
            _userMessage.value = "Folder name cannot be empty"
            return
        }
        viewModelScope.launch {
            repository.updateFolder(folder)
            _userMessage.value = "Updated folder \"${folder.name}\""
        }
    }

    fun deleteFolder(folderId: Long, deleteMedia: Boolean = false) {
        viewModelScope.launch {
            if (_selectedFolderId.value == folderId) {
                _selectedFolderId.value = null
            }
            if (_targetFolderForDownload.value?.id == folderId) {
                _targetFolderForDownload.value = null
            }
            repository.deleteFolder(folderId, deleteMedia)
            _userMessage.value = "Deleted folder"
        }
    }

    fun moveMediaToFolder(mediaId: Long, folder: MediaFolder?) {
        viewModelScope.launch {
            repository.moveMediaToFolder(mediaId, folder?.id, folder?.name)
            _userMessage.value = if (folder != null) "Moved to \"${folder.name}\"" else "Moved to Uncategorized"
            _moveToFolderTargetMedia.value = null
        }
    }

    fun removeMediaFromFolder(mediaId: Long) {
        viewModelScope.launch {
            repository.moveMediaToFolder(mediaId, null, null)
            _userMessage.value = "Removed from folder"
        }
    }

    // ==========================================
    // Batch / Multi-Link Downloader Actions
    // ==========================================
    fun setBatchInputText(text: String) {
        _batchInputText.value = text
    }

    fun pasteBatchFromClipboard() {
        val clipboard = getApplication<Application>().getSystemService(Context.CLIPBOARD_SERVICE) as? ClipboardManager
        if (clipboard != null && clipboard.hasPrimaryClip()) {
            val clipData = clipboard.primaryClip
            if (clipData != null && clipData.itemCount > 0) {
                val text = clipData.getItemAt(0).text?.toString()?.trim() ?: ""
                if (text.isNotEmpty()) {
                    val current = _batchInputText.value
                    _batchInputText.value = if (current.isBlank()) text else "$current\n$text"
                    _userMessage.value = "Pasted links into batch input"
                }
            }
        }
    }

    fun parseBatchUrls(rawInput: String = _batchInputText.value) {
        if (rawInput.isBlank()) {
            _userMessage.value = "Please enter one or more media links"
            return
        }

        viewModelScope.launch {
            _isBatchParsing.value = true
            val lines = rawInput.split("\n", ",", " ", "\t")
                .map { it.trim() }
                .filter { it.isNotBlank() && (it.startsWith("http://") || it.startsWith("https://") || it.contains("youtu")) }
                .distinct()

            if (lines.isEmpty()) {
                _isBatchParsing.value = false
                _userMessage.value = "No valid URLs found. Please check format."
                return@launch
            }

            val newItems = mutableListOf<BatchDownloadItem>()
            for (url in lines) {
                val clean = MediaExtractor.cleanUrl(url)
                val isSupported = MediaExtractor.isSupportedUrl(clean)
                if (isSupported) {
                    val extractRes = MediaExtractor.extractMediaInfo(clean)
                    val mediaInfo = extractRes.getOrNull() ?: MediaInfo(
                        title = "Media Clip - ${clean.takeLast(12)}",
                        author = "Vault Downloader",
                        originalUrl = clean,
                        videoId = clean.takeLast(10),
                        thumbnailUrl = "",
                        isYouTube = clean.contains("youtu")
                    )
                    newItems.add(
                        BatchDownloadItem(
                            rawUrl = clean,
                            mediaInfo = mediaInfo,
                            format = MediaFormat.MP4,
                            quality = MediaQuality.BEST,
                            status = BatchItemStatus.READY,
                            isSelected = true
                        )
                    )
                }
            }

            _batchItems.value = newItems
            _isBatchParsing.value = false
            _userMessage.value = "Parsed ${newItems.size} links successfully!"
        }
    }

    fun toggleBatchItemSelection(itemId: String) {
        _batchItems.update { list ->
            list.map { item ->
                if (item.id == itemId) item.copy(isSelected = !item.isSelected) else item
            }
        }
    }

    fun selectAllBatchItems(selected: Boolean) {
        _batchItems.update { list ->
            list.map { it.copy(isSelected = selected) }
        }
    }

    fun setBatchItemFormat(itemId: String, format: MediaFormat) {
        _batchItems.update { list ->
            list.map { item ->
                if (item.id == itemId) {
                    val newQuality = if (format.mediaType == MediaType.AUDIO && item.quality == MediaQuality.BEST) {
                        MediaQuality.AUDIO_ONLY
                    } else if (format.mediaType == MediaType.VIDEO && item.quality == MediaQuality.AUDIO_ONLY) {
                        MediaQuality.BEST
                    } else {
                        item.quality
                    }
                    item.copy(format = format, quality = newQuality)
                } else item
            }
        }
    }

    fun setBatchItemQuality(itemId: String, quality: MediaQuality) {
        _batchItems.update { list ->
            list.map { item ->
                if (item.id == itemId) {
                    val newFormat = if (quality == MediaQuality.AUDIO_ONLY) MediaFormat.MP3
                    else if (quality == MediaQuality.AUDIO_COMPACT) MediaFormat.M4A
                    else MediaFormat.MP4
                    item.copy(quality = quality, format = newFormat)
                } else item
            }
        }
    }

    fun applyBatchFormatToAll(format: MediaFormat, quality: MediaQuality) {
        _batchItems.update { list ->
            list.map { it.copy(format = format, quality = quality) }
        }
        _userMessage.value = "Applied ${format.name} (${quality.displayName}) to all items"
    }

    fun startBatchDownloads() {
        val itemsToDownload = _batchItems.value.filter {
            it.isSelected && (it.status == BatchItemStatus.READY || it.status == BatchItemStatus.FAILED || it.status == BatchItemStatus.INTERRUPTED || it.status == BatchItemStatus.PAUSED)
        }

        if (itemsToDownload.isEmpty()) {
            _userMessage.value = "No selected items ready to download"
            return
        }

        _isBatchDownloading.value = true
        _userMessage.value = "Starting batch download of ${itemsToDownload.size} items..."

        // Mark them as QUEUED
        _batchItems.update { list ->
            list.map { item ->
                if (itemsToDownload.any { it.id == item.id }) item.copy(status = BatchItemStatus.QUEUED)
                else item
            }
        }

        for (item in itemsToDownload) {
            val job = viewModelScope.launch(Dispatchers.IO) {
                batchConcurrencySemaphore.withPermit {
                    downloadSingleBatchItem(item.id)
                }
            }
            batchDownloadJobs[item.id] = job
        }
    }

    private suspend fun downloadSingleBatchItem(itemId: String) {
        val currentItem = _batchItems.value.firstOrNull { it.id == itemId } ?: return
        val media = currentItem.mediaInfo ?: return

        _batchItems.update { list ->
            list.map { if (it.id == itemId) it.copy(status = BatchItemStatus.DOWNLOADING) else it }
        }

        // Insert initial history record
        val historyRecord = DownloadHistoryRecord(
            title = media.title,
            author = media.author,
            sourceUrl = media.originalUrl,
            videoId = media.videoId,
            mediaType = currentItem.format.mediaType,
            format = currentItem.format,
            quality = currentItem.quality,
            status = DownloadStatus.INTERRUPTED,
            bytesDownloaded = currentItem.bytesDownloaded,
            totalBytes = if (currentItem.format.mediaType == MediaType.VIDEO) media.estimatedVideoSizeBytes else media.estimatedAudioSizeBytes,
            durationFormatted = media.durationFormatted,
            durationMs = media.durationMs,
            thumbnailUrl = media.thumbnailUrl,
            filePath = currentItem.tempFilePath
        )
        val historyId = repository.insertHistory(historyRecord)

        downloader.downloadMedia(
            mediaInfo = media,
            format = currentItem.format,
            quality = currentItem.quality,
            resumeFromBytes = currentItem.bytesDownloaded,
            resumeFilePath = currentItem.tempFilePath.takeIf { it.isNotBlank() }
        ).collect { state ->
            when (state) {
                is DownloadState.Progress -> {
                    _batchItems.update { list ->
                        list.map {
                            if (it.id == itemId) {
                                it.copy(
                                    status = BatchItemStatus.DOWNLOADING,
                                    progress = state.progress,
                                    bytesDownloaded = state.bytesDownloaded,
                                    totalBytes = state.totalBytes,
                                    speedFormatted = state.speedFormatted,
                                    etaSeconds = state.etaSeconds,
                                    tempFilePath = state.tempFilePath
                                )
                            } else it
                        }
                    }
                }
                is DownloadState.Success -> {
                    val savedMedia = state.savedMedia
                    repository.insertMedia(savedMedia)
                    repository.updateHistory(
                        historyRecord.copy(
                            id = historyId,
                            status = DownloadStatus.COMPLETED,
                            bytesDownloaded = savedMedia.fileSizeBytes,
                            totalBytes = savedMedia.fileSizeBytes,
                            filePath = savedMedia.filePath,
                            mediaStoreUri = savedMedia.mediaStoreUri
                        )
                    )
                    _batchItems.update { list ->
                        list.map {
                            if (it.id == itemId) {
                                it.copy(
                                    status = BatchItemStatus.COMPLETED,
                                    progress = 1.0f,
                                    bytesDownloaded = savedMedia.fileSizeBytes,
                                    totalBytes = savedMedia.fileSizeBytes,
                                    savedMedia = savedMedia
                                )
                            } else it
                        }
                    }
                }
                is DownloadState.Interrupted -> {
                    repository.updateHistory(
                        historyRecord.copy(
                            id = historyId,
                            status = DownloadStatus.INTERRUPTED,
                            bytesDownloaded = state.bytesDownloaded,
                            totalBytes = state.totalBytes,
                            filePath = state.tempFilePath,
                            errorMessage = state.reason
                        )
                    )
                    _batchItems.update { list ->
                        list.map {
                            if (it.id == itemId) {
                                it.copy(
                                    status = BatchItemStatus.INTERRUPTED,
                                    bytesDownloaded = state.bytesDownloaded,
                                    totalBytes = state.totalBytes,
                                    tempFilePath = state.tempFilePath,
                                    errorMessage = state.reason
                                )
                            } else it
                        }
                    }
                }
                is DownloadState.Error -> {
                    repository.updateHistory(
                        historyRecord.copy(
                            id = historyId,
                            status = DownloadStatus.FAILED,
                            bytesDownloaded = state.bytesDownloaded,
                            totalBytes = state.totalBytes,
                            filePath = state.tempFilePath,
                            errorMessage = state.message
                        )
                    )
                    _batchItems.update { list ->
                        list.map {
                            if (it.id == itemId) {
                                it.copy(
                                    status = BatchItemStatus.FAILED,
                                    errorMessage = state.message,
                                    tempFilePath = state.tempFilePath
                                )
                            } else it
                        }
                    }
                }
                else -> {}
            }
        }
    }

    fun pauseBatchItem(itemId: String) {
        batchDownloadJobs[itemId]?.cancel()
        batchDownloadJobs.remove(itemId)
        _batchItems.update { list ->
            list.map {
                if (it.id == itemId) it.copy(status = BatchItemStatus.PAUSED) else it
            }
        }
    }

    fun resumeBatchItem(itemId: String) {
        val job = viewModelScope.launch(Dispatchers.IO) {
            batchConcurrencySemaphore.withPermit {
                downloadSingleBatchItem(itemId)
            }
        }
        batchDownloadJobs[itemId] = job
    }

    fun retryBatchItem(itemId: String) {
        _batchItems.update { list ->
            list.map {
                if (it.id == itemId) it.copy(status = BatchItemStatus.READY, errorMessage = null) else it
            }
        }
        resumeBatchItem(itemId)
    }

    fun removeBatchItem(itemId: String) {
        batchDownloadJobs[itemId]?.cancel()
        batchDownloadJobs.remove(itemId)
        _batchItems.update { list -> list.filter { it.id != itemId } }
    }

    fun clearCompletedBatchItems() {
        _batchItems.update { list ->
            list.filter { it.status != BatchItemStatus.COMPLETED }
        }
    }

    fun clearBatchList() {
        batchDownloadJobs.values.forEach { it.cancel() }
        batchDownloadJobs.clear()
        _batchItems.value = emptyList()
        _batchInputText.value = ""
    }

    // ==========================================
    // Library & Player Actions
    // ==========================================
    fun setLibraryFilter(filter: LibraryTabFilter) {
        _libraryFilter.value = filter
    }

    fun setSearchQuery(query: String) {
        _searchQuery.value = query
    }

    fun playMedia(media: SavedMedia) {
        _playbackQueue.value = listOf(media)
        _playbackQueueIndex.value = 0
        _currentPlaylistName.value = null
        _currentPlayingMedia.value = media
    }

    fun closePlayer() {
        _currentPlayingMedia.value = null
        _currentPlaylistName.value = null
    }

    fun deleteMedia(media: SavedMedia) {
        viewModelScope.launch {
            if (_currentPlayingMedia.value?.id == media.id) {
                _currentPlayingMedia.value = null
            }
            repository.deleteMedia(media)
            _userMessage.value = "Removed \"${media.title}\" from Vault"
        }
    }

    fun shareMediaFile(context: Context, media: SavedMedia) {
        try {
            val shareUri: Uri = if (media.mediaStoreUri.isNotEmpty()) {
                Uri.parse(media.mediaStoreUri)
            } else if (media.filePath.isNotEmpty()) {
                val file = File(media.filePath)
                FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", file)
            } else {
                _userMessage.value = "File not available to share"
                return
            }

            val shareIntent = Intent(Intent.ACTION_SEND).apply {
                type = media.format.mimeType
                putExtra(Intent.EXTRA_STREAM, shareUri)
                putExtra(Intent.EXTRA_TITLE, media.title)
                putExtra(Intent.EXTRA_TEXT, "Shared from Media Vault: ${media.title}")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }

            val chooser = Intent.createChooser(shareIntent, "Share \"${media.title}\"")
            chooser.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(chooser)
        } catch (e: Exception) {
            _userMessage.value = "Share failed: ${e.localizedMessage}"
        }
    }

    fun clearUserMessage() {
        _userMessage.value = null
    }
}
