package com.example.data.repository

import android.content.Context
import android.net.Uri
import com.example.data.db.DownloadHistoryDao
import com.example.data.db.MediaDao
import com.example.data.db.PlaylistDao
import com.example.data.model.DownloadHistoryRecord
import com.example.data.model.DownloadStatus
import com.example.data.model.MediaType
import com.example.data.model.Playlist
import com.example.data.model.PlaylistItemCrossRef
import com.example.data.model.SavedMedia
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.withContext
import java.io.File

class MediaRepository(
    private val context: Context,
    private val mediaDao: MediaDao,
    private val historyDao: DownloadHistoryDao,
    private val playlistDao: PlaylistDao
) {
    // Media Operations
    val allMedia: Flow<List<SavedMedia>> = mediaDao.getAllMedia()

    fun getMediaByType(mediaType: MediaType): Flow<List<SavedMedia>> =
        mediaDao.getMediaByType(mediaType)

    suspend fun insertMedia(media: SavedMedia): Long = withContext(Dispatchers.IO) {
        mediaDao.insertMedia(media)
    }

    suspend fun getMediaById(id: Long): SavedMedia? = withContext(Dispatchers.IO) {
        mediaDao.getMediaById(id)
    }

    suspend fun deleteMedia(media: SavedMedia) = withContext(Dispatchers.IO) {
        // Delete from MediaStore if Uri is present
        if (media.mediaStoreUri.isNotEmpty()) {
            try {
                val uri = Uri.parse(media.mediaStoreUri)
                context.contentResolver.delete(uri, null, null)
            } catch (e: Exception) {
                // MediaStore delete may throw SecurityException if owned by another, or file may already be removed
            }
        }
        // Delete fallback local file if exists
        if (media.filePath.isNotEmpty()) {
            try {
                val file = File(media.filePath)
                if (file.exists()) {
                    file.delete()
                }
            } catch (e: Exception) {
                // Ignore file removal error
            }
        }
        // Delete from database
        mediaDao.deleteMediaById(media.id)
    }

    // Download History Operations
    val allHistory: Flow<List<DownloadHistoryRecord>> = historyDao.getAllHistory()

    fun getHistoryByStatus(status: DownloadStatus): Flow<List<DownloadHistoryRecord>> =
        historyDao.getHistoryByStatus(status)

    suspend fun insertHistory(record: DownloadHistoryRecord): Long = withContext(Dispatchers.IO) {
        historyDao.insertHistory(record)
    }

    suspend fun updateHistory(record: DownloadHistoryRecord) = withContext(Dispatchers.IO) {
        historyDao.updateHistory(record)
    }

    suspend fun deleteHistoryById(id: Long) = withContext(Dispatchers.IO) {
        historyDao.deleteHistoryById(id)
    }

    suspend fun clearAllHistory() = withContext(Dispatchers.IO) {
        historyDao.clearAllHistory()
    }

    suspend fun getHistoryById(id: Long): DownloadHistoryRecord? = withContext(Dispatchers.IO) {
        historyDao.getHistoryById(id)
    }

    // Playlist Operations
    val allPlaylists: Flow<List<Playlist>> = playlistDao.getAllPlaylists()

    fun getMediaForPlaylist(playlistId: Long): Flow<List<SavedMedia>> =
        playlistDao.getMediaForPlaylist(playlistId)

    fun getPlaylistIdsForMedia(mediaId: Long): Flow<List<Long>> =
        playlistDao.getPlaylistIdsForMedia(mediaId)

    fun getItemCountForPlaylist(playlistId: Long): Flow<Int> =
        playlistDao.getItemCountForPlaylist(playlistId)

    suspend fun createPlaylist(name: String, description: String = "", color: Long = 0xFFD0BCFF): Long = withContext(Dispatchers.IO) {
        playlistDao.insertPlaylist(
            Playlist(
                name = name,
                description = description,
                iconColor = color
            )
        )
    }

    suspend fun updatePlaylist(playlist: Playlist) = withContext(Dispatchers.IO) {
        playlistDao.updatePlaylist(playlist)
    }

    suspend fun deletePlaylist(id: Long) = withContext(Dispatchers.IO) {
        playlistDao.deletePlaylistItemsByPlaylistId(id)
        playlistDao.deletePlaylistById(id)
    }

    suspend fun addMediaToPlaylist(playlistId: Long, mediaId: Long, orderIndex: Int = 0) = withContext(Dispatchers.IO) {
        playlistDao.insertPlaylistItem(
            PlaylistItemCrossRef(
                playlistId = playlistId,
                mediaId = mediaId,
                orderIndex = orderIndex
            )
        )
    }

    suspend fun removeMediaFromPlaylist(playlistId: Long, mediaId: Long) = withContext(Dispatchers.IO) {
        playlistDao.deletePlaylistItem(playlistId, mediaId)
    }
}

