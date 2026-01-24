import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:convert';

///migration v8: settings storage in database
class MigrationV8 {
  static Future<void> migrate(Database db) async {
    debugPrint('SonoDatabase: Running migration v8...');

    //create app_settings table
    await _createSettingsTable(db);

    //migrate existing preferences from SharedPreferences to database
    await _migratePreferencesToDatabase(db);

    debugPrint('SonoDatabase: Migration v8 completed');
  }

  ///creates the app_settings table
  static Future<void> _createSettingsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_settings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category TEXT NOT NULL,
        key TEXT NOT NULL,
        value TEXT NOT NULL,
        updated_at INTEGER NOT NULL,
        UNIQUE(category, key)
      )
    ''');

    //create indexes for faster queries
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_settings_category ON app_settings(category)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_settings_key ON app_settings(key)',
    );

    debugPrint('SonoDatabase: app_settings table created');
  }

  ///migrates settings from SharedPreferences to database
  static Future<void> _migratePreferencesToDatabase(Database db) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      //mapping of old keys to new structure
      final migrations = <Map<String, dynamic>>[
        //UI settings
        {
          'old_key': 'theme_mode_v1',
          'category': 'ui',
          'new_key': 'theme_mode',
          'type': 'int',
        },
        {
          'old_key': 'accent_color_v1',
          'category': 'ui',
          'new_key': 'accent_color',
          'type': 'int',
        },
        {
          'old_key': 'experimental_themes_enabled_v1',
          'category': 'ui',
          'new_key': 'experimental_themes',
          'type': 'bool',
        },

        //playback settings
        {
          'old_key': 'background_playback_enabled_v1',
          'category': 'playback',
          'new_key': 'background_playback',
          'type': 'bool',
        },
        {
          'old_key': 'resume_after_reboot_enabled_v1',
          'category': 'playback',
          'new_key': 'resume_after_reboot',
          'type': 'bool',
        },
        {
          'old_key': 'crossfade_enabled_v1',
          'category': 'playback',
          'new_key': 'crossfade_enabled',
          'type': 'bool',
        },
        {
          'old_key': 'crossfade_duration_seconds_v1',
          'category': 'playback',
          'new_key': 'crossfade_duration',
          'type': 'int',
        },
        {
          'old_key': 'playback_speed_v1',
          'category': 'playback',
          'new_key': 'speed',
          'type': 'double',
        },
        {
          'old_key': 'playback_pitch_v1',
          'category': 'playback',
          'new_key': 'pitch',
          'type': 'double',
        },

        //library settings
        {
          'old_key': 'excluded_folders_v1',
          'category': 'library',
          'new_key': 'excluded_folders',
          'type': 'string_list',
        },
        {
          'old_key': 'album_cover_rotation_v1',
          'category': 'library',
          'new_key': 'cover_rotation',
          'type': 'bool',
        },

        //scrobbling settings
        {
          'old_key': 'api_mode_is_prod_preference_v1',
          'category': 'scrobbling',
          'new_key': 'api_mode_prod',
          'type': 'bool',
        },

        //analytics settings
        {
          'old_key': 'analytics_enabled_v1',
          'category': 'analytics',
          'new_key': 'enabled',
          'type': 'bool',
        },

        //last known version (system)
        {
          'old_key': 'last_known_app_version_v1',
          'category': 'system',
          'new_key': 'last_app_version',
          'type': 'string',
        },
      ];

      int migratedCount = 0;

      for (final migration in migrations) {
        final oldKey = migration['old_key'] as String;
        final category = migration['category'] as String;
        final newKey = migration['new_key'] as String;
        final type = migration['type'] as String;

        dynamic value;

        //read value from SharedPreferences based on type
        switch (type) {
          case 'int':
            value = prefs.getInt(oldKey);
            break;
          case 'double':
            value = prefs.getDouble(oldKey);
            break;
          case 'bool':
            value = prefs.getBool(oldKey);
            break;
          case 'string':
            value = prefs.getString(oldKey);
            break;
          case 'string_list':
            value = prefs.getStringList(oldKey);
            break;
        }

        //only migrate if value exists
        if (value != null) {
          //encode value as JSON
          final jsonValue = jsonEncode(value);

          //insert into database
          await db.insert(
            'app_settings',
            {
              'category': category,
              'key': newKey,
              'value': jsonValue,
              'updated_at': timestamp,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );

          migratedCount++;
          debugPrint(
            'SonoDatabase: Migrated $category.$newKey = $value',
          );
        }
      }

      //add migration version marker
      await db.insert(
        'app_settings',
        {
          'category': 'system',
          'key': 'migration_version',
          'value': jsonEncode(8),
          'updated_at': timestamp,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      debugPrint(
        'SonoDatabase: Migrated $migratedCount settings to database',
      );
    } catch (e) {
      debugPrint('SonoDatabase: Error migrating preferences: $e');
      //don't throw - allow app to continue with defaults
    }
  }
}