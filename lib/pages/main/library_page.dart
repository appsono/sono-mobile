import 'dart:io';
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:sono/pages/library/all_items_page.dart';
import 'package:sono/pages/servers/library_page.dart';
import 'package:sono/services/servers/server_service.dart';
import 'package:sono/services/utils/favorites_service.dart';
import 'package:sono/services/playlist/playlist_service.dart';
import 'package:sono/styles/text.dart';
import 'package:sono/utils/audio_filter_utils.dart';
import 'package:sono/widgets/global/page_header.dart';
import 'package:sono/styles/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:sono/widgets/global/content_constraint.dart';

class LibraryPage extends StatefulWidget {
  final VoidCallback? onMenuTap;
  final bool hasPermission;
  final VoidCallback onRequestPermission;
  final Map<String, dynamic>? currentUser;
  final bool isLoggedIn;

  const LibraryPage({
    super.key,
    this.onMenuTap,
    required this.hasPermission,
    required this.onRequestPermission,
    this.currentUser,
    this.isLoggedIn = false,
  });

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage>
    with AutomaticKeepAliveClientMixin {
  final OnAudioQuery _audioQuery = OnAudioQuery();

  @override
  bool get wantKeepAlive => true;

  void _navigateTo(
    BuildContext context,
    String pageTitle,
    ListItemType itemType,
    Future<List<dynamic>> future,
  ) {
    if (!widget.hasPermission) {
      widget.onRequestPermission();
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => AllItemsPage(
              pageTitle: pageTitle,
              itemsFuture: future,
              itemType: itemType,
              audioQuery: _audioQuery,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final serverService = context.watch<MusicServerService>();

    final List<_LibraryCategory> categories = [
      if (serverService.hasActiveServer)
        _LibraryCategory(
          title: serverService.activeServer!.name,
          icon: Icons.cloud_rounded,
          color: Colors.teal.shade300,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ServerLibraryPage(),
              ),
            );
          },
        ),
      _LibraryCategory(
        title: "Playlists",
        icon: Icons.queue_music_rounded,
        color: Colors.blue.shade300,
        onTap: () {
          _navigateTo(
            context,
            "Playlists",
            ListItemType.playlist,
            PlaylistService().getAllPlaylists(),
          );
        },
      ),
      _LibraryCategory(
        title: "Liked Songs",
        icon: Icons.favorite_rounded,
        color: Theme.of(context).primaryColor,
        onTap: () {
          final favoritesService = context.read<FavoritesService>();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => AllItemsPage(
                    pageTitle: "Liked Songs",
                    itemsFuture: () async {
                      final favIds =
                          await favoritesService.getFavoriteSongIds();
                      if (favIds.isEmpty) return [];
                      final allSongs = await AudioFilterUtils.getFilteredSongs(
                        _audioQuery,
                      );
                      return allSongs
                          .where((song) => favIds.contains(song.id))
                          .toList();
                    }(),
                    itemType: ListItemType.song,
                    audioQuery: _audioQuery,
                    onRefreshOverride: () async {
                      final favIds =
                          await favoritesService.getFavoriteSongIds();
                      if (favIds.isEmpty) return [];
                      final allSongs = await AudioFilterUtils.getFilteredSongs(
                        _audioQuery,
                      );
                      return allSongs
                          .where((song) => favIds.contains(song.id))
                          .toList();
                    },
                  ),
            ),
          );
        },
      ),
      _LibraryCategory(
        title: "Favorite Artists",
        icon: Icons.star_rounded,
        color: Colors.amber.shade400,
        onTap: () {
          final favoritesService = context.read<FavoritesService>();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => AllItemsPage(
                    pageTitle: "Favorite Artists",
                    itemsFuture: () async {
                      final favIds =
                          await favoritesService.getFavoriteArtistIds();
                      if (favIds.isEmpty) return [];
                      final allArtists =
                          await AudioFilterUtils.getFilteredArtists(
                            _audioQuery,
                          );
                      return allArtists
                          .where((artist) => favIds.contains(artist.id))
                          .toList();
                    }(),
                    itemType: ListItemType.artist,
                    audioQuery: _audioQuery,
                    onRefreshOverride: () async {
                      final favIds =
                          await favoritesService.getFavoriteArtistIds();
                      if (favIds.isEmpty) return [];
                      final allArtists =
                          await AudioFilterUtils.getFilteredArtists(
                            _audioQuery,
                          );
                      return allArtists
                          .where((artist) => favIds.contains(artist.id))
                          .toList();
                    },
                  ),
            ),
          );
        },
      ),
      _LibraryCategory(
        title: "Favorite Albums",
        icon: Icons.bookmark_added_rounded,
        color: Colors.green.shade400,
        onTap: () {
          final favoritesService = context.read<FavoritesService>();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => AllItemsPage(
                    pageTitle: "Favorite Albums",
                    itemsFuture: () async {
                      final favIds =
                          await favoritesService.getFavoriteAlbumIds();
                      if (favIds.isEmpty) return [];
                      final allAlbums =
                          await AudioFilterUtils.getFilteredAlbums(_audioQuery);
                      return allAlbums
                          .where((album) => favIds.contains(album.id))
                          .toList();
                    }(),
                    itemType: ListItemType.album,
                    audioQuery: _audioQuery,
                    onRefreshOverride: () async {
                      final favIds =
                          await favoritesService.getFavoriteAlbumIds();
                      if (favIds.isEmpty) return [];
                      final allAlbums =
                          await AudioFilterUtils.getFilteredAlbums(_audioQuery);
                      return allAlbums
                          .where((album) => favIds.contains(album.id))
                          .toList();
                    },
                  ),
            ),
          );
        },
      ),
      _LibraryCategory(
        title: "Songs",
        icon: Icons.music_note_rounded,
        color: Colors.purple.shade300,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => AllItemsPage(
                    pageTitle: "All Songs",
                    itemsFuture: AudioFilterUtils.getFilteredSongs(
                      _audioQuery,
                      sortType: SongSortType.TITLE,
                    ),
                    itemType: ListItemType.song,
                    audioQuery: _audioQuery,
                    songSortType: SongSortType.TITLE,
                  ),
            ),
          );
        },
      ),
      _LibraryCategory(
        title: "Albums",
        icon: Icons.album_rounded,
        color: Colors.orange.shade400,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => AllItemsPage(
                    pageTitle: "All Albums",
                    itemsFuture: AudioFilterUtils.getFilteredAlbums(
                      _audioQuery,
                      sortType: AlbumSortType.ALBUM,
                    ),
                    itemType: ListItemType.album,
                    audioQuery: _audioQuery,
                    albumSortType: AlbumSortType.ALBUM,
                  ),
            ),
          );
        },
      ),
      _LibraryCategory(
        title: "Artists",
        icon: Icons.person_rounded,
        color: Colors.teal.shade300,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => AllItemsPage(
                    pageTitle: "All Artists",
                    itemsFuture: AudioFilterUtils.getFilteredArtists(
                      _audioQuery,
                      sortType: ArtistSortType.ARTIST,
                    ),
                    itemType: ListItemType.artist,
                    audioQuery: _audioQuery,
                    artistSortType: ArtistSortType.ARTIST,
                  ),
            ),
          );
        },
      ),
      _LibraryCategory(
        title: "Recently Added",
        icon: Icons.history_rounded,
        color: Colors.lightBlue.shade300,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => AllItemsPage(
                    pageTitle: "Recently Added",
                    itemsFuture: AudioFilterUtils.getFilteredSongs(
                      _audioQuery,
                      sortType: SongSortType.DATE_ADDED,
                      orderType: OrderType.DESC_OR_GREATER,
                    ),
                    itemType: ListItemType.song,
                    audioQuery: _audioQuery,
                    songSortType: SongSortType.DATE_ADDED,
                    orderType: OrderType.DESC_OR_GREATER,
                  ),
            ),
          );
        },
      ),
      _LibraryCategory(
        title: "Genres",
        icon: Icons.category_rounded,
        color: Colors.red.shade300,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => AllItemsPage(
                    pageTitle: "Genres",
                    itemsFuture: _audioQuery.queryGenres(
                      sortType: GenreSortType.GENRE,
                    ),
                    itemType: ListItemType.genre,
                    audioQuery: _audioQuery,
                    genreSortType: GenreSortType.GENRE,
                  ),
            ),
          );
        },
      ),
      _LibraryCategory(
        title: "Folders",
        icon: Icons.folder_open_rounded,
        color: Colors.brown.shade300,
        onTap: () {
          _navigateTo(context, "Folders", ListItemType.folder, () async {
            final songs = await AudioFilterUtils.getFilteredSongs(_audioQuery);
            final Set<String> folderPaths = {};
            for (var song in songs) {
              if (song.data.isNotEmpty) {
                try {
                  folderPaths.add(Directory(song.data).parent.path);
                } catch (e) {
                  //
                }
              }
            }

            final List<Map<String, String>> folders =
                folderPaths.map((path) {
                  return {
                    'path': path,
                    'name': path
                        .split('/')
                        .lastWhere(
                          (e) => e.isNotEmpty,
                          orElse: () => 'Unknown Folder',
                        ),
                  };
                }).toList();

            folders.sort(
              (a, b) =>
                  a['name']!.toLowerCase().compareTo(b['name']!.toLowerCase()),
            );

            return folders;
          }());
        },
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: GlobalPageHeader(
        pageTitle: "Library",
        onMenuTap: widget.onMenuTap,
        currentUser: widget.currentUser,
        isLoggedIn: widget.isLoggedIn,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppTheme.backgroundDark, AppTheme.surfaceDark],
          ),
        ),
        child: ContentConstraint(
          maxWidth: 1200,
          child:
              widget.hasPermission
                  ? _buildGridView(categories)
                  : _buildPermissionDenied(),
        ),
      ),
    );
  }

  Widget _buildGridView(List<_LibraryCategory> categories) {
    final screenWidth = MediaQuery.of(context).size.width;

    //responsive column count based on screen width
    int crossAxisCount = 2; //default
    if (screenWidth > 1200) {
      crossAxisCount = 5; //large tablets/desktops
    } else if (screenWidth > 900) {
      crossAxisCount = 4; //medium tablets
    } else if (screenWidth > 700) {
      crossAxisCount = 3; //small tablets
    } else if (screenWidth > 500) {
      crossAxisCount = 2; //large phones in landscape
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16).copyWith(bottom: 180),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.0,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        return _CategoryCard(category: category);
      },
    );
  }

  Widget _buildPermissionDenied() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.music_off_rounded,
              color: Colors.white30,
              size: 80,
            ),
            SizedBox(height: AppTheme.spacingLg),
            Text(
              'Permission Required',
              style: AppStyles.sonoButtonText.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Sono needs permission to access your local audio files to build your library.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondaryDark, height: 1.5),
            ),
            SizedBox(height: AppTheme.spacingLg),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              onPressed: widget.onRequestPermission,
              icon: const Icon(Icons.security_rounded),
              label: const Text('Grant Permission'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LibraryCategory {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  _LibraryCategory({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

class _CategoryCard extends StatelessWidget {
  final _LibraryCategory category;
  const _CategoryCard({required this.category});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withAlpha(8),
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      child: InkWell(
        onTap: category.onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        splashColor: category.color.withAlpha(40),
        highlightColor: category.color.withAlpha(20),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white.withAlpha(20)),
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(category.icon, color: category.color, size: 36),
                Text(
                  category.title,
                  style: AppStyles.sonoButtonText.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
