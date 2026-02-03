import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:sono/services/utils/artwork_cache_service.dart';

class CachedArtworkImage extends StatefulWidget {
  final int id;
  final double size;
  final ArtworkType type;
  final BorderRadius? borderRadius;

  const CachedArtworkImage({
    super.key,
    required this.id,
    required this.size,
    this.type = ArtworkType.AUDIO,
    this.borderRadius,
  });

  @override
  State<CachedArtworkImage> createState() => _CachedArtworkImageState();
}

class _CachedArtworkImageState extends State<CachedArtworkImage> {
  @override
  Widget build(BuildContext context) {
    final double devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
    int requestSize = (widget.size * devicePixelRatio).round();

    if (widget.type == ArtworkType.ALBUM) {
      requestSize = requestSize.clamp(300, 600);
    }

    return RepaintBoundary(
      child: FutureBuilder<Uint8List?>(
        future: ArtworkCacheService.instance.getArtwork(
          widget.id,
          type: widget.type,
          size: requestSize,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done &&
              snapshot.hasData &&
              snapshot.data != null) {
            Widget imageWidget = Image.memory(
              snapshot.data!,
              width: widget.size,
              height: widget.size,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              filterQuality: FilterQuality.high,
              cacheWidth: requestSize,
              cacheHeight: requestSize,
            );

            return widget.borderRadius != null
                ? ClipRRect(
                  borderRadius: widget.borderRadius!,
                  child: imageWidget,
                )
                : imageWidget;
          }

          return Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: widget.borderRadius,
            ),
            child: Icon(
              widget.type == ArtworkType.ARTIST
                  ? Icons.person_rounded
                  : Icons.music_note_rounded,
              color: const Color(0xFF666666),
              size: widget.size * 0.35,
            ),
          );
        },
      ),
    );
  }
}