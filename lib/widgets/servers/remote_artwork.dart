import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:sono/services/servers/server_protocol.dart';
import 'package:sono/styles/app_theme.dart';

/// Displays cover art from a remote music server
class RemoteArtwork extends StatelessWidget {
  final String? coverArtId;
  final MusicServerProtocol protocol;
  final double size;
  final BorderRadius? borderRadius;
  final IconData fallbackIcon;

  const RemoteArtwork({
    super.key,
    required this.coverArtId,
    required this.protocol,
    this.size = 50,
    this.borderRadius,
    this.fallbackIcon = Icons.album_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(AppTheme.radiusSm);

    if (coverArtId == null || coverArtId!.isEmpty) {
      return _buildFallback(radius);
    }

    final url = protocol.getCoverArtUrl(coverArtId!, size: size.toInt() * 2);

    return ClipRRect(
      borderRadius: radius,
      child: CachedNetworkImage(
        imageUrl: url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (context, url) => _buildFallback(radius, clip: false),
        errorWidget: (context, url, error) =>
            _buildFallback(radius, clip: false),
      ),
    );
  }

  Widget _buildFallback(BorderRadius radius, {bool clip = true}) {
    final child = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withAlpha((0.1 * 255).round()),
        borderRadius: clip ? radius : null,
      ),
      child: Icon(
        fallbackIcon,
        color: Colors.white.withAlpha((0.4 * 255).round()),
        size: size * 0.4,
      ),
    );
    return child;
  }
}
