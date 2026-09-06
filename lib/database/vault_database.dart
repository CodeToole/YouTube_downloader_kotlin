import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/saved_media.dart';
import '../models/media_folder.dart';
import '../models/playlist.dart';
import '../models/download_history_record.dart';

class VaultDatabase {
  static final VaultDatabase instance = VaultDatabase._init();
  static Database? _database;

  VaultDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('media_vault.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    // Initialize FFI for desktop platforms (Windows / Linux)
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    String fullPath;
    if (!kIsWeb && Platform.isWindows) {
      final appDir = await getApplicationSupportDirectory();
      fullPath = join(appDir.path, filePath);
    } else {
      final dbPath = await getDatabasesPath();
      fullPath = join(dbPath, filePath);
    }

    return await openDatabase(
      fullPath,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // 1. Folders table
    await db.execute('''
      CREATE TABLE media_folders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        color INTEGER NOT NULL,
        iconName TEXT NOT NULL,
        description TEXT
      )
    ''');

    // 2. Saved Media table
    await db.execute('''
      CREATE TABLE saved_media (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        author TEXT NOT NULL,
        durationSeconds INTEGER NOT NULL,
        fileSizeBytes INTEGER NOT NULL,
        format TEXT NOT NULL,
        quality TEXT NOT NULL,
        originalUrl TEXT NOT NULL,
        localFilePath TEXT NOT NULL,
        thumbnailUrl TEXT,
        folderId INTEGER,
        folderName TEXT,
        downloadDate INTEGER NOT NULL,
        FOREIGN KEY (folderId) REFERENCES media_folders (id) ON DELETE SET NULL
      )
    ''');

    // 3. Playlists table
    await db.execute('''
      CREATE TABLE playlists (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        iconColor INTEGER NOT NULL
      )
    ''');

    // 4. Playlist items cross-reference table
    await db.execute('''
      CREATE TABLE playlist_items (
        playlistId INTEGER NOT NULL,
        mediaId INTEGER NOT NULL,
        orderIndex INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (playlistId, mediaId),
        FOREIGN KEY (playlistId) REFERENCES playlists (id) ON DELETE CASCADE,
        FOREIGN KEY (mediaId) REFERENCES saved_media (id) ON DELETE CASCADE
      )
    ''');

    // 5. Download History table
    await db.execute('''
      CREATE TABLE download_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        originalUrl TEXT NOT NULL,
        title TEXT NOT NULL,
        author TEXT NOT NULL,
        format TEXT NOT NULL,
        quality TEXT NOT NULL,
        status TEXT NOT NULL,
        bytesDownloaded INTEGER NOT NULL,
        totalBytes INTEGER NOT NULL,
        localFilePath TEXT NOT NULL,
        errorMessage TEXT,
        timestamp INTEGER NOT NULL
      )
    ''');
  }

  // ==========================================
  // Media Operations
  // ==========================================
  Future<int> insertMedia(SavedMedia media) async {
    final db = await database;
    return await db.insert('saved_media', media.toMap());
  }

  Future<List<SavedMedia>> getAllMedia({
    int? folderId,
    String? mediaType, // 'ALL', 'VIDEOS', 'AUDIO'
    String? searchQuery,
    String sortBy = 'DATE_DESC',
  }) async {
    final db = await database;
    List<String> whereClauses = [];
    List<dynamic> whereArgs = [];

    // Folder filter: null = all, -1 = uncategorized, >0 = specific folder
    if (folderId != null) {
      if (folderId == -1) {
        whereClauses.add('folderId IS NULL');
      } else {
        whereClauses.add('folderId = ?');
        whereArgs.add(folderId);
      }
    }

    // Media type filter
    if (mediaType != null && mediaType != 'ALL') {
      if (mediaType == 'VIDEOS') {
        whereClauses.add("UPPER(format) = 'MP4'");
      } else if (mediaType == 'AUDIO') {
        whereClauses.add("UPPER(format) = 'MP3'");
      }
    }

    // Search query
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      whereClauses.add('(title LIKE ? OR author LIKE ?)');
      whereArgs.add('%${searchQuery.trim()}%');
      whereArgs.add('%${searchQuery.trim()}%');
    }

    String orderBy;
    switch (sortBy) {
      case 'TITLE_ASC':
        orderBy = 'title COLLATE NOCASE ASC';
        break;
      case 'SIZE_DESC':
        orderBy = 'fileSizeBytes DESC';
        break;
      case 'DATE_DESC':
      default:
        orderBy = 'downloadDate DESC';
        break;
    }

    final whereString = whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;
    final maps = await db.query(
      'saved_media',
      where: whereString,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: orderBy,
    );

    return maps.map((e) => SavedMedia.fromMap(e)).toList();
  }

