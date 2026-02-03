import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:shimmer/shimmer.dart';
import 'package:sono/styles/app_theme.dart';
import 'package:sono/styles/text.dart';
import 'package:sono/widgets/player/sono_player.dart';
import 'package:sono/widgets/library/song_list_title.dart';
import 'package:sono/widgets/home/page_items.dart';
import 'package:sono/widgets/home/app_bar_content.dart';
import 'package:sono/widgets/home/page_header_elements.dart';
import 'package:sono/pages/library/all_items_page.dart';
import 'package:sono/pages/info/announcements_changelog_page.dart';
import 'package:sono/utils/audio_filter_utils.dart';
import 'package:sono/widgets/global/refresh_indicator.dart';

class HomePage extends StatefulWidget {
  final VoidCallback? onSearchTap;
  final VoidCallback? onMenuTap;
  final VoidCallback? onNewsTap;
  final VoidCallback? onSettingsTap;
  final VoidCallback? onCreatePlaylist;
  final bool hasPermission;
  final VoidCallback onRequestPermission;
  final Map<String, dynamic>? currentUser;
  final bool isLoggedIn;

  const HomePage({
    super.key,
    this.onSearchTap,
    this.onMenuTap,
    this.onNewsTap,
    this.onSettingsTap,
    this.onCreatePlaylist,
    required this.hasPermission,
    required this.onRequestPermission,
    this.currentUser,
    this.isLoggedIn = false,
  });

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage>
    with AutomaticKeepAliveClientMixin<HomePage> {
  final OnAudioQuery _audioQuery = OnAudioQuery();
  final SonoPlayer _sonoPlayer = SonoPlayer();

  Future<List<SongModel>> _recentlyAddedSongsPreviewFuture = Future.value([]);
  Future<List<AlbumModel>> _albumsPreviewFuture = Future.value([]);
  Future<List<ArtistModel>> _artistsPreviewFuture = Future.value([]);

  List<SongModel> _allSongs = [];
  List<SongModel> _paginatedSongs = [];
  bool _isLoadingAllSongs = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    if (widget.hasPermission) {
      _initializeDataFutures();
    }
  }

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.hasPermission && !oldWidget.hasPermission) {
      _initializeDataFutures();
    }

    if (widget.isLoggedIn != oldWidget.isLoggedIn ||
        widget.currentUser?['username'] != oldWidget.currentUser?['username']) {
      debugPrint(
        '[HomePage] Login state changed: ${oldWidget.isLoggedIn} -> ${widget.isLoggedIn}',
      );
      debugPrint(
        '[HomePage] User changed: ${oldWidget.currentUser?['username']} -> ${widget.currentUser?['username']}',
      );
      setState(() {
        //trigger rebuild to propagate new props to HomeAppBarContent
        //the setState with empty body forces the widget tree to rebuild
        //which will pass the updated isLoggedIn and currentUser to HomeAppBarContent
      });
    }
  }

  void _initializeDataFutures() {
    if (!widget.hasPermission || !mounted) return;

    setState(() {
      _recentlyAddedSongsPreviewFuture = AudioFilterUtils.getFilteredSongs(
        _audioQuery,
        sortType: SongSortType.DATE_ADDED,
        orderType: OrderType.DESC_OR_GREATER,
      ).then((s) => s.take(15).toList());

      _albumsPreviewFuture = AudioFilterUtils.getFilteredAlbums(
            _audioQuery,
          )
          .then((a) => a..sort((x, y) => (x.album).compareTo(y.album)))
          .then((a) => a.take(15).toList());

      _artistsPreviewFuture = AudioFilterUtils.getFilteredArtists(
            _audioQuery,
          )
          .then((a) => a..sort((x, y) => (x.artist).compareTo(y.artist)))
          .then((a) => a.take(15).toList());

      _isLoadingAllSongs = true;
    });

    AudioFilterUtils.getFilteredSongs(
      _audioQuery,
      sortType: SongSortType.TITLE,
      orderType: OrderType.ASC_OR_SMALLER,
    ).then((songs) {
      if (mounted) {
        setState(() {
          _allSongs = songs;    
          _paginatedSongs = songs.toList();
          _isLoadingAllSongs = false;
        });
      }
    });
  }

  /// Refreshes the home page data
  Future<void> refreshData() async {
    if (!widget.hasPermission || !mounted) return;
    _initializeDataFutures();
  }

  void _handleShuffleAll() async {
    if (!widget.hasPermission) return;
    final songs =
        _allSongs.isNotEmpty
            ? List<SongModel>.from(_allSongs)
            : await AudioFilterUtils.getFilteredSongs(
              _audioQuery,
            );

    if (songs.isNotEmpty) {
      songs.shuffle();
      _sonoPlayer.playNewPlaylist(songs, 0, context: "All Songs");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Shuffling all songs...'),
            backgroundColor: AppTheme.brandPink,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
  }

  void _handleSongTap(
    SongModel song,
    List<SongModel> currentListContext,
    int tappedIndexInContext, {
    String? playbackContext,
  }) {
    if (!widget.hasPermission) return;
    _sonoPlayer.playNewPlaylist(
      currentListContext,
      tappedIndexInContext,
      context: playbackContext,
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

    if (!widget.hasPermission) {
      return _buildPermissionDeniedWidget();
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppTheme.backgroundDark, AppTheme.surfaceDark],
          ),
        ),
        child: _buildHomepage(context),
      ),
    );
  }

  Widget _buildSkeletonLoader({
    required double width,
    required double height,
    BorderRadius? borderRadius,
  }) {
    return Shimmer.fromColors(
      baseColor: AppTheme.surfaceDark,
      highlightColor: AppTheme.elevatedSurfaceDark,
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

  Widget _buildSongSkeletonLoader() {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppTheme.spacing,
        vertical: AppTheme.spacingSm,
      ),
      child: Row(
        children: [
          _buildSkeletonLoader(
            width: 50,
            height: 50,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          SizedBox(width: AppTheme.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSkeletonLoader(
                  width: double.infinity,
                  height: AppTheme.spacing,
                ),
                SizedBox(height: AppTheme.spacingSm),
                _buildSkeletonLoader(width: 150, height: AppTheme.spacingMd),
              ],
            ),
          ),
        ],
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
        padding: EdgeInsets.symmetric(horizontal: AppTheme.spacing),
        itemBuilder: (context, index) {
          return Padding(
            padding: EdgeInsets.only(right: AppTheme.spacing),
            child: Column(
              children: [
                _buildSkeletonLoader(
                  width: itemWidth,
                  height: itemWidth,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                SizedBox(height: AppTheme.spacingSm),
                _buildSkeletonLoader(
                  width: itemWidth * 0.8,
                  height: AppTheme.spacingMd,
                ),
                SizedBox(height: AppTheme.spacingXs),
                _buildSkeletonLoader(
                  width: itemWidth * 0.6,
                  height: AppTheme.fontCaption,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCircularSkeletonLoader({
    required double diameter,
    required int itemCount,
  }) {
    return SizedBox(
      height: diameter + 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: itemCount,
        padding: EdgeInsets.symmetric(horizontal: AppTheme.spacing),
        itemBuilder: (context, index) {
          return Padding(
            padding: EdgeInsets.only(right: AppTheme.spacing),
            child: Column(
              children: [
                _buildSkeletonLoader(
                  width: diameter,
                  height: diameter,
                  borderRadius: BorderRadius.circular(diameter / 2),
                ),
                SizedBox(height: AppTheme.spacingSm),
                _buildSkeletonLoader(
                  width: diameter * 0.8,
                  height: AppTheme.spacingMd,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPermissionDeniedWidget() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppTheme.spacingLg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.music_off_rounded,
              color: AppTheme.textDisabledDark,
              size: 80,
            ),
            SizedBox(height: AppTheme.spacingLg),
            Text(
              'Permission Required',
              style: AppStyles.sonoButtonText.copyWith(
                fontSize: AppTheme.fontTitle,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimaryDark,
              ),
            ),
            SizedBox(height: AppTheme.spacingSm + 2),
            Text(
              'Sono needs permission to access your local audio files to build your library.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondaryDark, height: 1.5),
            ),
            SizedBox(height: AppTheme.spacingLg),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: AppTheme.textPrimaryDark,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingXl,
                  vertical: AppTheme.spacingMd,
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

  Widget _buildHomepage(BuildContext context) {
    const double appBarContentHeight = 70.0;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: <Widget>[
        SonoSliverRefreshControl(onRefresh: refreshData),
        SliverAppBar(
          pinned: true,
          floating: false,
          automaticallyImplyLeading: false,
          backgroundColor: AppTheme.backgroundDark,
          elevation: 0,
          toolbarHeight: appBarContentHeight,
          titleSpacing: 0,
          title: Builder(
            builder: (context) {
              return HomeAppBarContent(
                key: ValueKey(
                  'HomeAppBarContent_${widget.isLoggedIn}_${widget.currentUser?['username']}',
                ),
                onMenuTap: widget.onMenuTap ?? () {},
                onNewsTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AnnouncementsChangelogPage()),
                  );
                },
                onSearchTap: widget.onSearchTap,
                onSettingsTap: widget.onSettingsTap,
                toolbarHeight: appBarContentHeight,
                currentUser: widget.currentUser,
                isLoggedIn: widget.isLoggedIn,
              );
            },
          ),
        ),
        SliverToBoxAdapter(
          child: ShuffleCreatePlaylistButtons(
            onShuffleAll: _handleShuffleAll,
            onCreatePlaylist: widget.onCreatePlaylist ?? () {},
          ),
        ),
        _buildSection<SongModel>(
          context: context,
          title: "Recently Added",
          onSeeAllTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (context) => AllItemsPage(
                      pageTitle: "All Recently Added",
                      itemsFuture: AudioFilterUtils.getFilteredSongs(
                        _audioQuery,
                        sortType: SongSortType.DATE_ADDED,
                        orderType: OrderType.DESC_OR_GREATER,
                      ),
                      itemType: ListItemType.song,
                      audioQuery: _audioQuery,
                    ),
              ),
            );
          },
          future: _recentlyAddedSongsPreviewFuture,
          itemBuilder:
              (ctx, item, listCtx, idx) => HomePageSongItem(
                song: item,
                artworkSize: 70,
                onSongTap:
                    (s) => _handleSongTap(
                      s,
                      listCtx,
                      idx,
                      playbackContext: "Recently Added",
                    ),
              ),
          itemWidth: 70,
          listHeight: 125,
          skeletonLoader: _buildHorizontalSkeletonLoader(
            itemWidth: 70,
            itemHeight: 125,
            itemCount: 6,
          ),
        ),
        _buildSection<AlbumModel>(
          context: context,
          title: "Albums",
          onSeeAllTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (context) => AllItemsPage(
                      pageTitle: "All Albums",
                      itemsFuture: AudioFilterUtils.getFilteredAlbums(
                        _audioQuery,
                        sortType: AlbumSortType.ALBUM,
                        orderType: OrderType.ASC_OR_SMALLER,
                      ),
                      itemType: ListItemType.album,
                      audioQuery: _audioQuery,
                    ),
              ),
            );
          },
          future: _albumsPreviewFuture,
          itemBuilder:
              (ctx, item, listCtx, idx) => HomePageAlbumItem(
                album: item,
                artworkSize: 110,
                audioQuery: _audioQuery,
              ),
          itemWidth: 110,
          listHeight: 165,
          skeletonLoader: _buildHorizontalSkeletonLoader(
            itemWidth: 110,
            itemHeight: 165,
            itemCount: 4,
          ),
        ),
        _buildSection<ArtistModel>(
          context: context,
          title: "Artists",
          onSeeAllTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (context) => AllItemsPage(
                      pageTitle: "All Artists",
                      itemsFuture: AudioFilterUtils.getFilteredArtists(
                        _audioQuery,
                        sortType: ArtistSortType.ARTIST,
                        orderType: OrderType.ASC_OR_SMALLER,
                      ),
                      itemType: ListItemType.artist,
                      audioQuery: _audioQuery,
                    ),
              ),
            );
          },
          future: _artistsPreviewFuture,
          itemBuilder:
              (ctx, item, listCtx, idx) => HomePageArtistItem(
                artist: item,
                diameter: 80,
                audioQuery: _audioQuery,
              ),
          itemWidth: 80,
          listHeight: 130,
          skeletonLoader: _buildCircularSkeletonLoader(
            diameter: 80,
            itemCount: 5,
          ),
        ),
        _buildAllSongsHeader(),
        _buildAllSongsList(context),
        //if (_hasMoreSongs) _buildLoadMoreButton(),
        const SliverToBoxAdapter(child: SizedBox(height: 150)),
      ],
    );
  }

  Widget _buildAllSongsHeader() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppTheme.spacing,
          right: AppTheme.spacing,
          top: AppTheme.spacingXl,
          bottom: AppTheme.spacing,
        ),
        child: Text(
          "All Songs",
          style: AppStyles.sonoButtonText.copyWith(
            fontSize: AppTheme.fontSubtitle,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildAllSongsList(BuildContext context) {
    if (_isLoadingAllSongs) {
      return SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => _buildSongSkeletonLoader(),
          childCount: 10,
        ),
      );
    }
    if (_paginatedSongs.isEmpty) {
      if (widget.hasPermission) {
        return SliverToBoxAdapter(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(AppTheme.spacing),
              child: Text(
                'No songs found.',
                style: TextStyle(color: AppTheme.textSecondaryDark),
              ),
            ),
          ),
        );
      }
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final song = _paginatedSongs[index];
        final originalIndex = _allSongs.indexWhere((s) => s.id == song.id);
        return SongListTile(
          song: song,
          onSongTap:
              (selectedSong) => _handleSongTap(
                selectedSong,
                _allSongs,
                originalIndex,
                playbackContext: "All Songs",
              ),
        );
      }, childCount: _paginatedSongs.length),
    );
  }

  Widget _buildSection<T>({
    required BuildContext context,
    required String title,
    required VoidCallback onSeeAllTap,
    required Future<List<T>> future,
    required Widget Function(
      BuildContext,
      T,
      List<T> listContext,
      int indexInContext,
    )
    itemBuilder,
    required double itemWidth,
    required double listHeight,
    required Widget skeletonLoader,
  }) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: AppTheme.spacingSm + 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: AppTheme.spacing),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: AppStyles.sonoButtonText.copyWith(
                      fontSize: AppTheme.fontSubtitle,
                    ),
                  ),
                  InkWell(
                    onTap: onSeeAllTap,
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacingSm,
                        vertical: 4,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'See All',
                            style: TextStyle(
                              fontSize: AppTheme.fontSm,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondaryDark,
                              fontFamily: 'VarelaRound',
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 16,
                            color: AppTheme.textSecondaryDark,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: AppTheme.spacingMd),
            SizedBox(
              height: listHeight,
              child: FutureBuilder<List<T>>(
                future: future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return skeletonLoader;
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error fetching $title',
                        style: TextStyle(color: AppTheme.textSecondaryDark),
                      ),
                    );
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    if (widget.hasPermission) {
                      return Center(
                        child: Text(
                          'No $title found.',
                          style: TextStyle(color: AppTheme.textSecondaryDark),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  }
                  final items = snapshot.data!;
                  return ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: items.length,
                    padding: EdgeInsets.symmetric(horizontal: AppTheme.spacing),
                    physics: const BouncingScrollPhysics(),
                    cacheExtent: 300,
                    itemBuilder: (listViewContext, index) {
                      return RepaintBoundary(
                        key: ValueKey('${title}_${_getItemId(items[index])}'),
                        child: Padding(
                          padding: EdgeInsets.only(right: AppTheme.spacing),
                          child: SizedBox(
                            width: itemWidth,
                            child: itemBuilder(
                              listViewContext,
                              items[index],
                              items,
                              index,
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

dynamic _getItemId(dynamic item) {
  if (item is SongModel) return item.id;
  if (item is AlbumModel) return item.id;
  if (item is ArtistModel) return item.id;
  if (item is PlaylistModel) return item.id;
  return item.hashCode;
}