import 'dart:io';
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:sono/pages/library/all_items_page.dart';
import 'package:sono/services/utils/favorites_service.dart';
import 'package:sono/services/playlist/playlist_service.dart';
import 'package:sono/styles/text.dart';
import 'package:sono/utils/audio_filter_utils.dart';
import 'package:sono/widgets/global/page_header.dart';
import 'package:sono/styles/app_theme.dart';
import 'package:provider/provider.dart';

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

    final List<_LibraryCategory> categories = [
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
          _navigateTo(context, "Liked Songs", ListItemType.song, () async {
            final favIds = await favoritesService.getFavoriteSongIds();
            if (favIds.isEmpty) return [];
            final allSongs = await AudioFilterUtils.getFilteredSongs(
              _audioQuery,
            );
            return allSongs.where((song) => favIds.contains(song.id)).toList();
          }());
        },
      ),
      _LibraryCategory(
        title: "Favorite Artists",
        icon: Icons.star_rounded,
        color: Colors.amber.shade400,
        onTap: () {
          final favoritesService = context.read<FavoritesService>();
          _navigateTo(
            context,
            "Favorite Artists",
            ListItemType.artist,
            () async {
              final favIds = await favoritesService.getFavoriteArtistIds();
              if (favIds.isEmpty) return [];
              final allArtists = await AudioFilterUtils.getFilteredArtists(
                _audioQuery,
              );
              return allArtists
                  .where((artist) => favIds.contains(artist.id))
                  .toList();
            }(),
          );
        },
      ),
      _LibraryCategory(
        title: "Favorite Albums",
        icon: Icons.bookmark_added_rounded,
        color: Colors.green.shade400,
        onTap: () {
          final favoritesService = context.read<FavoritesService>();
          _navigateTo(
            context,
            "Favorite Albums",
            ListItemType.album,
            () async {
              final favIds = await favoritesService.getFavoriteAlbumIds();
              if (favIds.isEmpty) return [];
              final allAlbums = await AudioFilterUtils.getFilteredAlbums(
                _audioQuery,
              );
              return allAlbums
                  .where((album) => favIds.contains(album.id))
                  .toList();
            }(),
          );
        },
      ),
      _LibraryCategory(
        title: "Songs",
        icon: Icons.music_note_rounded,
        color: Colors.purple.shade300,
        onTap: () {
          _navigateTo(
            context,
            "All Songs",
            ListItemType.song,
            AudioFilterUtils.getFilteredSongs(
              _audioQuery,
              sortType: SongSortType.TITLE,
            ),
          );
        },
      ),
      _LibraryCategory(
        title: "Albums",
        icon: Icons.album_rounded,
        color: Colors.orange.shade400,
        onTap: () {
          _navigateTo(
            context,
            "All Albums",
            ListItemType.album,
            AudioFilterUtils.getFilteredAlbums(
              _audioQuery,
              sortType: AlbumSortType.ALBUM,
            ),
          );
        },
      ),
      _LibraryCategory(
        title: "Artists",
        icon: Icons.person_rounded,
        color: Colors.teal.shade300,
        onTap: () {
          _navigateTo(
            context,
            "All Artists",
            ListItemType.artist,
            AudioFilterUtils.getFilteredArtists(
              _audioQuery,
              sortType: ArtistSortType.ARTIST,
            ),
          );
        },
      ),
      _LibraryCategory(
        title: "Recently Added",
        icon: Icons.history_rounded,
        color: Colors.lightBlue.shade300,
        onTap: () {
          _navigateTo(
            context,
            "Recently Added",
            ListItemType.song,
            AudioFilterUtils.getFilteredSongs(
              _audioQuery,
              sortType: SongSortType.DATE_ADDED,
              orderType: OrderType.DESC_OR_GREATER,
            ),
          );
        },
      ),
      _LibraryCategory(
        title: "Genres",
        icon: Icons.category_rounded,
        color: Colors.red.shade300,
        onTap: () {
          _navigateTo(
            context,
            "Genres",
            ListItemType.genre,
            _audioQuery.queryGenres(sortType: GenreSortType.GENRE),
          );
        },
      ),
      _LibraryCategory(
        title: "Folders",
        icon: Icons.folder_open_rounded,
        color: Colors.brown.shade300,
        onTap: () {
          _navigateTo(context, "Folders", ListItemType.folder, () async {
            final songs = await AudioFilterUtils.getFilteredSongs(
              _audioQuery,
            );
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
        child:
            widget.hasPermission
                ? _buildGridView(categories)
                : _buildPermissionDenied(),
      ),
    );
  }

  Widget _buildGridView(List<_LibraryCategory> categories) {
    return GridView.builder(
      padding: const EdgeInsets.all(16).copyWith(bottom: 180),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.2,
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