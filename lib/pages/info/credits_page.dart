import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:yaml/yaml.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:sono/styles/app_theme.dart';

class Contributor {
  final String name;
  final String description;
  final String? githubUsername;

  Contributor({
    required this.name,
    required this.description,
    this.githubUsername,
  });
}

class ApiServices {
  final String name;
  final String description;
  final String? websiteUrl;
  final String? documentationUrl;

  ApiServices({
    required this.name,
    required this.description,
    this.websiteUrl,
    this.documentationUrl,
  });
}

class OpenSourceLibrary {
  final String name;
  final String? version;
  final String? description;
  final String? license;
  final String? homepage;

  OpenSourceLibrary({
    required this.name,
    this.version,
    this.description,
    this.license,
    this.homepage,
  });
}

class CreditsPage extends StatefulWidget {
  final VoidCallback? onMenuTap;

  const CreditsPage({super.key, this.onMenuTap});

  @override
  State<CreditsPage> createState() => _CreditsPageState();
}

class _CreditsPageState extends State<CreditsPage> {
  List<Contributor> _contributors = [];
  bool _isLoadingContributors = true;
  String? _contributorsError;

  @override
  void initState() {
    super.initState();
    _fetchContributors();
  }

  Future<void> _fetchContributors() async {
    setState(() {
      _isLoadingContributors = true;
      _contributorsError = null;
    });

    try {
      final response = await http.get(
        Uri.parse(
          'https://api.github.com/repos/appsono/sono-mobile/contributors',
        ),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);

        final contributors = <Contributor>[];
        for (final item in data) {
          final login = item['login'] as String?;
          final contributions = item['contributions'] as int?;

          if (login != null) {
            String role = 'Contributor';
            if (login == 'mathiiiiiis') {
              role = 'Creator';
            } else if (login == 'n0201') {
              role = 'Lead Developer';
            } else if (contributions != null && contributions > 100) {
              role = 'Core Contributor';
            } else if (contributions != null && contributions > 10) {
              role = 'Contributor';
            }

            contributors.add(
              Contributor(
                name: login,
                description: role,
                githubUsername: login,
              ),
            );
          }
        }

        if (mounted) {
          setState(() {
            _contributors = contributors;
            _isLoadingContributors = false;
          });
        }
      } else {
        throw Exception('Failed to load contributors: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching contributors: $e');
      if (mounted) {
        setState(() {
          _contributorsError = 'Could not load contributors from GitHub';
          _isLoadingContributors = false;
        });
      }
    }
  }

  final List<ApiServices> _apiServices = [
    ApiServices(
      name: 'GitHub API',
      description: 'User profile information and repository data',
      websiteUrl: 'https://github.com',
      documentationUrl: 'https://docs.github.com/en/rest',
    ),
    ApiServices(
      name: 'pub.dev API',
      description: 'Package information and metadata',
      websiteUrl: 'https://pub.dev',
      documentationUrl: 'https://pub.dev/help/api',
    ),
    ApiServices(
      name: 'Last.fm API',
      description: 'Artist infos, song metadata and song scribbling',
      websiteUrl: 'https://last.fm',
      documentationUrl: 'https://last.fm/api',
    ),
    ApiServices(
      name: 'lrclib API',
      description: 'Lyrics fetching and synchronization',
      websiteUrl: 'https://lrclib.net',
      documentationUrl: 'https://lrclib.net/docs',
    ),
    ApiServices(
      name: 'MusicBrainz API',
      description: 'Music metadata',
      websiteUrl: 'https://musicbrainz.org',
      documentationUrl: 'https://musicbrainz.org/doc/MusicBrainz_API',
    ),
    ApiServices(
      name: "Sono's own API Services",
      description:
          'Our own API services to keep the App up-to-date, and more...',
      websiteUrl: 'https://github.com/appsono/',
      documentationUrl: 'https://github.com/appsono/',
    ),
  ];

