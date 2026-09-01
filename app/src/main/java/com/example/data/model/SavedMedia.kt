package com.example.data.model

import androidx.room.Entity
import androidx.room.PrimaryKey

enum class MediaType {
    VIDEO,
    AUDIO
}

enum class MediaFormat(val extension: String, val mimeType: String, val mediaType: MediaType) {
    MP4("mp4", "video/mp4", MediaType.VIDEO),
    MP3("mp3", "audio/mpeg", MediaType.AUDIO),
    M4A("m4a", "audio/mp4", MediaType.AUDIO)
}

enum class MediaQuality(val displayName: String, val resolutionOrBitrate: String) {
    BEST("Highest Quality", "1080p / 320kbps"),
    STANDARD("Standard (720p / 192kbps)", "720p / 192kbps"),
    AUDIO_ONLY("Audio Only (320kbps MP3)", "320kbps"),
    AUDIO_COMPACT("Audio Compact (128kbps M4A)", "128kbps")
}

@Entity(tableName = "saved_media")
data class SavedMedia(
    @PrimaryKey(autoGenerate = true)
    val id: Long = 0,
    val title: String,
    val author: String,
    val sourceUrl: String,
    val videoId: String? = null,
    val mediaType: MediaType,
    val format: MediaFormat,
    val quality: MediaQuality,
    val fileSizeBytes: Long = 0L,
    val durationMs: Long = 0L,
    val thumbnailUrl: String = "",
    val mediaStoreUri: String = "",
    val filePath: String = "",
    val downloadDate: Long = System.currentTimeMillis(),
    val folderId: Long? = null,
    val folderName: String? = null
)
