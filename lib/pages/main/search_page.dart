import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:shimmer/shimmer.dart';
import 'package:sono/styles/text.dart';
import 'package:sono/widgets/player/sono_player.dart';
import 'package:sono/pages/library/album_page.dart';
import 'package:sono/pages/library/artist_page.dart';
import 'package:sono/widgets/global/page_header.dart';
import 'package:sono/services/utils/preferences_service.dart';
import 'package:sono/utils/audio_filter_utils.dart';
import 'package:sono/utils/error_handler.dart';
import 'package:sono/widgets/global/cached_artwork_image.dart';
import 'package:sono/widgets/library/artist_artwork_widget.dart';
import 'package:sono/styles/app_theme.dart';

enum SearchItemType { song, album, artist }

class SearchItem {
  final SearchItemType type;
  final dynamic data;
  final String sortKey;
  final int score;

  SearchItem({
    required this.type,
    required this.data,
    required this.sortKey,
    this.score = 0,
  });
}

class SearchPage extends StatefulWidget {
  final VoidCallback? onMenuTap;
  final bool hasPermission;
  final VoidCallback onRequestPermission;
  final Map<String, dynamic>? currentUser;
  final bool isLoggedIn;

  const SearchPage({
    super.key,
    this.onMenuTap,
    required this.hasPermission,
    required this.onRequestPermission,
    this.currentUser,
    this.isLoggedIn = false,
  });

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage>
    with AutomaticKeepAliveClientMixin<SearchPage> {
  //only keep alive when theres an active search (reduce memory usage)
  //when search is empty => allow page to be disposed and reclaim memory
  @override
  bool get wantKeepAlive => _query.isNotEmpty;

  final OnAudioQuery _audioQuery = OnAudioQuery();
  final SonoPlayer _sonoPlayer = SonoPlayer();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounce;
  final PreferencesService _prefsService = PreferencesService();

  bool _isLoadingInitialData = true;
  bool _isSearching = false;
  String _query = "";

  List<SongModel> _allSongs = [];
  List<AlbumModel> _allAlbums = [];
  List<ArtistModel> _allArtists = [];
  List<SearchItem> _searchResults = [];

  @override
  void initState() {
    super.initState();
    if (widget.hasPermission) {
      _loadInitialData();
    }
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void didUpdateWidget(covariant SearchPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.hasPermission && !oldWidget.hasPermission) {
      _loadInitialData();
    }
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();
    //clear large data structures to help garbage collection
    _allSongs.clear();
    _allAlbums.clear();
    _allArtists.clear();
    _searchResults.clear();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    if (!widget.hasPermission) return;
    setState(() => _isLoadingInitialData = true);

    try {
      _allAlbums = await AudioFilterUtils.getFilteredAlbums(
        _audioQuery,
        _prefsService,
      );
      _allArtists = await AudioFilterUtils.getFilteredArtists(
        _audioQuery,
        _prefsService,
      );
      _allSongs = await AudioFilterUtils.getFilteredSongs(
        _audioQuery,
        _prefsService,
        sortType: SongSortType.TITLE,
        orderType: OrderType.ASC_OR_SMALLER,
      );
    } catch (e, s) {
      debugPrint("Error loading initial data for search: $e");
      if (mounted) {
        ErrorHandler.showErrorSnackbar(
          context: context,
          message: 'Error loading library data for search.',
          error: e,
          stackTrace: s,
        );
      }
    }

    if (mounted) {
      setState(() => _isLoadingInitialData = false);
    }
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (_searchController.text != _query) {
        setState(() {
          _query = _searchController.text;
          if (_query.isEmpty) {
            _searchResults = [];
            _isSearching = false;
          } else {
            _performSearch();
          }
        });
        //update keep-alive state based on whether theres an active search
        updateKeepAlive();
      }
    });
  }

  void _performSearch() {
    if (!mounted) return;
    setState(() => _isSearching = true);

    final lowerCaseQuery = _query.toLowerCase();
    final List<SearchItem> foundItems = [];

    //Search songs with scoring
    for (var song in _allSongs) {
      int score = 0;
      if (song.title.toLowerCase().startsWith(lowerCaseQuery)) {
        score += 10;
      } else if (song.title.toLowerCase().contains(lowerCaseQuery)) {
        score += 5;
      }
      if (song.artist?.toLowerCase().contains(lowerCaseQuery) ?? false) {
        score += 3;
      }
      if (song.album?.toLowerCase().contains(lowerCaseQuery) ?? false) {
        score += 2;
      }

      if (score > 0) {
        foundItems.add(
          SearchItem(
            type: SearchItemType.song,
            data: song,
            sortKey: song.title.toLowerCase(),
            score: score,
          ),
        );
      }
    }

    //search albums with scoring
    for (var album in _allAlbums) {
      int score = 0;
      if (album.album.toLowerCase().startsWith(lowerCaseQuery)) {
        score += 10;
      } else if (album.album.toLowerCase().contains(lowerCaseQuery)) {
        score += 5;
      }
      if (album.artist?.toLowerCase().contains(lowerCaseQuery) ?? false) {
        score += 3;
      }

      if (score > 0) {
        foundItems.add(
          SearchItem(
            type: SearchItemType.album,
            data: album,
            sortKey: album.album.toLowerCase(),
            score: score,
          ),
        );
      }
    }

    //search artists with scoring
    for (var artist in _allArtists) {
      int score = 0;
      if (artist.artist.toLowerCase().startsWith(lowerCaseQuery)) {
        score += 10;
      } else if (artist.artist.toLowerCase().contains(lowerCaseQuery)) {
        score += 5;
      }

      if (score > 0) {
        foundItems.add(
          SearchItem(
            type: SearchItemType.artist,
            data: artist,
            sortKey: artist.artist.toLowerCase(),
            score: score,
          ),
        );
      }
    }

    //sort by score (highest first), then by type, then alphabetically
    foundItems.sort((a, b) {
      if (a.score != b.score) return b.score.compareTo(a.score);
      if (a.type.index != b.type.index) {
        return a.type.index.compareTo(b.type.index);
      }
      return a.sortKey.compareTo(b.sortKey);
    });

    if (mounted) {
      setState(() {
        _searchResults = foundItems;
        _isSearching = false;
      });
    }
  }

  Widget _buildResultItem(BuildContext context, SearchItem item) {
    switch (item.type) {
      case SearchItemType.song:
        final song = item.data as SongModel;
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          onTap: () {
            _searchFocusNode.unfocus();
            final songIndex = _allSongs.indexWhere((s) => s.id == song.id);
            if (songIndex != -1) {
              _sonoPlayer.playNewPlaylist(
                _allSongs,
                songIndex,
                context: "Search Results",
              );
            } else {
              _sonoPlayer.playNewPlaylist([song], 0, context: "Search Results");
            }
          },
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            child: CachedArtworkImage(
              id: song.id,
              size: 50,
              //quality: 100,
              type: ArtworkType.AUDIO,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
          ),
          title: Text(
            song.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppStyles.sonoListItemTitle,
          ),
          subtitle: Text(
            song.artist ?? 'Unknown Artist',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppStyles.sonoListItemSubtitle,
          ),
          trailing: const Icon(
            Icons.music_note_rounded,
            color: Colors.white30,
            size: 20,
          ),
        );

      case SearchItemType.album:
        final album = item.data as AlbumModel;
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          onTap: () {
            _searchFocusNode.unfocus();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (_) => AlbumPage(album: album, audioQuery: _audioQuery),
              ),
            );
          },
          leading: Hero(
            tag: 'search-album-artwork-${album.id}',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              child: CachedArtworkImage(
                id: album.id,
                size: 50,
                //quality: 100,
                type: ArtworkType.ALBUM,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
            ),
          ),
          title: Text(
            album.album,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppStyles.sonoListItemTitle,
          ),
          subtitle: Text(
            album.artist ?? 'Unknown Artist',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppStyles.sonoListItemSubtitle,
          ),
          trailing: const Icon(Icons.album_rounded, color: Colors.white30, size: 20),
        );

      case SearchItemType.artist:
        final artist = item.data as ArtistModel;
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          onTap: () {
            _searchFocusNode.unfocus();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (_) => ArtistPage(artist: artist, audioQuery: _audioQuery),
              ),
            );
          },
          leading: Hero(
            tag: 'search-artist-artwork-${artist.id}',
            child: SizedBox(
              width: 50,
              height: 50,
              child: ArtistArtworkWidget(
                artistName: artist.artist,
                artistId: artist.id,
                borderRadius: BorderRadius.circular(25),
              ),
            ),
          ),
          title: Text(
            artist.artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppStyles.sonoListItemTitle,
          ),
          subtitle: Text(
            '${artist.numberOfTracks ?? 0} songs',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppStyles.sonoListItemSubtitle,
          ),
          trailing: const Icon(Icons.person_rounded, color: Colors.white30, size: 20),
        );
    }
  }

  Widget _buildShimmerListItem() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[800]!,
      highlightColor: Colors.grey[700]!,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Container(
              width: 50.0,
              height: 50.0,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8.0),
              ),
            ),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 8.0)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Container(
                    width: double.infinity,
                    height: 16.0,
                    color: Colors.black,
                  ),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 4.0)),
                  Container(
                    width: MediaQuery.of(context).size.width * 0.5,
                    height: 12.0,
                    color: Colors.black,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildGroupedResults() {
    final List<Widget> widgets = [];

    //group by type
    final songs =
        _searchResults
            .where((item) => item.type == SearchItemType.song)
            .toList();
    final albums =
        _searchResults
            .where((item) => item.type == SearchItemType.album)
            .toList();
    final artists =
        _searchResults
            .where((item) => item.type == SearchItemType.artist)
            .toList();

    if (songs.isNotEmpty) {
      widgets.add(_buildSectionHeader('Songs', songs.length, Icons.music_note_rounded));
      widgets.addAll(
        songs.take(10).map((item) => _buildResultItem(context, item)),
      );
      if (songs.length > 10) {
        widgets.add(_buildShowMoreButton('${songs.length - 10} more songs'));
      }
    }

    if (albums.isNotEmpty) {
      widgets.add(_buildSectionHeader('Albums', albums.length, Icons.album_rounded));
      widgets.addAll(
        albums.take(10).map((item) => _buildResultItem(context, item)),
      );
      if (albums.length > 10) {
        widgets.add(_buildShowMoreButton('${albums.length - 10} more albums'));
      }
    }

    if (artists.isNotEmpty) {
      widgets.add(_buildSectionHeader('Artists', artists.length, Icons.person_rounded));
      widgets.addAll(
        artists.take(10).map((item) => _buildResultItem(context, item)),
      );
      if (artists.length > 10) {
        widgets.add(
          _buildShowMoreButton('${artists.length - 10} more artists'),
        );
      }
    }

    return widgets;
  }

  Widget _buildSectionHeader(String title, int count, IconData icon) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.brandPink, size: 20),
          SizedBox(width: AppTheme.spacingXs),
          Text(
            title,
            style: AppStyles.sonoPlayerTitle.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(width: AppTheme.spacingXs),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.brandPink.withAlpha(51),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: Text(
              count.toString(),
              style: const TextStyle(
                color: AppTheme.brandPink,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShowMoreButton(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            color: Colors.white.withAlpha(153),
            fontSize: 13,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    //ignore: deprecated_member_use
    return WillPopScope(
      onWillPop: () async {
        _searchFocusNode.unfocus();
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: GlobalPageHeader(
          pageTitle: "Search",
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
              colors: [AppTheme.backgroundDark, AppTheme.elevatedSurfaceDark],
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  style: AppStyles.sonoPlayerTitle.copyWith(fontSize: 16),
                  decoration: InputDecoration(
                    hintText: 'Search songs, albums, artists...',
                    hintStyle: AppStyles.sonoPlayerArtist.copyWith(
                      fontSize: 16,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppTheme.textSecondaryDark,
                    ),
                    suffixIcon:
                        _query.isNotEmpty
                            ? IconButton(
                              icon: const Icon(
                                Icons.clear_rounded,
                                color: AppTheme.textSecondaryDark,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                _searchFocusNode.unfocus();
                              },
                            )
                            : null,
                    filled: true,
                    fillColor: AppTheme.elevatedSurfaceDark,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
              Expanded(
                child:
                    _isLoadingInitialData
                        ? ListView.builder(
                          itemCount: 10,
                          itemBuilder:
                              (context, index) => _buildShimmerListItem(),
                        )
                        : _query.isEmpty
                        ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search_rounded,
                                size: 80,
                                color: Colors.white.withAlpha(77),
                              ),
                              SizedBox(height: AppTheme.spacing),
                              Text(
                                'Search your library',
                                style: AppStyles.sonoPlayerTitle.copyWith(
                                  fontSize: 20,
                                  color: AppTheme.textSecondaryDark,
                                ),
                              ),
                              SizedBox(height: AppTheme.spacingXs),
                              Text(
                                'Find songs, albums, and artists',
                                style: AppStyles.sonoPlayerArtist.copyWith(
                                  color: Colors.white38,
                                ),
                              ),
                            ],
                          ),
                        )
                        : _isSearching
                        ? ListView.builder(
                          itemCount: 5,
                          itemBuilder:
                              (context, index) => _buildShimmerListItem(),
                        )
                        : _searchResults.isEmpty
                        ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.music_off_rounded,
                                size: 80,
                                color: Colors.white30,
                              ),
                              SizedBox(height: AppTheme.spacing),
                              Text(
                                'No results found',
                                style: AppStyles.sonoPlayerTitle.copyWith(
                                  fontSize: 20,
                                  color: AppTheme.textSecondaryDark,
                                ),
                              ),
                              SizedBox(height: AppTheme.spacingXs),
                              Text(
                                'Try a different search',
                                style: AppStyles.sonoPlayerArtist.copyWith(
                                  color: Colors.white38,
                                ),
                              ),
                            ],
                          ),
                        )
                        : ListView(
                          padding: const EdgeInsets.only(bottom: 100),
                          children: _buildGroupedResults(),
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}