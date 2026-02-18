import 'package:flutter/material.dart';
import 'package:sono/data/models/remote_models.dart';
import 'package:sono/pages/servers/album_page.dart';
import 'package:sono/pages/servers/artist_page.dart';
import 'package:sono/services/servers/server_protocol.dart';
import 'package:sono/services/servers/server_service.dart';
import 'package:sono/styles/app_theme.dart';
import 'package:sono/styles/text.dart';
import 'package:sono/widgets/player/sono_player.dart';
import 'package:sono/widgets/servers/remote_artwork.dart';

class ServerLibraryPage extends StatefulWidget {
  const ServerLibraryPage({super.key});

  @override
  State<ServerLibraryPage> createState() => _ServerLibraryPageState();
}

class _ServerLibraryPageState extends State<ServerLibraryPage> {
  late final MusicServerProtocol _protocol;
  late final String _serverName;

  List<RemoteAlbum>? _recentAlbums;
  List<RemoteAlbum>? _randomAlbums;
  List<RemoteArtist>? _artists;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final service = MusicServerService.instance;
    _protocol = service.activeProtocol!;
    _serverName = service.activeServer!.name;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      //run all three independently so an empty album list doesnt block artists
      final results = await Future.wait([
        _protocol.getAlbumList(type: 'newest', count: 20).catchError((_) => <RemoteAlbum>[]),
        _protocol.getAlbumList(type: 'random', count: 20).catchError((_) => <RemoteAlbum>[]),
        _protocol.getArtists(),
      ]);

