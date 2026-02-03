import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:shimmer/shimmer.dart';
import 'package:sono/services/utils/favorites_service.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:sono/utils/error_handler.dart';
import 'package:sono/utils/string_cleanup.dart';
import 'package:sono/widgets/player/sono_player.dart';
import 'package:sono/widgets/home/page_items.dart';
import 'package:sono/services/api/lastfm_service.dart';
import 'package:sono/styles/app_theme.dart';
import 'package:sono/styles/text.dart';
import 'package:sono/widgets/library/artist_artwork_widget.dart';
import 'package:sono/widgets/library/artist_picture_picker_dialog.dart';
import 'package:sono/services/artists/artist_profile_image_service.dart';
import 'package:sono/services/artists/artist_image_fetch_service.dart';
import 'package:sono/data/repositories/artists_repository.dart';
import 'package:sono/widgets/global/refresh_indicator.dart';
import 'package:provider/provider.dart';

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

  List<AlbumModel> _albums = [];
  List<AlbumModel> _singlesAndEps = [];
  List<AlbumModel> _appearsOn = [];
  List<SongModel> _allArtistSongs = [];

  bool _isLoading = true;
  Map<String, dynamic>? _artistInfo;
  bool _isLoadingArtistInfo = true;
  bool _bioExpanded = false;
  bool _isArtistFavorite = false;

  @override
  void initState() {
    super.initState();
    _loadArtistData();
    _fetchArtistInfo();
    _loadFavoriteStatus();
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
            backgroundColor: newUrl != null ? AppTheme.success : AppTheme.warning,
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

        // If didnt get all expected songs, the artist might appear in combined strings
        // Fall back to filtering all songs
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
          if (album.numOfSongs >= 7) {
            albums.add(album);
          } else {
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
          _singlesAndEps =
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
        floatingActionButton:
            _allArtistSongs.isNotEmpty
                ? FloatingActionButton.extended(
                  onPressed: () {
                    SonoPlayer().playNewPlaylist(
                      _allArtistSongs..shuffle(),
                      0,
                      context: "Artist: ${widget.artistName}",
                    );
                  },
                  label: Text(
                    "SHUFFLE",
                    style: AppStyles.sonoButtonTextSmaller.copyWith(
                      color: AppTheme.textPrimaryDark,
                    ),
                  ),
                  icon: const Icon(
                    Icons.shuffle_rounded,
                    color: AppTheme.textPrimaryDark,
                  ),
                  backgroundColor: AppTheme.brandPink,
                )
                : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        body: CustomScrollView(
          slivers: <Widget>[
            SonoSliverRefreshControl(onRefresh: _loadArtistData),
            SliverAppBar(
              expandedHeight: 300.0,
              floating: false,
              pinned: true,
              stretch: true,
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: AppTheme.textPrimaryDark,
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.edit_rounded),
                  color: AppTheme.textPrimaryDark,
                  iconSize: 24,
                  tooltip: "Edit Artist Picture",
                  onPressed: _openImagePicker,
                ),
                IconButton(
                  icon: Icon(
                    _isArtistFavorite
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                  ),
                  color:
                      _isArtistFavorite
                          ? Colors.amber
                          : AppTheme.textPrimaryDark,
                  iconSize: 28,
                  tooltip: "Favorite Artist",
                  onPressed: _toggleFavorite,
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                centerTitle: true,
                title: Text(
                  widget.artistName,
                  style: AppStyles.sonoPlayerTitle.copyWith(fontSize: 16),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
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
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black26,
                            Colors.black87,
                          ],
                          stops: [0.0, 0.5, 1.0],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.spacing,
                  AppTheme.spacingXl,
                  AppTheme.spacing,
                  AppTheme.spacingSm,
                ),
                child: GestureDetector(
                  onTap: () => _launchURL(_artistInfo?['url']),
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          widget.artistName,
                          style: AppStyles.sonoPlayerTitle.copyWith(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (_artistInfo?['url'] != null)
                        const Padding(
                          padding: EdgeInsets.only(left: AppTheme.spacingSm),
                          child: Icon(
                            Icons.open_in_new_rounded,
                            color: Colors.white54,
                            size: 16,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (_isLoading)
              _buildArtistPageSkeleton()
            else ...[
              _buildDiscographySection("Albums", _albums, 165, 110),
              _buildDiscographySection(
                "Singles & EPs",
                _singlesAndEps,
                165,
                110,
              ),
              _buildDiscographySection("Appears On", _appearsOn, 165, 110),
              _buildArtistInfoBox(),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
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
                    child: HomePageAlbumItem(
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

  Widget _buildArtistInfoBox() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing),
        child: Container(
          padding: const EdgeInsets.all(AppTheme.spacing),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(51),
            borderRadius: BorderRadius.circular(AppTheme.radius),
          ),
          child:
              _isLoadingArtistInfo
                  ? const Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.brandPink,
                      strokeWidth: 2.0,
                    ),
                  )
                  : _artistInfo == null
                  ? const SizedBox.shrink()
                  : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "About ${getPrimaryArtist(widget.artistName)}",
                        style: AppStyles.sonoPlayerTitle.copyWith(fontSize: 16),
                      ),
                      const SizedBox(height: AppTheme.spacing),
                      _buildStatsRow(),
                      const SizedBox(height: AppTheme.spacing),
                      _buildBioText(),
                    ],
                  ),
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    final stats = _artistInfo?['stats'];
    if (stats == null) return const SizedBox.shrink();

    final listeners = int.tryParse(stats['listeners']?.toString() ?? '0') ?? 0;
    final playcount = int.tryParse(stats['playcount']?.toString() ?? '0') ?? 0;

    if (listeners == 0 && playcount == 0) return const SizedBox.shrink();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStatItem(
          Icons.play_circle_fill_rounded,
          NumberFormat.compact().format(playcount),
          "Total Plays",
        ),
        _buildStatItem(
          Icons.people_alt_rounded,
          NumberFormat.compact().format(listeners),
          "Listeners",
        ),
      ],
    );
  }

  Widget _buildBioText() {
    final bio = _artistInfo?['bio'];
    if (bio == null) return const SizedBox.shrink();

    final bioSummary =
        bio['summary']?.toString().split(' <a href')[0] ??
        'No biography available.';
    if (bioSummary.isEmpty || bioSummary == 'No biography available.') {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          bioSummary,
          maxLines: _bioExpanded ? 100 : 3,
          overflow: TextOverflow.ellipsis,
          style: AppStyles.sonoPlayerArtist.copyWith(fontSize: 14, height: 1.5),
        ),
        if (bioSummary.length > 150)
          InkWell(
            onTap: () => setState(() => _bioExpanded = !_bioExpanded),
            child: Padding(
              padding: const EdgeInsets.only(top: AppTheme.spacingSm),
              child: Text(
                _bioExpanded ? "Show Less" : "Read More",
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.textSecondaryDark, size: 28),
        const SizedBox(height: AppTheme.spacingSm),
        Text(
          value,
          style: AppStyles.sonoPlayerTitle.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppTheme.spacingXs),
        Text(label, style: AppStyles.sonoPlayerArtist.copyWith(fontSize: 12)),
      ],
    );
  }
}