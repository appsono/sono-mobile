import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:sono/data/models/playlist_model.dart' as db;
import 'package:sono/widgets/player/sono_player.dart';
import 'package:sono/services/playlist/playlist_service.dart';
import 'package:sono/styles/text.dart';
import 'package:sono/styles/app_theme.dart';
import 'package:sono/utils/artist_string_utils.dart';
import 'package:sono/utils/audio_filter_utils.dart';
import 'package:sono/services/utils/artwork_cache_service.dart';
import 'package:sono/widgets/global/add_to_playlist_dialog.dart';
import 'package:sono/widgets/global/refresh_indicator.dart';

class PlaylistDetailsPage extends StatefulWidget {
  final db.PlaylistModel playlist;
  final VoidCallback? onPlaylistChanged;

  const PlaylistDetailsPage({
    super.key,
    required this.playlist,
    this.onPlaylistChanged,
  });

  @override
  State<PlaylistDetailsPage> createState() => _PlaylistDetailsPageState();
}

class _PlaylistDetailsPageState extends State<PlaylistDetailsPage> {
  final OnAudioQuery _audioQuery = OnAudioQuery();

  late db.PlaylistModel _currentPlaylist;
  List<SongModel>? _loadedSongs;
  int? _coverSongId;
  bool _isLoading = true;
  String? _loadError;
  bool _isReorderMode = false;

  @override
  void initState() {
    super.initState();
    _currentPlaylist = widget.playlist;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    //load data after context is available for Provider
    if (_isLoading && _loadedSongs == null) {
      _loadPlaylistData();
    }
  }

  Future<void> _loadPlaylistData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final playlistService = context.read<PlaylistService>();
      final playlist = await playlistService.getPlaylist(widget.playlist.id);

      if (playlist == null) {
        if (mounted) {
          setState(() {
            _loadError = 'Playlist not found';
            _isLoading = false;
          });
        }
        return;
      }

      _coverSongId = await playlistService.getPlaylistCover(playlist.id);
      final songIds = await playlistService.getPlaylistSongIds(
        widget.playlist.id,
      );

      //query filtered songs (excluding songs from excluded folders)
      List<SongModel> allFilteredSongs = [];
      try {
        allFilteredSongs = await AudioFilterUtils.getFilteredSongs(
          _audioQuery,
          sortType: null,
          orderType: OrderType.ASC_OR_SMALLER,
        );
      } catch (e) {
        debugPrint('PlaylistDetailsPage: Error querying songs: $e');
      }

      final playlistSongs = <SongModel>[];
      for (final songId in songIds) {
        try {
          final song = allFilteredSongs.firstWhere((s) => s.id == songId);
          playlistSongs.add(song);
        } catch (e) {
          //song not found in filtered songs => either not in MediaStore or in excluded folder
          //dont clean up here since the song might just be in an excluded folder
          debugPrint('PlaylistDetailsPage: Song $songId not in filtered songs (might be excluded)');
        }
      }

