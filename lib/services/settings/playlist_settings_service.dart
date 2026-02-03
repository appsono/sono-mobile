import 'base_settings_service.dart';

///manages playlist-related settings (cover song IDs)
class PlaylistSettingsService extends BaseSettingsService {
  static final PlaylistSettingsService instance =
      PlaylistSettingsService._internal();

  PlaylistSettingsService._internal();

  @override
  String get category => 'playlist';

  ///gets the cover song ID for a specific playlist
  Future<String?> getPlaylistCoverSongId(int playlistId) async {
    final key = 'cover_song_id_$playlistId';
    try {
      return await getSetting<String>(key, '');
    } catch (e) {
      return null;
    }
  }

  ///sets the cover song ID for a specific playlist
  Future<void> setPlaylistCoverSongId(int playlistId, String songId) async {
    final key = 'cover_song_id_$playlistId';
    await setSetting<String>(key, songId);
  }

  ///deletes the cover song ID for a specific playlist
  Future<void> deletePlaylistCoverSongId(int playlistId) async {
    final key = 'cover_song_id_$playlistId';
    await deleteSetting(key);
  }
}
