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
    final responsiveSize = AppTheme.responsiveArtworkSize(context, artworkSize);
    final borderRadius = 12.0.r;
    return InkWell(
      onTap: () => onSongTap(song),
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
                  size: AppTheme.responsiveIconSize(context, 30, min: 24),
                ),
              ),
            ),
          ),
          SizedBox(height: AppTheme.responsiveSpacing(context, 6)),
          Text(
            song.title,
            style: AppStyles.sonoPlayerTitle.copyWith(
              fontSize: AppTheme.responsiveFontSize(context, 12, min: 10),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            ArtistStringUtils.getShortDisplay(song.artist ?? 'Unknown'),
            style: AppStyles.sonoPlayerArtist.copyWith(
              fontSize: AppTheme.responsiveFontSize(context, 10, min: 9),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
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
    final responsiveSize = AppTheme.responsiveArtworkSize(context, artworkSize);
    final borderRadius = 12.0.r;
    return InkWell(
      onTap:
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => AlbumPage(album: album, audioQuery: audioQuery),
            ),
          ),
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
                  size: AppTheme.responsiveIconSize(context, 40, min: 32),
                ),
              ),
            ),
          ),
          SizedBox(height: AppTheme.responsiveSpacing(context, 6)),
          Text(
            album.album,
            style: AppStyles.sonoPlayerTitle.copyWith(
              fontSize: AppTheme.responsiveFontSize(context, 12, min: 10),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          AlbumArtistText(
            albumId: album.id,
            fallbackArtist: album.artist,
            style: AppStyles.sonoPlayerArtist.copyWith(
              fontSize: AppTheme.responsiveFontSize(context, 10, min: 9),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
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
    final responsiveDiameter = AppTheme.responsiveArtworkSize(
      context,
      diameter,
    );
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
          SizedBox(height: AppTheme.responsiveSpacing(context, 8)),
          SizedBox(
            width: responsiveDiameter,
            child: Text(
              artist.artist,
              style: AppStyles.sonoPlayerTitle.copyWith(
                fontSize: AppTheme.responsiveFontSize(context, 12, min: 10),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
