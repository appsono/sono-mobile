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
  Future<Uint8List?>? _artworkFuture;
  int _requestSize = 0;
  int _lastId = -1;
  ArtworkType? _lastType;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initializeFuture();
  }

  @override
  void didUpdateWidget(CachedArtworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id ||
        oldWidget.type != widget.type ||
        oldWidget.size != widget.size) {
      _initializeFuture();
    }
  }

  void _initializeFuture() {
    final double devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
    int newRequestSize = (widget.size * devicePixelRatio).round();

    if (widget.type == ArtworkType.ALBUM) {
      newRequestSize = newRequestSize.clamp(300, 600);
    }

    if (_artworkFuture != null &&
        _requestSize == newRequestSize &&
        _lastId == widget.id &&
        _lastType == widget.type) {
      return;
    }

    _requestSize = newRequestSize;
    _lastId = widget.id;
    _lastType = widget.type;
    _artworkFuture = ArtworkCacheService.instance.getArtwork(
      widget.id,
      type: widget.type,
      size: _requestSize,
    );
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: FutureBuilder<Uint8List?>(
        future: _artworkFuture,
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
              cacheWidth: _requestSize,
              cacheHeight: _requestSize,
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
