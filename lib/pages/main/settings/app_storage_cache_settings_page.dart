import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:on_audio_query/on_audio_query.dart' as query;
import 'package:sono/data/repositories/playlists_repository.dart';
import 'package:sono/services/api/lastfm_service.dart';
import 'package:sono/services/api/lyrics_service.dart';
import 'package:sono/services/artists/artist_fetch_progress_service.dart';
import 'package:sono/services/artists/artist_image_fetch_service.dart';
import 'package:sono/services/playlist/playlist_migration_service.dart';
import 'package:sono/services/playlist/playlist_service.dart';
import 'package:sono/services/utils/artwork_cache_service.dart';
import 'package:sono/styles/app_theme.dart';
import 'package:sono/widgets/library/artist_artwork_widget.dart';

/// Developer sub-page: App Storage & Cache
/// Contains tools for playlist migration, artist image management, and cache control.
class AppStorageCacheSettingsPage extends StatefulWidget {
  const AppStorageCacheSettingsPage({super.key});

  @override
  State<AppStorageCacheSettingsPage> createState() =>
      _AppStorageCacheSettingsPageState();
}

class _AppStorageCacheSettingsPageState
    extends State<AppStorageCacheSettingsPage> {
  final ArtistFetchProgressService _progress = ArtistFetchProgressService();
  final PlaylistMigrationService _migrationService = PlaylistMigrationService();
  final PlaylistService _playlistService = PlaylistService();
  final PlaylistsRepository _playlistsRepo = PlaylistsRepository();
  final query.OnAudioQuery _audioQuery = query.OnAudioQuery();

  bool _isMigrating = false;
  bool _isSyncing = false;
  bool _isLinking = false;
  String? _migrationResult;

  void _showSnackBar({required String message, required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontFamily: 'VarelaRound'),
        ),
        backgroundColor: isError ? AppTheme.error : AppTheme.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// ============================== Playlist operations ==============================

  Future<void> _runPlaylistMigration() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: AppTheme.backgroundDark,
            title: const Text(
              'Migrate Local Playlists',
              style: TextStyle(color: Colors.white, fontFamily: 'VarelaRound'),
            ),
            content: Text(
              'This will reset the migration flag and re-import all MediaStore playlists into the app database.\n\nNote: Running this more than once may create duplicate playlists. For testing only.',
              style: TextStyle(
                color: Colors.white.withAlpha((0.8 * 255).round()),
                fontFamily: 'VarelaRound',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(fontFamily: 'VarelaRound'),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Migrate',
                  style: TextStyle(fontFamily: 'VarelaRound'),
                ),
              ),
            ],
          ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _isMigrating = true;
      _migrationResult = null;
    });

    try {
      await _migrationService.resetMigration();
      final result = await _migrationService.migrate();

      if (!mounted) return;

      if (result['success'] == true) {
        final playlists = result['playlistCount'] as int? ?? 0;
        final songs = result['songCount'] as int? ?? 0;
        final errors = result['errors'] as List? ?? [];
        final ms = result['durationMs'] as int? ?? 0;

        final msg =
            errors.isEmpty
                ? 'Migrated $playlists playlists, $songs songs in ${ms}ms'
                : 'Migrated $playlists playlists, $songs songs (${errors.length} errors) in ${ms}ms';

        setState(() => _migrationResult = msg);
        _showSnackBar(message: msg, isError: errors.isNotEmpty);
      } else {
        final err = result['error'] ?? 'Unknown error';
        setState(() => _migrationResult = 'Error: $err');
        _showSnackBar(message: 'Migration failed: $err', isError: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _migrationResult = 'Error: $e');
        _showSnackBar(message: 'Migration error: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isMigrating = false);
    }
  }

  /// Shows a picker dialog and re-creates/syncs the chosen DB playlist to MediaStore.
  Future<void> _syncDbPlaylistToMediaStore() async {
    if (_isSyncing) return;

    final playlists = await _playlistService.getAllPlaylists();
    if (!mounted) return;

    if (playlists.isEmpty) {
      _showSnackBar(message: 'No playlists found in database', isError: false);
      return;
    }

    final picked = await showDialog<int>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: AppTheme.backgroundDark,
            title: const Text(
              'Select Playlist',
              style: TextStyle(color: Colors.white, fontFamily: 'VarelaRound'),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: playlists.length,
                itemBuilder: (context, i) {
                  final pl = playlists[i];
                  return ListTile(
                    title: Text(
                      pl.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'VarelaRound',
                      ),
                    ),
                    subtitle: Text(
                      pl.mediastoreId != null
                          ? 'Linked (MediaStore ID ${pl.mediastoreId})'
                          : 'Not linked to MediaStore',
                      style: TextStyle(
                        color: Colors.white.withAlpha((0.5 * 255).round()),
                        fontFamily: 'VarelaRound',
                        fontSize: 12,
                      ),
                    ),
                    onTap: () => Navigator.pop(context, pl.id),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(fontFamily: 'VarelaRound'),
                ),
              ),
            ],
          ),
    );

    if (picked == null || !mounted) return;

    setState(() => _isSyncing = true);
    try {
      final success = await _playlistService.retrySync(picked);
      if (mounted) {
        _showSnackBar(
          message:
              success
                  ? 'Playlist synced to MediaStore'
                  : 'Sync failed; check app logs',
          isError: !success,
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(message: 'Sync error: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  /// Shows pickers to link a MediaStore playlist to a DB playlist.
  Future<void> _linkMediaStorePlaylist() async {
    if (_isLinking) return;

    // Step 1: pick a MediaStore playlist
    final mediaStorePlaylists = await _audioQuery.queryPlaylists();
    if (!mounted) return;

    if (mediaStorePlaylists.isEmpty) {
      _showSnackBar(message: 'No MediaStore playlists found', isError: false);
      return;
    }

    final pickedMediaStoreId = await showDialog<int>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: AppTheme.backgroundDark,
            title: const Text(
              'Step 1: Pick MediaStore Playlist',
              style: TextStyle(color: Colors.white, fontFamily: 'VarelaRound'),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: mediaStorePlaylists.length,
                itemBuilder: (context, i) {
                  final pl = mediaStorePlaylists[i];
                  return ListTile(
                    title: Text(
                      pl.playlist,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'VarelaRound',
                      ),
                    ),
                    subtitle: Text(
                      'ID: ${pl.id}',
                      style: TextStyle(
                        color: Colors.white.withAlpha((0.5 * 255).round()),
                        fontFamily: 'VarelaRound',
                        fontSize: 12,
                      ),
                    ),
                    onTap: () => Navigator.pop(context, pl.id),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(fontFamily: 'VarelaRound'),
                ),
              ),
            ],
          ),
    );

    if (pickedMediaStoreId == null || !mounted) return;

    // Step 2: pick a DB playlist
    final dbPlaylists = await _playlistService.getAllPlaylists();
    if (!mounted) return;

    if (dbPlaylists.isEmpty) {
      _showSnackBar(message: 'No DB playlists found', isError: false);
      return;
    }

    final pickedDbId = await showDialog<int>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: AppTheme.backgroundDark,
            title: const Text(
              'Step 2: Pick DB Playlist',
              style: TextStyle(color: Colors.white, fontFamily: 'VarelaRound'),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: dbPlaylists.length,
                itemBuilder: (context, i) {
                  final pl = dbPlaylists[i];
                  return ListTile(
                    title: Text(
                      pl.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'VarelaRound',
                      ),
                    ),
                    subtitle: Text(
                      pl.mediastoreId != null
                          ? 'Currently linked to MediaStore ID ${pl.mediastoreId}'
                          : 'Not linked',
                      style: TextStyle(
                        color: Colors.white.withAlpha((0.5 * 255).round()),
                        fontFamily: 'VarelaRound',
                        fontSize: 12,
                      ),
                    ),
                    onTap: () => Navigator.pop(context, pl.id),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(fontFamily: 'VarelaRound'),
                ),
              ),
            ],
          ),
    );

    if (pickedDbId == null || !mounted) return;

    setState(() => _isLinking = true);
    try {
      await _playlistsRepo.setMediaStoreId(pickedDbId, pickedMediaStoreId);
      if (mounted) {
        _showSnackBar(message: 'Playlist linked successfully', isError: false);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(message: 'Link error: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLinking = false);
    }
  }

  /// ============================== Artist images ==============================

  Future<void> _fetchMissingArtistImages() async {
    if (_progress.isFetching) return;

    try {
      final service = ArtistImageFetchService(progressService: _progress);
      //skipIfDone: false => ignores the "all done" flag,
      //but per-artist shouldFetchImage() still skips already-fetched ones
      await service.fetchAllArtistImages(skipIfDone: false);
    } catch (e) {
      if (mounted) {
        _showSnackBar(message: 'Fetch error: $e', isError: true);
      }
    }
  }

  Future<void> _refetchAllArtistImages() async {
    if (_progress.isFetching) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: AppTheme.backgroundDark,
            title: const Text(
              'Refetch All Artist Pictures',
              style: TextStyle(color: Colors.white, fontFamily: 'VarelaRound'),
            ),
            content: Text(
              'This will clear all stored artist image URLs and re-fetch every artist from the API. This may take a while.',
              style: TextStyle(
                color: Colors.white.withAlpha((0.8 * 255).round()),
                fontFamily: 'VarelaRound',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(fontFamily: 'VarelaRound'),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: AppTheme.warning),
                child: const Text(
                  'Refetch All',
                  style: TextStyle(fontFamily: 'VarelaRound'),
                ),
              ),
            ],
          ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final service = ArtistImageFetchService(progressService: _progress);
      await service.resetFetchState();
      await service.fetchAllArtistImages(skipIfDone: false);
    } catch (e) {
      if (mounted) {
        _showSnackBar(message: 'Refetch error: $e', isError: true);
      }
    }
  }

  /// ============================== Cache management ==============================

  Future<void> _confirmClearLastfmCache() async {
    final confirmed = await _confirmClear(
      'Clear Last.fm Cache',
      'This will remove all cached Last.fm artist info. Your Last.fm account will not be affected.',
    );
    if (!confirmed || !mounted) return;

    try {
      await LastfmService().clearCache();
      if (mounted) {
        _showSnackBar(message: 'Last.fm cache cleared', isError: false);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(message: 'Error clearing cache: $e', isError: true);
      }
    }
  }

  Future<void> _confirmClearArtistArtworkCache() async {
    final confirmed = await _confirmClear(
      'Clear Artist Artwork Cache',
      'Removes cached artist images (in-memory and disk). They will be re-downloaded on next display.',
    );
    if (!confirmed || !mounted) return;

    try {
      ArtistArtworkWidget.clearAllCache();
      await DefaultCacheManager().emptyCache();
      if (mounted) {
        _showSnackBar(message: 'Artist artwork cache cleared', isError: false);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(message: 'Error: $e', isError: true);
      }
    }
  }

  Future<void> _confirmClearAlbumSongArtworkCache() async {
    final confirmed = await _confirmClear(
      'Clear Album/Song Artwork Cache',
      'Removes in-memory cached artwork loaded from your device. Artwork will be re-read from storage on next display.',
    );
    if (!confirmed || !mounted) return;

    try {
      ArtworkCacheService.instance.clearAllCache();
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      if (mounted) {
        _showSnackBar(
          message: 'Album/Song artwork cache cleared',
          isError: false,
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(message: 'Error: $e', isError: true);
      }
    }
  }

  Future<void> _confirmClearNetworkImageCache() async {
    final confirmed = await _confirmClear(
      'Clear Network Image Cache',
      'Removes cached network images (e.g. artist photos fetched from the internet).',
    );
    if (!confirmed || !mounted) return;

    try {
      await DefaultCacheManager().emptyCache();
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      if (mounted) {
        _showSnackBar(message: 'Network image cache cleared', isError: false);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(message: 'Error: $e', isError: true);
      }
    }
  }

  Future<void> _confirmClearLyricsCache() async {
    final confirmed = await _confirmClear(
      'Clear Lyrics Cache',
      'Removes cached lyrics. They will be re-fetched from the internet when needed.',
    );
    if (!confirmed || !mounted) return;

    try {
      LyricsCacheService.instance.clearCache();
      if (mounted) {
        _showSnackBar(message: 'Lyrics cache cleared', isError: false);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(message: 'Error: $e', isError: true);
      }
    }
  }

  Future<void> _confirmClearAllCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: AppTheme.backgroundDark,
            title: const Text(
              'Clear All Cache',
              style: TextStyle(color: Colors.white, fontFamily: 'VarelaRound'),
            ),
            content: Text(
              'Clears all in-memory and disk caches: artist artwork, album/song artwork, network images, lyrics, and Last.fm data.\n\nAccount data, settings, playlists, and favorites are NOT affected.',
              style: TextStyle(
                color: Colors.white.withAlpha((0.8 * 255).round()),
                fontFamily: 'VarelaRound',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(fontFamily: 'VarelaRound'),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: AppTheme.warning),
                child: const Text(
                  'Clear All',
                  style: TextStyle(fontFamily: 'VarelaRound'),
                ),
              ),
            ],
          ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await LastfmService().clearCache();
      await DefaultCacheManager().emptyCache();
      LyricsCacheService.instance.clearCache();
      ArtworkCacheService.instance.clearAllCache();
      ArtistArtworkWidget.clearAllCache();
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();

      if (mounted) {
        _showSnackBar(message: 'All cache cleared', isError: false);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(message: 'Error clearing cache: $e', isError: true);
      }
    }
  }

  /// Generic confirm dialog => returns true if user confirmed.
  Future<bool> _confirmClear(String title, String body) async {
    return await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                backgroundColor: AppTheme.backgroundDark,
                title: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'VarelaRound',
                  ),
                ),
                content: Text(
                  body,
                  style: TextStyle(
                    color: Colors.white.withAlpha((0.8 * 255).round()),
                    fontFamily: 'VarelaRound',
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(fontFamily: 'VarelaRound'),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text(
                      'Clear',
                      style: TextStyle(fontFamily: 'VarelaRound'),
                    ),
                  ),
                ],
              ),
        ) ??
        false;
  }

  /// ============================== Build ==============================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Symbols.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'App Storage & Cache',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontFamily: 'VarelaRound',
          ),
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (Platform.isAndroid) ...[
            _sectionHeader('PLAYLISTS'),
            const SizedBox(height: 12),

            _buildActionTile(
              icon: Symbols.playlist_add_rounded,
              iconColor: AppTheme.info,
              title: 'Migrate All Local Playlists',
              subtitle:
                  _isMigrating
                      ? 'Migrating…'
                      : (_migrationResult ??
                          'Re-import MediaStore playlists into the app database'),
              trailing: _isMigrating ? const _LoadingIcon() : _chevron(),
              onTap: _isMigrating ? null : _runPlaylistMigration,
            ),
            const SizedBox(height: 8),

            _buildActionTile(
              icon: Symbols.sync_rounded,
              iconColor: AppTheme.info,
              title: 'Sync DB Playlist to MediaStore',
              subtitle:
                  'Re-create or re-sync a database playlist in MediaStore',
              trailing: _isSyncing ? const _LoadingIcon() : _chevron(),
              onTap: _isSyncing ? null : _syncDbPlaylistToMediaStore,
            ),
            const SizedBox(height: 8),

            _buildActionTile(
              icon: Symbols.link_rounded,
              iconColor: AppTheme.info,
              title: 'Link MediaStore Playlist',
              subtitle: 'Manually link a MediaStore playlist to a DB playlist',
              trailing: _isLinking ? const _LoadingIcon() : _chevron(),
              onTap: _isLinking ? null : _linkMediaStorePlaylist,
            ),

            const SizedBox(height: 24),
          ],

          _sectionHeader('ARTIST IMAGES'),
          const SizedBox(height: 12),

          AnimatedBuilder(
            animation: _progress,
            builder: (context, _) {
              final isFetching = _progress.isFetching;
              final hasStarted = _progress.totalArtists > 0;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasStarted) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha((0.05 * 255).round()),
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        border: Border.all(
                          color: Colors.white.withAlpha((0.1 * 255).round()),
                          width: 0.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isFetching
                                    ? Symbols.sync_rounded
                                    : Symbols.check_circle_rounded,
                                color:
                                    isFetching
                                        ? AppTheme.info
                                        : AppTheme.success,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _progress.statusText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withAlpha(
                                      (0.9 * 255).round(),
                                    ),
                                    fontFamily: 'VarelaRound',
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (isFetching) ...[
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: _progress.progress,
                                backgroundColor: Colors.white.withAlpha(
                                  (0.1 * 255).round(),
                                ),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppTheme.brandPink,
                                ),
                                minHeight: 4,
                              ),
                            ),
                            // Always keep this slot in the tree (empty string
                            // when null) => conditional add/remove changes the
                            // card height and causes the ListView to re-layout.
                            const SizedBox(height: 6),
                            Text(
                              _progress.currentArtist ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withAlpha(
                                  (0.5 * 255).round(),
                                ),
                                fontSize: 12,
                                fontFamily: 'VarelaRound',
                              ),
                            ),
                          ],
                          if (!isFetching && hasStarted) ...[
                            const SizedBox(height: 6),
                            Text(
                              '${_progress.successCount} fetched · ${_progress.failureCount} failed',
                              style: TextStyle(
                                color: Colors.white.withAlpha(
                                  (0.5 * 255).round(),
                                ),
                                fontSize: 12,
                                fontFamily: 'VarelaRound',
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  _buildActionTile(
                    icon: Symbols.person_search_rounded,
                    iconColor: AppTheme.info,
                    title: 'Fetch Missing Artist Pictures',
                    subtitle: 'Fetch images only for artists without one',
                    trailing: isFetching ? const _LoadingIcon() : _chevron(),
                    onTap: isFetching ? null : _fetchMissingArtistImages,
                  ),
                  const SizedBox(height: 8),

                  _buildActionTile(
                    icon: Symbols.refresh_rounded,
                    iconColor: AppTheme.warning,
                    title: 'Refetch All Artist Pictures',
                    subtitle: 'Clear stored images and re-fetch everything',
                    trailing: isFetching ? const _LoadingIcon() : _chevron(),
                    onTap: isFetching ? null : _refetchAllArtistImages,
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 24),
          _sectionHeader('CACHE MANAGEMENT'),
          const SizedBox(height: 12),

          _buildActionTile(
            icon: Symbols.face_rounded,
            iconColor: AppTheme.warning,
            title: 'Clear Artist Artwork Cache',
            subtitle: 'In-memory cache of artist images loaded from disk',
            trailing: _deleteIcon(),
            onTap: _confirmClearArtistArtworkCache,
          ),
          const SizedBox(height: 8),

          _buildActionTile(
            icon: Symbols.album_rounded,
            iconColor: AppTheme.warning,
            title: 'Clear Album/Song Artwork Cache',
            subtitle: 'In-memory cache of album and song covers from device',
            trailing: _deleteIcon(),
            onTap: _confirmClearAlbumSongArtworkCache,
          ),
          const SizedBox(height: 8),

          _buildActionTile(
            icon: Symbols.image_rounded,
            iconColor: AppTheme.warning,
            title: 'Clear Network Image Cache',
            subtitle: 'Cached images fetched from the internet',
            trailing: _deleteIcon(),
            onTap: _confirmClearNetworkImageCache,
          ),
          const SizedBox(height: 8),

          _buildActionTile(
            icon: Symbols.lyrics_rounded,
            iconColor: AppTheme.warning,
            title: 'Clear Lyrics Cache',
            subtitle: 'Cached lyrics fetched from lrclib.net',
            trailing: _deleteIcon(),
            onTap: _confirmClearLyricsCache,
          ),
          const SizedBox(height: 8),

          _buildActionTile(
            icon: Symbols.cleaning_services_rounded,
            iconColor: AppTheme.warning,
            title: 'Clear Last.fm Cache',
            subtitle: 'Cached Last.fm artist info (account data untouched)',
            trailing: _deleteIcon(),
            onTap: _confirmClearLastfmCache,
          ),
          const SizedBox(height: 8),

          _buildActionTile(
            icon: Symbols.delete_sweep_rounded,
            iconColor: AppTheme.error,
            title: 'Clear All Cache',
            subtitle: 'Clears all caches; account data & settings untouched',
            trailing: _deleteIcon(color: AppTheme.error),
            onTap: _confirmClearAllCache,
          ),
        ],
      ),
    );
  }

  /// ============================== Helpers ==============================

  Widget _sectionHeader(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 13,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
        fontFamily: 'VarelaRound',
      ),
    );
  }

  Widget _chevron() => Icon(
    Icons.chevron_right_rounded,
    color: Colors.white.withAlpha((0.5 * 255).round()),
    size: 20,
  );

  Widget _deleteIcon({Color? color}) => Icon(
    Icons.delete_outline,
    color: (color ?? Colors.white).withAlpha((0.5 * 255).round()),
    size: 20,
  );

  Widget _buildActionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Widget trailing,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Opacity(
          opacity: onTap == null ? 0.5 : 1.0,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha((0.05 * 255).round()),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(
                color: Colors.white.withAlpha((0.1 * 255).round()),
                width: 0.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconColor.withAlpha((0.15 * 255).round()),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'VarelaRound',
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withAlpha((0.7 * 255).round()),
                          fontSize: 14,
                          fontFamily: 'VarelaRound',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingIcon extends StatelessWidget {
  const _LoadingIcon();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
}
