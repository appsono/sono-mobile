import 'package:flutter/material.dart';
import 'package:sono/services/utils/album_artist_service.dart';
import 'package:sono/utils/artist_string_utils.dart';

/// Widget that displays proper album artist
class AlbumArtistText extends StatefulWidget {
  final int albumId;
  final String? fallbackArtist;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final int maxArtists;

  const AlbumArtistText({
    super.key,
    required this.albumId,
    this.fallbackArtist,
    this.style,
    this.maxLines,
    this.overflow,
    this.maxArtists = 2,
  });

  @override
  State<AlbumArtistText> createState() => _AlbumArtistTextState();
}

class _AlbumArtistTextState extends State<AlbumArtistText> {
  final AlbumArtistService _service = AlbumArtistService();
  String? _albumArtist;

  @override
  void initState() {
    super.initState();
    _loadAlbumArtist();
  }

  @override
  void didUpdateWidget(AlbumArtistText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.albumId != widget.albumId) {
      _loadAlbumArtist();
    }
  }

  Future<void> _loadAlbumArtist() async {
    //try to get from cache first for direct display
    final cached = _service.getCachedAlbumArtist(
      widget.albumId,
      widget.fallbackArtist,
    );

    if (mounted) {
      setState(() {
        _albumArtist = cached;
      });
    }

    //fetch actual value in background 
    //(will update if different from cache)
    final albumArtist = await _service.getAlbumArtist(
      widget.albumId,
      widget.fallbackArtist,
    );

    if (mounted && albumArtist != _albumArtist) {
      setState(() {
        _albumArtist = albumArtist;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayText = ArtistStringUtils.getShortDisplay(
      _albumArtist ?? widget.fallbackArtist ?? 'Unknown Artist',
      maxArtists: widget.maxArtists,
    );

    return Text(
      displayText,
      style: widget.style,
      maxLines: widget.maxLines,
      overflow: widget.overflow,
    );
  }
}
