import 'package:flutter/material.dart';
import 'package:sono/models/search/search_item.dart';
import 'package:sono/styles/app_theme.dart';

class SearchSectionHeader extends StatelessWidget {
  /// Type of items in this section
  final SearchItemType type;

  /// Number of results in this section
  final int count;

  /// Total number of results => before pagination/limiting
  final int totalCount;

  /// Callback when "View All" is tapped
  final VoidCallback? onViewAll;

  /// Whether the section is collapsed
  final bool isCollapsed;

  /// Callback when collapse toggle is tapped
  final VoidCallback? onToggleCollapse;

  const SearchSectionHeader({
    super.key,
    required this.type,
    required this.count,
    this.totalCount = 0,
    this.onViewAll,
    this.isCollapsed = false,
    this.onToggleCollapse,
  });

  @override
  Widget build(BuildContext context) {
    final title = _getTitle();
    final displayCount = totalCount > 0 ? totalCount : count;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing,
        vertical: AppTheme.spacingSm,
      ),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: AppTheme.fontSubtitle,
              fontWeight: FontWeight.w600,
              fontFamily: 'VarelaRound',
              color: Colors.white,
            ),
          ),

          const SizedBox(width: AppTheme.spacingSm),

          if (displayCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingSm,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: AppTheme.brandPink.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Text(
                '$displayCount',
                style: TextStyle(
                  fontSize: AppTheme.fontSm,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.brandPink,
                  fontFamily: 'VarelaRound',
                ),
              ),
            ),

          const Spacer(),

          if (onToggleCollapse != null)
            InkWell(
              onTap: onToggleCollapse,
              borderRadius: BorderRadius.circular(AppTheme.radiusCircle),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  isCollapsed
                      ? Icons.expand_more_rounded
                      : Icons.expand_less_rounded,
                  size: 20,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ),

          if (onViewAll != null && !isCollapsed)
            InkWell(
              onTap: onViewAll,
              borderRadius: BorderRadius.circular(AppTheme.radius),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingSm,
                  vertical: 4,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View All',
                      style: TextStyle(
                        fontSize: AppTheme.fontSm,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondaryDark,
                        fontFamily: 'VarelaRound',
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: AppTheme.textSecondaryDark,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _getTitle() {
    switch (type) {
      case SearchItemType.song:
        return count == 1 ? 'Song' : 'Songs';
      case SearchItemType.album:
        return count == 1 ? 'Album' : 'Albums';
      case SearchItemType.artist:
        return count == 1 ? 'Artist' : 'Artists';
    }
  }
}
