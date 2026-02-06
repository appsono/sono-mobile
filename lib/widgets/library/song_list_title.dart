import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sono/utils/artist_string_utils.dart';
import 'package:sono/widgets/global/add_to_playlist_dialog.dart';
import 'package:sono/widgets/player/sono_player.dart';
import 'package:sono/styles/text.dart';
import 'package:sono/styles/app_theme.dart';
import 'package:sono/widgets/global/cached_artwork_image.dart';

class SongListTile extends StatelessWidget {
  final SongModel song;
  final Function(SongModel)? onSongTap;
  final Function(SongModel)? onArtistTap;
  final Widget? trailing;

  const SongListTile({
    super.key,
    required this.song,
    this.onSongTap,
    this.onArtistTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SongModel?>(
      valueListenable: SonoPlayer().currentSong,
      builder: (context, currentSong, child) {
        final bool isCurrentSong = currentSong?.id == song.id;

        final TextStyle titleStyle =
            isCurrentSong
                ? AppStyles.sonoPlayerTitle.copyWith(
                  color: const Color(0xFFFF4893),
                )
                : AppStyles.sonoPlayerTitle;

        final TextStyle artistStyle =
            isCurrentSong
                ? AppStyles.sonoPlayerArtist.copyWith(
                  color: const Color(0xFFFF4893).withAlpha((255 * 0.7).round()),
                )
                : AppStyles.sonoPlayerArtist;

        return ListTile(
          contentPadding: EdgeInsets.symmetric(
            horizontal: AppTheme.responsiveSpacing(context, AppTheme.spacing),
            vertical: 0,
          ),
          leading: CachedArtworkImage(
            id: song.id,
            size: AppTheme.responsiveDimension(context, 50),
            type: ArtworkType.AUDIO,
            borderRadius: BorderRadius.circular(12.0.r),
          ),
          title: Text(
            song.title,
            style: titleStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: InkWell(
            onTap: onArtistTap != null ? () => onArtistTap!(song) : null,
            child: Text(
              ArtistStringUtils.getShortDisplay(
                song.artist ?? 'Unknown',
                maxArtists: 2,
              ),
              style: artistStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          trailing:
              trailing ??
              IconButton(
                icon:
                    isCurrentSong
                        ? ValueListenableBuilder<bool>(
                          valueListenable: SonoPlayer().isPlaying,
                          builder: (context, isPlaying, _) {
                            return Icon(
                              isPlaying
                                  ? Icons.bar_chart_rounded
                                  : Icons.play_arrow_rounded,
                              color: const Color(0xFFFF4893),
                              size: 24,
                            );
                          },
                        )
                        : const Icon(
                          Icons.more_vert_rounded,
                          color: Colors.white70,
                        ),
                onPressed: () {
                  _showSongOptionsBottomSheet(context, song);
                },
              ),
          onTap: () {
            if (onSongTap != null) {
              onSongTap!(song);
            }
          },
        );
      },
    );
  }
}

void _showSongOptionsBottomSheet(BuildContext context, SongModel song) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(vertical: 12.h),
              child: Container(
                width: 40.w,
                height: 5.h,
                decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
            ),
            ListTile(
              leading: CachedArtworkImage(
                id: song.id,
                size: 50.w,
                type: ArtworkType.AUDIO,
                borderRadius: BorderRadius.circular(8.0.r),
              ),
              title: Text(
                song.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppStyles.sonoPlayerTitle,
              ),
              subtitle: Text(
                ArtistStringUtils.getShortDisplay(song.artist ?? 'Unknown'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppStyles.sonoPlayerArtist,
              ),
            ),
            const Divider(color: Colors.white24, indent: 20, endIndent: 20),
            ListTile(
              leading: const Icon(
                Icons.playlist_play_rounded,
                color: Colors.white70,
              ),
              title: const Text(
                "Play next",
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              onTap: () {
                Navigator.pop(context);
                SonoPlayer().addSongToPlayNext(song);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Playing next"),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 1),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.queue_music_rounded,
                color: Colors.white70,
              ),
              title: const Text(
                "Add to queue",
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              onTap: () {
                Navigator.pop(context);
                SonoPlayer().addSongsToQueue([song]);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Added to queue"),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 1),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.playlist_add_rounded,
                color: Colors.white70,
              ),
              title: const Text(
                "Add to playlist...",
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
                      child: AddToPlaylistSheet(song: song),
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
