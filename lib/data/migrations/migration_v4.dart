import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart';

///migration v4: add context tracking to recent plays
///adds context column to track listening sessions (album, playlist, shuffle)
class MigrationV4 {
  static const int version = 4;

  static Future<void> migrate(Database db) async {
    debugPrint('SonoDatabase: Running migration v4...');

    try {
      //check existing columns to avoid duplicate column errors
      final tableInfo = await db.rawQuery('PRAGMA table_info(recent_plays)');
      final existingColumns =
          tableInfo.map((col) => col['name'] as String).toSet();

      //add context column to track listening context
      if (!existingColumns.contains('context')) {
        await db.execute('ALTER TABLE recent_plays ADD COLUMN context TEXT');
      }

      debugPrint('SonoDatabase: Migration v4 completed successfully');
    } catch (e) {
      debugPrint('SonoDatabase: Error in migration v4: $e');
      rethrow;
    }
  }
}
