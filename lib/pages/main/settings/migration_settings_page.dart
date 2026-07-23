import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:sono/data/database/database_helper.dart';
import 'package:sono/services/migration/sono_export_service.dart';
import 'package:sono/styles/app_theme.dart';

class MigrationSettingsPage extends StatefulWidget {
  const MigrationSettingsPage({super.key});

  @override
  State<MigrationSettingsPage> createState() => _MigrationSettingsPageState();
}

class _MigrationSettingsPageState extends State<MigrationSettingsPage> {
  bool _busy = false;

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final json =
          await SonoExportService(SonoDatabaseHelper.instance).exportToJson();

      final now = DateTime.now();
      String p(int v) => v.toString().padLeft(2, '0');
      final stamp =
          '${now.year}${p(now.month)}${p(now.day)}'
          '${p(now.hour)}${p(now.minute)}';

      final path = await FilePicker.platform.saveFile(
        fileName: 'sono-migration-$stamp.json',
        bytes: utf8.encode(json),
      );

      _toast(path == null ? 'Export cancelled' : 'Saved');
    } catch (e) {
      _toast('Export failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundDark,
        title: const Text(
          'Move to the new Sono',
          style: TextStyle(fontFamily: 'VarelaRound'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _paragraph(
            'Sono has been rebuilt from scratch. The next release replaces '
            'this app entirely.',
          ),
          _paragraph(
            'If you install the new Sono from the Play Store, your data '
            'carries over on its own and you can ignore this page.',
          ),
          _paragraph(
            'If you use the APK from GitHub, export here and import the file '
            'in the new app under Settings, Backup.',
          ),
          const SizedBox(height: 8),
          _bullet('Liked songs'),
          _bullet('Playlists, including covers'),
          _bullet('Favorite albums and artists'),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _busy ? null : _export,
            icon:
                _busy
                    ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Symbols.download_rounded),
            label: Text(_busy ? 'Exporting' : 'Export my data'),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.brandPink,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _paragraph(
            'Nothing is deleted or changed. You can export as often as you '
            'like.',
            muted: true,
          ),
        ],
      ),
    );
  }

  Widget _paragraph(String text, {bool muted = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      text,
      style: TextStyle(
        color: Colors.white.withAlpha(((muted ? 0.5 : 0.8) * 255).round()),
        fontSize: 14,
        height: 1.45,
        fontFamily: 'VarelaRound',
      ),
    ),
  );

  Widget _bullet(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6, left: 4),
    child: Row(
      children: [
        Icon(Symbols.check_rounded, size: 16, color: AppTheme.brandPink),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontFamily: 'VarelaRound',
          ),
        ),
      ],
    ),
  );
}
