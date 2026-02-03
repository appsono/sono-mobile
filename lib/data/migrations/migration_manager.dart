import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart';
import 'migration_v1.dart';
import 'migration_v2.dart';
import 'migration_v3.dart';
import 'migration_v4.dart';
import 'migration_v5.dart';
import 'migration_v6.dart';
import 'migration_v7.dart';
import 'migration_v8.dart';

class MigrationManager {
  ///current database version
  static const int currentVersion = 8;

  ///runs database migrations from oldVersion to newVersion
  static Future<void> migrate(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    debugPrint(
      'SonoDatabase: Migrating from version $oldVersion to $newVersion',
    );

    //run migrations sequentially
    for (int version = oldVersion + 1; version <= newVersion; version++) {
      await _runMigration(db, version);
    }
  }

  ///runs initial database creation
  static Future<void> onCreate(Database db, int version) async {
    debugPrint('SonoDatabase: Creating database version $version');

    for (int v = 1; v <= version; v++) {
      await _runMigration(db, v);
    }
  }

  ///runs a specific migration version
  static Future<void> _runMigration(Database db, int version) async {
    switch (version) {
      case 1:
        await MigrationV1.migrate(db);
        break;
      case 2:
        await MigrationV2.migrate(db);
        break;
      case 3:
        await MigrationV3.migrate(db);
        break;
      case 4:
        await MigrationV4.migrate(db);
        break;
      case 5:
        await MigrationV5.migrate(db);
        break;
      case 6:
        await MigrationV6.migrate(db);
        break;
      case 7:
        await MigrationV7.migrate(db);
        break;
      case 8:
        await MigrationV8.migrate(db);
        break;
      default:
        debugPrint('SonoDatabase: No migration found for version $version');
    }
  }
}
