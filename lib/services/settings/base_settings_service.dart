import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sono/data/database/database_helper.dart';

///base class for all settings services
///provides database access and common CRUD operations for settings
abstract class BaseSettingsService with ChangeNotifier {
  ///the category this service manages
  String get category;

  ///in-memory cache for frequently accessed settings
  final Map<String, dynamic> _cache = {};

  ///gets the database instance
  Future<Database> get _db async => await SonoDatabaseHelper.instance.database;

  ///gets a setting value by key
  ///returns the value if found, otherwise returns defaultValue
  Future<T> getSetting<T>(String key, T defaultValue) async {
    //check cache first
    if (_cache.containsKey(key)) {
      return _cache[key] as T;
    }

    try {
      final db = await _db;
      final results = await db.query(
        'app_settings',
        where: 'category = ? AND key = ?',
        whereArgs: [category, key],
        limit: 1,
      );

      if (results.isEmpty) {
        _cache[key] = defaultValue;
        return defaultValue;
      }

      final jsonValue = results.first['value'] as String;
      final value = jsonDecode(jsonValue) as T;

      _cache[key] = value;
      return value;
    } catch (e) {
      debugPrint('$category: Error getting setting $key: $e');
      _cache[key] = defaultValue;
      return defaultValue;
    }
  }

  ///sets a setting value by key
  ///updates both database and cache, then notifies listeners
  Future<void> setSetting<T>(String key, T value) async {
    try {
      final db = await _db;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final jsonValue = jsonEncode(value);

      await db.insert('app_settings', {
        'category': category,
        'key': key,
        'value': jsonValue,
        'updated_at': timestamp,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      _cache[key] = value;
      notifyListeners();

      debugPrint('$category: Set $key = $value');
    } catch (e) {
      debugPrint('$category: Error setting $key: $e');
      rethrow;
    }
  }

  ///deletes a setting by key
  Future<void> deleteSetting(String key) async {
    try {
      final db = await _db;

      await db.delete(
        'app_settings',
        where: 'category = ? AND key = ?',
        whereArgs: [category, key],
      );

      _cache.remove(key);
      notifyListeners();

      debugPrint('$category: Deleted $key');
    } catch (e) {
      debugPrint('$category: Error deleting $key: $e');
    }
  }

  ///clears all settings for this category
  Future<void> clearAll() async {
    try {
      final db = await _db;

      await db.delete(
        'app_settings',
        where: 'category = ?',
        whereArgs: [category],
      );

      _cache.clear();
      notifyListeners();

      debugPrint('$category: Cleared all settings');
    } catch (e) {
      debugPrint('$category: Error clearing settings: $e');
    }
  }

  ///gets all settings for this category
  Future<Map<String, dynamic>> getAllSettings() async {
    try {
      final db = await _db;
      final results = await db.query(
        'app_settings',
        where: 'category = ?',
        whereArgs: [category],
      );

      final settings = <String, dynamic>{};
      for (final row in results) {
        final key = row['key'] as String;
        final jsonValue = row['value'] as String;
        settings[key] = jsonDecode(jsonValue);
      }

      return settings;
    } catch (e) {
      debugPrint('$category: Error getting all settings: $e');
      return {};
    }
  }

  ///preloads all settings into cache for faster access
  Future<void> preloadCache() async {
    try {
      final settings = await getAllSettings();
      _cache.addAll(settings);
      debugPrint('$category: Preloaded ${settings.length} settings into cache');
    } catch (e) {
      debugPrint('$category: Error preloading cache: $e');
    }
  }
}
