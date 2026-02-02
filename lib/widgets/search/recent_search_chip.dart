import 'package:flutter/material.dart';
import 'package:sono/models/search/recent_search_model.dart';
import 'package:sono/styles/app_theme.dart';

class RecentSearchChip extends StatelessWidget {
  /// Recent search to display
  final RecentSearch search;

  /// Callback when chip is tapped
  final VoidCallback onTap;

  /// Callback when delete button is tapped
  final VoidCallback onDelete;

  const RecentSearchChip({
    super.key,
    required this.search,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.elevatedSurfaceDark,
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingMd,
            vertical: AppTheme.spacingSm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.history_rounded,
                size: 18,
                color: Colors.white.withValues(alpha: 0.5),
              ),
              const SizedBox(width: AppTheme.spacingSm),

              Flexible(
                child: Text(
                  search.query,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: AppTheme.fontBody,
                    fontFamily: 'VarelaRound',
                  ),
                ),
              ),

              const SizedBox(width: AppTheme.spacingSm),

              InkWell(
                onTap: onDelete,
                borderRadius: BorderRadius.circular(AppTheme.radiusCircle),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
