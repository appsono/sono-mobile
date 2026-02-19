import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:sono/data/models/remote_models.dart';
import 'package:sono/data/repositories/artist_data_repository.dart';
import 'package:sono/pages/servers/album_page.dart';
import 'package:sono/services/api/lastfm_service.dart';
import 'package:sono/services/artists/artist_image_fetch_service.dart';
import 'package:sono/services/servers/server_protocol.dart';
import 'package:sono/styles/app_theme.dart';
import 'package:sono/styles/text.dart';
import 'package:sono/widgets/artist/about_modal.dart';
import 'package:sono/widgets/artist/about_section.dart';
import 'package:sono/widgets/artist/page_skeletons.dart';
import 'package:sono/widgets/player/sono_player.dart';
import 'package:sono/widgets/servers/remote_artwork.dart';
import 'package:url_launcher/url_launcher.dart';

class RemoteArtistPage extends StatefulWidget {
  final RemoteArtist artist;
  final MusicServerProtocol protocol;

  const RemoteArtistPage({
    super.key,
    required this.artist,
    required this.protocol,
  });

  @override
  State<RemoteArtistPage> createState() => _RemoteArtistPageState();
}

class _RemoteArtistPageState extends State<RemoteArtistPage> {
  /// Albums
  List<RemoteAlbum>? _albums;
  bool _isLoading = true;
  String? _error;
  bool _showAllAlbums = false;

  /// Top songs
  List<RemoteSong>? _topSongs;
  List<SongModel>? _topSongModels;
  bool _isLoadingTopSongs = true;

  /// Artist metadata (Last.fm + Kworb)
  Map<String, dynamic>? _lastfmInfo;
  bool _isLoadingArtistInfo = true;
  int? _monthlyListeners;

  /// Artist image
  String? _artistImageUrl;

  /// Star state
  bool _isStarred = false;
  final Set<String> _starredSongIds = {};
  Timer? _starRefreshTimer;
  static const Duration _starRefreshInterval = Duration(seconds: 5);

  /// All songs for shuffle/play all
  List<SongModel> _allArtistSongModels = [];

  @override
  void initState() {
    super.initState();
    _isStarred = widget.artist.starred;
    _loadAlbums();
    _loadTopSongs();
    _loadArtistMetadata();
    _startStarRefresh();
  }

  @override
  void dispose() {
    _starRefreshTimer?.cancel();
    super.dispose();
  }

  void _startStarRefresh() {
    if (_starRefreshTimer?.isActive ?? false) return;
    _starRefreshTimer = Timer.periodic(
      _starRefreshInterval,
      (_) => _refreshStarStates(),
    );
  }

  Future<void> _refreshStarStates() async {
    if (!mounted) return;
    try {
      final results = await Future.wait([
        widget.protocol.getArtist(widget.artist.id),
        widget.protocol.getTopSongs(widget.artist.name),
      ]);
      if (!mounted) return;
      final artist = results[0] as RemoteArtist?;
      final songs = results[1] as List<RemoteSong>;
      setState(() {
        if (artist != null) _isStarred = artist.starred;
        _starredSongIds
          ..clear()
          ..addAll(songs.where((s) => s.starred).map((s) => s.id));
      });
    } catch (_) {}
  }