      if (mounted) {
        setState(() {
          _recentAlbums = results[0] as List<RemoteAlbum>;
          _randomAlbums = results[1] as List<RemoteAlbum>;
          _artists = results[2] as List<RemoteArtist>;
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
            icon: const Icon(Icons.arrow_back_rounded,
                color: AppTheme.textPrimaryDark),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            _serverName,
            style: const TextStyle(
              fontSize: AppTheme.fontTitle,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryDark,
              fontFamily: AppTheme.fontFamily,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.search_rounded,
                  color: AppTheme.textPrimaryDark),
              onPressed: () => _showSearch(context),
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _buildError()
                : RefreshIndicator(
                    onRefresh: _loadData,
                    child: ListView(
                      physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics()),
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.of(context).padding.bottom + 100,
                      ),
                      children: [
                        if (_recentAlbums != null &&
                            _recentAlbums!.isNotEmpty)
                          _buildSection('Recently Added', _recentAlbums!),
                        if (_randomAlbums != null &&
                            _randomAlbums!.isNotEmpty)
                          _buildSection('Random Albums', _randomAlbums!),
                        if (_artists != null && _artists!.isNotEmpty)
                          _buildArtistsSection(),
                      ],
                    ),
                  ),
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
            const Icon(Icons.error_outline_rounded,
                size: 48, color: AppTheme.textTertiaryDark),
            const SizedBox(height: 16),
            const Text(
              'Failed to load library',
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
              onPressed: _loadData,
              child: const Text('Retry',
                  style: TextStyle(fontFamily: AppTheme.fontFamily)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<RemoteAlbum> albums) {
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
            title,
            style: AppStyles.sonoButtonText.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding:
                const EdgeInsets.symmetric(horizontal: AppTheme.spacing),
            itemCount: albums.length,
            itemBuilder: (context, index) {
              final album = albums[index];
              return _buildAlbumCard(album);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAlbumCard(RemoteAlbum album) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              RemoteAlbumPage(album: album, protocol: _protocol),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(right: AppTheme.spacing),
        child: SizedBox(
          width: 140,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radius),
                child: RemoteArtwork(
                  coverArtId: album.coverArtId,
                  protocol: _protocol,
                  size: 140,
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                album.name,
                style: AppStyles.sonoPlayerTitle.copyWith(fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (album.artistName != null)
                Text(
                  album.artistName!,
                  style: AppStyles.sonoPlayerArtist.copyWith(fontSize: 10),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildArtistsSection() {
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
            'Artists',
            style: AppStyles.sonoButtonText.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _artists!.length,
          itemBuilder: (context, index) {
            final artist = _artists![index];
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacing,
                vertical: 2,
              ),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: RemoteArtwork(
                    coverArtId: artist.coverArtId,
                    protocol: _protocol,
                    size: 44,
                    borderRadius: BorderRadius.circular(22),
                    fallbackIcon: Icons.person_rounded,
                  ),
                ),
              ),
              title: Text(
                artist.name,
                style: AppStyles.sonoListItemTitle,
              ),
              subtitle: Text(
                '${artist.albumCount} album${artist.albumCount == 1 ? '' : 's'}',
                style: AppStyles.sonoListItemSubtitle.copyWith(
                  fontSize: AppTheme.fontSm,
                ),
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RemoteArtistPage(
                      artist: artist, protocol: _protocol),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  void _showSearch(BuildContext context) {
    showSearch(
      context: context,
      delegate: _RemoteSearchDelegate(_protocol),
    );
  }
}

class _RemoteSearchDelegate extends SearchDelegate<String?> {
  final MusicServerProtocol _protocol;

  _RemoteSearchDelegate(this._protocol)
      : super(
          searchFieldLabel: 'Search server...',
          searchFieldStyle: const TextStyle(
            color: AppTheme.textPrimaryDark,
            fontFamily: AppTheme.fontFamily,
          ),
        );

  @override
  ThemeData appBarTheme(BuildContext context) {
    return ThemeData(
      appBarTheme: const AppBarTheme(
        backgroundColor: AppTheme.backgroundDark,
        elevation: 0,
      ),
      scaffoldBackgroundColor: AppTheme.backgroundDark,
      inputDecorationTheme: const InputDecorationTheme(
        hintStyle: TextStyle(
          color: AppTheme.textTertiaryDark,
          fontFamily: AppTheme.fontFamily,
        ),
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(
          color: AppTheme.textPrimaryDark,
          fontFamily: AppTheme.fontFamily,
        ),
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear_rounded,
              color: AppTheme.textPrimaryDark),
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back_rounded,
          color: AppTheme.textPrimaryDark),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    if (query.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<RemoteSearchResult>(
      future: _protocol.search(query.trim()),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Search failed: ${snapshot.error}',
              style: const TextStyle(
                color: AppTheme.textSecondaryDark,
                fontFamily: AppTheme.fontFamily,
              ),
            ),
          );
        }

        final result = snapshot.data!;
        if (result.artists.isEmpty &&
            result.albums.isEmpty &&
            result.songs.isEmpty) {
          return const Center(
            child: Text(
              'No results found',
              style: TextStyle(
                color: AppTheme.textSecondaryDark,
                fontFamily: AppTheme.fontFamily,
              ),
            ),
          );
        }

        return ListView(
          physics: const BouncingScrollPhysics(),
          children: [
            if (result.artists.isNotEmpty) ...[
              _sectionHeader('Artists'),
              ...result.artists.map((a) => ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: RemoteArtwork(
                          coverArtId: a.coverArtId,
                          protocol: _protocol,
                          size: 40,
                          borderRadius: BorderRadius.circular(20),
                          fallbackIcon: Icons.person_rounded,
                        ),
                      ),
                    ),
                    title: Text(a.name,
                        style: AppStyles.sonoListItemTitle),
                    onTap: () {
                      close(context, null);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RemoteArtistPage(
                              artist: a, protocol: _protocol),
                        ),
                      );
                    },
                  )),
            ],
            if (result.albums.isNotEmpty) ...[
              _sectionHeader('Albums'),
              ...result.albums.map((a) => ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: RemoteArtwork(
                          coverArtId: a.coverArtId,
                          protocol: _protocol,
                          size: 40,
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusSm),
                        ),
                      ),
                    ),
                    title: Text(a.name,
                        style: AppStyles.sonoListItemTitle),
                    subtitle: a.artistName != null
                        ? Text(a.artistName!,
                            style: AppStyles.sonoListItemSubtitle)
                        : null,
                    onTap: () {
                      close(context, null);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RemoteAlbumPage(
                              album: a, protocol: _protocol),
                        ),
                      );
                    },
                  )),
            ],
            if (result.songs.isNotEmpty) ...[
              _sectionHeader('Songs'),
              ...result.songs.map((s) => ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: RemoteArtwork(
                          coverArtId: s.coverArtId,
                          protocol: _protocol,
                          size: 40,
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusSm),
                        ),
                      ),
                    ),
                    title: Text(s.title,
                        style: AppStyles.sonoListItemTitle),
                    subtitle: Text(
                        '${s.artist ?? 'Unknown'} \u2022 ${s.album ?? ''}',
                        style: AppStyles.sonoListItemSubtitle),
                    onTap: () {
                      close(context, null);
                      final songModel =
                          s.toSongModel(
                            _protocol.getStreamUrl(s.id),
                            coverArtUrl: s.coverArtId != null
                                ? _protocol.getCoverArtUrl(s.coverArtId!, size: 600)
                                : null,
                          );
                      SonoPlayer().playNewPlaylist(
                        [songModel],
                        0,
                        context: 'Server search: ${s.title}',
                      );
                    },
                  )),
            ],
          ],
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.trim().length >= 2) {
      return buildResults(context);
    }
    return const Center(
      child: Text(
        'Type to search...',
        style: TextStyle(
          color: AppTheme.textTertiaryDark,
          fontFamily: AppTheme.fontFamily,
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppTheme.spacing, AppTheme.spacing, AppTheme.spacing, 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: AppTheme.textTertiaryDark,
          fontSize: AppTheme.fontSm,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          fontFamily: AppTheme.fontFamily,
        ),
      ),
    );
  }
}
