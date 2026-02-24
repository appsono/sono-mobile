import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:sono/services/api/lastfm_service.dart';
import 'package:sono/services/api/lyrics_service.dart';
import 'package:sono/services/artists/artist_fetch_progress_service.dart';
import 'package:sono/services/artists/artist_image_fetch_service.dart';
import 'package:sono/services/playlist/playlist_migration_service.dart';
import 'package:sono/services/utils/artwork_cache_service.dart';
import 'package:sono/services/utils/preferences_service.dart';
import 'package:sono/styles/app_theme.dart';
import 'package:sono/widgets/library/artist_artwork_widget.dart';

/// Developer sub-page: App Storage & Cache
/// Contains tools for playlist migration and artist image management.
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

  bool _isMigrating = false;
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

        final msg = errors.isEmpty
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

  Future<void> _confirmClearLastfmCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: AppTheme.backgroundDark,
            title: const Text(
              'Clear Last.fm Cache',
              style: TextStyle(color: Colors.white, fontFamily: 'VarelaRound'),
            ),
            content: Text(
              'This will remove all cached Last.fm data. Are you sure?',
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
    );

    if (confirmed == true && mounted) {
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
              'This will remove all cached data including artwork. Are you sure?',
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
    );

    if (confirmed == true && mounted) {
      try {
        await LastfmService().clearCache();
        LyricsCacheService.instance.clearCache();
        ArtworkCacheService.instance.clearAllCache();
        ArtistArtworkWidget.clearAllCache();
        await CachedNetworkImage.evictFromCache('');
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
        PreferencesService().clearCache();

        if (mounted) {
          _showSnackBar(
            message: 'All cache cleared successfully',
            isError: false,
          );
        }
      } catch (e) {
        if (mounted) {
          _showSnackBar(message: 'Error clearing cache: $e', isError: true);
        }
      }
    }
  }

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
            const Text(
              'PLAYLISTS',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                fontFamily: 'VarelaRound',
              ),
            ),
            const SizedBox(height: 12),

            _buildActionTile(
              icon: Symbols.playlist_add_rounded,
              iconColor: AppTheme.info,
              title: 'Migrate All Local Playlists',
              subtitle: _isMigrating
                  ? 'Migrating…'
                  : (_migrationResult ?? 'Re-import MediaStore playlists into the app database'),
              trailing: _isMigrating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white.withAlpha((0.5 * 255).round()),
                      size: 20,
                    ),
              onTap: _isMigrating ? null : _runPlaylistMigration,
            ),

            const SizedBox(height: 24),
          ],

          const Text(
            'ARTIST IMAGES',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              fontFamily: 'VarelaRound',
            ),
          ),
          const SizedBox(height: 12),

          AnimatedBuilder(
            animation: _progress,
            builder: (context, _) {

              final isFetching = _progress.isFetching;
              final hasStarted = _progress.totalArtists > 0;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status card
                  if (hasStarted) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha((0.05 * 255).round()),
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusMd),
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
                                color: isFetching
                                    ? AppTheme.info
                                    : AppTheme.success,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _progress.statusText,
                                style: TextStyle(
                                  color: Colors.white.withAlpha(
                                    (0.9 * 255).round(),
                                  ),
                                  fontFamily: 'VarelaRound',
                                  fontWeight: FontWeight.w500,
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
                            if (_progress.currentArtist != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                _progress.currentArtist!,
                                style: TextStyle(
                                  color: Colors.white.withAlpha(
                                    (0.5 * 255).round(),
                                  ),
                                  fontSize: 12,
                                  fontFamily: 'VarelaRound',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
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
                    trailing: isFetching
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.white.withAlpha(
                              (0.5 * 255).round(),
                            ),
                            size: 20,
                          ),
                    onTap: isFetching ? null : _fetchMissingArtistImages,
                  ),
                  const SizedBox(height: 8),

                  _buildActionTile(
                    icon: Symbols.refresh_rounded,
                    iconColor: AppTheme.warning,
                    title: 'Refetch All Artist Pictures',
                    subtitle: 'Clear stored images and re-fetch everything',
                    trailing: isFetching
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.white.withAlpha(
                              (0.5 * 255).round(),
                            ),
                            size: 20,
                          ),
                    onTap: isFetching ? null : _refetchAllArtistImages,
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 24),

          const Text(
            'CACHE MANAGEMENT',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              fontFamily: 'VarelaRound',
            ),
          ),
          const SizedBox(height: 12),

          _buildActionTile(
            icon: Symbols.cleaning_services_rounded,
            iconColor: AppTheme.warning,
            title: 'Clear Last.fm Cache',
            subtitle: 'Remove cached Last.fm data',
            trailing: Icon(
              Icons.delete_outline,
              color: Colors.white.withAlpha((0.5 * 255).round()),
              size: 20,
            ),
            onTap: _confirmClearLastfmCache,
          ),
          const SizedBox(height: 8),

          _buildActionTile(
            icon: Symbols.delete_sweep_rounded,
            iconColor: AppTheme.warning,
            title: 'Clear All Cache',
            subtitle: 'Remove all cached data including artwork',
            trailing: Icon(
              Icons.delete_outline,
              color: Colors.white.withAlpha((0.5 * 255).round()),
              size: 20,
            ),
            onTap: _confirmClearAllCache,
          ),
        ],
      ),
    );
  }

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
