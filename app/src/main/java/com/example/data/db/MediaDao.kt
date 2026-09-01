package com.example.data.db

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import com.example.data.model.MediaType
import com.example.data.model.SavedMedia
import kotlinx.coroutines.flow.Flow

@Dao
interface MediaDao {
    @Query("SELECT * FROM saved_media ORDER BY downloadDate DESC")
    fun getAllMedia(): Flow<List<SavedMedia>>

    @Query("SELECT * FROM saved_media WHERE mediaType = :mediaType ORDER BY downloadDate DESC")
    fun getMediaByType(mediaType: MediaType): Flow<List<SavedMedia>>

    @Query("SELECT * FROM saved_media WHERE id = :id LIMIT 1")
    suspend fun getMediaById(id: Long): SavedMedia?

    @Query("SELECT * FROM saved_media WHERE sourceUrl = :url LIMIT 1")
    suspend fun getMediaByUrl(url: String): SavedMedia?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertMedia(media: SavedMedia): Long

    @Query("DELETE FROM saved_media WHERE id = :id")
    suspend fun deleteMediaById(id: Long)

    @Query("DELETE FROM saved_media")
    suspend fun deleteAllMedia()
}
