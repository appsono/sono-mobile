import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart';

///migration v2: add hybrid playlist sync support
///adds columns for MediaStore linking and sync status
class MigrationV2 {
  static const int version = 2;

  static Future<void> migrate(Database db) async {
    debugPrint('SonoDatabase: Running migration v2...');

    try {
      //check existing columns to avoid duplicate column errors
      final tableInfo = await db.rawQuery('PRAGMA table_info(app_playlists)');
      final existingColumns =
          tableInfo.map((col) => col['name'] as String).toSet();

      //add columns only if they don't exist
      if (!existingColumns.contains('mediastore_id')) {
        await db.execute(
          'ALTER TABLE app_playlists ADD COLUMN mediastore_id INTEGER',
        );
      }
      if (!existingColumns.contains('is_favorite')) {
        await db.execute(
          'ALTER TABLE app_playlists ADD COLUMN is_favorite INTEGER NOT NULL DEFAULT 0',
        );
      }
      if (!existingColumns.contains('sync_status')) {
        await db.execute(
          'ALTER TABLE app_playlists ADD COLUMN sync_status TEXT NOT NULL DEFAULT "synced"',
        );
      }

      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_app_playlists_mediastore_id ON app_playlists(mediastore_id)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_app_playlists_is_favorite ON app_playlists(is_favorite)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_app_playlists_sync_status ON app_playlists(sync_status)',
      );

      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_playlist_songs_position ON playlist_songs(playlist_id, position)',
      );

      debugPrint('SonoDatabase: Migration v2 completed successfully');
    } catch (e) {
      debugPrint('SonoDatabase: Error in migration v2: $e');
      rethrow;
    }
  }
}
