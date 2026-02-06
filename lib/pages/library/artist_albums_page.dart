import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:sono/pages/library/album_page.dart';
import 'package:sono/styles/app_theme.dart';

class ArtistAlbumsPage extends StatelessWidget {
  final String artistName;
  final List<AlbumModel> albums;
  final List<AlbumModel> eps;
  final OnAudioQuery audioQuery;

  const ArtistAlbumsPage({
    super.key,
    required this.artistName,
    required this.albums,
    required this.eps,
    required this.audioQuery,
  });

  @override
  Widget build(BuildContext context) {
    //only show albums and EPs (4+ songs) filter out singles
    final allReleases = [
      ...albums,
      ...eps.where((album) => album.numOfSongs >= 4),
    ];

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: Text(
          'Albums & EPs',
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            color: AppTheme.textPrimaryDark,
            fontSize: AppTheme.fontTitle,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppTheme.elevatedSurfaceDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppTheme.textPrimaryDark,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body:
          allReleases.isEmpty
              ? Center(
                child: Text(
                  'No albums or EPs found',
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    color: AppTheme.textSecondaryDark,
                    fontSize: AppTheme.fontBody,
                  ),
                ),
              )
              : ListView.builder(
                padding: const EdgeInsets.all(AppTheme.spacing),
                itemCount: allReleases.length,
                itemBuilder: (context, index) {
                  final album = allReleases[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppTheme.spacingMd),
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder:
                                (context) => AlbumPage(
                                  album: album,
                                  audioQuery: audioQuery,
                                ),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      child: Row(
                        children: [
                          //album artwork
                          ClipRRect(
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusSm,
                            ),
                            child: SizedBox(
                              width: 80,
                              height: 80,
                              child: QueryArtworkWidget(
                                id: album.id,
                                type: ArtworkType.ALBUM,
                                nullArtworkWidget: Container(
                                  color: AppTheme.elevatedSurfaceDark,
                                  child: const Center(
                                    child: Icon(
                                      Icons.album_rounded,
                                      color: AppTheme.textTertiaryDark,
                                      size: 32,
                                    ),
                                  ),
                                ),
                                artworkFit: BoxFit.cover,
                                artworkBorder: BorderRadius.zero,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppTheme.spacingMd),
                          //album info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  album.album,
                                  style: const TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    color: AppTheme.textPrimaryDark,
                                    fontSize: AppTheme.font,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${album.numOfSongs} ${album.numOfSongs == 1 ? 'song' : 'songs'}',
                                  style: const TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    color: AppTheme.textSecondaryDark,
                                    fontSize: AppTheme.fontSm,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
    );
  }
}
