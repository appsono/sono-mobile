/* THIS IS THE ALL ITEMS PAGE
* it includes multiple List Types
* - all songs
* - all albums
* - all artists
* - all playlists
* - all genres
* - all folders
*/
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:shimmer/shimmer.dart';
import 'package:sono/utils/audio_filter_utils.dart';
import 'package:sono/utils/artist_string_utils.dart';
import 'package:sono/widgets/global/bottom_sheet.dart';
import 'package:sono/data/models/playlist_model.dart' as db;
import 'package:sono/services/playlist/playlist_service.dart';
import 'package:sono/pages/library/playlist_details_page.dart';
import 'package:sono/widgets/library/song_list_title.dart';
import 'package:sono/pages/library/album_page.dart';
import 'package:sono/pages/library/artist_page.dart';
import 'package:sono/widgets/player/sono_player.dart';
import 'package:sono/styles/text.dart';
import 'package:sono/styles/app_theme.dart';
import 'package:sono/widgets/global/cached_artwork_image.dart';
import 'package:sono/widgets/global/refresh_indicator.dart';
import 'package:sono/widgets/library/artist_artwork_widget.dart';

enum ListItemType { song, album, artist, playlist, genre, folder }

class AllItemsPage extends StatefulWidget {
  final String pageTitle;
  final Future<List<dynamic>> itemsFuture;
  final ListItemType itemType;
  final OnAudioQuery audioQuery;

  const AllItemsPage({
    super.key,
    required this.pageTitle,
    required this.itemsFuture,
    required this.itemType,
    required this.audioQuery,
  });

  @override
  State<AllItemsPage> createState() => _AllItemsPageState();
}

class _AllItemsPageState extends State<AllItemsPage> {
  List<dynamic>? _resolvedItems;
  late Future<List<dynamic>> _itemsFuture;

  @override
  void initState() {
    super.initState();
    _itemsFuture = widget.itemsFuture;
  }

  void _refreshPlaylists() {
    if (widget.itemType == ListItemType.playlist) {
      setState(() {
        _itemsFuture = PlaylistService().getAllPlaylists();
      });
    }
  }

  Future<void> _onRefresh() async {
    setState(() {
      _resolvedItems = null;
      switch (widget.itemType) {
        case ListItemType.playlist:
          _itemsFuture = PlaylistService().getAllPlaylists();
          break;
        case ListItemType.song:
          _itemsFuture = AudioFilterUtils.getFilteredSongs(
            widget.audioQuery,
          );
          break;
        case ListItemType.album:
          _itemsFuture = widget.audioQuery.queryAlbums();
          break;
        case ListItemType.artist:
          _itemsFuture = widget.audioQuery.queryArtists();
          break;
        case ListItemType.genre:
          _itemsFuture = widget.audioQuery.queryGenres();
          break;
        case ListItemType.folder:
          _itemsFuture = widget.audioQuery.queryAllPath();
          break;
      }
    });
    await _itemsFuture;
  }

