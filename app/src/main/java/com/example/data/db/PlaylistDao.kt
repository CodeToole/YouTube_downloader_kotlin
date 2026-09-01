package com.example.data.db

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Update
import com.example.data.model.Playlist
import com.example.data.model.PlaylistItemCrossRef
import com.example.data.model.SavedMedia
import kotlinx.coroutines.flow.Flow

@Dao
interface PlaylistDao {
    @Query("SELECT * FROM playlists ORDER BY createdAt DESC")
    fun getAllPlaylists(): Flow<List<Playlist>>

    @Query("SELECT * FROM playlists WHERE id = :id LIMIT 1")
    suspend fun getPlaylistById(id: Long): Playlist?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertPlaylist(playlist: Playlist): Long

    @Update
    suspend fun updatePlaylist(playlist: Playlist)

    @Query("DELETE FROM playlists WHERE id = :id")
    suspend fun deletePlaylistById(id: Long)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertPlaylistItem(item: PlaylistItemCrossRef)

    @Query("DELETE FROM playlist_items WHERE playlistId = :playlistId AND mediaId = :mediaId")
    suspend fun deletePlaylistItem(playlistId: Long, mediaId: Long)

    @Query("DELETE FROM playlist_items WHERE playlistId = :playlistId")
    suspend fun deletePlaylistItemsByPlaylistId(playlistId: Long)

    @Query("""
        SELECT sm.* FROM saved_media sm
        INNER JOIN playlist_items pi ON sm.id = pi.mediaId
        WHERE pi.playlistId = :playlistId
        ORDER BY pi.orderIndex ASC, pi.addedAt ASC
    """)
    fun getMediaForPlaylist(playlistId: Long): Flow<List<SavedMedia>>

    @Query("SELECT playlistId FROM playlist_items WHERE mediaId = :mediaId")
    fun getPlaylistIdsForMedia(mediaId: Long): Flow<List<Long>>

    @Query("SELECT COUNT(*) FROM playlist_items WHERE playlistId = :playlistId")
    fun getItemCountForPlaylist(playlistId: Long): Flow<Int>
}
