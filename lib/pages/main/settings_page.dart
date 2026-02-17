import 'package:flutter/material.dart';
import 'package:sono/widgets/global/page_header.dart';
import 'package:sono/styles/app_theme.dart';
import 'package:sono/pages/main/settings/general_settings_page.dart';
import 'package:sono/pages/main/settings/playback_audio_settings_page.dart';
import 'package:sono/pages/main/settings/library_scrobbling_settings_page.dart';
import 'package:sono/pages/main/settings/account_settings_page.dart';
import 'package:sono/pages/main/settings/developer_settings_page.dart';
import 'package:sono/pages/main/settings/about_settings_page.dart';
import 'package:sono/widgets/global/content_constraint.dart';

/// main settings page
class SettingsPage extends StatelessWidget {
  final VoidCallback? onMenuTap;
  final Map<String, dynamic>? currentUser;
  final bool isLoggedIn;

  const SettingsPage({
    super.key,
    this.onMenuTap,
    this.currentUser,
    this.isLoggedIn = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: Column(
        children: [
          GlobalPageHeader(
            pageTitle: "Settings",
            onMenuTap: onMenuTap,
            currentUser: currentUser,
            isLoggedIn: isLoggedIn,
          ),
          Expanded(
            child: ContentConstraint(child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.only(
                top: 24,
                left: 16,
                right: 16,
                bottom: MediaQuery.of(context).padding.bottom + 80,
              ),
              children: [
                _buildSettingsCard(
                  context,
                  icon: Icons.palette_rounded,
                  title: 'General',
                  subtitle: 'Theme, appearance, auto-update',
                  onTap:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const GeneralSettingsPage(),
                        ),
                      ),
                ),
                const SizedBox(height: 5),
                _buildSettingsCard(
                  context,
                  icon: Icons.music_note_rounded,
                  title: 'Playback & Audio',
                  subtitle: 'Speed, pitch, crossfade, equalizer',
                  onTap:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => const PlaybackAudioSettingsPage(),
                        ),
                      ),
                ),
                const SizedBox(height: 5),
                _buildSettingsCard(
                  context,
                  icon: Icons.library_music_rounded,
                  title: 'Library & Scrobbling',
                  subtitle: 'Excluded folders, Last.fm scrobbling',
                  onTap:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) =>
                                  const LibraryScrobblingSettingsPage(),
                        ),
                      ),
                ),
                const SizedBox(height: 5),
                if (isLoggedIn)
                  _buildSettingsCard(
                    context,
                    icon: Icons.person_rounded,
                    title: 'Account',
                    subtitle: 'Password, privacy, Export Data',
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => AccountSettingsPage(
                                  currentUser: currentUser,
                                ),
                          ),
                        ),
                  ),
                if (isLoggedIn) const SizedBox(height: 5),
                _buildSettingsCard(
                  context,
                  icon: Icons.code_rounded,
                  title: 'Developer',
                  subtitle: 'Analytics, API, cache, database',
                  onTap:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const DeveloperSettingsPage(),
                        ),
                      ),
                ),
                const SizedBox(height: 25),
                _buildSettingsCard(
                  context,
                  icon: Icons.info_rounded,
                  title: 'About',
                  subtitle: 'Version, credits, links',
                  onTap:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AboutSettingsPage(),
                        ),
                      ),
                ),
              ],
            )),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        child: Container(
          constraints: const BoxConstraints(minHeight: 88),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha((0.05 * 255).round()),
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(
              color: Colors.white.withAlpha((0.1 * 255).round()),
              width: 0.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.brandPink.withAlpha((0.15 * 255).round()),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: Icon(icon, color: AppTheme.brandPink, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'VarelaRound',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withAlpha((0.6 * 255).round()),
                        fontSize: 14,
                        fontFamily: 'VarelaRound',
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white.withAlpha((0.4 * 255).round()),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