  Future<void> _showCreatePlaylistDialog() async {
    final nameController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showSonoBottomSheet<void>(
      context: context,
      title: 'Create Playlist',
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing),
        child: Form(
          key: formKey,
          child: TextFormField(
            controller: nameController,
            autofocus: true,
            style: const TextStyle(color: AppTheme.textPrimaryDark),
            decoration: InputDecoration(
              hintText: "Playlist Name",
              hintStyle: TextStyle(color: AppTheme.textTertiaryDark),
              filled: true,
              fillColor: AppTheme.surfaceDark,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                borderSide: BorderSide(color: AppTheme.brandPink, width: 2),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a name';
              }
              return null;
            },
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: Text(
            'Cancel',
            style: TextStyle(color: AppTheme.textSecondaryDark),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        TextButton(
          child: Text('Create', style: TextStyle(color: AppTheme.brandPink)),
          onPressed: () async {
            if (formKey.currentState!.validate()) {
              final navigator = Navigator.of(context);
              final scaffoldMessenger = ScaffoldMessenger.of(context);

              try {
                final playlistService = PlaylistService();
                await playlistService.createPlaylist(
                  name: nameController.text.trim(),
                );

                if (!mounted) return;

                navigator.pop();
                _refreshPlaylists();

                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: const Text("Playlist created successfully!"),
                    backgroundColor: AppTheme.success,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              } catch (e) {
                debugPrint('Error creating playlist: $e');

                if (!mounted) return;

                navigator.pop();

                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text("Failed to create playlist: $e"),
                    backgroundColor: AppTheme.error,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            }
          },
        ),
      ],
    );
  }

  void _playAll() {
    if (_resolvedItems != null && _resolvedItems!.isNotEmpty) {
      final songs = _resolvedItems!.cast<SongModel>();
      if (songs.isNotEmpty) {
        SonoPlayer().playNewPlaylist(songs, 0, context: widget.pageTitle);
      }
    }
  }

  Widget _buildSkeletonListItem() {
    return RepaintBoundary(
      child: Shimmer.fromColors(
        baseColor: AppTheme.surfaceDark,
        highlightColor: AppTheme.elevatedSurfaceDark,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing,
            vertical: AppTheme.spacingSm,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Container(
                width: 50.0,
                height: 50.0,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceDark,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
              ),
              const SizedBox(width: AppTheme.spacing),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Container(
                      width: double.infinity,
                      height: 16.0,
                      color: AppTheme.surfaceDark,
                      margin: const EdgeInsets.only(bottom: AppTheme.spacingSm),
                    ),
                    Container(
                      width: 120.0,
                      height: 12.0,
                      color: AppTheme.surfaceDark,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppTheme.backgroundDark, AppTheme.surfaceDark],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: _buildFab(),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: <Widget>[
            SliverAppBar(
              title: Text(
                widget.pageTitle,
                style: AppStyles.sonoPlayerTitle.copyWith(fontSize: 18),
              ),
              backgroundColor: AppTheme.backgroundDark.withAlpha(204),
              elevation: 0,
              pinned: true,
              leading: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_rounded,
                  color: AppTheme.textPrimaryDark,
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            SonoSliverRefreshControl(onRefresh: _onRefresh),
            //content list
            FutureBuilder<List<dynamic>>(
              future: _itemsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildSkeletonListItem(),
                      childCount: 15,
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return SliverFillRemaining(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppTheme.spacing),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline_rounded,
                              size: AppTheme.iconHero,
                              color: AppTheme.textTertiaryDark,
                            ),
                            const SizedBox(height: AppTheme.spacing),
                            Text(
                              'Error loading items',
                              style: TextStyle(
                                color: AppTheme.textSecondaryDark,
                                fontSize: AppTheme.font,
                              ),
                            ),
                            const SizedBox(height: AppTheme.spacingSm),
                            Text(
                              '${snapshot.error}',
                              style: TextStyle(
                                color: AppTheme.textTertiaryDark,
                                fontSize: AppTheme.fontSm,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return SliverFillRemaining(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppTheme.spacing),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _getEmptyIcon(),
                              size: AppTheme.iconHero,
                              color: AppTheme.textTertiaryDark,
                            ),
                            const SizedBox(height: AppTheme.spacing),
                            Text(
                              _getEmptyMessage(),
                              style: TextStyle(
                                color: AppTheme.textSecondaryDark,
                                fontSize: AppTheme.font,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                _resolvedItems = snapshot.data!;
                return SliverPadding(
                  padding: const EdgeInsets.only(bottom: 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = _resolvedItems![index];
                        return RepaintBoundary(
                          child: _buildListItem(context, item),
                        );
                      },
                      childCount: _resolvedItems!.length,
                      addAutomaticKeepAlives: false,
                      addRepaintBoundaries: false,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  IconData _getEmptyIcon() {
    switch (widget.itemType) {
      case ListItemType.song:
        return Icons.music_note_rounded;
      case ListItemType.album:
        return Icons.album_rounded;
      case ListItemType.artist:
        return Icons.person_rounded;
      case ListItemType.playlist:
        return Icons.queue_music_rounded;
      case ListItemType.genre:
        return Icons.category_rounded;
      case ListItemType.folder:
        return Icons.folder_rounded;
    }
  }

  String _getEmptyMessage() {
    switch (widget.itemType) {
      case ListItemType.song:
        return 'No songs found';
      case ListItemType.album:
        return 'No albums found';
      case ListItemType.artist:
        return 'No artists found';
      case ListItemType.playlist:
        return 'No playlists yet. Create one!';
      case ListItemType.genre:
        return 'No genres found';
      case ListItemType.folder:
        return 'No folders found';
    }
  }

  Widget? _buildFab() {
    //FAB for creating playlists
    if (widget.itemType == ListItemType.playlist) {
      return FloatingActionButton.extended(
        onPressed: _showCreatePlaylistDialog,
        label: Text(
          "CREATE PLAYLIST",
          style: AppStyles.sonoButtonTextSmaller.copyWith(
            color: AppTheme.textPrimaryDark,
          ),
        ),
        icon: const Icon(Icons.add_rounded, color: AppTheme.textPrimaryDark),
        backgroundColor: AppTheme.brandPink,
      );
    }

    if (widget.itemType == ListItemType.song &&
        _resolvedItems != null &&
        _resolvedItems!.isNotEmpty) {
      return FloatingActionButton.extended(
        onPressed: _playAll,
        label: Text(
          "PLAY ALL",
          style: AppStyles.sonoButtonTextSmaller.copyWith(
            color: AppTheme.textPrimaryDark,
          ),
        ),
        icon: const Icon(Icons.play_arrow, color: AppTheme.textPrimaryDark),
        backgroundColor: AppTheme.brandPink,
      );
    }
    return null;
  }

  Widget _buildListItem(BuildContext context, dynamic item) {
    switch (widget.itemType) {
      case ListItemType.song:
        final song = item as SongModel;
        return SongListTile(
          song: song,
          onSongTap: (selectedSong) {
            if (_resolvedItems != null) {
              final songList = _resolvedItems!.cast<SongModel>();
              final songIndex = songList.indexOf(selectedSong);
              if (songIndex != -1) {
                SonoPlayer().playNewPlaylist(
                  songList,
                  songIndex,
                  context: widget.pageTitle,
                );
              }
            }
          },
        );
      case ListItemType.album:
        final album = item as AlbumModel;
        return _AlbumListTile(
          album: album,
          onTap:
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (_) => AlbumPage(
                        album: album,
                        audioQuery: widget.audioQuery,
                      ),
                ),
              ),
        );
      case ListItemType.artist:
        final artist = item as ArtistModel;
        return _ArtistListTile(
          artist: artist,
          onTap:
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (_) => ArtistPage(
                        artist: artist,
                        audioQuery: widget.audioQuery,
                      ),
                ),
              ),
        );
      case ListItemType.playlist:
        //handle database playlists
        if (item is db.PlaylistModel) {
          return _DatabasePlaylistTile(
            playlist: item,
            onRefresh: _refreshPlaylists,
          );
        }
        //handle on_audio_query playlists (legacy => shouldnt happen)
        else if (item is PlaylistModel) {
          debugPrint(
            'Warning: Received MediaStore playlist in AllItemsPage, expected database playlist',
          );
          return const SizedBox.shrink();
        }
        //unknown type
        else {
          debugPrint(
            'Error: Unknown playlist type in AllItemsPage: ${item.runtimeType}',
          );
          return const SizedBox.shrink();
        }
      case ListItemType.genre:
        final genre = item as GenreModel;
        return _GenreListTile(
          genre: genre,
          onTap:
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (_) => AllItemsPage(
                        pageTitle: genre.genre,
                        itemsFuture: widget.audioQuery.queryAudiosFrom(
                          AudiosFromType.GENRE_ID,
                          genre.id,
                          sortType: SongSortType.TITLE,
                        ),
                        itemType: ListItemType.song,
                        audioQuery: widget.audioQuery,
                      ),
                ),
              ),
        );
      case ListItemType.folder:
        final folder = item as Map<String, String>;
        final folderName = folder['name']!;
        final folderPath = folder['path']!;
        return _FolderListTile(
          name: folderName,
          path: folderPath,
          onTap:
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (_) => AllItemsPage(
                        pageTitle: folderName,
                        itemsFuture: AudioFilterUtils.getFilteredSongs(
                          widget.audioQuery,
                          sortType: SongSortType.TITLE,
                          path: folderPath,
                        ),
                        itemType: ListItemType.song,
                        audioQuery: widget.audioQuery,
                      ),
                ),
              ),
        );
    }
  }
}

///Album list tile with RepaintBoundary
class _AlbumListTile extends StatelessWidget {
  final AlbumModel album;
  final VoidCallback onTap;

  const _AlbumListTile({required this.album, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CachedArtworkImage(
        id: album.id,
        size: 50,
        type: ArtworkType.ALBUM,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      title: Text(
        album.album,
        style: AppStyles.sonoListItemTitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        ArtistStringUtils.getShortDisplay(
          album.artist ?? 'Unknown Artist',
          maxArtists: 2,
        ),
        style: AppStyles.sonoListItemSubtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing,
        vertical: AppTheme.spacingXs,
      ),
    );
  }
}

///Artist list tile
class _ArtistListTile extends StatelessWidget {
  final ArtistModel artist;
  final VoidCallback onTap;

  const _ArtistListTile({required this.artist, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: SizedBox(
        width: 50,
        height: 50,
        child: ArtistArtworkWidget(
          artistName: artist.artist,
          artistId: artist.id,
          borderRadius: BorderRadius.circular(25.0),
        ),
      ),
      title: Text(
        artist.artist,
        style: AppStyles.sonoListItemTitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${artist.numberOfTracks ?? 0} songs',
        style: AppStyles.sonoListItemSubtitle,
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing,
        vertical: AppTheme.spacingXs,
      ),
    );
  }
}

///Genre list tile
class _GenreListTile extends StatelessWidget {
  final GenreModel genre;
  final VoidCallback onTap;

  const _GenreListTile({required this.genre, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        ),
        child: const Icon(
          Icons.category_rounded,
          color: AppTheme.textSecondaryDark,
        ),
      ),
      title: Text(genre.genre, style: AppStyles.sonoListItemTitle),
      subtitle: Text(
        '${genre.numOfSongs} songs',
        style: AppStyles.sonoListItemSubtitle,
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios_rounded,
        color: AppTheme.textTertiaryDark,
        size: 16,
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing,
        vertical: AppTheme.spacingXs,
      ),
    );
  }
}

///Folder list tile
class _FolderListTile extends StatelessWidget {
  final String name;
  final String path;
  final VoidCallback onTap;

