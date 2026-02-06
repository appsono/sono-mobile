import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:sono/models/popular_song.dart';
import 'package:sono/styles/app_theme.dart';
import 'package:sono/widgets/artist/page_skeletons.dart';
import 'package:sono/widgets/player/sono_player.dart';

class PopularSongsSection extends StatelessWidget {
  final List<PopularSong> songs;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final Function(PopularSong)? onSongTap;
  final Function(PopularSong)? onMoreTap;

  const PopularSongsSection({
    super.key,
    required this.songs,
    this.isLoading = false,
    this.errorMessage,
    this.onRetry,
    this.onSongTap,
    this.onMoreTap,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const PopularSongsSkeleton();
    }

    //hide section if there was an error loading or if no songs available
    if (errorMessage != null || songs.isEmpty) {
      return const SizedBox.shrink();
    }

    //show with songs
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        //header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing),
          child: const Text(
            'Popular',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              color: AppTheme.textPrimaryDark,
              fontSize: AppTheme.fontTitle,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: AppTheme.spacingMd),

        //song list
        ...songs
            .asMap()
            .entries
            .take(5)
            .map((entry) => _buildSongTile(entry.key + 1, entry.value)),
      ],
    );
  }

  Widget _buildSongTile(int rank, PopularSong song) {
    final numberFormat = NumberFormat.decimalPattern();

    if (song.localSong == null) {
      //song not in library => show greyed out
      return Opacity(
        opacity: 0.5,
        child: _buildSongTileContent(rank, song, numberFormat, false),
      );
    }

    //song in library => check if currently playing
    return ValueListenableBuilder<SongModel?>(
      valueListenable: SonoPlayer().currentSong,
      builder: (context, currentSong, _) {
        final isCurrentSong = currentSong?.id == song.localSong!.id;
        return _buildSongTileContent(rank, song, numberFormat, isCurrentSong);
      },
    );
  }

  Widget _buildSongTileContent(
    int rank,
    PopularSong song,
    NumberFormat numberFormat,
    bool isCurrentSong,
  ) {
    final titleColor =
        isCurrentSong ? AppTheme.brandPink : AppTheme.textPrimaryDark;
    final subtitleColor =
        isCurrentSong
            ? AppTheme.brandPink.withAlpha((255 * 0.7).round())
            : AppTheme.textSecondaryDark;

    return InkWell(
      onTap: song.isInLibrary ? () => onSongTap?.call(song) : null,
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
                '$rank',
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
            //album artwork
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              child: SizedBox(
                width: 48,
                height: 48,
                child:
                    song.localSong != null
                        ? QueryArtworkWidget(
                          id: song.localSong!.albumId ?? song.localSong!.id,
                          type: ArtworkType.ALBUM,
                          nullArtworkWidget: _buildPlaceholder(),
                          artworkFit: BoxFit.cover,
                          artworkBorder: BorderRadius.zero,
                        )
                        : _buildPlaceholder(),
              ),
            ),
            const SizedBox(width: AppTheme.spacingMd),
            //song info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      color: titleColor,
                      fontSize: AppTheme.font,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    song.streams != null
                        ? numberFormat.format(song.streams)
                        : song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      color: subtitleColor,
                      fontSize: AppTheme.fontSm,
                    ),
                  ),
                ],
              ),
            ),
            //three-dot menu or playing indicator
            if (song.isInLibrary)
              isCurrentSong
                  ? ValueListenableBuilder<bool>(
                    valueListenable: SonoPlayer().isPlaying,
                    builder: (context, isPlaying, _) {
                      return IconButton(
                        icon: Icon(
                          isPlaying
                              ? Icons.bar_chart_rounded
                              : Icons.play_arrow_rounded,
                          color: AppTheme.brandPink,
                          size: 20,
                        ),
                        onPressed: () => onMoreTap?.call(song),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      );
                    },
                  )
                  : IconButton(
                    icon: const Icon(
                      Icons.more_vert_rounded,
                      color: AppTheme.textSecondaryDark,
                    ),
                    iconSize: 20,
                    onPressed: () => onMoreTap?.call(song),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  )
            else
              const SizedBox(width: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: AppTheme.elevatedSurfaceDark,
      child: const Center(
        child: Icon(
          Icons.music_note_rounded,
          color: AppTheme.textTertiaryDark,
          size: 20,
        ),
      ),
    );
  }
}
