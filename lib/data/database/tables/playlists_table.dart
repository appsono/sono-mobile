import 'package:sqflite/sqflite.dart';

class PlaylistsTable {
  static const String tableName = 'app_playlists';

  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        cover_song_id INTEGER,
        mediastore_id INTEGER,
        is_favorite INTEGER NOT NULL DEFAULT 0,
        sync_status TEXT NOT NULL DEFAULT 'synced',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_app_playlists_mediastore_id ON $tableName(mediastore_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_app_playlists_is_favorite ON $tableName(is_favorite)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_app_playlists_sync_status ON $tableName(sync_status)',
    );
  }
}

class PlaylistSongsTable {
  static const String tableName = 'playlist_songs';

  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        playlist_id INTEGER NOT NULL,
        song_id INTEGER NOT NULL,
        position INTEGER NOT NULL,
        added_at INTEGER NOT NULL,
        FOREIGN KEY (playlist_id) REFERENCES ${PlaylistsTable.tableName} (id) ON DELETE CASCADE,
        UNIQUE(playlist_id, song_id)
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_playlist_songs_playlist_id ON $tableName(playlist_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_playlist_songs_song_id ON $tableName(song_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_playlist_songs_position ON $tableName(playlist_id, position)',
    );
  }
}
