import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart';

///migration v3: add custom playlist cover support
///adds column for custom cover image path
class MigrationV3 {
  static const int version = 3;

  static Future<void> migrate(Database db) async {
    debugPrint('SonoDatabase: Running migration v3...');

    try {
      //check existing columns to avoid duplicate column errors
      final tableInfo = await db.rawQuery('PRAGMA table_info(app_playlists)');
      final existingColumns =
          tableInfo.map((col) => col['name'] as String).toSet();

      //add custom_cover_path column for custom playlist covers only if it doesn't exist
      if (!existingColumns.contains('custom_cover_path')) {
        await db.execute(
          'ALTER TABLE app_playlists ADD COLUMN custom_cover_path TEXT',
        );
      }

      debugPrint('SonoDatabase: Migration v3 completed successfully');
    } catch (e) {
      debugPrint('SonoDatabase: Error in migration v3: $e');
      rethrow;
    }
  }
}