  Future<Map<String, dynamic>?> _getGithubProfile(String? username) async {
    if (username == null || username.isEmpty) return null;

    try {
      final response = await http.get(
        Uri.parse('https://api.github.com/users/$username'),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      debugPrint('Error fetching GitHub profile for $username: $e');
    }
    return null;
  }

  Future<List<OpenSourceLibrary>> _getLibraries() async {
    try {
      final pubspecString = await rootBundle.loadString('pubspec.yaml');
      final pubspecMap = loadYaml(pubspecString);
      final dependencies = pubspecMap['dependencies'] as YamlMap?;

      if (dependencies != null) {
        List<OpenSourceLibrary> libraries = [];

        for (String key in dependencies.keys.cast<String>()) {
          if (key != 'flutter' && key != 'cupertino_icons') {
            final versionInfo = dependencies[key];
            String? version;

            if (versionInfo is String) {
              version = versionInfo;
            } else if (versionInfo is Map &&
                versionInfo.containsKey('version')) {
              version = versionInfo['version'].toString();
            }

            libraries.add(
              OpenSourceLibrary(
                name: key,
                version: version,
                homepage: 'https://pub.dev/packages/$key',
              ),
            );
          }
        }

        libraries.sort((a, b) => a.name.compareTo(b.name));
        return libraries;
      }
      return [];
    } catch (e) {
      throw Exception('Could not load or parse pubspec.yaml');
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
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
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: const Text(
              'Credits',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontFamily: 'VarelaRound',
              ),
            ),
          ),

          _buildSectionHeader("Development Team"),
          _buildContributorsSection(),

          _buildSectionHeader("APIs & Services"),
          _buildApiServicesSection(),

          _buildSectionHeader("Open Source Libraries"),
          _buildLibrariesSection(),

          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildContributorsSection() {
    if (_isLoadingContributors) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ),
      );
    }

    if (_contributorsError != null) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Icon(
                Icons.error_outline_rounded,
                color: Colors.white.withAlpha((0.5 * 255).round()),
                size: 48,
              ),
              SizedBox(height: 16),
              Text(
                _contributorsError!,
                style: TextStyle(
                  color: Colors.white.withAlpha((0.7 * 255).round()),
                  fontSize: 14,
                  fontFamily: 'VarelaRound',
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              TextButton(
                onPressed: _fetchContributors,
                child: Text(
                  'Retry',
                  style: TextStyle(
                    color: AppTheme.brandPink,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_contributors.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'No contributors found',
            style: TextStyle(
              color: Colors.white.withAlpha((0.7 * 255).round()),
              fontSize: 14,
              fontFamily: 'VarelaRound',
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList.builder(
        itemCount: _contributors.length,
        itemBuilder: (context, index) {
          final contributor = _contributors[index];

          return FutureBuilder<Map<String, dynamic>?>(
            future: _getGithubProfile(contributor.githubUsername),
            builder: (context, snapshot) {
              final profileData = snapshot.data;
              final avatarUrl = profileData?['avatar_url'] as String?;
              final profileUrl = profileData?['html_url'] as String?;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.white.withAlpha(
                      (0.1 * 255).round(),
                    ),
                    backgroundImage:
                        avatarUrl != null ? NetworkImage(avatarUrl) : null,
                    child:
                        snapshot.connectionState == ConnectionState.waiting
                            ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                            : (avatarUrl == null
                                ? const Icon(
                                  Icons.person_rounded,
                                  color: Colors.white,
                                  size: 20,
                                )
                                : null),
                  ),
                  title: Text(
                    contributor.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                      fontFamily: 'VarelaRound',
                    ),
                  ),
                  subtitle: Text(
                    contributor.description,
                    style: TextStyle(
                      color: Colors.white.withAlpha((0.7 * 255).round()),
                      fontSize: 14,
                      fontFamily: 'VarelaRound',
                    ),
                  ),
                  trailing:
                      profileUrl != null
                          ? Icon(
                            Icons.open_in_new_rounded,
                            color: Colors.white.withAlpha((0.5 * 255).round()),
                            size: 18,
                          )
                          : null,
                  onTap:
                      profileUrl != null ? () => _launchUrl(profileUrl) : null,
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildApiServicesSection() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList.builder(
        itemCount: _apiServices.length,
        itemBuilder: (context, index) {
          final api = _apiServices[index];
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
                child: const Icon(
                  Icons.api_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              title: Text(
                api.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                  fontFamily: 'VarelaRound',
                ),
              ),
              subtitle: Text(
                api.description,
                style: TextStyle(
                  color: Colors.white.withAlpha((0.7 * 255).round()),
                  fontSize: 14,
                  fontFamily: 'VarelaRound',
                ),
              ),
              trailing:
                  api.websiteUrl != null
                      ? Icon(
                        Icons.open_in_new_rounded,
                        color: Colors.white.withAlpha((0.5 * 255).round()),
                        size: 18,
                      )
                      : null,
              onTap:
                  api.websiteUrl != null
                      ? () => _launchUrl(api.websiteUrl!)
                      : null,
            ),
          );
        },
      ),
    );
  }

  Widget _buildLibrariesSection() {
    return FutureBuilder<List<OpenSourceLibrary>>(
      future: _getLibraries(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                "Could not load libraries. Make sure 'pubspec.yaml' is in your assets.",
                style: TextStyle(
                  color: Colors.white.withAlpha((0.7 * 255).round()),
                  fontSize: 14,
                  fontFamily: 'VarelaRound',
                ),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                "No libraries found",
                style: TextStyle(
                  color: Colors.white.withAlpha((0.7 * 255).round()),
                  fontSize: 14,
                  fontFamily: 'VarelaRound',
                ),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final libraries = snapshot.data!;
        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList.builder(
            itemCount: libraries.length,
            itemBuilder: (context, index) {
              final library = libraries[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 4),
                child: ListTile(
                  dense: true,
                  leading: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha((0.1 * 255).round()),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    child: const Icon(
                      Icons.inventory_2_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  title: Text(
                    library.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'VarelaRound',
                    ),
                  ),
                  subtitle:
                      library.version != null
                          ? Text(
                            'v${library.version}',
                            style: TextStyle(
                              color: Colors.white.withAlpha(
                                (0.5 * 255).round(),
                              ),
                              fontSize: 12,
                              fontFamily: 'VarelaRound',
                            ),
                          )
                          : null,
                  trailing: Icon(
                    Icons.open_in_new_rounded,
                    color: Colors.white.withAlpha((0.3 * 255).round()),
                    size: 16,
                  ),
                  onTap:
                      library.homepage != null
                          ? () => _launchUrl(library.homepage!)
                          : null,
                ),
              );
            },
          ),
        );
      },
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
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Text(
              'YOU KNOW IM FRRRRIIIIIIEEEEDDDDD!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withAlpha((0.5 * 255).round()),
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
