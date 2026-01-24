import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sono/services/utils/favorites_service.dart';
import 'package:sono/widgets/player/sono_player.dart';
import 'package:sono/widgets/global/add_to_playlist_dialog.dart';
import 'package:sono/styles/text.dart';
import 'package:sono/styles/app_theme.dart';
import 'package:sono/services/utils/artwork_cache_service.dart';
import 'package:sono/utils/artist_string_utils.dart';
import 'package:sono/utils/artist_navigation.dart';

import 'package:sono/widgets/sas/sas_modal.dart';
import 'package:sono/widgets/global/refresh_indicator.dart';
import 'package:provider/provider.dart';

class AlbumPage extends StatefulWidget {
  final AlbumModel album;
  final OnAudioQuery audioQuery;

  const AlbumPage({super.key, required this.album, required this.audioQuery});

  @override
  State<AlbumPage> createState() => _AlbumPageState();
}

class _AlbumPageState extends State<AlbumPage> {
  late Future<List<SongModel>> _songsFuture;
  List<SongModel>? _loadedSongs;
  final Map<int, Uint8List?> _artistArtworkCache = {};
  final Map<String, ArtistModel> _artistLookup =
      {}; //artist name (lowercase) -> ArtistModel
  bool _isAlbumFavorite = false;

  @override
  void initState() {
    super.initState();
    _loadSongs();
    _loadFavoriteStatus();
    _loadArtists();
  }

  //duration formatter
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

  //calc total duration
  Duration _calculateAlbumDuration(List<SongModel> albumSongs) {
    int totalMilliseconds = 0;
    for (final song in albumSongs) {
      totalMilliseconds += song.duration ?? 0;
    }
    return Duration(milliseconds: totalMilliseconds);
  }

