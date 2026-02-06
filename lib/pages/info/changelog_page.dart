import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:intl/intl.dart';
import 'package:sono/services/utils/analytics_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sono/styles/text.dart';
import 'package:sono/utils/error_handler.dart';
import 'package:sono/styles/app_theme.dart';

class Release {
  final String tagName;
  final String name;
  final String body;
  final DateTime publishedAt;
  final String htmlUrl;

  Release({
    required this.tagName,
    required this.name,
    required this.body,
    required this.publishedAt,
    required this.htmlUrl,
  });

  factory Release.fromJson(Map<String, dynamic> json) {
    return Release(
      tagName: json['tag_name'] ?? 'N/A',
      name: json['name'] ?? json['tag_name'] ?? 'N/A',
      body: json['body'] ?? 'No description provided.',
      publishedAt:
          DateTime.tryParse(json['published_at'] ?? '') ?? DateTime.now(),
      htmlUrl: json['html_url'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tag_name': tagName,
      'name': name,
      'body': body,
      'published_at': publishedAt.toIso8601String(),
      'html_url': htmlUrl,
    };
  }
}

class ChangelogPage extends StatefulWidget {
  const ChangelogPage({super.key});

  @override
  State<ChangelogPage> createState() => _ChangelogPageState();
}

class _ChangelogPageState extends State<ChangelogPage> {
  List<Release>? _releases;
  bool _isLoading = true;
  String? _statusMessage;

  final String _githubRepo = 'mathiiiiiis/SonoAPK';
  final String _cacheKey = 'changelog_cache_sonoapk_v1';

  @override
  void initState() {
    super.initState();
    _fetchChangelog();
    AnalyticsService.logScreenView('ChangelogPage');
  }

