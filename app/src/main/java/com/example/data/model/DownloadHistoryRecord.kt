package com.example.data.model

import androidx.room.Entity
import androidx.room.PrimaryKey

enum class DownloadStatus {
    COMPLETED,
    FAILED,
    INTERRUPTED
}

@Entity(tableName = "download_history")
data class DownloadHistoryRecord(
    @PrimaryKey(autoGenerate = true)
    val id: Long = 0,
    val title: String,
    val author: String,
    val sourceUrl: String,
    val videoId: String? = null,
    val mediaType: MediaType,
    val format: MediaFormat,
    val quality: MediaQuality,
    val status: DownloadStatus,
    val bytesDownloaded: Long = 0L,
    val totalBytes: Long = 0L,
    val errorMessage: String? = null,
    val durationFormatted: String = "",
    val durationMs: Long = 0L,
    val thumbnailUrl: String = "",
    val filePath: String = "",
    val mediaStoreUri: String = "",
    val timestamp: Long = System.currentTimeMillis()
)
