import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:shimmer/shimmer.dart';
import 'package:sono/services/utils/favorites_service.dart';
import 'package:sono/services/utils/artwork_cache_service.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:sono/utils/error_handler.dart';
import 'package:sono/utils/string_cleanup.dart';
import 'package:sono/widgets/player/sono_player.dart';
import 'package:sono/widgets/home/page_items.dart';
import 'package:sono/pages/library/album_page.dart';
import 'package:sono/widgets/global/add_to_playlist_dialog.dart';
import 'package:sono/services/api/lastfm_service.dart';
import 'package:sono/styles/app_theme.dart';
import 'package:sono/styles/text.dart';
import 'package:sono/widgets/library/artist_artwork_widget.dart';
import 'package:sono/widgets/library/artist_picture_picker_dialog.dart';
import 'package:sono/services/artists/artist_profile_image_service.dart';
import 'package:sono/services/artists/artist_image_fetch_service.dart';
import 'package:sono/data/repositories/artists_repository.dart';
import 'package:sono/data/repositories/artist_data_repository.dart';
import 'package:sono_refresh/sono_refresh.dart';
import 'package:sono/widgets/artist/popular_songs_section.dart';
import 'package:sono/widgets/artist/about_section.dart';
import 'package:sono/widgets/artist/about_modal.dart';
import 'package:sono/models/popular_song.dart';
import 'package:provider/provider.dart';
import 'package:sono/pages/library/artist_albums_page.dart';

class ArtistPage extends StatefulWidget {
  final ArtistModel artist;
  final OnAudioQuery audioQuery;

  const ArtistPage({super.key, required this.artist, required this.audioQuery});

  /// The artist name for display
  String get artistName => artist.artist;

  /// The MediaStore artist ID
  /// Note: Can be negative for split artists (e.g., from "Artist A, Artist B")
  int get artistId => artist.id;

  /// Whether this is a split artist (negative ID)
  bool get isSplitArtist => artist.id < 0;

  @override
  State<ArtistPage> createState() => _ArtistPageState();
}

class _ArtistPageState extends State<ArtistPage> {
  final LastfmService _lastfmService = LastfmService();
  final ArtistDataRepository _artistDataRepository = ArtistDataRepository();

  List<AlbumModel> _albums = [];
  List<AlbumModel> _singles = [];
  List<AlbumModel> _appearsOn = [];
  List<SongModel> _allArtistSongs = [];

  bool _isLoading = true;
  Map<String, dynamic>? _artistInfo;
  bool _isLoadingArtistInfo = true;
  bool _isArtistFavorite = false;

  //popular songs state
  List<PopularSong> _popularSongs = [];
  bool _isLoadingPopularSongs = true;
  String? _popularSongsError;
  int? _sonoMonthlyListeners;


  @override
  void initState() {
    super.initState();
    _loadArtistData().then((_) {
      //fetch popular songs AFTER library data loads so it can be matched
      if (mounted) {
        _fetchPopularSongs(forceRefresh: false);
      }
    });
    _fetchArtistInfo();
    _loadFavoriteStatus();
  }