      if (mounted) {
        setState(() {
          _currentPlaylist = playlist;
          _loadedSongs = playlistSongs;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('PlaylistDetailsPage: Error loading playlist: $e');
      if (mounted) {
        setState(() {
          _loadedSongs = [];
          _loadError = 'Failed to load playlist';
          _isLoading = false;
        });
      }
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = (duration.inMinutes % 60);
    final seconds = (duration.inSeconds % 60);

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '$minutes:${seconds.toString().padLeft(2, '0')}';
    }
  }

  Duration _calculatePlaylistDuration() {
    int totalMilliseconds = 0;
    for (final song in _loadedSongs ?? []) {
      final songDuration = song.duration;
      if (songDuration != null) {
        totalMilliseconds += (songDuration as num).toInt();
      }
    }
    return Duration(milliseconds: totalMilliseconds);
  }

  Future<void> _showCoverPickerModal() async {
    final playlistService = context.read<PlaylistService>();
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (modalContext) => _CoverPickerModal(
            playlistId: _currentPlaylist.id,
            playlistSongs: _loadedSongs ?? [],
            onCoverSelected: (songId) async {
              Navigator.of(modalContext).pop();

              try {
                await playlistService.setPlaylistCover(
                  _currentPlaylist.id,
                  songId,
                );
                if (mounted) {
                  setState(() => _coverSongId = songId);
                  widget.onPlaylistChanged?.call();
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                      content: Text('Playlist cover updated'),
                      backgroundColor: AppTheme.success,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text('Failed to update cover: $e'),
                      backgroundColor: AppTheme.error,
                    ),
                  );
                }
              }
            },
            onRemoveCover: () async {
              Navigator.of(modalContext).pop();

              try {
                await playlistService.removePlaylistCover(_currentPlaylist.id);
                if (mounted) {
                  setState(() => _coverSongId = null);
                  widget.onPlaylistChanged?.call();
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                      content: Text('Playlist cover removed'),
                      backgroundColor: AppTheme.warning,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text('Failed to remove cover: $e'),
                      backgroundColor: AppTheme.error,
                    ),
                  );
                }
              }
            },
            onPickFromSystem: () async {
              Navigator.of(modalContext).pop();
              final picker = ImagePicker();
              final image = await picker.pickImage(source: ImageSource.gallery);

              if (image != null && mounted) {
                try {
                  final success = await playlistService.setCustomPlaylistCover(
                    _currentPlaylist.id,
                    image.path,
                  );

                  if (success && mounted) {
                    //clear song cover and reload playlist data
                    setState(() => _coverSongId = null);
                    await _loadPlaylistData();
                    widget.onPlaylistChanged?.call();

                    scaffoldMessenger.showSnackBar(
                      const SnackBar(
                        content: Text('Custom cover set successfully'),
                        backgroundColor: AppTheme.success,
                      ),
                    );
                  } else if (mounted) {
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(
                        content: Text('Failed to set custom cover'),
                        backgroundColor: AppTheme.error,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Text('Error setting custom cover: $e'),
                        backgroundColor: AppTheme.error,
                      ),
                    );
                  }
                }
              }
            },
          ),
    );
  }

  Future<void> _reorderSongs(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) newIndex -= 1;
    if (_loadedSongs == null || _loadedSongs!.isEmpty) return;

    //Bounds check
    if (oldIndex < 0 ||
        oldIndex >= _loadedSongs!.length ||
        newIndex < 0 ||
        newIndex >= _loadedSongs!.length) {
      return;
    }

    final songToMove = _loadedSongs![oldIndex];

    setState(() {
      _loadedSongs!.removeAt(oldIndex);
      _loadedSongs!.insert(newIndex, songToMove);
    });

    try {
      final playlistService = context.read<PlaylistService>();
      await playlistService.reorderSong(
        playlistId: _currentPlaylist.id,
        songId: songToMove.id,
        newPosition: newIndex,
      );
      widget.onPlaylistChanged?.call();
    } catch (e) {
      debugPrint('PlaylistDetailsPage: Error reordering: $e');
      //Revert on error
      await _loadPlaylistData();
    }
  }

  void _showPlaylistOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (modalContext) => Container(
            decoration: BoxDecoration(
              color: AppTheme.cardDark,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppTheme.radiusXl),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(vertical: AppTheme.spacingMd),
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[700],
                      borderRadius: BorderRadius.circular(AppTheme.radius),
                    ),
                  ),
                ),
                //Add to queue
                ListTile(
                  leading: Icon(
                    Icons.queue_music_rounded,
                    color: AppTheme.textSecondaryDark,
                    size: 28,
                  ),
                  title: Text(
                    "Add Playlist to Queue",
                    style: TextStyle(
                      color: AppTheme.textPrimaryDark,
                      fontSize: 16,
                      fontFamily: 'VarelaRound',
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(modalContext);
                    if (_loadedSongs != null && _loadedSongs!.isNotEmpty) {
                      SonoPlayer().addSongsToQueue(_loadedSongs!);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Playlist added to queue"),
                          backgroundColor: Colors.green,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                ),
                //Change cover
                ListTile(
                  leading: Icon(
                    Icons.photo_library_rounded,
                    color: AppTheme.textSecondaryDark,
                    size: 28,
                  ),
                  title: Text(
                    "Change Playlist Cover",
                    style: TextStyle(
                      color: AppTheme.textPrimaryDark,
                      fontSize: 16,
                      fontFamily: 'VarelaRound',
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(modalContext);
                    _showCoverPickerModal();
                  },
                ),
                //Rename
                ListTile(
                  leading: Icon(
                    Icons.edit_rounded,
                    color: AppTheme.textSecondaryDark,
                    size: 28,
                  ),
                  title: Text(
                    "Rename Playlist",
                    style: TextStyle(
                      color: AppTheme.textPrimaryDark,
                      fontSize: 16,
                      fontFamily: 'VarelaRound',
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(modalContext);
                    _renamePlaylist();
                  },
                ),
                //Delete
                ListTile(
                  leading: const Icon(
                    Icons.delete_rounded,
                    color: AppTheme.error,
                    size: 28,
                  ),
                  title: const Text(
                    "Delete Playlist",
                    style: TextStyle(
                      color: AppTheme.error,
                      fontSize: 16,
                      fontFamily: 'VarelaRound',
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(modalContext);
                    _deletePlaylist();
                  },
                ),
                SizedBox(height: AppTheme.spacingLg),
              ],
            ),
          ),
    );
  }

  Future<void> _renamePlaylist() async {
    //Store context-dependent values before async operations
    final playlistService = context.read<PlaylistService>();
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final controller = TextEditingController(text: _currentPlaylist.name);
    final newName = await showDialog<String>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            backgroundColor: AppTheme.surfaceDark,
            title: const Text(
              'Rename Playlist',
              style: TextStyle(color: AppTheme.textPrimaryDark),
            ),
            content: TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(color: AppTheme.textPrimaryDark),
              decoration: const InputDecoration(
                hintText: "Playlist Name",
                hintStyle: TextStyle(color: AppTheme.textTertiaryDark),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: AppTheme.textSecondaryDark),
                ),
              ),
              TextButton(
                onPressed:
                    () => Navigator.pop(dialogContext, controller.text.trim()),
                child: const Text(
                  'Save',
                  style: TextStyle(color: AppTheme.brandPink),
                ),
              ),
            ],
          ),
    );

    if (newName != null &&
        newName.isNotEmpty &&
        newName != _currentPlaylist.name) {
      try {
        await playlistService.updatePlaylist(
          id: _currentPlaylist.id,
          name: newName,
        );
        if (mounted) {
          setState(
            () => _currentPlaylist = _currentPlaylist.copyWith(name: newName),
          );
          widget.onPlaylistChanged?.call();
        }
      } catch (e) {
        if (mounted) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text('Failed to rename: $e'),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _deletePlaylist() async {
    //Store context-dependent values before async operations
    final playlistService = context.read<PlaylistService>();
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            backgroundColor: AppTheme.surfaceDark,
            title: const Text(
              'Delete Playlist?',
              style: TextStyle(color: AppTheme.textPrimaryDark),
            ),
            content: Text(
              'This will permanently delete "${_currentPlaylist.name}".',
              style: const TextStyle(color: AppTheme.textSecondaryDark),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: AppTheme.textSecondaryDark),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: AppTheme.error),
                ),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      try {
        await playlistService.deletePlaylist(_currentPlaylist.id);
        widget.onPlaylistChanged?.call();
        if (mounted) {
          navigator.pop();
        }
      } catch (e) {
        if (mounted) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text('Failed to delete: $e'),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      }
    }
  }

  void _showSongOptionsBottomSheet(SongModel song) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (modalContext) => Container(
            decoration: BoxDecoration(
              color: AppTheme.cardDark,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppTheme.radiusXl),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(vertical: AppTheme.spacingMd),
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[700],
                      borderRadius: BorderRadius.circular(AppTheme.radius),
                    ),
                  ),
                ),
                ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    child: SizedBox(
                      width: 50,
                      height: 50,
                      child: FutureBuilder<Uint8List?>(
                        future: ArtworkCacheService.instance.getArtwork(
                          song.id,
                          size: 100,
                        ),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                                  ConnectionState.done &&
                              snapshot.hasData &&
                              snapshot.data != null) {
                            return Image.memory(
                              snapshot.data!,
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                              gaplessPlayback: true,
                              filterQuality: FilterQuality.medium,
                              cacheWidth: 100,
                              cacheHeight: 100,
                            );
                          }
                          return Container(
                            width: 50,
                            height: 50,
                            color: Colors.grey.shade800,
                            child: Icon(
                              Icons.music_note_rounded,
                              color: AppTheme.textSecondaryDark,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  title: Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppStyles.sonoPlayerTitle,
                  ),
                  subtitle: Text(
                    ArtistStringUtils.getShortDisplay(
                      song.artist ?? 'Unknown Artist',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppStyles.sonoPlayerArtist,
                  ),
                ),
                Divider(
                  color: AppTheme.textPrimaryDark.opacity20,
                  indent: 20,
                  endIndent: 20,
                ),
                ListTile(
                  leading: Icon(
                    Icons.playlist_play_rounded,
                    color: AppTheme.textSecondaryDark,
                  ),
                  title: Text(
                    "Play next",
                    style: TextStyle(
                      color: AppTheme.textPrimaryDark,
                      fontSize: 16,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(modalContext);
                    SonoPlayer().addSongToPlayNext(song);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Playing next"),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.queue_music_rounded,
                    color: AppTheme.textSecondaryDark,
                  ),
                  title: Text(
                    "Add to queue",
                    style: TextStyle(
                      color: AppTheme.textPrimaryDark,
                      fontSize: 16,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(modalContext);
                    SonoPlayer().addSongsToQueue([song]);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Added to queue"),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.playlist_add_rounded,
                    color: AppTheme.textSecondaryDark,
                  ),
                  title: Text(
                    "Add to playlist...",
                    style: TextStyle(
                      color: AppTheme.textPrimaryDark,
                      fontSize: 16,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(modalContext);
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: Colors.transparent,
                      isScrollControlled: true,
                      builder:
                          (sheetContext) => Padding(
                            padding: EdgeInsets.only(
                              bottom:
                                  MediaQuery.of(sheetContext).viewInsets.bottom,
                            ),
                            child: AddToPlaylistSheet(song: song),
                          ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.remove_circle_outline,
                    color: AppTheme.warning,
                  ),
                  title: const Text(
                    "Remove from Playlist",
                    style: TextStyle(color: AppTheme.warning, fontSize: 16),
                  ),
                  onTap: () async {
                    Navigator.pop(modalContext);
                    try {
                      final playlistService = context.read<PlaylistService>();
                      await playlistService.removeSongFromPlaylist(
                        _currentPlaylist.id,
                        song.id,
                      );
                      if (mounted) {
                        setState(
                          () =>
                              _loadedSongs?.removeWhere((s) => s.id == song.id),
                        );
                        widget.onPlaylistChanged?.call();
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to remove song: $e'),
                            backgroundColor: AppTheme.error,
                          ),
                        );
                      }
                    }
                  },
                ),
                SizedBox(height: AppTheme.spacingLg),
              ],
            ),
          ),
    );
  }

  Widget _buildSongTile(SongModel song, int index) {
    return ValueListenableBuilder<SongModel?>(
      key: ValueKey('song-tile-${song.id}'),
      valueListenable: SonoPlayer().currentSong,
      builder: (context, currentSong, child) {
        final isCurrentSong = currentSong?.id == song.id;
        final titleStyle =
            isCurrentSong
                ? AppStyles.sonoPlayerTitle.copyWith(color: AppTheme.brandPink)
                : AppStyles.sonoPlayerTitle;
        final artistStyle =
            isCurrentSong
                ? AppStyles.sonoPlayerArtist.copyWith(
                  color: AppTheme.brandPink.withAlpha((255 * 0.7).round()),
                )
                : AppStyles.sonoPlayerArtist;

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 24.0,
            vertical: 4.0,
          ),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            child: SizedBox(
              width: 50,
              height: 50,
              child: FutureBuilder<Uint8List?>(
                future: ArtworkCacheService.instance.getArtwork(
                  song.id,
                  size: 100,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.done &&
                      snapshot.hasData &&
                      snapshot.data != null) {
                    return Image.memory(
                      snapshot.data!,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      filterQuality: FilterQuality.medium,
                      cacheWidth: 100,
                      cacheHeight: 100,
                    );
                  }
                  return Container(
                    width: 50,
                    height: 50,
                    color: Colors.grey.shade800,
                    child: const Icon(
                      Icons.music_note_rounded,
                      color: AppTheme.textSecondaryDark,
                      size: 24,
                    ),
                  );
                },
              ),
            ),
          ),
          title: Text(
            song.title,
            style: titleStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            ArtistStringUtils.getShortDisplay(song.artist ?? 'Unknown Artist'),
            style: artistStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing:
              _isReorderMode
                  ? ReorderableDragStartListener(
                    index: index,
                    child: const Icon(
                      Icons.drag_handle_rounded,
                      color: AppTheme.textSecondaryDark,
                      size: 20,
                    ),
                  )
                  : IconButton(
                    icon: const Icon(
                      Icons.more_vert_rounded,
                      color: AppTheme.textSecondaryDark,
                      size: 20,
                    ),
                    onPressed: () => _showSongOptionsBottomSheet(song),
                  ),
          onTap: () {
            if (_loadedSongs != null && _loadedSongs!.isNotEmpty) {
              final songIndex = _loadedSongs!.indexOf(song);
              if (songIndex != -1) {
                SonoPlayer().playNewPlaylist(
                  _loadedSongs!,
                  songIndex,
                  context: "Playlist: ${_currentPlaylist.name}",
                );
              }
            }
          },
          onLongPress: () => _showSongOptionsBottomSheet(song),
        );
      },
    );
  }

  Widget _buildSongsList() {
    if (_loadedSongs == null || _loadedSongs!.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(48.0),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.music_note_rounded, size: 64, color: Colors.white24),
              SizedBox(height: AppTheme.spacing),
              Text(
                'No songs in this playlist yet',
                style: TextStyle(color: Colors.white54),
              ),
            ],
          ),
        ),
      );
    }

    if (_isReorderMode) {
      return ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        onReorder: _reorderSongs,
        itemCount: _loadedSongs!.length,
        itemBuilder: (context, index) {
          final song = _loadedSongs![index];
          return Container(
            key: ValueKey('reorder-${song.id}'),
            child: _buildSongTile(song, index),
          );
        },
        proxyDecorator: (child, index, animation) {
          return Material(
            color: Colors.transparent,
            child: ScaleTransition(
              scale: animation.drive(Tween(begin: 1.0, end: 1.05)),
              child: child,
            ),
          );
        },
      );
    }

    //normal list (no reordering)
    return Column(
      children: List.generate(
        _loadedSongs!.length,
        (index) => _buildSongTile(_loadedSongs![index], index),
      ),
    );
  }

  Widget _buildCoverArtwork() {
    //check if this is the "Liked Songs" playlist
    final isLikedSongs = _currentPlaylist.name.toLowerCase() == 'liked songs';

    if (isLikedSongs) {
      //always show default heart icon for Liked Songs
      return Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        ),
        child: const Icon(
          Icons.favorite_rounded,
          color: AppTheme.textSecondaryDark,
          size: 100,
        ),
      );
    }

    //check for custom cover first
    if (_currentPlaylist.hasCustomCover) {
      final customCoverPath = _currentPlaylist.customCoverPath;
      if (customCoverPath != null) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          child: Image.file(
            File(customCoverPath),
            key: ValueKey(
              '$customCoverPath-${_currentPlaylist.updatedAt.millisecondsSinceEpoch}',
            ), //force reload when file changes
            fit: BoxFit.cover,
            cacheHeight: 800,
            cacheWidth: 800,
            errorBuilder: (context, error, stackTrace) {
              debugPrint(
                'PlaylistDetailsPage: Error loading custom cover: $error',
              );
              return Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade800,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: const Icon(
                  Icons.queue_music_rounded,
                  color: Colors.white54,
                  size: 100,
                ),
              );
            },
          ),
        );
      }
    }

    //safe artwork widget with error handling
    if (_coverSongId == null) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade800,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        ),
        child: const Icon(
          Icons.queue_music_rounded,
          color: Colors.white54,
          size: 100,
        ),
      );
    }

    return QueryArtworkWidget(
      id: _coverSongId!,
      type: ArtworkType.AUDIO,
      artworkFit: BoxFit.cover,
      artworkQuality: FilterQuality.medium,
      artworkBorder: BorderRadius.zero,
      size: 400,
      nullArtworkWidget: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade800,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        ),
        child: const Icon(
          Icons.queue_music_rounded,
          color: Colors.white54,
          size: 100,
        ),
      ),
      keepOldArtwork: true,
      errorBuilder: (context, error, stackTrace) {
        debugPrint(
          'PlaylistDetailsPage: Artwork error for song $_coverSongId: $error',
        );
        return Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade800,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          ),
          child: const Icon(
            Icons.queue_music_rounded,
            color: Colors.white54,
            size: 100,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundDark,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_loadError != null) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundDark,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: AppTheme.error),
              SizedBox(height: AppTheme.spacing),
              Text(
                _loadError!,
                style: const TextStyle(color: AppTheme.textSecondaryDark),
              ),
              SizedBox(height: AppTheme.spacing),
              ElevatedButton(
                onPressed: _loadPlaylistData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppTheme.backgroundDark, AppTheme.elevatedSurfaceDark],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: SonoRefreshIndicator(
          onRefresh: _loadPlaylistData,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              //playlist Artwork
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 8.0,
                ),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: GestureDetector(
                    onTap:
                        _currentPlaylist.name.toLowerCase() != 'liked songs'
                            ? _showCoverPickerModal
                            : null,
                    child: Hero(
                      tag: 'playlist-artwork-${_currentPlaylist.id}',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                        child: _buildCoverArtwork(),
                      ),
                    ),
                  ),
                ),
              ),

              //Playlist Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Text(
                  _currentPlaylist.name,
                  style: AppStyles.sonoPlayerTitle.copyWith(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.left,
                ),
              ),

              SizedBox(height: AppTheme.spacingXs),

              //Song count + duration
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child:
                    _loadedSongs != null && _loadedSongs!.isNotEmpty
                        ? Text(
                          '${_loadedSongs!.length} songs • ${_formatDuration(_calculatePlaylistDuration())}',
                          style: AppStyles.sonoPlayerArtist.copyWith(
                            fontSize: 14,
                            color: Colors.white54,
                          ),
                        )
                        : Text(
                          '0 songs',
                          style: AppStyles.sonoPlayerArtist.copyWith(
                            fontSize: 14,
                            color: Colors.white54,
                          ),
                        ),
              ),

              SizedBox(height: AppTheme.spacing),

              //Action buttons row - matching Album Page exactly
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Row(
                  children: [
                    //Combined left buttons container
                    Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppTheme.elevatedSurfaceDark,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        border: Border.all(
                          color: const Color(0xFF3d3d3d),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          //Reorder toggle button
                          IconButton(
                            icon: Icon(
                              _isReorderMode
                                  ? Icons.reorder_rounded
                                  : Icons.swap_vert_rounded,
                              color:
                                  _isReorderMode
                                      ? AppTheme.brandPink
                                      : AppTheme.textSecondaryDark,
                            ),
                            iconSize: 24,
                            onPressed: () {
                              setState(() => _isReorderMode = !_isReorderMode);
                            },
                            tooltip:
                                _isReorderMode
                                    ? 'Exit reorder mode'
                                    : 'Reorder songs',
                          ),

                          //Three-dot menu button
                          IconButton(
                            icon: const Icon(
                              Icons.more_vert_rounded,
                              color: AppTheme.textSecondaryDark,
                            ),
                            iconSize: 24,
                            onPressed: _showPlaylistOptions,
                          ),
                        ],
                      ),
                    ),

                    const Spacer(),

                    //Shuffle button
                    Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppTheme.elevatedSurfaceDark,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        border: Border.all(
                          color: const Color(0xFF3d3d3d),
                          width: 1,
                        ),
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.shuffle_rounded,
                          color: AppTheme.textSecondaryDark,
                        ),
                        iconSize: 24,
                        onPressed:
                            _loadedSongs != null && _loadedSongs!.isNotEmpty
                                ? () {
                                  final shuffledSongs = List<SongModel>.from(
                                    _loadedSongs!,
                                  )..shuffle();
                                  SonoPlayer().playNewPlaylist(
                                    shuffledSongs,
                                    0,
                                    context:
                                        "Playlist: ${_currentPlaylist.name}",
                                  );
                                }
                                : null,
                      ),
                    ),

                    SizedBox(width: AppTheme.spacingSm),

                    //Play/Pause button - matching Album Page exactly
                    ValueListenableBuilder<SongModel?>(
                      valueListenable: SonoPlayer().currentSong,
                      builder: (context, currentSong, _) {
                        return ValueListenableBuilder<String?>(
                          valueListenable: SonoPlayer().playbackContext,
                          builder: (context, playbackContext, _) {
                            final expectedContext =
                                "Playlist: ${_currentPlaylist.name}";
                            final isPlaylistPlaying =
                                playbackContext == expectedContext &&
                                (_loadedSongs?.any(
                                      (song) => song.id == currentSong?.id,
                                    ) ??
                                    false);

                            return Container(
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppTheme.brandPink,
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusMd,
                                ),
                              ),
                              child: ValueListenableBuilder<bool>(
                                valueListenable: SonoPlayer().isPlaying,
                                builder: (context, isPlaying, _) {
                                  return IconButton(
                                    icon: Icon(
                                      (isPlaylistPlaying && isPlaying)
                                          ? Icons.pause_rounded
                                          : Icons.play_arrow_rounded,
                                      color: Colors.white,
                                    ),
                                    iconSize: 24,
                                    onPressed:
                                        _loadedSongs != null &&
                                                _loadedSongs!.isNotEmpty
                                            ? () {
                                              if (isPlaylistPlaying &&
                                                  isPlaying) {
                                                SonoPlayer().pause();
                                              } else if (isPlaylistPlaying &&
                                                  !isPlaying) {
                                                SonoPlayer().play();
                                              } else {
                                                SonoPlayer().playNewPlaylist(
                                                  _loadedSongs!,
                                                  0,
                                                  context:
                                                      "Playlist: ${_currentPlaylist.name}",
                                                );
                                              }
                                            }
                                            : null,
                                  );
                                },
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),

              SizedBox(height: AppTheme.spacing),

              //Songs List
              _buildSongsList(),

              //Bottom padding for player
              const SizedBox(height: 120),
            ],
          ),
        ),
      ),
    );
  }
}