  Future<void> _fetchChangelog() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });

    try {
      final Uri url = Uri.parse(
        'https://api.github.com/repos/$_githubRepo/releases',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final releases = data.map((item) => Release.fromJson(item)).toList();
        if (mounted) {
          setState(() {
            _releases = releases;
            _isLoading = false;
            if (releases.isEmpty) {
              _statusMessage = "No changelog entries found.";
            }
          });
        }
        await _cacheReleases(releases);
      } else {
        throw http.ClientException(
          "Failed to load changelog. Status: ${response.statusCode}",
        );
      }
    } catch (e, s) {
      if (mounted) {
        ErrorHandler.showErrorSnackbar(
          context: context,
          message: 'Could not fetch latest changelog.',
          error: e,
          stackTrace: s,
        );
        await _loadCachedReleases(isFallbackFromFetchFailure: true);
      }
    }
  }

  Future<void> _cacheReleases(List<Release> releases) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String jsonString = json.encode(
        releases.map((r) => r.toJson()).toList(),
      );
      await prefs.setString(_cacheKey, jsonString);
    } catch (e) {
      //
    }
  }

  Future<void> _loadCachedReleases({
    bool isFallbackFromFetchFailure = false,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonString = prefs.getString(_cacheKey);
      if (jsonString != null) {
        final List<dynamic> data = json.decode(jsonString);
        final releases = data.map((item) => Release.fromJson(item)).toList();
        if (mounted) {
          setState(() {
            _releases = releases;
            _isLoading = false;
            if (releases.isNotEmpty) {
              if (isFallbackFromFetchFailure) {
                _statusMessage =
                    "Showing cached entries. Please connect to the internet to fetch the latest posts.";
              } else {
                _statusMessage = 'Showing cached changelog.';
              }
            } else {
              _statusMessage =
                  isFallbackFromFetchFailure
                      ? "ugh, that's bad - you're offline and no changelog was cached!"
                      : "No changelog entries found in cache.";
            }
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _releases = [];
            _statusMessage =
                isFallbackFromFetchFailure
                    ? "ugh, that's bad - you're offline and no changelog was cached!"
                    : "No changelog available locally.";
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _releases = [];
          _statusMessage =
              isFallbackFromFetchFailure
                  ? "ugh, that's bad - you're offline! (Cache error)"
                  : "Error loading cached changelog.";
        });
      }
    }
  }

  Widget _buildStatusWidget(BuildContext context) {
    if (_statusMessage == null) return const SizedBox.shrink();

    IconData iconData;
    String title;
    String message;
    Color iconColor;
    TextStyle titleStyle = AppStyles.sonoPlayerTitle.copyWith(
      fontSize: 18.0,
      color: Colors.white,
    );
    TextStyle messageStyle = AppStyles.sonoPlayerArtist.copyWith(
      fontSize: 14.0,
      color: Colors.white.withAlpha((0.8 * 255).round()),
      height: 1.4,
    );

    if (_statusMessage == "No changelog entries found.") {
      iconData = Icons.inbox_rounded;
      title = "All Caught Up!";
      message = "No new changelog entries to show right now.";
      iconColor = Colors.lightBlueAccent;
    } else if (_statusMessage ==
        "Showing cached entries. Please connect to the internet to fetch the latest posts.") {
      iconData = Icons.cloud_sync_rounded;
      title = "Viewing Offline Changelog";
      message =
          "These are saved updates. Connect to the internet for the latest.";
      iconColor = Colors.amberAccent;
    } else if (_statusMessage!.startsWith(
      "ugh, that's bad - you're offline and no changelog was cached!",
    )) {
      iconData = Icons.wifi_off_rounded;
      title = "You're Offline";
      message =
          "We couldn't fetch the latest updates as you're offline, and no saved changelog was found.";
      iconColor = Colors.orangeAccent;
    } else if (_statusMessage!.startsWith(
      "ugh, that's bad - you're offline! (Cache error)",
    )) {
      iconData = Icons.sd_card_alert_rounded;
      title = "Offline & Cache Issue";
      message =
          "Couldn't fetch updates, and there was a problem with the saved changelog. Please check your connection.";
      iconColor = Colors.redAccent;
    } else {
      iconData = Icons.info_outline_rounded;
      title = "Status";
      message = _statusMessage!;
      iconColor = AppTheme.textSecondaryDark;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 24.0),
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
      decoration: BoxDecoration(
        color:
            Theme.of(context).scaffoldBackgroundColor == AppTheme.backgroundDark
                ? AppTheme.cardDark
                : Theme.of(context).cardColor.withAlpha((0.5 * 255).round()),
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(iconData, size: 48.0, color: iconColor),
          const SizedBox(height: 20.0),
          Text(title, textAlign: TextAlign.center, style: titleStyle),
          const SizedBox(height: 10.0),
          Text(message, textAlign: TextAlign.center, style: messageStyle),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppTheme.backgroundDark, AppTheme.elevatedSurfaceDark],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: CustomScrollView(
          slivers: <Widget>[
            SliverAppBar(
              expandedHeight: 200.0,
              floating: false,
              pinned: true,
              stretch: true,
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_rounded,
                  color: Colors.white,
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
              flexibleSpace: FlexibleSpaceBar(
                centerTitle: true,
                title: Text(
                  "Changelog",
                  style: AppStyles.sonoPlayerTitle.copyWith(fontSize: 16),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.grey.shade800, Colors.grey.shade900],
                        ),
                      ),
                      child: const Icon(
                        Icons.history_edu_rounded,
                        color: Colors.white24,
                        size: 80,
                      ),
                    ),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black26,
                            Colors.black87,
                          ],
                          stops: [0.0, 0.5, 1.0],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "What's New",
                      style: AppStyles.sonoPlayerTitle.copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (!_isLoading &&
                        _releases != null &&
                        _releases!.isNotEmpty &&
                        _statusMessage ==
                            "Showing cached entries. Please connect to the internet to fetch the latest posts.")
                      Padding(
                        padding: const EdgeInsets.only(top: 12.0, bottom: 4.0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12.0,
                            vertical: 8.0,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amberAccent.withAlpha(
                              (0.1 * 255).round(),
                            ),
                            borderRadius: BorderRadius.circular(8.0),
                            border: Border.all(
                              color: Colors.amberAccent.withAlpha(
                                (0.4 * 255).round(),
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.cloud_download_rounded,
                                color: Colors.amberAccent.shade100,
                                size: 20,
                              ),
                              const SizedBox(width: 10.0),
                              Expanded(
                                child: Text(
                                  "Viewing saved updates. Connect for the latest version.",
                                  style: TextStyle(
                                    color: Colors.amberAccent.shade100,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (_releases != null && _releases!.isNotEmpty)
                      const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
            _buildContent(),
            const SliverToBoxAdapter(child: SizedBox(height: 30)),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: CircularProgressIndicator(color: AppTheme.brandPink),
        ),
      );
    }

    if (_releases == null || _releases!.isEmpty) {
      if (_statusMessage != null) {
        return SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 20.0),
            child: Center(child: _buildStatusWidget(context)),
          ),
        );
      } else {
        return const SliverToBoxAdapter(child: SizedBox.shrink());
      }
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final release = _releases![index];
        final String formattedDate = DateFormat(
          'MMMM d, yy',
        ).format(release.publishedAt.toLocal());
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Card(
            color: AppTheme.surfaceDark,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              side: BorderSide(
                color: Colors.white.withAlpha((0.1 * 255).round()),
                width: 0.5,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            margin: EdgeInsets.zero,
            child: ExpansionTile(
              backgroundColor: const Color(0xFF232323),
              collapsedIconColor: AppTheme.textSecondaryDark,
              iconColor: AppTheme.brandPink,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 12.0, bottom: 4.0),
                    child: Text(
                      release.name,
                      style: AppStyles.sonoPlayerTitle.copyWith(fontSize: 17),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Text(
                      'Version: ${release.tagName} • Released: $formattedDate',
                      style: AppStyles.sonoPlayerArtist.copyWith(
                        fontSize: 11,
                        color: Colors.white60,
                      ),
                    ),
                  ),
                ],
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
                  child: MarkdownBody(
                    data:
                        release.body.isNotEmpty
                            ? release.body
                            : "No specific details provided for this update.",
                    styleSheet: MarkdownStyleSheet.fromTheme(
                      Theme.of(context),
                    ).copyWith(
                      p: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withAlpha((0.8 * 255).round()),
                        fontSize: 13.5,
                        height: 1.5,
                      ),
                      listBullet: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withAlpha((0.85 * 255).round()),
                      ),
                      h1: AppStyles.sonoPlayerTitle.copyWith(
                        fontSize: 20,
                        color: Colors.white,
                        height: 1.8,
                      ),
                      h2: AppStyles.sonoPlayerTitle.copyWith(
                        fontSize: 18,
                        color: Colors.white,
                        height: 1.8,
                      ),
                      h3: AppStyles.sonoPlayerTitle.copyWith(
                        fontSize: 16,
                        color: Colors.white,
                        height: 1.8,
                      ),
                      codeblockDecoration: BoxDecoration(
                        color: Colors.black.withAlpha((0.25 * 255).round()),
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      ),
                      code: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontFamily: 'monospace',
                        backgroundColor: Colors.black.withAlpha(
                          (0.25 * 255).round(),
                        ),
                        color: Colors.lightBlueAccent.withAlpha(
                          (0.9 * 255).round(),
                        ),
                        fontSize: 12.5,
                      ),
                    ),
                    onTapLink: (text, href, title) async {
                      if (href != null) {
                        final Uri url = Uri.parse(href);
                        try {
                          if (await canLaunchUrl(url)) {
                            await launchUrl(
                              url,
                              mode: LaunchMode.externalApplication,
                            );
                          }
                        } catch (e) {
                          //URL launch failed
                        }
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      }, childCount: _releases!.length),
    );
  }
}