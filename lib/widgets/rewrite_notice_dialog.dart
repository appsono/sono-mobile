import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sono/pages/main/settings/migration_settings_page.dart';
import 'package:sono/styles/app_theme.dart';

class RewriteNoticeDialog extends StatelessWidget {
  const RewriteNoticeDialog({super.key});

  static const _seenKey = 'rewrite_notice_seen';

  static Future<void> maybeShow(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_seenKey) ?? false) return;
    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const RewriteNoticeDialog(),
    );
    await prefs.setBool(_seenKey, true);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.backgroundDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Symbols.auto_awesome_rounded,
                  color: AppTheme.brandPink,
                  size: 24,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Sono is being rebuilt',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'VarelaRound',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _text(
              'The next release replaces this app with a complete rewrite.',
            ),
            _text(
              'If you update from the Play Store, everything carries over on '
              'its own.',
            ),
            _text(
              'If you use the APK from GitHub, export your data first or it '
              'will not come along.',
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MigrationSettingsPage(),
                    ),
                  );
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.brandPink,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                ),
                child: const Text(
                  'Export my data',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'VarelaRound',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Later',
                  style: TextStyle(
                    color: Colors.white.withAlpha((0.6 * 255).round()),
                    fontSize: 15,
                    fontFamily: 'VarelaRound',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _text(String value) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      value,
      style: TextStyle(
        color: Colors.white.withAlpha((0.75 * 255).round()),
        fontSize: 14,
        height: 1.45,
        fontFamily: 'VarelaRound',
      ),
    ),
  );
}
