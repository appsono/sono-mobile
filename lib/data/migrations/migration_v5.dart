import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart';

///migration v5: Clear recent plays history
class MigrationV5 {
  static const int version = 5;

  static Future<void> migrate(Database db) async {
    debugPrint('SonoDatabase: Running migration v5...');

    try {
      //clear all existing recent play history
      //this prevents old entries from being shown as "Individual Song"
      await db.execute('DELETE FROM recent_plays');
      debugPrint('SonoDatabase: Cleared recent plays history during migration');

      debugPrint('SonoDatabase: Migration v5 completed successfully');
    } catch (e) {
      debugPrint('SonoDatabase: Error in migration v5: $e');
      rethrow;
    }
  }
}