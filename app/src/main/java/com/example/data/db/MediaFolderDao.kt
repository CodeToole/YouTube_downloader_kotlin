package com.example.data.db

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Update
import com.example.data.model.MediaFolder
import kotlinx.coroutines.flow.Flow

@Dao
interface MediaFolderDao {
    @Query("SELECT * FROM media_folders ORDER BY name ASC")
    fun getAllFolders(): Flow<List<MediaFolder>>

    @Query("SELECT * FROM media_folders WHERE id = :id LIMIT 1")
    suspend fun getFolderById(id: Long): MediaFolder?

    @Query("SELECT * FROM media_folders WHERE name = :name LIMIT 1")
    suspend fun getFolderByName(name: String): MediaFolder?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertFolder(folder: MediaFolder): Long

    @Update
    suspend fun updateFolder(folder: MediaFolder)

    @Query("DELETE FROM media_folders WHERE id = :id")
    suspend fun deleteFolderById(id: Long)

    @Query("DELETE FROM media_folders")
    suspend fun deleteAllFolders()
}