  Future<void> _loadAlbums() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final albums = await widget.protocol.getArtistAlbums(widget.artist.id);
      if (mounted) {
        setState(() {
          _albums = albums;
          _isLoading = false;
        });
        _loadAllArtistSongs();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadAllArtistSongs() async {
    if (_albums == null || _albums!.isEmpty) return;

    final allSongs = <SongModel>[];
    for (final album in _albums!) {
      try {
        final songs = await widget.protocol.getAlbumSongs(album.id);
        allSongs.addAll(
          songs.map(
            (s) => s.toSongModel(
              widget.protocol.getStreamUrl(s.id),
              coverArtUrl:
                  s.coverArtId != null
                      ? widget.protocol.getCoverArtUrl(s.coverArtId!, size: 600)
                      : null,
            ),
          ),
        );
      } catch (_) {}
    }
    if (mounted) {
      setState(() => _allArtistSongModels = allSongs);
    }
  }

  Future<void> _loadTopSongs() async {
    setState(() => _isLoadingTopSongs = true);
    try {
      final songs = await widget.protocol.getTopSongs(widget.artist.name);
      if (mounted) {
        setState(() {
          _topSongs = songs;
          _topSongModels =
              songs
                  .map(
                    (s) => s.toSongModel(
                      widget.protocol.getStreamUrl(s.id),
                      coverArtUrl:
                          s.coverArtId != null
                              ? widget.protocol.getCoverArtUrl(
                                s.coverArtId!,
                                size: 600,
                              )
                              : null,
                    ),
                  )
                  .toList();
          _starredSongIds.addAll(
            songs.where((s) => s.starred).map((s) => s.id),
          );
          _isLoadingTopSongs = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingTopSongs = false);
      }
    }
  }

  Future<void> _loadArtistMetadata() async {
    setState(() => _isLoadingArtistInfo = true);
    try {
      final results = await Future.wait([
        ArtistImageFetchService().fetchArtistImage(widget.artist.name),
        LastfmService().getArtistInfo(widget.artist.name),
        ArtistDataRepository().getArtistData(widget.artist.name),
      ]);

      final imageUrl = results[0] as String?;
      final lastfmInfo = results[1] as Map<String, dynamic>?;
      final artistData = results[2] as ArtistData?;

      if (mounted) {
        setState(() {
          _artistImageUrl = imageUrl;
          _lastfmInfo = lastfmInfo;
          _monthlyListeners = artistData?.monthlyListeners;
          _isLoadingArtistInfo = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingArtistInfo = false);
      }
    }
  }

  Future<void> _toggleStar() async {
    final wasStarred = _isStarred;
    setState(() => _isStarred = !_isStarred);
    try {
      if (wasStarred) {
        await widget.protocol.unstar(artistId: widget.artist.id);
      } else {
        await widget.protocol.star(artistId: widget.artist.id);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isStarred = wasStarred);
      }
    }
  }

  Future<void> _toggleSongStar(RemoteSong song) async {
    final wasStarred = _starredSongIds.contains(song.id);
    setState(() {
      if (wasStarred) {
        _starredSongIds.remove(song.id);
      } else {
        _starredSongIds.add(song.id);
      }
    });
    try {
      if (wasStarred) {
        await widget.protocol.unstar(id: song.id);
      } else {
        await widget.protocol.star(id: song.id);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (wasStarred) {
            _starredSongIds.add(song.id);
          } else {
            _starredSongIds.remove(song.id);
          }
        });
      }
    }
  }

