import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sono/styles/app_theme.dart';
import 'package:sono/pages/info/credits_page.dart';

/// about settings page - version, credits, links
class AboutSettingsPage extends StatefulWidget {
  const AboutSettingsPage({super.key});

  @override
  State<AboutSettingsPage> createState() => _AboutSettingsPageState();
}

class _AboutSettingsPageState extends State<AboutSettingsPage> {
  String _version = 'Loading...';
  String _buildNumber = '';

  @override
  void initState() {
    super.initState();
    _loadAppInfo();
  }

  Future<void> _loadAppInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _version = packageInfo.version;
      _buildNumber = packageInfo.buildNumber;
    });
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not launch URL')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            backgroundColor: AppTheme.backgroundDark,
            elevation: 0,
            pinned: true,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_rounded,
                color: Colors.white,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: const Text(
              'About',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontFamily: 'VarelaRound',
              ),
            ),
          ),

          _buildAppInfoHeader(),

          _buildSectionHeader("Links"),
          _buildLinksSection(),

          _buildSectionHeader("Version Info"),
          _buildVersionSection(),

          _buildSectionHeader("Legal"),
          _buildLegalSection(),

          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildAppInfoHeader() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.brandPink,
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                child: Image.asset(
                  'assets/icon/adaptive_monochrome.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.music_note_rounded,
                      size: 40,
                      color: Colors.black,
                    );
                  },
                ),
              ),
            ),
            SizedBox(height: AppTheme.spacing),
            const Text(
              'Sono',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontFamily: 'VarelaRound',
              ),
            ),
            SizedBox(height: AppTheme.spacingXs),
            Text(
              'Local Music Player',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withAlpha((0.7 * 255).round()),
                fontFamily: 'VarelaRound',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLinksSection() {
    final links = [
      {
        'icon': Icons.discord_rounded,
        'title': 'Discord Server',
        'subtitle': 'Join our community',
        'url': 'https://discord.sono.wtf',
        'color': const Color(0xFF5865F2),
      },
      {
        'icon': Icons.code_rounded,
        'title': 'GitHub',
        'subtitle': 'View source code',
        'url': 'https://github.com/appsono',
        'color': Colors.white,
      },
      {
        'icon': Icons.coffee_rounded,
        'title': 'Support Development',
        'subtitle': 'Buy me a coffee',
        'url': 'https://ko-fi.com/mathiiis',
        'color': const Color(0xFFFF5E5B),
      },
    ];

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList.builder(
        itemCount: links.length,
        itemBuilder: (context, index) {
          final link = links[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: (link['color'] as Color).withAlpha(
                    (0.15 * 255).round(),
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Icon(
                  link['icon'] as IconData,
                  color: link['color'] as Color,
                  size: 20,
                ),
              ),
              title: Text(
                link['title'] as String,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                  fontFamily: 'VarelaRound',
                ),
              ),
              subtitle: Text(
                link['subtitle'] as String,
                style: TextStyle(
                  color: Colors.white.withAlpha((0.7 * 255).round()),
                  fontSize: 14,
                  fontFamily: 'VarelaRound',
                ),
              ),
              trailing: Icon(
                Icons.open_in_new_rounded,
                color: Colors.white.withAlpha((0.5 * 255).round()),
                size: 18,
              ),
              onTap: () => _launchUrl(link['url'] as String),
            ),
          );
        },
      ),
    );
  }

  Widget _buildVersionSection() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverToBoxAdapter(
        child: Column(
          children: [
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha((0.1 * 255).round()),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: const Icon(
                  Icons.info_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              title: const Text(
                'Version',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                  fontFamily: 'VarelaRound',
                ),
              ),
              subtitle: Text(
                '$_version (Build $_buildNumber)',
                style: TextStyle(
                  color: Colors.white.withAlpha((0.7 * 255).round()),
                  fontSize: 14,
                  fontFamily: 'VarelaRound',
                ),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha((0.1 * 255).round()),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: const Icon(
                  Icons.people_outline,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              title: const Text(
                'Credits',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                  fontFamily: 'VarelaRound',
                ),
              ),
              subtitle: Text(
                'View contributors and libraries',
                style: TextStyle(
                  color: Colors.white.withAlpha((0.7 * 255).round()),
                  fontSize: 14,
                  fontFamily: 'VarelaRound',
                ),
              ),
              trailing: Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white.withAlpha((0.5 * 255).round()),
                size: 16,
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CreditsPage()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegalSection() {
    final legal = [
      {
        'icon': Icons.privacy_tip_rounded,
        'title': 'Privacy Policy',
        'url': 'https://sono.wtf/privacy',
      },
      {
        'icon': Icons.description_rounded,
        'title': 'Terms of Service',
        'url': 'https://sono.wtf/terms',
      },
      {
        'icon': Icons.inventory_2_rounded,
        'title': 'Open Source Licenses',
        'action': 'licenses',
      },
    ];

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList.builder(
        itemCount: legal.length,
        itemBuilder: (context, index) {
          final item = legal[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha((0.1 * 255).round()),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Icon(
                  item['icon'] as IconData,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              title: Text(
                item['title'] as String,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                  fontFamily: 'VarelaRound',
                ),
              ),
              trailing: Icon(
                Icons.open_in_new_rounded,
                color: Colors.white.withAlpha((0.5 * 255).round()),
                size: 18,
              ),
              onTap: () {
                if (item.containsKey('url')) {
                  _launchUrl(item['url'] as String);
                } else if (item['action'] == 'licenses') {
                  showLicensePage(
                    context: context,
                    applicationName: 'Sono',
                    applicationVersion: _version,
                  );
                }
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
        child: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: 'VarelaRound',
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          children: [
            Text(
              'Made with ❤️ by the Sono Group',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withAlpha((0.6 * 255).round()),
                fontSize: 14,
                fontFamily: 'VarelaRound',
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
          ],
        ),
      ),
    );
  }
}