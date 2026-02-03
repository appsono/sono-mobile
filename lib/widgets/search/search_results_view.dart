import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:sono/models/search/search_item.dart';
import 'package:sono/widgets/search/search_section_header.dart';
import 'package:sono/pages/library/album_page.dart';
import 'package:sono/pages/library/artist_page.dart';
import 'package:sono/styles/app_theme.dart';
import 'package:sono/widgets/library/song_list_title.dart';
import 'package:sono/widgets/global/cached_artwork_image.dart';
import 'package:sono/widgets/library/artist_artwork_widget.dart';
import 'package:sono/widgets/player/sono_player.dart';

class SearchResultsView extends StatelessWidget {
  /// All search results
  final List<SearchItem> results;

  /// Grouped results by type
  final Map<SearchItemType, List<SearchItem>> groupedResults;

  /// Current tab index
  /// => 0 = All, 1 = Songs, 2 = Albums, 3 = Artists
  final int currentTab;

  /// Number of items loaded per type
  final Map<SearchItemType, int> loadedCounts;

  /// Page size
  final int pageSize;

  /// Callback to load more items for a type
  final ValueChanged<SearchItemType>? onLoadMore;

  /// Callback when "View All" is tapped for a type
  final ValueChanged<SearchItemType>? onViewAll;

  const SearchResultsView({
    super.key,
    required this.results,
    required this.groupedResults,
    required this.currentTab,
    required this.loadedCounts,
    this.pageSize = 30,
    this.onLoadMore,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return _buildNoResults();
    }

    //tab index 0 = All => show grouped results
    if (currentTab == 0) {
      return _buildAllTab(context);
    }

    //other tabs show specific type
    final type = _getTypeForTab(currentTab);
    final typeResults = groupedResults[type] ?? [];

    return _buildTypeTab(context, type, typeResults);
  }

  Widget _buildAllTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 150),
      physics: const BouncingScrollPhysics(),
      children: [
        if (groupedResults[SearchItemType.song]?.isNotEmpty ?? false)
          _buildSection(
            context,
            SearchItemType.song,
            groupedResults[SearchItemType.song]!,
            limit: 10,
          ),

        if (groupedResults[SearchItemType.album]?.isNotEmpty ?? false)
          _buildSection(
            context,
            SearchItemType.album,
            groupedResults[SearchItemType.album]!,
            limit: 10,
          ),

        if (groupedResults[SearchItemType.artist]?.isNotEmpty ?? false)
          _buildSection(
            context,
            SearchItemType.artist,
            groupedResults[SearchItemType.artist]!,
            limit: 10,
          ),
      ],
    );
  }

  Widget _buildSection(
    BuildContext context,
    SearchItemType type,
    List<SearchItem> items, {
    int limit = 10,
  }) {
    final displayItems = items.take(limit).toList();
    final hasMore = items.length > limit;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SearchSectionHeader(
          type: type,
          count: displayItems.length,
          totalCount: items.length,
          onViewAll:
              hasMore && onViewAll != null ? () => onViewAll!(type) : null,
        ),

        ...displayItems.map((item) => _buildItem(context, item)),

        if (hasMore) const SizedBox(height: AppTheme.spacingSm),
      ],
    );
  }

  Widget _buildTypeTab(
    BuildContext context,
    SearchItemType type,
    List<SearchItem> items,
  ) {
    final loadedCount = loadedCounts[type] ?? pageSize;
    final displayItems = items.take(loadedCount).toList();
    final hasMore = items.length > loadedCount;

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 150),
      physics: const BouncingScrollPhysics(),
      itemCount: displayItems.length + (hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == displayItems.length) {
          if (hasMore && onLoadMore != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              onLoadMore!(type);
            });
          }
          return _buildLoadingIndicator();
        }

        return RepaintBoundary(
          key: ValueKey('search-item-$index'),
          child: _buildItem(context, displayItems[index]),
        );
      },
    );
  }

  Widget _buildItem(BuildContext context, SearchItem item) {
    switch (item.type) {
      case SearchItemType.song:
        return _buildSongItem(context, item.data as SongModel);
      case SearchItemType.album:
        return _buildAlbumItem(context, item.data as AlbumModel);
      case SearchItemType.artist:
        return _buildArtistItem(context, item.data as ArtistModel);
    }
  }

  Widget _buildSongItem(BuildContext context, SongModel song) {
    return SongListTile(
      song: song,
      onSongTap: (tappedSong) {
        final sonoPlayer = SonoPlayer();
        final songs =
            groupedResults[SearchItemType.song]
                ?.map((item) => item.data as SongModel)
                .toList() ??
            [];
        final index = songs.indexWhere((s) => s.id == tappedSong.id);
        sonoPlayer.playNewPlaylist(
          songs,
          index >= 0 ? index : 0,
          context: 'Search Results',
        );
      },
    );
  }

  Widget _buildAlbumItem(BuildContext context, AlbumModel album) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) =>
                    AlbumPage(album: album, audioQuery: OnAudioQuery()),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacing,
          vertical: AppTheme.spacingSm,
        ),
        child: Row(
          children: [
            Hero(
              tag: 'search-album-${album.id}',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radius),
                child: CachedArtworkImage(
                  id: album.id,
                  type: ArtworkType.ALBUM,
                  size: 50,
                ),
              ),
            ),
            const SizedBox(width: AppTheme.spacingMd),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    album.album,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: AppTheme.font,
                      fontFamily: 'VarelaRound',
                      color: Colors.white,
                    ),
                  ),
                  if (album.artist != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      album.artist!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: AppTheme.fontBody,
                        fontFamily: 'VarelaRound',
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            Icon(
              Icons.chevron_right_rounded,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArtistItem(BuildContext context, ArtistModel artist) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) =>
                    ArtistPage(artist: artist, audioQuery: OnAudioQuery()),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacing,
          vertical: AppTheme.spacingSm,
        ),
        child: Row(
          children: [
            Hero(
              tag: 'search-artist-${artist.id}',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusCircle),
                child: SizedBox(
                  width: 50,
                  height: 50,
                  child: ArtistArtworkWidget(
                    artistName: artist.artist,
                    artistId: artist.id,
                    borderRadius: BorderRadius.circular(AppTheme.radiusCircle),
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
                    artist.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: AppTheme.font,
                      fontFamily: 'VarelaRound',
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${artist.numberOfTracks} ${artist.numberOfTracks == 1 ? 'track' : 'tracks'}',
                    style: TextStyle(
                      fontSize: AppTheme.fontBody,
                      fontFamily: 'VarelaRound',
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),

            Icon(
              Icons.chevron_right_rounded,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing2xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 80,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            const SizedBox(height: AppTheme.spacingLg),
            Text(
              'No results found',
              style: TextStyle(
                fontSize: AppTheme.fontTitle,
                fontWeight: FontWeight.w600,
                fontFamily: 'VarelaRound',
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: AppTheme.spacingSm),
            Text(
              'Try searching with different keywords',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppTheme.fontBody,
                color: Colors.white.withValues(alpha: 0.5),
                fontFamily: 'VarelaRound',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return const Padding(
      padding: EdgeInsets.all(AppTheme.spacingLg),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.brandPink),
          ),
        ),
      ),
    );
  }

  SearchItemType _getTypeForTab(int tabIndex) {
    switch (tabIndex) {
      case 1:
        return SearchItemType.song;
      case 2:
        return SearchItemType.album;
      case 3:
        return SearchItemType.artist;
      default:
        return SearchItemType.song;
    }
  }
}
