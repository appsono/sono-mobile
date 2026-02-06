import 'package:sqflite/sqflite.dart';

class FavoritesTable {
  static const String tableName = 'favorites';

  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        song_id INTEGER NOT NULL UNIQUE,
        added_at INTEGER NOT NULL,
        type TEXT NOT NULL DEFAULT 'song'
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_favorites_song_id ON $tableName(song_id)',
    );
  }
}

class FavoriteArtistsTable {
  static const String tableName = 'favorite_artists';

  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        artist_id INTEGER NOT NULL UNIQUE,
        artist_name TEXT NOT NULL,
        added_at INTEGER NOT NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_favorite_artists_artist_id ON $tableName(artist_id)',
    );
  }
}

class FavoriteAlbumsTable {
  static const String tableName = 'favorite_albums';

  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        album_id INTEGER NOT NULL UNIQUE,
        album_name TEXT NOT NULL,
        added_at INTEGER NOT NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_favorite_albums_album_id ON $tableName(album_id)',
    );
  }
}