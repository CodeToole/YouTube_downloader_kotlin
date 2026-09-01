package com.example.data.db

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Update
import com.example.data.model.DownloadHistoryRecord
import com.example.data.model.DownloadStatus
import kotlinx.coroutines.flow.Flow

@Dao
interface DownloadHistoryDao {
    @Query("SELECT * FROM download_history ORDER BY timestamp DESC")
    fun getAllHistory(): Flow<List<DownloadHistoryRecord>>

    @Query("SELECT * FROM download_history WHERE status = :status ORDER BY timestamp DESC")
    fun getHistoryByStatus(status: DownloadStatus): Flow<List<DownloadHistoryRecord>>

    @Query("SELECT * FROM download_history WHERE id = :id LIMIT 1")
    suspend fun getHistoryById(id: Long): DownloadHistoryRecord?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertHistory(record: DownloadHistoryRecord): Long

    @Update
    suspend fun updateHistory(record: DownloadHistoryRecord)

    @Query("DELETE FROM download_history WHERE id = :id")
    suspend fun deleteHistoryById(id: Long)

    @Query("DELETE FROM download_history")
    suspend fun clearAllHistory()
}
