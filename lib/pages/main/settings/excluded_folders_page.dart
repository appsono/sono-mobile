import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:sono/services/settings/library_settings_service.dart';
import 'package:sono/styles/app_theme.dart';
import 'package:sono/widgets/global/bottom_sheet.dart';

/// excluded folders management page
class ExcludedFoldersPage extends StatefulWidget {
  const ExcludedFoldersPage({super.key});

  @override
  State<ExcludedFoldersPage> createState() => _ExcludedFoldersPageState();
}

class _ExcludedFoldersPageState extends State<ExcludedFoldersPage> {
  final LibrarySettingsService _librarySettings =
      LibrarySettingsService.instance;

  List<String> _excludedFolders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadExcludedFolders();
  }

  Future<void> _loadExcludedFolders() async {
    final folders = await _librarySettings.getExcludedFolders();
    setState(() {
      _excludedFolders = folders;
      _isLoading = false;
    });
  }

  Future<void> _addFolder() async {
    try {
      //use directory picker
      final result = await FilePicker.platform.getDirectoryPath();

      if (result != null) {
        await _librarySettings.addExcludedFolder(result);
        await _loadExcludedFolders();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Added: $result',
                style: const TextStyle(fontFamily: 'VarelaRound'),
              ),
              backgroundColor: AppTheme.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error adding folder: $e',
              style: const TextStyle(fontFamily: 'VarelaRound'),
            ),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _removeFolder(String folder) async {
    final confirmed = await showSonoBottomSheet<bool>(
      context: context,
      title: 'Remove Folder',
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.folder_off_rounded,
              size: 48,
              color: AppTheme.error.withAlpha((0.7 * 255).round()),
            ),
            const SizedBox(height: 16),
            Text(
              'Remove "$folder" from excluded folders?',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontFamily: 'VarelaRound',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Songs in this folder will appear in your library again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withAlpha((0.7 * 255).round()),
                fontSize: 14,
                fontFamily: 'VarelaRound',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            'CANCEL',
            style: TextStyle(
              color: Colors.white.withAlpha((0.7 * 255).round()),
              fontFamily: 'VarelaRound',
            ),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.error,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: const Text(
            'REMOVE',
            style: TextStyle(fontFamily: 'VarelaRound'),
          ),
        ),
      ],
    );

    if (confirmed == true) {
      await _librarySettings.removeExcludedFolder(folder);
      await _loadExcludedFolders();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Folder removed from exclusion list',
              style: TextStyle(fontFamily: 'VarelaRound'),
            ),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Excluded Folders',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontFamily: 'VarelaRound',
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _excludedFolders.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.folder_open_rounded,
                          size: 64,
                          color: Colors.white.withAlpha((0.3 * 255).round()),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No Excluded Folders',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontFamily: 'VarelaRound',
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add folders to exclude them from your music library',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withAlpha((0.7 * 255).round()),
                            fontFamily: 'VarelaRound',
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _addFolder,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.brandPink,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text(
                            'Add Folder',
                            style: TextStyle(fontFamily: 'VarelaRound'),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.info.withAlpha((0.1 * 255).round()),
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        border: Border.all(
                          color: AppTheme.info.withAlpha((0.3 * 255).round()),
                          width: 0.5,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_rounded,
                              size: 20,
                              color: AppTheme.info,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Songs in these folders will not appear in your library',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white.withAlpha((0.7 * 255).round()),
                                  fontFamily: 'VarelaRound',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    ..._excludedFolders.map((folder) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha((0.05 * 255).round()),
                            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                            border: Border.all(
                              color: Colors.white.withAlpha((0.1 * 255).round()),
                              width: 0.5,
                            ),
                          ),
                          child: ListTile(
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppTheme.brandPink.withAlpha((0.15 * 255).round()),
                                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                              ),
                              child: Icon(
                                Icons.folder_off_rounded,
                                color: AppTheme.brandPink,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              folder,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                                fontFamily: 'VarelaRound',
                              ),
                            ),
                            trailing: IconButton(
                              icon: Icon(
                                Icons.delete_rounded,
                                color: Colors.white.withAlpha((0.5 * 255).round()),
                              ),
                              tooltip: 'Remove',
                              onPressed: () => _removeFolder(folder),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
      floatingActionButton: _excludedFolders.isNotEmpty
          ? FloatingActionButton(
              onPressed: _addFolder,
              tooltip: 'Add Folder',
              backgroundColor: AppTheme.brandPink,
              foregroundColor: Colors.white,
              child: const Icon(Icons.add_rounded),
            )
          : null,
    );
  }
}