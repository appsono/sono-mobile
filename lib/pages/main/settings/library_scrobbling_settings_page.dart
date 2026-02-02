import 'package:flutter/material.dart';
import 'package:sono/styles/app_theme.dart';
import 'package:sono/services/settings/library_settings_service.dart';
import 'package:sono/services/api/lastfm_service.dart';
import 'package:sono/services/utils/preferences_service.dart';
import 'package:sono/widgets/global/bottom_sheet.dart';
import 'package:sono/widgets/global/skeleton_loader.dart';
import 'excluded_folders_page.dart';

/// Library & Scrobbling Settings Page
class LibraryScrobblingSettingsPage extends StatefulWidget {
  const LibraryScrobblingSettingsPage({super.key});

  @override
  State<LibraryScrobblingSettingsPage> createState() =>
      _LibraryScrobblingSettingsPageState();
}

class _LibraryScrobblingSettingsPageState
    extends State<LibraryScrobblingSettingsPage> {
  final LibrarySettingsService _librarySettings =
      LibrarySettingsService.instance;
  final LastfmService _lastfmService = LastfmService();
  final PreferencesService _prefsService = PreferencesService();

  List<String> _excludedFolders = [];
  bool _isLoadingLastfm = true;
  bool _isLastfmLoggedIn = false;
  String? _lastfmUsername;
  bool _isLastfmLoggingIn = false;
  bool _isScrobblingEnabled = false;

  final TextEditingController _lastfmUserController = TextEditingController();
  final TextEditingController _lastfmPasswordController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _lastfmUserController.dispose();
    _lastfmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoadingLastfm = true;
    });

    final folders = await _librarySettings.getExcludedFolders();
    setState(() {
      _excludedFolders = folders;
    });

    final lastfmLoggedIn = await _lastfmService.validateSession();
    String? username;
    if (lastfmLoggedIn) {
      username = await _lastfmService.getUserName();
    }
    final scrobblingEnabled = await _prefsService.isLastfmScrobblingEnabled();

    setState(() {
      _isLastfmLoggedIn = lastfmLoggedIn;
      _lastfmUsername = username;
      _isScrobblingEnabled = scrobblingEnabled;
      _isLoadingLastfm = false;
    });
  }

  void _showLastfmLoginDialog() {
    showSonoBottomSheet(
      context: context,
      title: "Connect to Last.fm",
      child: StatefulBuilder(
        builder: (context, setDialogState) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _lastfmUserController,
                  enabled: !_isLastfmLoggingIn,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'VarelaRound',
                  ),
                  decoration: InputDecoration(
                    labelText: 'Username',
                    labelStyle: TextStyle(
                      color: Colors.white.withAlpha((0.7 * 255).round()),
                      fontFamily: 'VarelaRound',
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: Colors.white.withAlpha((0.3 * 255).round()),
                      ),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: AppTheme.brandPink),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    prefixIcon: Icon(
                      Icons.person_rounded,
                      color:
                          _isLastfmLoggingIn
                              ? Colors.white.withAlpha((0.3 * 255).round())
                              : Colors.white.withAlpha((0.7 * 255).round()),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _lastfmPasswordController,
                  enabled: !_isLastfmLoggingIn,
                  obscureText: true,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'VarelaRound',
                  ),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    labelStyle: TextStyle(
                      color: Colors.white.withAlpha((0.7 * 255).round()),
                      fontFamily: 'VarelaRound',
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: Colors.white.withAlpha((0.3 * 255).round()),
                      ),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: AppTheme.brandPink),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    prefixIcon: Icon(
                      Icons.lock_rounded,
                      color:
                          _isLastfmLoggingIn
                              ? Colors.white.withAlpha((0.3 * 255).round())
                              : Colors.white.withAlpha((0.7 * 255).round()),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
      actions: [
        TextButton(
          onPressed:
              _isLastfmLoggingIn
                  ? null
                  : () {
                    _lastfmUserController.clear();
                    _lastfmPasswordController.clear();
                    Navigator.of(context).pop();
                  },
          child: Text(
            "CANCEL",
            style: TextStyle(
              color: Colors.white.withAlpha((0.7 * 255).round()),
              fontFamily: 'VarelaRound',
            ),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: _isLastfmLoggingIn ? null : _handleLastfmLogin,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.brandPink,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child:
              _isLastfmLoggingIn
                  ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                  : const Text(
                    "LOGIN",
                    style: TextStyle(fontFamily: 'VarelaRound'),
                  ),
        ),
      ],
    );
  }

  Future<void> _handleLastfmLogin() async {
    final username = _lastfmUserController.text.trim();
    final password = _lastfmPasswordController.text;

    if (username.isEmpty || password.isEmpty) {
      _showSnackBar(
        message: "Please enter both username and password.",
        isError: true,
      );
      return;
    }

    setState(() => _isLastfmLoggingIn = true);

    try {
      final success = await _lastfmService.authenticateDirect(
        username,
        password,
      );

      if (success) {
        _lastfmUserController.clear();
        _lastfmPasswordController.clear();
        if (mounted) Navigator.of(context).pop();
        await _loadSettings();

        _showSnackBar(
          message: "Connected to Last.fm as $username!",
          isError: false,
        );
      } else {
        throw Exception("Authentication failed");
      }
    } catch (e) {
      String errorMessage = 'Last.fm connection failed';
      if (e.toString().contains('Invalid username or password')) {
        errorMessage = 'Invalid username or password';
      } else if (e.toString().contains('network')) {
        errorMessage = 'Network error. Please check your connection.';
      } else if (e.toString().contains('timeout')) {
        errorMessage = 'Connection timeout. Please try again.';
      }
      _showSnackBar(message: errorMessage, isError: true);
    } finally {
      if (mounted) setState(() => _isLastfmLoggingIn = false);
    }
  }

  Future<void> _handleLastfmLogout() async {
    try {
      await _lastfmService.clearSessionDetails();
      await _loadSettings();
      _showSnackBar(message: "Disconnected from Last.fm", isError: false);
    } catch (e) {
      _showSnackBar(
        message: "Failed to disconnect from Last.fm",
        isError: true,
      );
    }
  }

  void _showSnackBar({required String message, required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontFamily: 'VarelaRound'),
        ),
        backgroundColor: isError ? AppTheme.error : AppTheme.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Library & Scrobbling',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontFamily: 'VarelaRound',
          ),
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'LIBRARY',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              fontFamily: 'VarelaRound',
            ),
          ),
          const SizedBox(height: 12),
          _buildNavigationTile(
            icon: Icons.folder_off_rounded,
            title: 'Excluded Folders',
            subtitle:
                _excludedFolders.isEmpty
                    ? 'No folders excluded'
                    : '${_excludedFolders.length} folder(s) excluded',
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ExcludedFoldersPage(),
                ),
              );
              _loadSettings();
            },
          ),
          const SizedBox(height: 24),
          const Text(
            'LAST.FM SCROBBLING',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              fontFamily: 'VarelaRound',
            ),
          ),
          const SizedBox(height: 12),
          if (_isLoadingLastfm) ...[
            const SkeletonListTile(),
            const SizedBox(height: 8),
            const SkeletonListTile(),
          ] else ...[
            _buildLastfmTile(),
            const SizedBox(height: 8),
            _buildSwitchTile(
              icon: Icons.multitrack_audio_rounded,
              title: 'Enable Scrobbling',
              subtitle:
                  _isScrobblingEnabled
                      ? 'Your tracks will be scrobbled to Last.fm'
                      : 'Scrobbling is disabled',
              value: _isScrobblingEnabled,
              enabled: _isLastfmLoggedIn,
              onChanged: (value) async {
                await _prefsService.setLastfmScrobblingEnabled(value);
                setState(() => _isScrobblingEnabled = value);
                _showSnackBar(
                  message: value ? 'Scrobbling enabled' : 'Scrobbling disabled',
                  isError: false,
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNavigationTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha((0.05 * 255).round()),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(
              color: Colors.white.withAlpha((0.1 * 255).round()),
              width: 0.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha((0.1 * 255).round()),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Icon(
                  icon,
                  color: Colors.white.withAlpha((0.7 * 255).round()),
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'VarelaRound',
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withAlpha((0.7 * 255).round()),
                        fontSize: 14,
                        fontFamily: 'VarelaRound',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white.withAlpha((0.5 * 255).round()),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLastfmTile() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (_isLastfmLoggedIn) {
            showDialog(
              context: context,
              builder:
                  (context) => AlertDialog(
                    backgroundColor: AppTheme.backgroundDark,
                    title: const Text(
                      'Disconnect from Last.fm?',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'VarelaRound',
                      ),
                    ),
                    content: Text(
                      'This will stop scrobbling your tracks.',
                      style: TextStyle(
                        color: Colors.white.withAlpha((0.8 * 255).round()),
                        fontFamily: 'VarelaRound',
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(fontFamily: 'VarelaRound'),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _handleLastfmLogout();
                        },
                        child: const Text(
                          'Disconnect',
                          style: TextStyle(fontFamily: 'VarelaRound'),
                        ),
                      ),
                    ],
                  ),
            );
          } else {
            _showLastfmLoginDialog();
          }
        },
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha((0.05 * 255).round()),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(
              color: Colors.white.withAlpha((0.1 * 255).round()),
              width: 0.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color:
                      _isLastfmLoggedIn
                          ? AppTheme.success.withAlpha((0.15 * 255).round())
                          : Colors.white.withAlpha((0.1 * 255).round()),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Icon(
                  _isLastfmLoggedIn
                      ? Icons.check_circle_outline
                      : Icons.music_note_rounded,
                  color:
                      _isLastfmLoggedIn
                          ? AppTheme.success
                          : Colors.white.withAlpha((0.7 * 255).round()),
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isLastfmLoggedIn
                          ? 'Last.fm Connected'
                          : 'Connect Last.fm',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'VarelaRound',
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isLastfmLoggedIn
                          ? 'Connected as ${_lastfmUsername ?? "Unknown"}'
                          : 'Scrobble your music to Last.fm',
                      style: TextStyle(
                        color: Colors.white.withAlpha((0.7 * 255).round()),
                        fontSize: 14,
                        fontFamily: 'VarelaRound',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                _isLastfmLoggedIn ? Icons.logout_rounded : Icons.login_rounded,
                color: Colors.white.withAlpha((0.5 * 255).round()),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
    bool enabled = true,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withAlpha((0.05 * 255).round()),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: Colors.white.withAlpha((0.1 * 255).round()),
          width: 0.5,
        ),
      ),
      child: SwitchListTile(
        secondary: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color:
                value && enabled
                    ? AppTheme.brandPink.withAlpha((0.15 * 255).round())
                    : Colors.white.withAlpha((0.1 * 255).round()),
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          ),
          child: Icon(
            icon,
            color:
                value && enabled
                    ? AppTheme.brandPink
                    : Colors.white.withAlpha(
                      ((enabled ? 0.7 : 0.3) * 255).round(),
                    ),
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            color:
                enabled
                    ? Colors.white
                    : Colors.white.withAlpha((0.5 * 255).round()),
            fontFamily: 'VarelaRound',
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: Colors.white.withAlpha(
              ((enabled ? 0.7 : 0.4) * 255).round(),
            ),
            fontFamily: 'VarelaRound',
          ),
        ),
        value: value,
        activeTrackColor: AppTheme.brandPink.withAlpha((0.5 * 255).round()),
        activeThumbColor: AppTheme.brandPink,
        onChanged: enabled ? onChanged : null,
      ),
    );
  }
}