  @override
  void dispose() {
    //clear any pending operations
    super.dispose();
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

  Widget _buildArtworkPlaceholder() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF444444), Color(0xFF333333)],
        ),
      ),
      child: const Center(
        child: Icon(Icons.person_rounded, color: Colors.white54, size: 100),
      ),
    );
  }

  Widget _buildHorizontalSkeletonLoader({
    required double itemWidth,
    required double itemHeight,
    required int itemCount,
  }) {
    return SizedBox(
      height: itemHeight,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: itemCount,
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing),
        physics: const NeverScrollableScrollPhysics(),
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: AppTheme.spacing),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSkeletonLoader(
                  width: itemWidth,
                  height: itemWidth,
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                ),
                const SizedBox(height: AppTheme.spacingSm),
                _buildSkeletonLoader(
                  width: itemWidth * 0.9,
                  height: 14,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                const SizedBox(height: 6),
                _buildSkeletonLoader(
                  width: itemWidth * 0.6,
                  height: 12,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildArtistPageSkeleton() {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              left: AppTheme.spacing,
              right: AppTheme.spacing,
              top: AppTheme.spacingXl,
              bottom: AppTheme.spacingMd,
            ),
            child: _buildSkeletonLoader(
              width: 120,
              height: 22,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
          ),
          _buildHorizontalSkeletonLoader(
            itemWidth: 110,
            itemHeight: 165,
            itemCount: 3,
          ),
          const SizedBox(height: AppTheme.spacing),
          Padding(
            padding: const EdgeInsets.only(
              left: AppTheme.spacing,
              right: AppTheme.spacing,
              top: AppTheme.spacingXl,
              bottom: AppTheme.spacingMd,
            ),
            child: _buildSkeletonLoader(
              width: 180,
              height: 22,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
          ),
          _buildHorizontalSkeletonLoader(
            itemWidth: 110,
            itemHeight: 165,
            itemCount: 2,
          ),
        ],
      ),
    );
  }

  Future<void> _loadFavoriteStatus() async {
    if (!mounted) return;
    final artistId = widget.artistId;
    final favoritesService = context.read<FavoritesService>();
    final isFavorite = await favoritesService.isArtistFavorite(artistId);
    if (mounted) {
      setState(() {
        _isArtistFavorite = isFavorite;
      });
    }
  }

  Future<void> _toggleFavorite() async {
    if (!mounted) return;
    final artistId = widget.artistId;
    final favoritesService = context.read<FavoritesService>();

    if (_isArtistFavorite) {
      await favoritesService.removeArtistFromFavorites(artistId);
    } else {
      await favoritesService.addArtistToFavorites(artistId, widget.artistName);
    }
    _loadFavoriteStatus();
  }

  Future<void> _openImagePicker() async {
    if (!mounted) return;

    final result = await showDialog<ArtistPictureResult>(
      context: context,
      builder:
          (context) => ArtistPicturePickerDialog(artistName: widget.artistName),
    );

    if (result != null && mounted) {
      if (result.remove) {
        await _removeArtistImage();
      } else if (result.refetch) {
        await _refetchArtistImage();
      } else if (result.imagePath != null) {
        await _saveArtistImage(result.imagePath!);
      }
    }
  }

  Future<void> _saveArtistImage(String path) async {
    try {
      final service = ArtistProfileImageService();
      final savedPath = await service.saveArtistImage(widget.artistName, path);

      //clear both metadata cache and flutter image cache for file
      await ArtistArtworkWidget.clearCacheForArtistWithFile(
        widget.artistName,
        savedPath,
      );

      if (mounted) {
        setState(() {}); //refresh to show new image
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Artist picture updated'),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
          ),
        );
      }
    } catch (e, stackTrace) {
      if (mounted) {
        ErrorHandler.showErrorSnackbar(
          context: context,
          message: 'Failed to save artist picture',
          error: e,
          stackTrace: stackTrace,
        );
      }
    }
  }

  Future<void> _removeArtistImage() async {
    try {
      final service = ArtistProfileImageService();

      //get file path before deleting so cache can get cleared
      final imageFile = await service.getArtistImageFile(widget.artistName);
      final filePath = imageFile?.path;

      await service.deleteArtistImage(widget.artistName);

      final repo = ArtistsRepository();
      await repo.removeCustomImage(widget.artistName);

      //clear both metadata cache and flutter image cache for file
      await ArtistArtworkWidget.clearCacheForArtistWithFile(
        widget.artistName,
        filePath,
      );

      if (mounted) {
        setState(() {}); //refresh to show fallback image
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Artist picture removed'),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
          ),
        );
      }
    } catch (e, stackTrace) {
      if (mounted) {
        ErrorHandler.showErrorSnackbar(
          context: context,
          message: 'Failed to remove artist picture',
          error: e,
          stackTrace: stackTrace,
        );
      }
    }
  }

  Future<void> _refetchArtistImage() async {
    try {
      final repo = ArtistsRepository();
      final fetchService = ArtistImageFetchService();

      //clear existing fetched image to allow refetch
      await repo.clearFetchedImageForArtist(widget.artistName);

      //clear the widget cache for this artist
      ArtistArtworkWidget.clearCacheForArtist(widget.artistName);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Fetching artist picture...'),
            backgroundColor: AppTheme.brandPink,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            duration: const Duration(seconds: 1),
          ),
        );
      }

      //fetch new image from API
      final newUrl = await fetchService.fetchArtistImage(widget.artistName);

      if (mounted) {
        //clear cache again to pick up new image
        ArtistArtworkWidget.clearCacheForArtist(widget.artistName);
        setState(() {}); //refresh UI

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newUrl != null
                  ? 'Artist picture updated'
                  : 'No picture found for this artist',
            ),
            backgroundColor:
                newUrl != null ? AppTheme.success : AppTheme.warning,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
          ),
        );
      }
    } catch (e, stackTrace) {
      if (mounted) {
        ErrorHandler.showErrorSnackbar(
          context: context,
          message: 'Failed to fetch artist picture',
          error: e,
          stackTrace: stackTrace,
        );
      }
    }
  }

  Future<void> _loadArtistData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      /// Query songs by artist
      /// The plugin has special handling for split artists (negative IDs),
      /// For regular artists => query by name to match how queryArtists() merges them
      if (widget.artist.id < 0) {
        //split artist with negative ID
        _allArtistSongs = await widget.audioQuery.queryAudiosFrom(
          AudiosFromType.ARTIST_ID,
          widget.artist.id,
        );
      } else {
        //regular artist => query by name
        _allArtistSongs = await widget.audioQuery.queryAudiosFrom(
          AudiosFromType.ARTIST,
          widget.artist.artist,
        );

        //if didnt get all expected songs, artist might appear in combined strings
        //fall back to filtering all songs
        final expectedTracks = widget.artist.numberOfTracks ?? 0;
        if (_allArtistSongs.length < expectedTracks && expectedTracks > 0) {
          debugPrint(
            'Artist ${widget.artist.artist}: Expected ${widget.artist.numberOfTracks} songs '
            'but only found ${_allArtistSongs.length}. Searching combined artist strings...',
          );

          final allSongs = await widget.audioQuery.querySongs();
          final artistNameLower = widget.artist.artist.toLowerCase().trim();

          //find songs where the artist field contains our artist name
          final Set<int?> existingSongIds =
              _allArtistSongs.map((s) => s.id).toSet();

          //common separators used in combined artist strings
          final separators = [
            ', ',
            ' feat. ',
            ' ft. ',
            ' featuring ',
            ' / ',
            '/',
            ' & ',
            ' and ',
            ' x ',
            ' X ',
          ];

          final additionalSongs =
              allSongs.where((song) {
                if (existingSongIds.contains(song.id)) return false;
                if (song.artist == null) return false;

                final songArtistLower = song.artist!.toLowerCase().trim();
                if (songArtistLower == artistNameLower) return true;

                //check if artist appears with separators
                for (final sep in separators) {
                  if (songArtistLower.startsWith('$artistNameLower$sep') ||
                      songArtistLower.endsWith('$sep$artistNameLower') ||
                      songArtistLower.contains('$sep$artistNameLower$sep')) {
                    return true;
                  }
                }
                return false;
              }).toList();

          _allArtistSongs = [..._allArtistSongs, ...additionalSongs];
          debugPrint(
            'Found ${additionalSongs.length} additional songs in combined strings. '
            'Total: ${_allArtistSongs.length}',
          );
        }
      }

      if (!mounted) return;

      final Set<int?> albumIds =
          _allArtistSongs.map((song) => song.albumId).toSet();
      albumIds.remove(null);

      if (albumIds.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final allAlbumsInLibrary = await widget.audioQuery.queryAlbums();
      final artistAlbums =
          allAlbumsInLibrary
              .where((album) => albumIds.contains(album.id))
              .toList();

      final albums = <AlbumModel>[];
      final singles = <AlbumModel>[];
      final appearsOn = <AlbumModel>[];

      for (final album in artistAlbums) {
        if (album.artist != null &&
            getPrimaryArtist(album.artist) !=
                getPrimaryArtist(widget.artistName)) {
          appearsOn.add(album);
        } else {
          //albums & EPs: 4+ songs ONLY, Singles: 1-3 songs
          if (album.numOfSongs >= 4) {
            albums.add(album);
          } else {
            //singles (1-3 songs)
            singles.add(album);
          }
        }
      }
      if (mounted) {
        setState(() {
          _albums =
              albums..sort(
                (a, b) =>
                    a.album.toLowerCase().compareTo(b.album.toLowerCase()),
              );
          _singles =
              singles..sort(
                (a, b) =>
                    a.album.toLowerCase().compareTo(b.album.toLowerCase()),
              );
          _appearsOn =
              appearsOn..sort(
                (a, b) =>
                    a.album.toLowerCase().compareTo(b.album.toLowerCase()),
              );
          _isLoading = false;
        });
      }
    } catch (e, s) {
      if (mounted) {
        ErrorHandler.showErrorSnackbar(
          context: context,
          message: "Failed to load artist's discography from your library.",
          error: e,
          stackTrace: s,
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchArtistInfo() async {
    if (!mounted) return;
    setState(() => _isLoadingArtistInfo = true);
    try {
      final primaryArtist = getPrimaryArtist(widget.artistName);
      final info = await _lastfmService.getArtistInfo(primaryArtist);
      if (mounted) {
        setState(() => _artistInfo = info);
      }
    } catch (e, s) {
      if (mounted) {
        ErrorHandler.showErrorSnackbar(
          context: context,
          message: 'Could not load artist info from Last.fm.',
          error: e,
          stackTrace: s,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingArtistInfo = false);
      }
    }
  }

  Future<void> _fetchPopularSongs({bool forceRefresh = false}) async {
    if (!mounted) return;
    setState(() {
      _isLoadingPopularSongs = true;
      _popularSongsError = null;
    });

    try {
      final primaryArtist = getPrimaryArtist(widget.artistName);
      debugPrint('ArtistPage: Fetching popular songs for: $primaryArtist (forceRefresh: $forceRefresh)');

      final artistData = await _artistDataRepository.getArtistData(
        primaryArtist,
        forceRefresh: forceRefresh,
      );

      if (artistData != null && mounted) {
        debugPrint('ArtistPage: Got ${artistData.topSongs.length} songs from API');
        debugPrint('ArtistPage: Monthly listeners: ${artistData.monthlyListeners}');

        //check if cache is corrupted (empty songs or empty titles)
        final hasValidSongs = artistData.topSongs.any((song) => song.title.isNotEmpty);

        //if cache returned 0 songs or corrupted data => force refresh
        if (!forceRefresh && (artistData.topSongs.isEmpty || !hasValidSongs)) {
          debugPrint('ArtistPage: Cache has invalid data (${artistData.topSongs.length} songs, valid: $hasValidSongs), forcing fresh fetch');
          return _fetchPopularSongs(forceRefresh: true);
        }

        //match popular songs with library
        final matchedSongs = await _artistDataRepository.matchSongsWithLibrary(
          artistData.topSongs,
          _allArtistSongs,
        );

        debugPrint('ArtistPage: Matched ${matchedSongs.length} songs with library');
        debugPrint('ArtistPage: Songs in library: ${matchedSongs.where((s) => s.isInLibrary).length}');

        //validate matched songs have proper data
        final validSongs = matchedSongs.where((song) {
          if (song.title.isEmpty) {
            debugPrint('ArtistPage: WARNING - Song with empty title: ${song.toJson()}');
            return false;
          }
          return true;
        }).toList();

        if (validSongs.length != matchedSongs.length) {
          debugPrint('ArtistPage: Filtered out ${matchedSongs.length - validSongs.length} songs with empty titles');
        }

        setState(() {
          _popularSongs = validSongs;
          _sonoMonthlyListeners = artistData.monthlyListeners;
          _isLoadingPopularSongs = false;
        });
      } else if (mounted) {
        debugPrint('ArtistPage: No artist data returned from API');
        setState(() {
          _popularSongs = [];
          _sonoMonthlyListeners = null;
          _isLoadingPopularSongs = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('ArtistPage: Error fetching popular songs: $e');
      debugPrint('ArtistPage: Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _popularSongsError = e.toString();
          _isLoadingPopularSongs = false;
        });
      }
    }
  }

  /// Builds a playlist starting with popular songs in library order,
  /// followed by all remaining artist songs in random order.
  List<SongModel> _buildArtistPlaylist() {
    final popularLocalSongs = _popularSongs
        .where((s) => s.localSong != null)
        .take(5)
        .map((s) => s.localSong!)
        .toList();
    final popularIds = popularLocalSongs.map((s) => s.id).toSet();
    final remainingSongs = List<SongModel>.from(
      _allArtistSongs.where((s) => !popularIds.contains(s.id)),
    )..shuffle();
    return [...popularLocalSongs, ...remainingSongs];
  }

  void _onPopularSongTap(PopularSong song) {
    if (song.localSong != null) {
      //find index in all artist songs
      final index = _allArtistSongs.indexWhere((s) => s.id == song.localSong!.id);
      if (index >= 0) {
        SonoPlayer().playNewPlaylist(
          _allArtistSongs,
          index,
          context: "Artist: ${widget.artistName}",
        );
      } else {
        //fallback: play just this song
        SonoPlayer().playNewPlaylist(
          [song.localSong!],
          0,
          context: "Artist: ${widget.artistName}",
        );
      }
    }
  }

  void _showPopularSongOptions(PopularSong song) {
    if (song.localSong == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A1A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              //drag handle
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[700],
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              //song header with artwork
              ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 50,
                    height: 50,
                    child: FutureBuilder<Uint8List?>(
                      future: ArtworkCacheService.instance.getArtwork(
                        song.localSong!.id,
                        size: 150,
                      ),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.done &&
                            snapshot.hasData &&
                            snapshot.data != null) {
                          return Image.memory(
                            snapshot.data!,
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                            cacheWidth: 150,
                            cacheHeight: 150,
                          );
                        }
                        return Container(
                          width: 50,
                          height: 50,
                          color: Colors.grey.shade800,
                          child: const Icon(
                            Icons.music_note_rounded,
                            color: Colors.white70,
                            size: 24,
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
                  song.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppStyles.sonoPlayerArtist,
                ),
              ),
              const Divider(color: Colors.white24, indent: 20, endIndent: 20),
              //play next
              ListTile(
                leading: const Icon(
                  Icons.playlist_play_rounded,
                  color: Colors.white70,
                ),
                title: const Text(
                  'Play next',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                onTap: () {
                  Navigator.pop(context);
                  SonoPlayer().addSongToPlayNext(song.localSong!);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Added to play next'),
                      backgroundColor: AppTheme.success,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                    ),
                  );
                },
              ),
              //add to queue
              ListTile(
                leading: const Icon(
                  Icons.queue_music_rounded,
                  color: Colors.white70,
                ),
                title: const Text(
                  'Add to queue',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                onTap: () {
                  Navigator.pop(context);
                  SonoPlayer().addSongsToQueue([song.localSong!]);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Added to queue'),
                      backgroundColor: AppTheme.success,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                    ),
                  );
                },
              ),
              //add to playlist
              ListTile(
                leading: const Icon(
                  Icons.playlist_add_rounded,
                  color: Colors.white70,
                ),
                title: const Text(
                  'Add to playlist...',
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
                        child: AddToPlaylistSheet(song: song.localSong!),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  void _showAboutModalSheet() {
    final bio = _artistInfo?['bio']?['content']?.toString() ?? '';
    if (bio.isEmpty) return;

    final stats = _artistInfo?['stats'];
    final playcount = stats != null
        ? int.tryParse(stats['playcount']?.toString() ?? '0')
        : null;

    AboutModal.show(
      context,
      artistName: getPrimaryArtist(widget.artistName),
      bio: bio,
      monthlyListeners: _sonoMonthlyListeners,
      totalPlays: playcount,
      artistUrl: _artistInfo?['url'],
    );
  }

  void _openLastFmLink() {
    _launchURL(_artistInfo?['url']);
  }

  Future<void> _launchURL(String? urlString) async {
    if (urlString == null) return;
    final Uri url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      debugPrint('Could not launch $url');
    }
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
        body: SonoRefreshIndicator(
          onRefresh: () async {
            await _loadArtistData();
            await _fetchPopularSongs(forceRefresh: true);
            await _fetchArtistInfo();
          },
          logo: Image.asset(
            'assets/images/logos/favicon-white.png',
            width: 28,
            height: 28,
            color: AppTheme.backgroundLight,
            colorBlendMode: BlendMode.srcIn,
          ),
          indicatorColor: AppTheme.elevatedSurfaceDark,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: <Widget>[
              SliverAppBar(
              expandedHeight: 280.0,
              floating: false,
              pinned: true,
              stretch: true,
              backgroundColor: AppTheme.backgroundDark,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: AppTheme.textPrimaryDark,
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
              flexibleSpace: LayoutBuilder(
                builder: (context, constraints) {
                  //calculate collapse ratio: 1.0 = expanded, 0.0 = collapsed
                  final expandRatio = ((constraints.maxHeight - kToolbarHeight) /
                      (280.0 - kToolbarHeight)).clamp(0.0, 1.0);

                  //crossfade: big title fades out while collapsed title fades in
                  final bigTitleOpacity = ((expandRatio - 0.3) / 0.3).clamp(0.0, 1.0);
                  final collapsedTitleOpacity = ((0.7 - expandRatio) / 0.2).clamp(0.0, 1.0);

                  return FlexibleSpaceBar(
                    title: expandRatio < 0.7
                        ? Opacity(
                            opacity: collapsedTitleOpacity,
                            child: Text(
                              widget.artistName,
                              style: const TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                color: AppTheme.textPrimaryDark,
                                fontSize: AppTheme.fontTitle,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        : null,
                    titlePadding: const EdgeInsets.only(left: 56, bottom: 16),
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        Hero(
                          tag: 'artist-artwork-${widget.artistId}',
                          child: ArtistArtworkWidget(
                            artistName: widget.artistName,
                            artistId: widget.artistId,
                            fit: BoxFit.cover,
                            placeholderWidget: _buildArtworkPlaceholder(),
                          ),
                        ),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.3),
                                Colors.black.withValues(alpha: 0.7),
                                AppTheme.backgroundDark,
                              ],
                              stops: [0.0, 0.7, 1.0],
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: AppTheme.spacing,
                          left: AppTheme.spacing,
                          right: AppTheme.spacing,
                          child: Opacity(
                            opacity: bigTitleOpacity,
                            child: Text(
                              widget.artistName,
                              style: const TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                color: AppTheme.textPrimaryDark,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            //actions row
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacing,
                  vertical: AppTheme.spacingMd,
                ),
                child: _buildActionsRow(),
              ),
            ),
            //popular songs section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: AppTheme.spacing),
                child: PopularSongsSection(
                  songs: _popularSongs,
                  isLoading: _isLoadingPopularSongs,
                  errorMessage: _popularSongsError,
                  onSongTap: _onPopularSongTap,
                  onMoreTap: _showPopularSongOptions,
                ),
              ),
            ),
            if (_isLoading)
              _buildArtistPageSkeleton()
            else ...[
              _buildAlbumsSection(),
              _buildDiscographySection("Singles", _singles, 165, 110),
              _buildDiscographySection("Appears On", _appearsOn, 165, 110),
              _buildAboutSection(),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionsRow() {
    return Row(
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
                  _isArtistFavorite
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  color:
                      _isArtistFavorite
                          ? AppTheme.textPrimaryDark
                          : AppTheme.textSecondaryDark,
                ),
                iconSize: 24,
                onPressed: _toggleFavorite,
              ),

              //external link button (Last.fm)
              IconButton(
                icon: const Icon(
                  Icons.open_in_new_rounded,
                  color: AppTheme.textSecondaryDark,
                ),
                iconSize: 24,
                onPressed: _artistInfo?['url'] != null ? _openLastFmLink : null,
              ),

              //three-dot menu button
              IconButton(
                icon: const Icon(
                  Icons.more_vert_rounded,
                  color: AppTheme.textSecondaryDark,
                ),
                iconSize: 24,
                onPressed: _showArtistOptionsBottomSheet,
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
                _allArtistSongs.isNotEmpty
                    ? () {
                      final shuffledSongs = List<SongModel>.from(
                        _allArtistSongs,
                      )..shuffle();
                      SonoPlayer().playNewPlaylist(
                        shuffledSongs,
                        0,
                        context: "Artist: ${widget.artistName}",
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
                final expectedContext = "Artist: ${widget.artistName}";
                final isArtistPlaying =
                    playbackContext == expectedContext &&
                    (_allArtistSongs.any(
                          (song) => song.id == currentSong?.id,
                        ));

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
                          (isArtistPlaying && isPlaying)
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.white,
                        ),
                        iconSize: 24,
                        onPressed:
                            _allArtistSongs.isNotEmpty
                                ? () {
                                  if (isArtistPlaying && isPlaying) {
                                    SonoPlayer().pause();
                                  } else if (isArtistPlaying && !isPlaying) {
                                    SonoPlayer().play();
                                  } else {
                                    SonoPlayer().playNewPlaylist(
                                      _buildArtistPlaylist(),
                                      0,
                                      context: "Artist: ${widget.artistName}",
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
    );
  }

  void _showArtistOptionsBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bottomSheetBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              //drag handle
              Container(
                width: 40,
                height: 5,
                margin: const EdgeInsets.only(top: 12, bottom: 16),
                decoration: BoxDecoration(
                  color: AppTheme.textTertiaryDark,
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
              //add all to queue
              ListTile(
                leading: const Icon(
                  Icons.queue_music_rounded,
                  color: AppTheme.textPrimaryDark,
                ),
                title: const Text(
                  'Add all to queue',
                  style: TextStyle(color: AppTheme.textPrimaryDark),
                ),
                onTap: () {
                  Navigator.pop(context);
                  if (_allArtistSongs.isNotEmpty) {
                    SonoPlayer().addSongsToQueue(_allArtistSongs);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Added ${_allArtistSongs.length} songs to queue',
                        ),
                        backgroundColor: AppTheme.success,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        ),
                      ),
                    );
                  }
                },
              ),
              //edit artist picture
              ListTile(
                leading: const Icon(
                  Icons.image_rounded,
                  color: AppTheme.textPrimaryDark,
                ),
                title: const Text(
                  'Edit artist picture',
                  style: TextStyle(color: AppTheme.textPrimaryDark),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _openImagePicker();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAlbumsSection() {
    if (_albums.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              left: AppTheme.spacing,
              right: AppTheme.spacing,
              top: AppTheme.spacingXl,
              bottom: AppTheme.spacingMd,
            ),
            child: Text(
              'Albums & EPs',
              style: AppStyles.sonoButtonText.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          //show only first 2 albums
          ..._albums.take(2).map(
            (album) => Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacing,
                vertical: AppTheme.spacingSm,
              ),
              child: InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => AlbumPage(
                        album: album,
                        audioQuery: widget.audioQuery,
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                child: Row(
                  children: [
                    //album artwork
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      child: SizedBox(
                        width: 80,
                        height: 80,
                        child: QueryArtworkWidget(
                          id: album.id,
                          type: ArtworkType.ALBUM,
                          nullArtworkWidget: Container(
                            color: AppTheme.elevatedSurfaceDark,
                            child: const Center(
                              child: Icon(
                                Icons.album_rounded,
                                color: AppTheme.textTertiaryDark,
                                size: 32,
                              ),
                            ),
                          ),
                          artworkFit: BoxFit.cover,
                          artworkBorder: BorderRadius.zero,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingMd),
                    //album info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            album.album,
                            style: const TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              color: AppTheme.textPrimaryDark,
                              fontSize: AppTheme.font,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Album',
                            style: const TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              color: AppTheme.textSecondaryDark,
                              fontSize: AppTheme.fontSm,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          //show all button if more than 2
          if (_albums.length > 2)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacing,
                vertical: AppTheme.spacingSm,
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => ArtistAlbumsPage(
                          artistName: widget.artistName,
                          albums: _albums,
                          eps: _singles,
                          audioQuery: widget.audioQuery,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.elevatedSurfaceDark,
                    foregroundColor: AppTheme.textPrimaryDark,
                    elevation: 0,
                    side: const BorderSide(
                      color: Color(0xFF3d3d3d),
                      width: 1,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'Show all',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.fontBody,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAboutSection() {
    final stats = _artistInfo?['stats'];
    final playcount = stats != null
        ? int.tryParse(stats['playcount']?.toString() ?? '0')
        : null;
    final bio = _artistInfo?['bio']?['content']?.toString();

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(top: AppTheme.spacing),
        child: AboutSection(
          bio: bio,
          monthlyListeners: _sonoMonthlyListeners,
          totalPlays: playcount,
          artistUrl: _artistInfo?['url'],
          isLoading: _isLoadingArtistInfo,
          onViewMore: _showAboutModalSheet,
          onLinkTap: _openLastFmLink,
        ),
      ),
    );
  }

  Widget _buildDiscographySection(
    String title,
    List<AlbumModel> albums,
    double listHeight,
    double itemWidth,
  ) {
    if (albums.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              left: AppTheme.spacing,
              right: AppTheme.spacing,
              top: AppTheme.spacingXl,
              bottom: AppTheme.spacingMd,
            ),
            child: Text(
              title,
              style: AppStyles.sonoButtonText.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(
            height: listHeight,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing),
              itemCount: albums.length,
              itemBuilder: (context, index) {
                final album = albums[index];
                return Padding(
                  padding: const EdgeInsets.only(right: AppTheme.spacing),
                  child: SizedBox(
                    width: itemWidth,
                    child: album.numOfSongs == 1 && title == "Singles"
                        ? _buildSingleSongItem(album, itemWidth)
                        : HomePageAlbumItem(
                            album: album,
                            audioQuery: widget.audioQuery,
                            artworkSize: itemWidth,
                          ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSingleSongItem(AlbumModel album, double artworkSize) {
    return FutureBuilder<List<SongModel>>(
      future: widget.audioQuery.queryAudiosFrom(
        AudiosFromType.ALBUM_ID,
        album.id,
      ),
      builder: (context, snapshot) {
        final songName = snapshot.hasData && snapshot.data!.isNotEmpty
            ? snapshot.data!.first.title
            : album.album;

        return InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AlbumPage(album: album, audioQuery: widget.audioQuery),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radius),
                child: SizedBox(
                  width: artworkSize,
                  height: artworkSize,
                  child: QueryArtworkWidget(
                    id: album.id,
                    type: ArtworkType.ALBUM,
                    artworkFit: BoxFit.cover,
                    artworkBorder: BorderRadius.circular(AppTheme.radius),
                    keepOldArtwork: true,
                    nullArtworkWidget: Container(
                      width: artworkSize,
                      height: artworkSize,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade800,
                        borderRadius: BorderRadius.circular(AppTheme.radius),
                      ),
                      child: const Icon(
                        Icons.music_note_rounded,
                        color: Colors.white54,
                        size: 40,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                songName,
                style: AppStyles.sonoPlayerTitle.copyWith(fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                'Single',
                style: AppStyles.sonoPlayerArtist.copyWith(fontSize: 10),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }
}
