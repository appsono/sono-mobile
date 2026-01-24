import 'package:flutter/material.dart';
import 'playlist_migration_service.dart';

/// Service for initializing playlist system and running migration
/// Shows notifications to user during migration process
class PlaylistInitializationService {
  final PlaylistMigrationService _migrationService = PlaylistMigrationService();

  bool _isInitialized = false;
  bool _isMigrating = false;

  bool get isInitialized => _isInitialized;
  bool get isMigrating => _isMigrating;

  /// Initialize playlist system (call on app startup)
  /// Shows notification to user during migration
  Future<void> initialize(BuildContext context) async {
    if (_isInitialized) {
      debugPrint('PlaylistInitializationService: Already initialized');
      return;
    }

    try {
      //check if migration is needed
      final needsMigration = !await _migrationService.isMigrationComplete();

      if (!needsMigration) {
        debugPrint('PlaylistInitializationService: No migration needed');
        _isInitialized = true;
        return;
      }

      //start migration in background
      _isMigrating = true;
      if (context.mounted) {
        _showMigrationNotification(context);
      }

      //run migration
      final result = await _migrationService.migrate();

      //hide notification
      _isMigrating = false;

      //show result notification
      if (!context.mounted) return;

      if (result['success'] == true) {
        _showMigrationSuccessNotification(
          context,
          playlistCount: result['playlistCount'] ?? 0,
          songCount: result['songCount'] ?? 0,
        );

        //clean up old SharedPreferences data after successful migration
        await _migrationService.cleanupOldData();
      } else {
        _showMigrationErrorNotification(
          context,
          result['error'] ?? 'Unknown error',
        );
      }

      _isInitialized = true;
    } catch (e) {
      debugPrint(
        'PlaylistInitializationService: Error during initialization: $e',
      );
      _isMigrating = false;
      if (context.mounted) {
        _showMigrationErrorNotification(context, e.toString());
      }
      _isInitialized = true; //continue anyway
    }
  }

  /// Show notification while migration is in progress
  void _showMigrationNotification(BuildContext context) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(width: 16),
            Text('Migrating playlists...'),
          ],
        ),
        duration: Duration(seconds: 30), //Long duration
        backgroundColor: Theme.of(context).primaryColor,
      ),
    );
  }

  /// Show success notification after migration
  void _showMigrationSuccessNotification(
    BuildContext context, {
    required int playlistCount,
    required int songCount,
  }) {
    if (!context.mounted) return;

    //dismiss any existing snackbar
    ScaffoldMessenger.of(context).clearSnackBars();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Migrated $playlistCount ${playlistCount == 1 ? 'playlist' : 'playlists'} with $songCount ${songCount == 1 ? 'song' : 'songs'}',
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 4),
      ),
    );
  }

  /// Show error notification if migration fails
  void _showMigrationErrorNotification(BuildContext context, String error) {
    if (!context.mounted) return;

    //dismiss any existing snackbar
    ScaffoldMessenger.of(context).clearSnackBars();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.warning_rounded, color: Colors.white),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Playlist migration had issues. Some playlists may not have migrated.',
              ),
            ),
          ],
        ),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 6),
        action: SnackBarAction(
          label: 'Details',
          textColor: Colors.white,
          onPressed: () {
            debugPrint(
              'PlaylistInitializationService: Migration error: $error',
            );
          },
        ),
      ),
    );
  }

  /// Get initialization status for debugging
  Map<String, dynamic> getStatus() {
    return {'isInitialized': _isInitialized, 'isMigrating': _isMigrating};
  }

  /// Retry migration (for manual retry from settings)
  Future<Map<String, dynamic>> retryMigration(BuildContext context) async {
    if (_isMigrating) {
      return {'success': false, 'error': 'Migration already in progress'};
    }

    try {
      _isMigrating = true;
      if (context.mounted) {
        _showMigrationNotification(context);
      }

      final result = await _migrationService.migrate();

      _isMigrating = false;

      if (!context.mounted) return result;

      if (result['success'] == true) {
        _showMigrationSuccessNotification(
          context,
          playlistCount: result['playlistCount'] ?? 0,
          songCount: result['songCount'] ?? 0,
        );
      } else {
        _showMigrationErrorNotification(
          context,
          result['error'] ?? 'Unknown error',
        );
      }

      return result;
    } catch (e) {
      _isMigrating = false;
      if (context.mounted) {
        _showMigrationErrorNotification(context, e.toString());
      }
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Get migration statistics
  Future<Map<String, dynamic>> getMigrationStats() async {
    return await _migrationService.getMigrationStats();
  }
}