  Future<SavedMedia?> getMediaById(int id) async {
    final db = await database;
    final maps = await db.query('saved_media', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) {
      return SavedMedia.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateMediaFolder(int mediaId, int? folderId, String? folderName) async {
    final db = await database;
    return await db.update(
      'saved_media',
      {
        'folderId': folderId,
        'folderName': folderName,
      },
      where: 'id = ?',
      whereArgs: [mediaId],
    );
  }

  Future<int> renameMedia(int mediaId, String newTitle) async {
    final db = await database;
    return await db.update(
      'saved_media',
      {'title': newTitle},
      where: 'id = ?',
      whereArgs: [mediaId],
    );
  }

  Future<int> deleteMedia(int id) async {
    final db = await database;
    // Delete cross-references first
    await db.delete('playlist_items', where: 'mediaId = ?', whereArgs: [id]);
    return await db.delete('saved_media', where: 'id = ?', whereArgs: [id]);
  }

  // ==========================================
  // Folder Operations
  // ==========================================
  Future<int> insertFolder(MediaFolder folder) async {
    final db = await database;
    return await db.insert('media_folders', folder.toMap());
  }

  Future<List<MediaFolder>> getAllFolders() async {
    final db = await database;
    final maps = await db.query('media_folders', orderBy: 'name COLLATE NOCASE ASC');
    return maps.map((e) => MediaFolder.fromMap(e)).toList();
  }

  Future<int> updateFolder(MediaFolder folder) async {
    final db = await database;
    final result = await db.update(
      'media_folders',
      folder.toMap(),
      where: 'id = ?',
      whereArgs: [folder.id],
    );
    // Also update denormalized folderName in saved_media
    await db.update(
      'saved_media',
      {'folderName': folder.name},
      where: 'folderId = ?',
      whereArgs: [folder.id],
    );
    return result;
  }

  Future<int> deleteFolder(int folderId, {bool deleteMediaFiles = false}) async {
    final db = await database;
    if (deleteMediaFiles) {
      // Find all media in folder and delete them
      final mediaList = await getAllMedia(folderId: folderId);
      for (final m in mediaList) {
        if (m.id != null) {
          await deleteMedia(m.id!);
          try {
            final f = File(m.localFilePath);
            if (f.existsSync()) f.deleteSync();
          } catch (_) {}
        }
      }
    } else {
      // Move items to uncategorized
      await db.update(
        'saved_media',
        {'folderId': null, 'folderName': null},
        where: 'folderId = ?',
        whereArgs: [folderId],
      );
    }
    return await db.delete('media_folders', where: 'id = ?', whereArgs: [folderId]);
  }

  // ==========================================
  // Playlist Operations
  // ==========================================
  Future<int> insertPlaylist(Playlist playlist) async {
    final db = await database;
    return await db.insert('playlists', playlist.toMap());
  }

  Future<List<Playlist>> getAllPlaylists() async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT p.*, COUNT(pi.mediaId) as itemCount
      FROM playlists p
      LEFT JOIN playlist_items pi ON p.id = pi.playlistId
      GROUP BY p.id
      ORDER BY p.name COLLATE NOCASE ASC
    ''');
    return maps.map((e) => Playlist.fromMap(e, itemCount: e['itemCount'] as int? ?? 0)).toList();
  }

  Future<int> updatePlaylist(Playlist playlist) async {
    final db = await database;
    return await db.update(
      'playlists',
      playlist.toMap(),
      where: 'id = ?',
      whereArgs: [playlist.id],
    );
  }

  Future<int> deletePlaylist(int playlistId) async {
    final db = await database;
    await db.delete('playlist_items', where: 'playlistId = ?', whereArgs: [playlistId]);
    return await db.delete('playlists', where: 'id = ?', whereArgs: [playlistId]);
  }

  Future<void> addMediaToPlaylist(int playlistId, int mediaId, {int orderIndex = 0}) async {
    final db = await database;
    await db.insert(
      'playlist_items',
      {
        'playlistId': playlistId,
        'mediaId': mediaId,
        'orderIndex': orderIndex,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> removeMediaFromPlaylist(int playlistId, int mediaId) async {
    final db = await database;
    return await db.delete(
      'playlist_items',
      where: 'playlistId = ? AND mediaId = ?',
      whereArgs: [playlistId, mediaId],
    );
  }

  Future<List<SavedMedia>> getMediaForPlaylist(int playlistId) async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT sm.*
      FROM saved_media sm
      INNER JOIN playlist_items pi ON sm.id = pi.mediaId
      WHERE pi.playlistId = ?
      ORDER BY pi.orderIndex ASC, sm.downloadDate DESC
    ''', [playlistId]);
    return maps.map((e) => SavedMedia.fromMap(e)).toList();
  }

  // ==========================================
  // Download History Operations
  // ==========================================
  Future<int> insertHistory(DownloadHistoryRecord record) async {
    final db = await database;
    return await db.insert('download_history', record.toMap());
  }

  Future<int> updateHistory(DownloadHistoryRecord record) async {
    final db = await database;
    return await db.update(
      'download_history',
      record.toMap(),
      where: 'id = ?',
      whereArgs: [record.id],
    );
  }

  Future<List<DownloadHistoryRecord>> getAllHistory({DownloadHistoryStatus? statusFilter}) async {
    final db = await database;
    if (statusFilter != null) {
      final maps = await db.query(
        'download_history',
        where: 'status = ?',
        whereArgs: [statusFilter.nameUpper],
        orderBy: 'timestamp DESC',
      );
      return maps.map((e) => DownloadHistoryRecord.fromMap(e)).toList();
    } else {
      final maps = await db.query('download_history', orderBy: 'timestamp DESC');
      return maps.map((e) => DownloadHistoryRecord.fromMap(e)).toList();
    }
  }

  Future<int> deleteHistory(int id) async {
    final db = await database;
    return await db.delete('download_history', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> clearAllHistory() async {
    final db = await database;
    return await db.delete('download_history');
  }
}
