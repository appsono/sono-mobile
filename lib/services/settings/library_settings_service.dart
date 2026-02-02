import 'package:flutter/material.dart';

import 'base_settings_service.dart';

///manages library-related settings (excluded folders, cover rotation)
class LibrarySettingsService extends BaseSettingsService {
  static final LibrarySettingsService instance =
      LibrarySettingsService._internal();

  LibrarySettingsService._internal();

  @override
  String get category => 'library';

  //default values
  static const List<String> _defaultExcludedFolders = [];
  static const bool _defaultCoverRotation = true;
  static const bool _defaultAutoUpdate = true;

  final ValueNotifier<bool> coverRotationEnabled =
    ValueNotifier<bool>(_defaultCoverRotation);
  
  Future<void> init() async {
    coverRotationEnabled.value = await getCoverRotationEnabled();
  }

  final ValueNotifier<bool> autoUpdateEnabled =
      ValueNotifier<bool>(_defaultAutoUpdate);

  ///gets the list of excluded folders
  Future<List<String>> getExcludedFolders() async {
    final dynamic result = await getSetting<dynamic>(
      'excluded_folders',
      _defaultExcludedFolders,
    );
    if (result is List) {
      return result.map((e) => e.toString()).toList();
    }
    return _defaultExcludedFolders;
  }

  ///sets the list of excluded folders
  Future<void> setExcludedFolders(List<String> folders) async {
    await setSetting<List<String>>('excluded_folders', folders);
  }

  ///adds a folder to the excluded folders list
  Future<void> addExcludedFolder(String folder) async {
    final folders = await getExcludedFolders();
    if (!folders.contains(folder)) {
      final mutableFolders = List<String>.from(folders);
      mutableFolders.add(folder);
      await setExcludedFolders(mutableFolders);
    }
  }

  ///removes a folder from the excluded folders list
  Future<void> removeExcludedFolder(String folder) async {
    final folders = await getExcludedFolders();
    final mutableFolders = List<String>.from(folders);
    mutableFolders.remove(folder);
    await setExcludedFolders(mutableFolders);
  }

  ///gets whether album cover rotation is enabled
  Future<bool> getCoverRotationEnabled() async {
    return await getSetting<bool>('cover_rotation', _defaultCoverRotation);
  }

  ///sets whether album cover rotation is enabled
  Future<void> setCoverRotationEnabled(bool enabled) async {
    await setSetting<bool>('cover_rotation', enabled);
    coverRotationEnabled.value = enabled; // 
  }

  Future<bool> getAutoUpdateEnabled() async {
    return await getSetting<bool>(
      'auto_update_enabled_preference_v1',
      _defaultAutoUpdate,
    );
  }


  Future<void> setAutoUpdateEnabled(bool enabled) async {
    if (autoUpdateEnabled.value == enabled) return;

    await setSetting<bool>(
      'auto_update_enabled_preference_v1',
      enabled,
    );

    autoUpdateEnabled.value = enabled;
  }
}