  Widget _buildSkeletonLoader({
    required double width,
    required double height,
    BorderRadius? borderRadius,
  }) {
    return Shimmer.fromColors(
      baseColor: AppTheme.elevatedSurfaceDark,
      highlightColor: const Color(0xFF404040),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius:
              borderRadius ?? BorderRadius.circular(AppTheme.radiusMd),
          color: AppTheme.textPrimaryDark,
        ),
      ),
    );
  }

  Widget _buildSongListSkeleton() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing,
        vertical: AppTheme.spacingSm,
      ),
      child: Row(
        children: [
          _buildSkeletonLoader(
            width: 50,
            height: 50,
            borderRadius: BorderRadius.circular(AppTheme.radius),
          ),
          const SizedBox(width: AppTheme.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSkeletonLoader(width: double.infinity, height: 16),
                const SizedBox(height: AppTheme.spacingSm),
                _buildSkeletonLoader(width: 150, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _loadArtists() async {
    try {
      //query all artists
      final allArtists = await widget.audioQuery.queryArtists();

      //build lookup map: artist name (lowercase) => ArtistModel
      for (final artist in allArtists) {
        _artistLookup[artist.artist.toLowerCase()] = artist;
      }

      //preload artwork for this albums artists
      final albumArtists = ArtistStringUtils.splitArtists(
        widget.album.artist ?? 'Unknown',
      );

      for (final artistName in albumArtists.take(3)) {
        final artist = _artistLookup[artistName.toLowerCase()];
        if (artist != null && !_artistArtworkCache.containsKey(artist.id)) {
          final artwork = await ArtworkCacheService.instance.getArtwork(
            artist.id,
            type: ArtworkType.ARTIST,
            size: 100,
          );
          if (mounted) {
            setState(() {
              _artistArtworkCache[artist.id] = artwork;
            });
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error loading artists: $e');
      }
    }
  }

  Future<void> _onRefresh() async {
    _loadSongs();
    await _songsFuture;
  }

  //artwork preloading
  void _loadSongs() {
    final stopwatch = Stopwatch()..start();

    _songsFuture = widget.audioQuery.queryAudiosFrom(
      AudiosFromType.ALBUM_ID,
      widget.album.id,
      sortType: null,
      orderType: OrderType.ASC_OR_SMALLER,
    );

    _songsFuture
        .then((songs) {
          stopwatch.stop();

          if (kDebugMode) {
            debugPrint(
              'AlbumPage: Loaded ${songs.length} songs in ${stopwatch.elapsedMilliseconds}ms',
            );
          }

          if (mounted) {
            songs.sort((a, b) {
              final trackA = a.track;
              final trackB = b.track;

              //both have track numbers (including 0)
              if (trackA != null && trackB != null) {
                return trackA.compareTo(trackB);
              }
              //only A has track number
              if (trackA != null) return -1;
              //only B has track number
              if (trackB != null) return 1;
              //neither has track number, sort by title
              return a.title.compareTo(b.title);
            });

            setState(() {
              _loadedSongs = songs;
            });

            //preload artwork => better scrolling
            //use microtask to not block the UI
            Future.microtask(() {
              if (mounted && songs.isNotEmpty) {
                final artworkStopwatch = Stopwatch()..start();
                final songIds = songs.map((s) => s.id).toList();

                ArtworkCacheService.instance
                    .preloadArtwork(
                      songIds,
                      maxPreload:
                          20, //only preload first 20 to avoid memory spike
                    )
                    .then((_) {
                      artworkStopwatch.stop();
                      if (kDebugMode) {
                        debugPrint(
                          'AlbumPage: Preloaded artwork in ${artworkStopwatch.elapsedMilliseconds}ms',
                        );
                      }
                    });
              }
            });
          }
        })
        .catchError((error) {
          stopwatch.stop();
          if (kDebugMode) {
            debugPrint(
              'AlbumPage: Load failed after ${stopwatch.elapsedMilliseconds}ms: $error',
            );
          }

          if (mounted) {
            setState(() {
              _loadedSongs = [];
            });
          }
        });
  }

  Future<void> _loadFavoriteStatus() async {
    if (!mounted) return;
    final favoritesService = context.read<FavoritesService>();
    final isFavorite = await favoritesService.isAlbumFavorite(widget.album.id);
    if (mounted) {
      setState(() {
        _isAlbumFavorite = isFavorite;
      });
    }
  }

  Future<void> _toggleFavorite() async {
    if (!mounted) return;
    final favoritesService = context.read<FavoritesService>();
    if (_isAlbumFavorite) {
      await favoritesService.removeAlbumFromFavorites(widget.album.id);
    } else {
      await favoritesService.addAlbumToFavorites(
        widget.album.id,
        widget.album.album,
      );
    }
    _loadFavoriteStatus();
  }

  void _navigateToArtist(String artistName) {
    final artist = _artistLookup[artistName.toLowerCase()];
    if (artist != null) {
      ArtistNavigation.navigateWithArtistModel(
        context,
        artist,
        widget.audioQuery,
      );
    } else {
      //fallback: query by name if not in lookup yet
      ArtistNavigation.navigateToArtistByName(
        context,
        artistName,
        widget.audioQuery,
      );
    }
  }

  void _showArtistsModal() {
    final artists = ArtistStringUtils.splitArtists(
      widget.album.artist ?? 'Unknown',
    );

    if (artists.length == 1) {
      //navigate directly if only one
      _navigateToArtist(artists.first);
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: AppTheme.cardDark,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppTheme.radiusXl),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              //drag handle
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppTheme.spacingMd,
                ),
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[700],
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                  ),
                ),
              ),
              //title
              const Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingLg,
                  vertical: AppTheme.spacingSm,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Artists",
                    style: TextStyle(
                      color: AppTheme.textPrimaryDark,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'VarelaRound',
                    ),
                  ),
                ),
              ),
              //artist list
              ...artists.map((artistName) {
                final artist = _artistLookup[artistName.toLowerCase()];
                final cachedArtwork =
                    artist != null ? _artistArtworkCache[artist.id] : null;

                return ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(25),
                    child: SizedBox(
                      width: 50,
                      height: 50,
                      child:
                          cachedArtwork != null
                              ? Image.memory(
                                cachedArtwork,
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                                gaplessPlayback: true,
                              )
                              : Container(
                                color: Colors.grey.shade800,
                                child: const Icon(
                                  Icons.person_rounded,
                                  color: Colors.white54,
                                  size: 30,
                                ),
                              ),
                    ),
                  ),
                  title: Text(
                    artistName,
                    style: const TextStyle(
                      color: AppTheme.textPrimaryDark,
                      fontSize: 16,
                      fontFamily: 'VarelaRound',
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _navigateToArtist(artistName);
                  },
                );
              }),
              const SizedBox(height: AppTheme.spacingLg),
            ],
          ),
        );
      },
    );
  }

  void _showAlbumOptionsBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: AppTheme.cardDark,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppTheme.radiusXl),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppTheme.spacingMd,
                ),
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[700],
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                  ),
                ),
              ),
              //add album to queue
              ListTile(
                leading: const Icon(
                  Icons.queue_music_rounded,
                  color: AppTheme.textSecondaryDark,
                  size: 28,
                ),
                title: const Text(
                  "Add Album to Queue",
                  style: TextStyle(
                    color: AppTheme.textPrimaryDark,
                    fontSize: 16,
                    fontFamily: 'VarelaRound',
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  if (_loadedSongs != null && _loadedSongs!.isNotEmpty) {
                    SonoPlayer().addSongsToQueue(_loadedSongs!);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Album added to queue"),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
              ),
              //go to artist
              ListTile(
                leading: const Icon(
                  Icons.person_outline_rounded,
                  color: AppTheme.textSecondaryDark,
                  size: 28,
                ),
                title: const Text(
                  "Go to Artist's Page",
                  style: TextStyle(
                    color: AppTheme.textPrimaryDark,
                    fontSize: 16,
                    fontFamily: 'VarelaRound',
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showArtistsModal();
                },
              ),
              //add to playlist
              ListTile(
                leading: const Icon(
                  Icons.playlist_add_rounded,
                  color: AppTheme.textSecondaryDark,
                  size: 28,
                ),
                title: const Text(
                  "Add to Playlist",
                  style: TextStyle(
                    color: AppTheme.textPrimaryDark,
                    fontSize: 16,
                    fontFamily: 'VarelaRound',
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  if (_loadedSongs != null && _loadedSongs!.isNotEmpty) {
                    //add all songs to playlist
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: Colors.transparent,
                      isScrollControlled: true,
                      builder: (context) {
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: MediaQuery.of(context).viewInsets.bottom,
                          ),
                          child: AddToPlaylistSheet(song: _loadedSongs!.first),
                        );
                      },
                    );
                  }
                },
              ),
              //start sas
              ListTile(
                leading: const Icon(
                  Icons.cast_rounded,
                  color: AppTheme.textSecondaryDark,
                  size: 28,
                ),
                title: Row(
                  children: [
                    const Text(
                      "Start SAS (Sono Audio Stream)",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontFamily: 'VarelaRound',
                      ),
                    ),
                    SizedBox(width: AppTheme.spacingXs),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.brandPink,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                      child: const Text(
                        "BETA",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'VarelaRound',
                        ),
                      ),
                    ),
                  ],
                ),
                onTap: () {
                  showSASAdaptiveModal(context);
                },
              ),
              SizedBox(height: AppTheme.spacingLg),
            ],
          ),
        );
      },
    );
  }

  void _openLastFmLink() async {
    final artist = widget.album.artist ?? '';
    final album = widget.album.album;

    if (artist.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Cannot open Last.fm: Unknown artist"),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Opening Last.fm..."),
        duration: Duration(seconds: 1),
      ),
    );

    final encodedArtist = Uri.encodeComponent(artist);
    final encodedAlbum = Uri.encodeComponent(album);
    final url = 'https://www.last.fm/music/$encodedArtist/$encodedAlbum';
    final uri = Uri.parse(url);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Could not open Last.fm"),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _showSongOptionsBottomSheet(SongModel song) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: AppTheme.cardDark,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[700],
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                ),
              ),
              ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
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
              const Divider(color: Colors.white24, indent: 20, endIndent: 20),
              ListTile(
                leading: const Icon(
                  Icons.playlist_play_rounded,
                  color: AppTheme.textSecondaryDark,
                ),
                title: const Text(
                  "Play next",
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                onTap: () {
                  Navigator.pop(context);
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
                leading: const Icon(
                  Icons.queue_music_rounded,
                  color: AppTheme.textSecondaryDark,
                ),
                title: const Text(
                  "Add to queue",
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                onTap: () {
                  Navigator.pop(context);
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
                leading: const Icon(
                  Icons.playlist_add_rounded,
                  color: AppTheme.textSecondaryDark,
                ),
                title: const Text(
                  "Add to playlist...",
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                onTap: () {
                  Navigator.pop(context);
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    isScrollControlled: true,
                    builder: (context) {
                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: MediaQuery.of(context).viewInsets.bottom,
                        ),
                        child: AddToPlaylistSheet(song: song),
                      );
                    },
                  );
                },
              ),
              SizedBox(height: AppTheme.spacingLg),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSongTile(SongModel song, int index) {
    return ValueListenableBuilder<SongModel?>(
      valueListenable: SonoPlayer().currentSong,
      builder: (context, currentSong, child) {
        final bool isCurrentSong = currentSong?.id == song.id;

        final TextStyle titleStyle =
            isCurrentSong
                ? AppStyles.sonoPlayerTitle.copyWith(color: AppTheme.brandPink)
                : AppStyles.sonoPlayerTitle;

        final TextStyle artistStyle =
            isCurrentSong
                ? AppStyles.sonoPlayerArtist.copyWith(
                  color: AppTheme.brandPink.withAlpha((255 * 0.7).round()),
                )
                : AppStyles.sonoPlayerArtist;

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 24.0,
            vertical: 0.0,
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
          trailing: IconButton(
            icon: const Icon(
              Icons.more_vert_rounded,
              color: AppTheme.textSecondaryDark,
              size: 20,
            ),
            onPressed: () {
              _showSongOptionsBottomSheet(song);
            },
          ),
          onTap: () {
            final songIndex = _loadedSongs!.indexOf(song);
            if (songIndex != -1) {
              SonoPlayer().playNewPlaylist(
                _loadedSongs!,
                songIndex,
                context: "Album: ${widget.album.album}",
              );
            }
          },
        );
      },
    );
  }

  Widget _buildArtistAvatars() {
    final artists = ArtistStringUtils.splitArtists(
      widget.album.artist ?? 'Unknown',
    );
    final displayArtists = artists.take(2).toList();

    // Return empty if artists haven't loaded yet
    if (_artistLookup.isEmpty) {
      return const SizedBox(width: 24, height: 24);
    }

    return SizedBox(
      width: displayArtists.length == 1 ? 26 : 38,
      height: 26,
      child: Stack(
        children:
            displayArtists.asMap().entries.map((entry) {
              final index = entry.key;
              final artistName = entry.value;
              final artist = _artistLookup[artistName.toLowerCase()];
              final cachedArtwork =
                  artist != null ? _artistArtworkCache[artist.id] : null;

              return Positioned(
                left: index * 12.0,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: AppTheme.backgroundDark,
                      width: 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child:
                          cachedArtwork != null
                              ? Image.memory(
                                cachedArtwork,
                                width: 24,
                                height: 24,
                                fit: BoxFit.cover,
                                gaplessPlayback: true,
                              )
                              : Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade800,
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusMd,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.person_rounded,
                                  color: Colors.white54,
                                  size: 14,
                                ),
                              ),
                    ),
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }

  Widget _buildSongsList(List<SongModel> songs) {
    final widgets = <Widget>[];

    //first pass: check if there are multiple discs
    final discNumbers =
        songs.map((s) => s.discNumber ?? 1).toSet(); //default to disc 1 if null
    final hasMultipleDiscs = discNumbers.length > 1;

    int? previousDiscNumber;

    for (int index = 0; index < songs.length; index++) {
      final song = songs[index];
      final currentDiscNumber = song.discNumber ?? 1;

      //add disc separator when disc number changes
      if (hasMultipleDiscs && currentDiscNumber != previousDiscNumber) {
        widgets.add(
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: index == 0 ? 12.0 : 16.0,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Divider(
                    color: AppTheme.textSecondaryDark.withAlpha(
                      (255 * 0.3).round(),
                    ),
                    thickness: 1,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Text(
                    'Disc $currentDiscNumber',
                    style: TextStyle(
                      color: AppTheme.textSecondaryDark,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'VarelaRound',
                    ),
                  ),
                ),
                Expanded(
                  child: Divider(
                    color: AppTheme.textSecondaryDark.withAlpha(
                      (255 * 0.3).round(),
                    ),
                    thickness: 1,
                  ),
                ),
              ],
            ),
          ),
        );
        previousDiscNumber = currentDiscNumber;
      }

      widgets.add(_buildSongTile(song, index));
    }

    return Column(children: widgets);
  }

  @override
  Widget build(BuildContext context) {
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
            icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: SonoRefreshIndicator(
          onRefresh: _onRefresh,
          child: ListView(
            padding: const EdgeInsets.all(0),
            children: [
              //album artwork section
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 8.0,
                ),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Hero(
                    tag: 'album-artwork-${widget.album.id}',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      child: QueryArtworkWidget(
                        id: widget.album.id,
                        type: ArtworkType.ALBUM,
                        artworkFit: BoxFit.cover,
                        artworkQuality: FilterQuality.high,
                        artworkBorder: BorderRadius.zero,
                        size: 800,
                        nullArtworkWidget: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade800,
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusSm,
                            ),
                          ),
                          child: const Icon(
                            Icons.album_rounded,
                            color: Colors.white54,
                            size: 100,
                          ),
                        ),
                        keepOldArtwork: true,
                      ),
                    ),
                  ),
                ),
              ),

              //Album Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Text(
                  widget.album.album,
                  style: AppStyles.sonoPlayerTitle.copyWith(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.left,
                ),
              ),

              SizedBox(height: AppTheme.spacingXs),

              //artist profile pictures
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: InkWell(
                  onTap: _showArtistsModal,
                  child: Row(
                    children: [
                      _buildArtistAvatars(),
                      SizedBox(width: AppTheme.spacingXs),
                      Expanded(
                        child: Text(
                          ArtistStringUtils.getShortDisplay(
                            widget.album.artist ?? 'Unknown Artist',
                          ),
                          style: AppStyles.sonoPlayerArtist.copyWith(
                            fontSize: 16,
                            color: AppTheme.textSecondaryDark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: AppTheme.spacingXs),

              //song count + duration
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child:
                    _loadedSongs != null && _loadedSongs!.isNotEmpty
                        ? Text(
                          '${_loadedSongs!.length} songs • ${_formatDuration(_calculateAlbumDuration(_loadedSongs!))}',
                          style: AppStyles.sonoPlayerArtist.copyWith(
                            fontSize: 14,
                            color: Colors.white54,
                          ),
                        )
                        : Text(
                          '${widget.album.numOfSongs} songs',
                          style: AppStyles.sonoPlayerArtist.copyWith(
                            fontSize: 14,
                            color: Colors.white54,
                          ),
                        ),
              ),

              SizedBox(height: AppTheme.spacing),

              //action buttons row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Row(
                  children: [
                    //combined left buttons container
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
                          //favorite button
                          IconButton(
                            icon: Icon(
                              _isAlbumFavorite
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                              color:
                                  _isAlbumFavorite
                                      ? AppTheme.textPrimaryDark
                                      : AppTheme.textSecondaryDark,
                            ),
                            iconSize: 24,
                            onPressed: _toggleFavorite,
                          ),

                          //share/external link button
                          IconButton(
                            icon: const Icon(
                              Icons.open_in_new_rounded,
                              color: AppTheme.textSecondaryDark,
                            ),
                            iconSize: 24,
                            onPressed: _openLastFmLink,
                          ),

                          //three-dot menu button
                          IconButton(
                            icon: const Icon(
                              Icons.more_vert_rounded,
                              color: AppTheme.textSecondaryDark,
                            ),
                            iconSize: 24,
                            onPressed: _showAlbumOptionsBottomSheet,
                          ),
                        ],
                      ),
                    ),

                    const Spacer(),

                    //shuffle button
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
                                    context: "Album: ${widget.album.album}",
                                  );
                                }
                                : null,
                      ),
                    ),

                    SizedBox(width: AppTheme.spacingSm),

                    //play/pause button
                    ValueListenableBuilder<SongModel?>(
                      valueListenable: SonoPlayer().currentSong,
                      builder: (context, currentSong, _) {
                        return ValueListenableBuilder<String?>(
                          valueListenable: SonoPlayer().playbackContext,
                          builder: (context, playbackContext, _) {
                            final expectedContext =
                                "Album: ${widget.album.album}";
                            final isAlbumPlaying =
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
                                      (isAlbumPlaying && isPlaying)
                                          ? Icons.pause_rounded
                                          : Icons.play_arrow_rounded,
                                      color: Colors.white,
                                    ),
                                    iconSize: 24,
                                    onPressed:
                                        _loadedSongs != null &&
                                                _loadedSongs!.isNotEmpty
                                            ? () {
                                              if (isAlbumPlaying && isPlaying) {
                                                SonoPlayer().pause();
                                              } else if (isAlbumPlaying &&
                                                  !isPlaying) {
                                                SonoPlayer().play();
                                              } else {
                                                SonoPlayer().playNewPlaylist(
                                                  _loadedSongs!,
                                                  0,
                                                  context:
                                                      "Album: ${widget.album.album}",
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

              //song list
              FutureBuilder<List<SongModel>>(
                future: _songsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      _loadedSongs == null) {
                    //show skeleton while loading
                    return Column(
                      children: List.generate(
                        8,
                        (index) => _buildSongListSkeleton(),
                      ),
                    );
                  } else if (_loadedSongs != null) {
                    if (_loadedSongs!.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Text(
                            'No songs found in this album',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      );
                    }
                    return _buildSongsList(_loadedSongs!);
                  } else if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Text(
                          'Error loading songs: ${snapshot.error}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),

              //bottom padding for player
              const SizedBox(height: 120),
            ],
          ),
        ),
      ),
    );
  }
}