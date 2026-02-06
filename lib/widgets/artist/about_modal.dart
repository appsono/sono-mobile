import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sono/styles/app_theme.dart';

class AboutModal extends StatelessWidget {
  final String artistName;
  final String bio;
  final int? monthlyListeners;
  final int? totalPlays;
  final String? artistUrl;

  const AboutModal({
    super.key,
    required this.artistName,
    required this.bio,
    this.monthlyListeners,
    this.totalPlays,
    this.artistUrl,
  });

  static Future<void> show(
    BuildContext context, {
    required String artistName,
    required String bio,
    int? monthlyListeners,
    int? totalPlays,
    String? artistUrl,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.9,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder:
                (context, scrollController) => AboutModal(
                  artistName: artistName,
                  bio: bio,
                  monthlyListeners: monthlyListeners,
                  totalPlays: totalPlays,
                  artistUrl: artistUrl,
                ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final numberFormat = NumberFormat.compact();
    final cleanBio = _cleanBioText(bio);

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          //drag handle
          Container(
            width: 40,
            height: 5,
            margin: const EdgeInsets.only(top: 12, bottom: 16),
            decoration: BoxDecoration(
              color: AppTheme.textTertiaryDark,
              borderRadius: BorderRadius.circular(2.5),
            ),
          ),

          //header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'About $artistName',
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      color: AppTheme.textPrimaryDark,
                      fontSize: AppTheme.fontHeading,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppTheme.textSecondaryDark,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppTheme.spacing),

          //stats row
          if (monthlyListeners != null || totalPlays != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing),
              child: Row(
                children: [
                  if (monthlyListeners != null) ...[
                    _buildStat(
                      value: numberFormat.format(monthlyListeners),
                      label: 'monthly listeners',
                    ),
                    const SizedBox(width: AppTheme.spacingXl),
                  ],
                  if (totalPlays != null)
                    _buildStat(
                      value: numberFormat.format(totalPlays),
                      label: 'total plays',
                    ),
                ],
              ),
            ),

          if (monthlyListeners != null || totalPlays != null)
            const SizedBox(height: AppTheme.spacingXl),

          //full bio text
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacing,
                vertical: AppTheme.spacingSm,
              ),
              child: Text(
                cleanBio,
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  color: AppTheme.textSecondaryDark,
                  fontSize: AppTheme.fontBody,
                  height: 1.7,
                ),
              ),
            ),
          ),

          //safe area padding at bottom
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }

  Widget _buildStat({required String value, required String label}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            color: AppTheme.textPrimaryDark,
            fontSize: AppTheme.fontDisplay,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            color: AppTheme.textSecondaryDark,
            fontSize: AppTheme.fontBody,
          ),
        ),
      ],
    );
  }

  String _cleanBioText(String text) {
    return text
        .replaceAll(
          RegExp(
            r'\s*Read more on Last\.fm.*',
            caseSensitive: false,
            dotAll: true,
          ),
          '',
        )
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .trim();
  }
}
