package com.example.data.model

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "media_folders")
data class MediaFolder(
    @PrimaryKey(autoGenerate = true)
    val id: Long = 0,
    val name: String,
    val color: Long = 0xFF6750A4, // Primary Accent Color
    val iconName: String = "folder", // folder, music, video, school, work, star, download
    val description: String = "",
    val createdAt: Long = System.currentTimeMillis()
)
