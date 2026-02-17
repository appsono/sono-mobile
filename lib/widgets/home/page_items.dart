import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sono/utils/artist_string_utils.dart';
import 'package:sono/styles/text.dart';
import 'package:sono/styles/app_theme.dart';
import 'package:sono/pages/library/album_page.dart';
import 'package:sono/pages/library/artist_page.dart';
import 'package:sono/widgets/library/artist_artwork_widget.dart';
import 'package:sono/widgets/library/album_artist_text.dart';

class HomePageSongItem extends StatelessWidget {
  final SongModel song;
  final double artworkSize;
  final Function(SongModel) onSongTap;

  const HomePageSongItem({
    super.key,
    required this.song,
    this.artworkSize = 70.0,
    required this.onSongTap,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;
    final isLargeScreen = screenWidth > 600;
    final responsiveSize = isDesktop
        ? artworkSize.clamp(100.0, 160.0)
        : isLargeScreen
        ? artworkSize.clamp(80.0, 140.0)
        : AppTheme.responsiveArtworkSize(context, artworkSize);
    final borderRadius = isLargeScreen ? 14.0 : 12.0.r;
    return InkWell(
      onTap: () => onSongTap(song),
      child: SizedBox(
        width: responsiveSize,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(borderRadius),
              child: QueryArtworkWidget(
                id: song.id,
                type: ArtworkType.AUDIO,
                artworkWidth: responsiveSize,
                artworkHeight: responsiveSize,
                artworkFit: BoxFit.cover,
                artworkBorder: BorderRadius.circular(borderRadius),
                keepOldArtwork: true,
                nullArtworkWidget: Container(
                  width: responsiveSize,
                  height: responsiveSize,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade800,
                    borderRadius: BorderRadius.circular(borderRadius),
                  ),
                  child: Icon(
                    Icons.music_note_rounded,
                    color: Colors.white54,
                    size: AppTheme.responsiveIconSize(context, 30.0, min: 24.0),
                  ),
                ),
              ),
            ),
            SizedBox(height: AppTheme.responsiveSpacing(context, isLargeScreen ? 6.0 : 4.0)),
            Flexible(
              child: Text(
                song.title,
                style: AppStyles.sonoPlayerTitle.copyWith(
                  fontSize: isLargeScreen ? 14.0 : AppTheme.responsiveFontSize(context, 12.0, min: 10.0),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Flexible(
              child: Text(
                ArtistStringUtils.getShortDisplay(song.artist ?? 'Unknown'),
                style: AppStyles.sonoPlayerArtist.copyWith(
                  fontSize: isLargeScreen ? 12.0 : AppTheme.responsiveFontSize(context, 10.0, min: 9.0),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomePageAlbumItem extends StatelessWidget {
  final AlbumModel album;
  final double artworkSize;
  final OnAudioQuery audioQuery;

  const HomePageAlbumItem({
    super.key,
    required this.album,
    this.artworkSize = 110.0,
    required this.audioQuery,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;
    final isLargeScreen = screenWidth > 600;
    final responsiveSize = isDesktop
        ? artworkSize.clamp(140.0, 200.0)
        : isLargeScreen
        ? artworkSize.clamp(120.0, 180.0)
        : AppTheme.responsiveArtworkSize(context, artworkSize);
    final borderRadius = isLargeScreen ? 16.0 : 12.0.r;
    return InkWell(
      onTap:
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => AlbumPage(album: album, audioQuery: audioQuery),
            ),
          ),
      child: SizedBox(
        width: responsiveSize,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(borderRadius),
              child: QueryArtworkWidget(
                id: album.id,
                type: ArtworkType.ALBUM,
                artworkWidth: responsiveSize,
                artworkHeight: responsiveSize,
                artworkFit: BoxFit.cover,
                artworkBorder: BorderRadius.circular(borderRadius),
                keepOldArtwork: true,
                nullArtworkWidget: Container(
                  width: responsiveSize,
                  height: responsiveSize,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade800,
                    borderRadius: BorderRadius.circular(borderRadius),
                  ),
                  child: Icon(
                    Icons.album_rounded,
                    color: Colors.white54,
                    size: AppTheme.responsiveIconSize(context, 40.0, min: 32.0),
                  ),
                ),
              ),
            ),
            SizedBox(height: AppTheme.responsiveSpacing(context, isLargeScreen ? 8.0 : 4.0)),
            Flexible(
              child: Text(
                album.album,
                style: AppStyles.sonoPlayerTitle.copyWith(
                  fontSize: isLargeScreen ? 15.0 : AppTheme.responsiveFontSize(context, 12.0, min: 10.0),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Flexible(
              child: AlbumArtistText(
                albumId: album.id,
                fallbackArtist: album.artist,
                style: AppStyles.sonoPlayerArtist.copyWith(
                  fontSize: isLargeScreen ? 13.0 : AppTheme.responsiveFontSize(context, 10.0, min: 9.0),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomePageArtistItem extends StatelessWidget {
  final ArtistModel artist;
  final double diameter;
  final OnAudioQuery audioQuery;

  const HomePageArtistItem({
    super.key,
    required this.artist,
    this.diameter = 80.0,
    required this.audioQuery,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;
    final isLargeScreen = screenWidth > 600;
    final responsiveDiameter = isDesktop
        ? diameter.clamp(110.0, 160.0)
        : isLargeScreen
        ? diameter.clamp(90.0, 140.0)
        : AppTheme.responsiveArtworkSize(context, diameter);
    return InkWell(
      onTap:
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) =>
                      ArtistPage(artist: artist, audioQuery: audioQuery),
            ),
          ),
      child: SizedBox(
        width: responsiveDiameter,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: responsiveDiameter,
              height: responsiveDiameter,
              child: ArtistArtworkWidget(
                artistName: artist.artist,
                artistId: artist.id,
                borderRadius: BorderRadius.circular(responsiveDiameter / 2),
              ),
            ),
            SizedBox(height: AppTheme.responsiveSpacing(context, isLargeScreen ? 8.0 : 6.0)),
            Flexible(
              child: Text(
                artist.artist,
                style: AppStyles.sonoPlayerTitle.copyWith(
                  fontSize: isLargeScreen ? 14.0 : AppTheme.responsiveFontSize(context, 12.0, min: 10.0),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