//Cover Picker Bottom Modal
class _CoverPickerModal extends StatelessWidget {
  final int playlistId;
  final List<SongModel> playlistSongs;
  final Function(int) onCoverSelected;
  final VoidCallback onRemoveCover;
  final VoidCallback onPickFromSystem;

  const _CoverPickerModal({
    required this.playlistId,
    required this.playlistSongs,
    required this.onCoverSelected,
    required this.onRemoveCover,
    required this.onPickFromSystem,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusXl),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: AppTheme.spacingMd),
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(AppTheme.radius),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(AppTheme.spacingLg),
            child: Row(
              children: [
                Text(
                  'Choose Playlist Cover',
                  style: TextStyle(
                    color: AppTheme.textPrimaryDark,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'VarelaRound',
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: AppTheme.textSecondaryDark,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AppTheme.textPrimaryDark.opacity20),

          //Options
          ListTile(
            leading: Icon(
              Icons.photo_library_rounded,
              color: AppTheme.textSecondaryDark,
            ),
            title: Text(
              'Pick from System Photos',
              style: TextStyle(color: AppTheme.textPrimaryDark, fontSize: 16),
            ),
            onTap: onPickFromSystem,
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: AppTheme.warning),
            title: const Text(
              'Remove Cover',
              style: TextStyle(color: AppTheme.warning, fontSize: 16),
            ),
            onTap: onRemoveCover,
          ),

          Divider(height: 1, color: AppTheme.textPrimaryDark.opacity20),
          Padding(
            padding: EdgeInsets.all(AppTheme.spacing),
            child: Text(
              'Or select from playlist songs:',
              style: TextStyle(color: AppTheme.textSecondaryDark, fontSize: 14),
            ),
          ),

          //Songs grid
          if (playlistSongs.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32.0),
              child: Text(
                'Add songs to this playlist first!',
                style: TextStyle(color: AppTheme.textPrimaryDark.opacity50),
              ),
            )
          else
            Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.4,
              ),
              padding: EdgeInsets.symmetric(horizontal: AppTheme.spacing),
              child: GridView.builder(
                shrinkWrap: true,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: AppTheme.spacingMd,
                  mainAxisSpacing: AppTheme.spacingMd,
                  childAspectRatio: 1,
                ),
                itemCount: playlistSongs.length,
                itemBuilder: (context, index) {
                  final song = playlistSongs[index];
                  return GestureDetector(
                    onTap: () => onCoverSelected(song.id),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      child: QueryArtworkWidget(
                        id: song.id,
                        type: ArtworkType.AUDIO,
                        artworkFit: BoxFit.cover,
                        size: 200,
                        nullArtworkWidget: Container(
                          color: Colors.grey.shade800,
                          child: Icon(
                            Icons.music_note_rounded,
                            color: AppTheme.textPrimaryDark.opacity50,
                            size: 40,
                          ),
                        ),
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey.shade800,
                            child: Icon(
                              Icons.music_note_rounded,
                              color: AppTheme.textPrimaryDark.opacity50,
                              size: 40,
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          SizedBox(height: AppTheme.spacingLg),
        ],
      ),
    );
  }
}