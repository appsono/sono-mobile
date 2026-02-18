import 'dart:async';

import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:sono/data/models/remote_models.dart';
import 'package:sono/pages/servers/artist_page.dart';
import 'package:sono/services/servers/server_protocol.dart';
import 'package:sono/styles/app_theme.dart';
import 'package:sono/styles/text.dart';
import 'package:sono/widgets/player/sono_player.dart';
import 'package:sono/widgets/servers/remote_artwork.dart';
import 'package:url_launcher/url_launcher.dart';

class RemoteAlbumPage extends StatefulWidget {
  final RemoteAlbum album;
  final MusicServerProtocol protocol;

  const RemoteAlbumPage({
    super.key,
    required this.album,
    required this.protocol,
  });

  @override
  State<RemoteAlbumPage> createState() => _RemoteAlbumPageState();
}

class _RemoteAlbumPageState extends State<RemoteAlbumPage> {
  List<RemoteSong>? _songs;
  List<SongModel>? _songModels;
  bool _isLoading = true;
  String? _error;
  bool _isStarred = false;
  final Set<String> _starredSongIds = {};
  Timer? _starRefreshTimer;
  static const Duration _starRefreshInterval = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    _isStarred = widget.album.starred;
    _loadSongs();
    _startStarRefresh();
  }

  @override
  void dispose() {
    _starRefreshTimer?.cancel();
    super.dispose();
  }

  void _startStarRefresh() {
    if (_starRefreshTimer?.isActive ?? false) return;
    _starRefreshTimer = Timer.periodic(_starRefreshInterval, (_) => _refreshStarStates());
  }

  Future<void> _refreshStarStates() async {
    if (!mounted) return;
    try {
      final results = await Future.wait([
        widget.protocol.getAlbum(widget.album.id),
        widget.protocol.getAlbumSongs(widget.album.id),
      ]);
      if (!mounted) return;
      final album = results[0] as RemoteAlbum?;
      final songs = results[1] as List<RemoteSong>;
      setState(() {
        if (album != null) _isStarred = album.starred;
        _starredSongIds
          ..clear()
          ..addAll(songs.where((s) => s.starred).map((s) => s.id));
      });
    } catch (_) {}
  }

  Future<void> _loadSongs() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final songs = await widget.protocol.getAlbumSongs(widget.album.id);
      if (mounted) {
        setState(() {
          _songs = songs;
          _songModels = songs
              .map((s) => s.toSongModel(
                    widget.protocol.getStreamUrl(s.id),
                    coverArtUrl: s.coverArtId != null
                        ? widget.protocol
                            .getCoverArtUrl(s.coverArtId!, size: 600)
                        : null,
                  ))
              .toList();
          _starredSongIds.addAll(
            songs.where((s) => s.starred).map((s) => s.id),
          );
          _isLoading = false;
        });
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

  String _formatDuration(int? seconds) {
    if (seconds == null || seconds == 0) return '';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  String _formatTotalDuration() {
    if (_songs == null || _songs!.isEmpty) return '';
    int totalSeconds = 0;
    for (final song in _songs!) {
      totalSeconds += song.duration ?? 0;
    }
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  void _playSong(int index) {
    if (_songModels == null || _songModels!.isEmpty) return;
    SonoPlayer().playNewPlaylist(
      _songModels!,
      index,
      context: 'Server Album: ${widget.album.name}',
    );
  }

  void _playAll() => _playSong(0);

  Future<void> _toggleStar() async {
    final wasStarred = _isStarred;
    setState(() => _isStarred = !_isStarred);
    try {
      if (wasStarred) {
        await widget.protocol.unstar(albumId: widget.album.id);
      } else {
        await widget.protocol.star(albumId: widget.album.id);
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

  void _openLastFmLink() async {
    final artist = widget.album.artistName ?? '';
    final album = widget.album.name;

    if (artist.isEmpty) return;

    final encodedArtist = Uri.encodeComponent(artist);
    final encodedAlbum = Uri.encodeComponent(album);
    final url = 'https://www.last.fm/music/$encodedArtist/$encodedAlbum';
    final uri = Uri.parse(url);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _navigateToArtist() {
    final artistId = widget.album.artistId;
    final artistName = widget.album.artistName;
    if (artistId == null || artistName == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RemoteArtistPage(
          artist: RemoteArtist(
            id: artistId,
            name: artistName,
            serverId: widget.album.serverId,
          ),
          protocol: widget.protocol,
        ),
      ),
    );
  }

  void _showSongOptionsBottomSheet(RemoteSong song, int index) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: AppTheme.cardDark,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXl)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: AppTheme.spacingMd),
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[700],
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                  ),
                ),
              ),
              //song header
              ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: SizedBox(
                    width: 50,
                    height: 50,
                    child: RemoteArtwork(
                      coverArtId: song.coverArtId,
                      protocol: widget.protocol,
                      size: 50,
                      borderRadius: BorderRadius.circular(8.0),
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
                  song.artist ?? 'Unknown Artist',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppStyles.sonoPlayerArtist,
                ),
              ),
              const Divider(
                  color: Colors.white24, indent: 20, endIndent: 20),
              // Star/unstar
              ListTile(
                leading: Icon(
                  _starredSongIds.contains(song.id)
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  color: _starredSongIds.contains(song.id)
                      ? AppTheme.textPrimaryDark
                      : AppTheme.textSecondaryDark,
                ),
                title: Text(
                  _starredSongIds.contains(song.id) ? 'Unstar' : 'Star',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontFamily: AppTheme.fontFamily),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _toggleSongStar(song);
                },
              ),
              //play next
              ListTile(
                leading: const Icon(
                  Icons.playlist_play_rounded,
                  color: AppTheme.textSecondaryDark,
                ),
                title: const Text(
                  'Play next',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontFamily: AppTheme.fontFamily),
                ),
                onTap: () {
                  Navigator.pop(context);
                  if (_songModels != null && index < _songModels!.length) {
                    SonoPlayer().addSongToPlayNext(_songModels![index]);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Playing next'),
                        backgroundColor: AppTheme.success,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusMd),
                        ),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  }
                },
              ),
              //add to queue
              ListTile(
                leading: const Icon(
                  Icons.queue_music_rounded,
                  color: AppTheme.textSecondaryDark,
                ),
                title: const Text(
                  'Add to queue',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontFamily: AppTheme.fontFamily),
                ),
                onTap: () {
                  Navigator.pop(context);
                  if (_songModels != null && index < _songModels!.length) {
                    SonoPlayer().addSongsToQueue([_songModels![index]]);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Added to queue'),
                        backgroundColor: AppTheme.success,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusMd),
                        ),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  }
                },
              ),
              SizedBox(height: AppTheme.spacingLg),
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
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXl)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: AppTheme.spacingMd),
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
                  'Add Album to Queue',
                  style: TextStyle(
                    color: AppTheme.textPrimaryDark,
                    fontSize: 16,
                    fontFamily: AppTheme.fontFamily,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  if (_songModels != null && _songModels!.isNotEmpty) {
                    SonoPlayer().addSongsToQueue(_songModels!);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Album added to queue'),
                        backgroundColor: AppTheme.success,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusMd),
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
              ),
              //go to artists page
              if (widget.album.artistId != null)
                ListTile(
                  leading: const Icon(
                    Icons.person_rounded,
                    color: AppTheme.textSecondaryDark,
                    size: 28,
                  ),
                  title: const Text(
                    "Go to Artist's Page",
                    style: TextStyle(
                      color: AppTheme.textPrimaryDark,
                      fontSize: 16,
                      fontFamily: AppTheme.fontFamily,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _navigateToArtist();
                  },
                ),
              SizedBox(height: AppTheme.spacingLg),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAlbumInfoSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          //album artwork
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                child: RemoteArtwork(
                  coverArtId: widget.album.coverArtId,
                  protocol: widget.protocol,
                  size: 400,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
              ),
            ),
          ),

          SizedBox(height: AppTheme.spacingXs),

          //album title
          Text(
            widget.album.name,
            style: AppStyles.sonoPlayerTitle.copyWith(
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.left,
          ),

          SizedBox(height: AppTheme.spacingSm),

          //artist name (tappable to navigate)
          if (widget.album.artistName != null)
            InkWell(
              onTap: widget.album.artistId != null ? _navigateToArtist : null,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  widget.album.artistName!,
                  style: AppStyles.sonoPlayerArtist.copyWith(
                    fontSize: 16,
                    color: AppTheme.textSecondaryDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),

          SizedBox(height: AppTheme.spacingSm),

          //song count + duration + year
          Text(
            [
              '${_songs?.length ?? widget.album.songCount} songs',
              if (_songs != null && _songs!.isNotEmpty) _formatTotalDuration(),
              if (widget.album.year != null) '${widget.album.year}',
            ].where((s) => s.isNotEmpty).join(' \u2022 '),
            style: AppStyles.sonoPlayerArtist.copyWith(
              fontSize: 14,
              color: Colors.white54,
            ),
          ),

          SizedBox(height: AppTheme.spacing),

          //action buttons
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final expectedContext = 'Server: ${widget.album.name}';

    return Row(
      children: [
        //left buttons container
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
              //star button
              IconButton(
                icon: Icon(
                  _isStarred
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  color: _isStarred
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
                onPressed: widget.album.artistName != null
                    ? _openLastFmLink
                    : null,
              ),
              //more options
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
            onPressed: _songModels != null && _songModels!.isNotEmpty
                ? () {
                    final shuffled =
                        List<SongModel>.from(_songModels!)..shuffle();
                    SonoPlayer().playNewPlaylist(
                      shuffled,
                      0,
                      context: expectedContext,
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
                final isAlbumPlaying = playbackContext == expectedContext &&
                    (_songModels?.any((s) => s.id == currentSong?.id) ??
                        false);

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
                          (isAlbumPlaying && isPlaying)
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.white,
                        ),
                        iconSize: 24,
                        onPressed:
                            _songModels != null && _songModels!.isNotEmpty
                                ? () {
                                    if (isAlbumPlaying && isPlaying) {
                                      SonoPlayer().pause();
                                    } else if (isAlbumPlaying && !isPlaying) {
                                      SonoPlayer().play();
                                    } else {
                                      _playAll();
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

  Widget _buildSongTile(RemoteSong song, int index) {
    return ValueListenableBuilder<SongModel?>(
      valueListenable: SonoPlayer().currentSong,
      builder: (context, currentSong, child) {
        final syntheticId = _songModels != null && index < _songModels!.length
            ? _songModels![index].id
            : null;
        final bool isCurrentSong = currentSong?.id == syntheticId;

        final TextStyle titleStyle = isCurrentSong
            ? AppStyles.sonoPlayerTitle.copyWith(color: AppTheme.brandPink)
            : AppStyles.sonoPlayerTitle;

        final TextStyle artistStyle = isCurrentSong
            ? AppStyles.sonoPlayerArtist.copyWith(
                fontSize: AppTheme.fontSm,
                color: AppTheme.brandPink.withAlpha((255 * 0.7).round()),
              )
            : AppStyles.sonoPlayerArtist.copyWith(
                fontSize: AppTheme.fontSm,
                color: AppTheme.textTertiaryDark,
              );

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
            [
              if (song.artist != null) song.artist!,
              if (song.suffix != null) song.suffix!.toUpperCase(),
              if (song.bitRate != null) '${song.bitRate} kbps',
            ].join(' \u2022 '),
            style: artistStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _formatDuration(song.duration),
                style: const TextStyle(
                  color: AppTheme.textTertiaryDark,
                  fontSize: AppTheme.fontSm,
                  fontFamily: AppTheme.fontFamily,
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.more_vert_rounded,
                  color: AppTheme.textSecondaryDark,
                  size: 20,
                ),
                onPressed: () => _showSongOptionsBottomSheet(song, index),
              ),
            ],
          ),
          onTap: () => _playSong(index),
        );
      },
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 48, color: AppTheme.textTertiaryDark),
            const SizedBox(height: 16),
            const Text(
              'Failed to load songs',
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
              onPressed: _loadSongs,
              child: const Text('Retry',
                  style: TextStyle(fontFamily: AppTheme.fontFamily)),
            ),
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
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _buildError()
                : ListView(
                    padding: const EdgeInsets.all(0),
                    children: [
                      _buildAlbumInfoSection(),
                      SizedBox(height: AppTheme.spacing),
                      if (_songs != null)
                        ...List.generate(_songs!.length, (index) {
                          return _buildSongTile(_songs![index], index);
                        }),
                      const SizedBox(height: 120),
                    ],
                  ),
      ),
    );
  }
}
