package com.example.data.model

data class MediaInfo(
    val title: String,
    val author: String,
    val originalUrl: String,
    val videoId: String?,
    val thumbnailUrl: String,
    val durationFormatted: String = "03:45",
    val durationMs: Long = 225000L,
    val isYouTube: Boolean = true,
    val estimatedVideoSizeBytes: Long = 18_500_000L,
    val estimatedAudioSizeBytes: Long = 4_200_000L
)
