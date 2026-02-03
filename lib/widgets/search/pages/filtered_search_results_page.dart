import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:sono/models/search/search_item.dart';
import 'package:sono/pages/library/album_page.dart';
import 'package:sono/pages/library/artist_page.dart';
import 'package:sono/widgets/library/song_list_title.dart';
import 'package:sono/widgets/global/cached_artwork_image.dart';
import 'package:sono/widgets/library/artist_artwork_widget.dart';
import 'package:sono/widgets/player/sono_player.dart';
import 'package:sono/styles/app_theme.dart';

class FilteredSearchResultsPage extends StatefulWidget {
  /// Type of results to display
  final SearchItemType type;

  /// All results for this type
  final List<SearchItem> results;

  /// Search query
  final String query;

  const FilteredSearchResultsPage({
    super.key,
    required this.type,
    required this.results,
    required this.query,
  });

  @override
  State<FilteredSearchResultsPage> createState() =>
      _FilteredSearchResultsPageState();
}

class _FilteredSearchResultsPageState extends State<FilteredSearchResultsPage> {
  late List<SearchItem> _sortedResults;

  @override
  void initState() {
    super.initState();
    _sortedResults = List.from(widget.results);
  }

  String _getTitle() {
    switch (widget.type) {
      case SearchItemType.song:
        return 'Songs';
      case SearchItemType.album:
        return 'Albums';
      case SearchItemType.artist:
        return 'Artists';
    }
  }

  IconData _getIcon() {
    switch (widget.type) {
      case SearchItemType.song:
        return Icons.music_note_rounded;
      case SearchItemType.album:
        return Icons.album_rounded;
      case SearchItemType.artist:
        return Icons.person_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppTheme.backgroundDark,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: Row(
            children: [
              Icon(_getIcon(), size: 20, color: AppTheme.brandPink),
              const SizedBox(width: AppTheme.spacingSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getTitle(),
                      style: const TextStyle(
                        fontSize: AppTheme.fontSubtitle,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'VarelaRound',
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '"${widget.query}" · ${_sortedResults.length} results',
                      style: TextStyle(
                        fontSize: AppTheme.fontSm,
                        fontFamily: 'VarelaRound',
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 150),
                physics: const BouncingScrollPhysics(),
                itemCount: _sortedResults.length,
                itemBuilder: (context, index) {
                  return RepaintBoundary(
                    key: ValueKey('filtered-result-$index'),
                    child: _buildItem(context, _sortedResults[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
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
            _sortedResults.map((item) => item.data as SongModel).toList();
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
              tag: 'filtered-album-${album.id}',
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
              tag: 'filtered-artist-${artist.id}',
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
}