  const _FolderListTile({
    required this.name,
    required this.path,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        ),
        child: const Icon(
          Icons.folder_rounded,
          color: AppTheme.textSecondaryDark,
        ),
      ),
      title: Text(name, style: AppStyles.sonoListItemTitle),
      subtitle: Text(
        path,
        style: AppStyles.sonoListItemSubtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios_rounded,
        color: AppTheme.textTertiaryDark,
        size: 16,
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing,
        vertical: AppTheme.spacingXs,
      ),
    );
  }
}

///Helper widget for database playlists in list view
class _DatabasePlaylistTile extends StatefulWidget {
  final db.PlaylistModel playlist;
  final VoidCallback? onRefresh;

  const _DatabasePlaylistTile({required this.playlist, this.onRefresh});

  @override
  State<_DatabasePlaylistTile> createState() => _DatabasePlaylistTileState();
}

class _DatabasePlaylistTileState extends State<_DatabasePlaylistTile>
    with AutomaticKeepAliveClientMixin {
  final PlaylistService _playlistService = PlaylistService();
  int? _coverSongId;
  int _count = 0;
  bool _isLoading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(covariant _DatabasePlaylistTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playlist.id != widget.playlist.id) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      //load cover and count in parallel
      final results = await Future.wait([
        _playlistService.getPlaylistCover(widget.playlist.id),
        _playlistService.getPlaylistSongCount(widget.playlist.id),
      ]);

      if (mounted) {
        setState(() {
          _coverSongId = results[0];
          _count = results[1] as int;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading playlist data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  ///Check if this is the "Liked Songs" playlist (always use default icon)
  bool get _isLikedSongsPlaylist {
    final name = widget.playlist.name.toLowerCase();
    return name == 'liked songs' ||
        name == 'favorites' ||
        name == 'liked' ||
        name.contains('liked songs');
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        child: _buildCover(),
      ),
      title: Text(
        widget.playlist.name,
        style: AppStyles.sonoListItemTitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle:
          _isLoading
              ? Container(
                width: 60,
                height: 12,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceDark,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
              )
              : Text(
                '$_count ${_count == 1 ? "song" : "songs"}',
                style: AppStyles.sonoListItemSubtitle,
              ),
      trailing: const Icon(
        Icons.arrow_forward_ios_rounded,
        color: AppTheme.textTertiaryDark,
        size: 16,
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PlaylistDetailsPage(playlist: widget.playlist),
          ),
        ).then((_) {
          //Refresh data when returning from details page
          _loadData();
          widget.onRefresh?.call();
        });
      },
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing,
        vertical: AppTheme.spacingXs,
      ),
    );
  }

  Widget _buildCover() {
    //liked Songs always uses default icon
    if (_isLikedSongsPlaylist) {
      return _buildDefaultCover(icon: Icons.favorite_rounded);
    }

    //check for custom cover first
    if (widget.playlist.hasCustomCover) {
      final customCoverPath = widget.playlist.customCoverPath;
      if (customCoverPath != null) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          child: Image.file(
            File(customCoverPath),
            width: 50,
            height: 50,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return _buildDefaultCover();
            },
          ),
        );
      }
    }

    //check for song artwork cover
    if (_coverSongId != null) {
      return CachedArtworkImage(
        id: _coverSongId!,
        size: 50,
        type: ArtworkType.AUDIO,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      );
    }

    //default icon
    return _buildDefaultCover();
  }

  Widget _buildDefaultCover({IconData icon = Icons.queue_music_rounded}) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Icon(icon, color: AppTheme.textSecondaryDark, size: 28),
    );
  }
}