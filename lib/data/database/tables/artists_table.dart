import 'package:sqflite/sqflite.dart';

class ArtistMetadataTable {
  static const String tableName = 'artist_metadata';

  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        artist_name TEXT NOT NULL UNIQUE,
        artist_name_lower TEXT NOT NULL,
        custom_image_path TEXT,
        fetched_image_url TEXT,
        fetch_attempted_at INTEGER,
        mediastore_id INTEGER,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_artist_metadata_name ON $tableName(artist_name_lower)',
    );

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_artist_metadata_mediastore_id ON $tableName(mediastore_id)',
    );
  }
}
