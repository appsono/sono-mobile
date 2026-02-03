import 'package:flutter/material.dart';
import 'package:sono/styles/app_theme.dart';

class ShuffleCreatePlaylistButtons extends StatelessWidget {
  final VoidCallback onShuffleAll;
  final VoidCallback onCreatePlaylist;

  const ShuffleCreatePlaylistButtons({
    super.key,
    required this.onShuffleAll,
    required this.onCreatePlaylist,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(AppTheme.responsiveSpacing(context, 16)),
      child: Row(
        children: [
          Expanded(
            child: _ActionButton(
              onTap: onShuffleAll,
              icon: Icons.shuffle_rounded,
              label: 'Shuffle all',
              isDark: true,
            ),
          ),
          SizedBox(
            width: AppTheme.responsiveSpacing(context, AppTheme.spacingSm),
          ),
          Expanded(
            child: _ActionButton(
              onTap: onCreatePlaylist,
              icon: Icons.add_rounded,
              label: 'Create Playlist',
              isDark: false,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final VoidCallback onTap;
  final IconData icon;
  final String label;
  final bool isDark;

  const _ActionButton({
    required this.onTap,
    required this.icon,
    required this.label,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final backgroundColor = isDark ? const Color(0xFF2A2A2A) : Colors.white;
    final foregroundColor = isDark ? Colors.white : AppTheme.cardDark;
    final borderColor =
        isDark ? Colors.white.withAlpha(25) : Colors.transparent;

    final borderRadius = AppTheme.responsiveDimension(
      context,
      AppTheme.radiusMd,
    );

    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(borderRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: AppTheme.responsiveSpacing(context, 16),
            vertical: AppTheme.responsiveSpacing(context, 14),
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: borderColor,
              width: AppTheme.responsiveDimension(context, 1),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Icon(
                icon,
                color: foregroundColor,
                size: AppTheme.responsiveIconSize(context, 20, min: 18),
              ),
              SizedBox(width: AppTheme.responsiveSpacing(context, 10)),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'VarelaRound',
                    fontSize: AppTheme.responsiveFontSize(context, 14, min: 12),
                    fontWeight: FontWeight.w600,
                    color: foregroundColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

@Deprecated('Use ShuffleCreatePlaylistButtons instead')
typedef ShuffleSearchButtons = ShuffleCreatePlaylistButtons;
