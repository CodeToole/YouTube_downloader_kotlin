package com.example.data.model

import java.util.UUID

enum class BatchItemStatus {
    IDLE,
    PARSING,
    READY,
    QUEUED,
    DOWNLOADING,
    PAUSED,
    INTERRUPTED,
    COMPLETED,
    FAILED
}

data class BatchDownloadItem(
    val id: String = UUID.randomUUID().toString(),
    val rawUrl: String,
    val mediaInfo: MediaInfo? = null,
    val format: MediaFormat = MediaFormat.MP4,
    val quality: MediaQuality = MediaQuality.BEST,
    val isSelected: Boolean = true,
    val status: BatchItemStatus = BatchItemStatus.IDLE,
    val progress: Float = 0f,
    val bytesDownloaded: Long = 0L,
    val totalBytes: Long = 0L,
    val speedFormatted: String = "",
    val etaSeconds: Long = 0L,
    val errorMessage: String? = null,
    val tempFilePath: String = "",
    val savedMedia: SavedMedia? = null,
    val historyId: Long? = null
)