  void _openLastFmLink() {
    final url = _lastfmInfo?['url'] as String?;
    if (url != null) {
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  void _showAboutModal() {
    final bio = _lastfmInfo?['bio']?['content']?.toString() ?? '';
    if (bio.isEmpty) return;

    final stats = _lastfmInfo?['stats'];
    final playcount =
        stats != null
            ? int.tryParse(stats['playcount']?.toString() ?? '0')
            : null;

    AboutModal.show(
      context,
      artistName: widget.artist.name,
      bio: bio,
      monthlyListeners: _monthlyListeners,
      totalPlays: playcount,
      artistUrl: _lastfmInfo?['url'],
    );
  }

  void _showArtistOptionsBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder:
          (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.textTertiaryDark,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(
                    Icons.refresh_rounded,
                    color: AppTheme.textSecondaryDark,
                  ),
                  title: const Text(
                    'Refresh artist data',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      color: AppTheme.textPrimaryDark,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _refreshAllData();
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.playlist_add_rounded,
                    color: AppTheme.textSecondaryDark,
                  ),
                  title: const Text(
                    'Add all to queue',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      color: AppTheme.textPrimaryDark,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    if (_allArtistSongModels.isNotEmpty) {
                      SonoPlayer().addSongsToQueue(_allArtistSongModels);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Added ${_allArtistSongModels.length} songs to queue',
                          ),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
    );
  }

  Future<void> _refreshAllData() async {
    await Future.wait([_loadAlbums(), _loadTopSongs(), _loadArtistMetadata()]);
  }

  void _showTopSongOptions(RemoteSong song, int index) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder:
          (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.textTertiaryDark,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacing,
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                        child: SizedBox(
                          width: 48,
                          height: 48,
                          child: RemoteArtwork(
                            coverArtId: song.coverArtId,
                            protocol: widget.protocol,
                            size: 48,
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusSm,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppTheme.spacingMd),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              song.title,
                              style: const TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                color: AppTheme.textPrimaryDark,
                                fontSize: AppTheme.font,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (song.artist != null)
                              Text(
                                song.artist!,
                                style: const TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  color: AppTheme.textSecondaryDark,
                                  fontSize: AppTheme.fontSm,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Divider(color: Color(0xFF3d3d3d)),
                ListTile(
                  leading: Icon(
                    _starredSongIds.contains(song.id)
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color:
                        _starredSongIds.contains(song.id)
                            ? AppTheme.textPrimaryDark
                            : AppTheme.textSecondaryDark,
                  ),
                  title: Text(
                    _starredSongIds.contains(song.id) ? 'Unstar' : 'Star',
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      color: AppTheme.textPrimaryDark,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _toggleSongStar(song);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.playlist_play_rounded,
                    color: AppTheme.textSecondaryDark,
                  ),
                  title: const Text(
                    'Play next',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      color: AppTheme.textPrimaryDark,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    if (_topSongModels != null &&
                        index < _topSongModels!.length) {
                      SonoPlayer().addSongToPlayNext(_topSongModels![index]);
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.queue_music_rounded,
                    color: AppTheme.textSecondaryDark,
                  ),
                  title: const Text(
                    'Add to queue',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      color: AppTheme.textPrimaryDark,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    if (_topSongModels != null &&
                        index < _topSongModels!.length) {
                      SonoPlayer().addSongsToQueue([_topSongModels![index]]);
                    }
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
    );
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
        body: RefreshIndicator(
          onRefresh: _refreshAllData,
          color: AppTheme.brandPink,
          backgroundColor: AppTheme.cardDark,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              _buildSliverAppBar(),
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
              //top songs
              SliverToBoxAdapter(child: _buildTopSongsSection()),
              //albums content
              if (_isLoading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                SliverFillRemaining(child: _buildError())
              else if (_albums != null && _albums!.isNotEmpty) ...[
                SliverToBoxAdapter(child: _buildDiscographyCarousel()),
                SliverToBoxAdapter(child: _buildAlbumsListSection()),
              ] else
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        'No albums found',
                        style: TextStyle(
                          color: AppTheme.textSecondaryDark,
                          fontSize: AppTheme.font,
                          fontFamily: AppTheme.fontFamily,
                        ),
                      ),
                    ),
                  ),
                ),
              //about section
              SliverToBoxAdapter(child: _buildAboutSection()),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: MediaQuery.of(context).padding.bottom + 100,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
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
          final expandRatio = ((constraints.maxHeight - kToolbarHeight) /
                  (280.0 - kToolbarHeight))
              .clamp(0.0, 1.0);

          final bigTitleOpacity = ((expandRatio - 0.3) / 0.3).clamp(0.0, 1.0);
          final collapsedTitleOpacity = ((0.7 - expandRatio) / 0.2).clamp(
            0.0,
            1.0,
          );

          return FlexibleSpaceBar(
            title:
                expandRatio < 0.7
                    ? Opacity(
                      opacity: collapsedTitleOpacity,
                      child: Text(
                        widget.artist.name,
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
                _buildHeaderImage(),
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
                      stops: const [0.0, 0.7, 1.0],
                    ),
                  ),
                ),
                Positioned(
                  bottom: AppTheme.spacing,
                  left: AppTheme.spacing,
                  right: AppTheme.spacing,
                  child: Opacity(
                    opacity: bigTitleOpacity,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.artist.name,
                          style: const TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            color: AppTheme.textPrimaryDark,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_albums?.length ?? widget.artist.albumCount} album${(_albums?.length ?? widget.artist.albumCount) == 1 ? '' : 's'}',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            color: AppTheme.textSecondaryDark,
                            fontSize: AppTheme.fontBody,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeaderImage() {
    if (_artistImageUrl != null) {
      return CachedNetworkImage(
        imageUrl: _artistImageUrl!,
        fit: BoxFit.cover,
        placeholder: (context, url) => _buildFallbackArtwork(),
        errorWidget: (context, url, error) => _buildFallbackArtwork(),
      );
    }
    return _buildFallbackArtwork();
  }

  Widget _buildFallbackArtwork() {
    return RemoteArtwork(
      coverArtId: widget.artist.coverArtId,
      protocol: widget.protocol,
      size: 400,
      borderRadius: BorderRadius.zero,
      fallbackIcon: Icons.person_rounded,
    );
  }

  Widget _buildActionsRow() {
    return Row(
      children: [
        //left buttons container
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: AppTheme.elevatedSurfaceDark,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: const Color(0xFF3d3d3d), width: 1),
          ),
          child: Row(
            children: [
              //star button
              IconButton(
                icon: Icon(
                  _isStarred ? Icons.star_rounded : Icons.star_border_rounded,
                  color:
                      _isStarred
                          ? AppTheme.textPrimaryDark
                          : AppTheme.textSecondaryDark,
                ),
                iconSize: 24,
                onPressed: _toggleStar,
              ),
              //last.fm link
              IconButton(
                icon: const Icon(
                  Icons.open_in_new_rounded,
                  color: AppTheme.textSecondaryDark,
                ),
                iconSize: 24,
                onPressed: _lastfmInfo?['url'] != null ? _openLastFmLink : null,
              ),
              //more options
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
            border: Border.all(color: const Color(0xFF3d3d3d), width: 1),
          ),
          child: IconButton(
            icon: const Icon(
              Icons.shuffle_rounded,
              color: AppTheme.textSecondaryDark,
            ),
            iconSize: 24,
            onPressed:
                _allArtistSongModels.isNotEmpty
                    ? () {
                      final shuffled = List<SongModel>.from(
                        _allArtistSongModels,
                      )..shuffle();
                      SonoPlayer().playNewPlaylist(
                        shuffled,
                        0,
                        context: "Artist: ${widget.artist.name}",
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
                final expectedContext = "Artist: ${widget.artist.name}";
                final isArtistPlaying =
                    playbackContext == expectedContext &&
                    _allArtistSongModels.any(
                      (song) => song.id == currentSong?.id,
                    );

                return Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.brandPink,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
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
                            _allArtistSongModels.isNotEmpty
                                ? () {
                                  if (isArtistPlaying && isPlaying) {
                                    SonoPlayer().pause();
                                  } else if (isArtistPlaying && !isPlaying) {
                                    SonoPlayer().play();
                                  } else {
                                    SonoPlayer().playNewPlaylist(
                                      _allArtistSongModels,
                                      0,
                                      context:
                                          "Server Artist: ${widget.artist.name}",
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

  Widget _buildTopSongsSection() {
    if (!_isLoadingTopSongs && (_topSongs == null || _topSongs!.isEmpty)) {
      return const SizedBox.shrink();
    }

    if (_isLoadingTopSongs) {
      return const Padding(
        padding: EdgeInsets.only(top: AppTheme.spacing),
        child: PopularSongsSkeleton(),
      );
    }

    final displaySongs = _topSongs!.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: AppTheme.spacing,
            right: AppTheme.spacing,
            top: AppTheme.spacing,
          ),
          child: Text(
            'Popular',
            style: AppStyles.sonoButtonText.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: AppTheme.spacingMd),
        ...List.generate(displaySongs.length, (index) {
          final song = displaySongs[index];
          return _buildTopSongRow(song, index);
        }),
      ],
    );
  }

  Widget _buildTopSongRow(RemoteSong song, int index) {
    return ValueListenableBuilder<SongModel?>(
      valueListenable: SonoPlayer().currentSong,
      builder: (context, currentSong, _) {
        final isCurrentSong =
            _topSongModels != null &&
            index < _topSongModels!.length &&
            currentSong?.id == _topSongModels![index].id;

        return InkWell(
          onTap: () {
            if (_topSongModels != null) {
              SonoPlayer().playNewPlaylist(
                _topSongModels!,
                index,
                context: "Artist: ${widget.artist.name}",
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacing,
              vertical: AppTheme.spacingSm,
            ),
            child: Row(
              children: [
                //rank number
                SizedBox(
                  width: 24,
                  child: Text(
                    '${index + 1}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      color:
                          isCurrentSong
                              ? AppTheme.brandPink
                              : AppTheme.textSecondaryDark,
                      fontSize: AppTheme.fontBody,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.spacingMd),
                //artwork
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: RemoteArtwork(
                      coverArtId: song.coverArtId,
                      protocol: widget.protocol,
                      size: 48,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.spacingMd),
                //song info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          color:
                              isCurrentSong
                                  ? AppTheme.brandPink
                                  : AppTheme.textPrimaryDark,
                          fontSize: AppTheme.font,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (song.artist != null)
                        Text(
                          song.artist!,
                          style: const TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            color: AppTheme.textSecondaryDark,
                            fontSize: AppTheme.fontSm,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                //more button
                IconButton(
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: AppTheme.textSecondaryDark,
                    size: 20,
                  ),
                  onPressed: () => _showTopSongOptions(song, index),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDiscographyCarousel() {
    return Column(
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
            'Discography',
            style: AppStyles.sonoButtonText.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(
          height: 165,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing),
            itemCount: _albums!.length,
            itemBuilder: (context, index) {
              final album = _albums![index];
              return Padding(
                padding: const EdgeInsets.only(right: AppTheme.spacing),
                child: SizedBox(
                  width: 110,
                  child: InkWell(
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (_) => RemoteAlbumPage(
                                  album: album,
                                  protocol: widget.protocol,
                                ),
                          ),
                        ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppTheme.radius),
                          child: SizedBox(
                            width: 110,
                            height: 110,
                            child: RemoteArtwork(
                              coverArtId: album.coverArtId,
                              protocol: widget.protocol,
                              size: 110,
                              borderRadius: BorderRadius.circular(
                                AppTheme.radius,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          album.name,
                          style: AppStyles.sonoPlayerTitle.copyWith(
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (album.year != null)
                          Text(
                            album.year.toString(),
                            style: AppStyles.sonoPlayerArtist.copyWith(
                              fontSize: 10,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAlbumsListSection() {
    final displayAlbums = _showAllAlbums ? _albums! : _albums!.take(2).toList();

    return Column(
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
        ...displayAlbums.map((album) => _buildAlbumRow(album)),
        if (!_showAllAlbums && _albums!.length > 2)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacing,
              vertical: AppTheme.spacingSm,
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => setState(() => _showAllAlbums = true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.elevatedSurfaceDark,
                  foregroundColor: AppTheme.textPrimaryDark,
                  elevation: 0,
                  side: const BorderSide(color: Color(0xFF3d3d3d), width: 1),
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
    );
  }

  Widget _buildAlbumRow(RemoteAlbum album) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing,
        vertical: AppTheme.spacingSm,
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder:
                  (_) =>
                      RemoteAlbumPage(album: album, protocol: widget.protocol),
            ),
          );
        },
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              child: SizedBox(
                width: 80,
                height: 80,
                child: RemoteArtwork(
                  coverArtId: album.coverArtId,
                  protocol: widget.protocol,
                  size: 80,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
              ),
            ),
            const SizedBox(width: AppTheme.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    album.name,
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
                    [
                      if (album.year != null) '${album.year}',
                      '${album.songCount} songs',
                    ].join(' \u2022 '),
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
    );
  }

  Widget _buildAboutSection() {
    final stats = _lastfmInfo?['stats'];
    final playcount =
        stats != null
            ? int.tryParse(stats['playcount']?.toString() ?? '0')
            : null;
    final bio = _lastfmInfo?['bio']?['content']?.toString();

    if (!_isLoadingArtistInfo &&
        bio == null &&
        _monthlyListeners == null &&
        playcount == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: AppTheme.spacing),
      child: AboutSection(
        bio: bio,
        monthlyListeners: _monthlyListeners,
        totalPlays: playcount,
        artistUrl: _lastfmInfo?['url'],
        isLoading: _isLoadingArtistInfo,
        onViewMore: _showAboutModal,
        onLinkTap: _openLastFmLink,
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: AppTheme.textTertiaryDark,
            ),
            const SizedBox(height: 16),
            const Text(
              'Failed to load albums',
              style: TextStyle(
                color: AppTheme.textSecondaryDark,
                fontSize: AppTheme.font,
                fontFamily: AppTheme.fontFamily,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(
                color: AppTheme.textTertiaryDark,
                fontSize: AppTheme.fontSm,
                fontFamily: AppTheme.fontFamily,
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _loadAlbums,
              child: const Text(
                'Retry',
                style: TextStyle(fontFamily: AppTheme.fontFamily),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
