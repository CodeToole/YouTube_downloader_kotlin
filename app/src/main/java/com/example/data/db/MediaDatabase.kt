package com.example.data.db

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase
import com.example.data.model.DownloadHistoryRecord
import com.example.data.model.MediaFolder
import com.example.data.model.Playlist
import com.example.data.model.PlaylistItemCrossRef
import com.example.data.model.SavedMedia

@Database(
    entities = [
        SavedMedia::class,
        DownloadHistoryRecord::class,
        Playlist::class,
        PlaylistItemCrossRef::class,
        MediaFolder::class
    ],
    version = 3,
    exportSchema = false
)
abstract class MediaDatabase : RoomDatabase() {
    abstract fun mediaDao(): MediaDao
    abstract fun downloadHistoryDao(): DownloadHistoryDao
    abstract fun playlistDao(): PlaylistDao
    abstract fun mediaFolderDao(): MediaFolderDao

    companion object {
        @Volatile
        private var INSTANCE: MediaDatabase? = null

        fun getDatabase(context: Context): MediaDatabase {
            return INSTANCE ?: synchronized(this) {
                val instance = Room.databaseBuilder(
                    context.applicationContext,
                    MediaDatabase::class.java,
                    "media_vault_db"
                ).fallbackToDestructiveMigration()
                 .build()
                INSTANCE = instance
                instance
            }
        }
    }
}

