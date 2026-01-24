import 'package:flutter/material.dart';
import 'package:sono/styles/app_theme.dart';
import 'package:sono/services/api/api_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class NewsItem {
  final String type; //'announcement' or 'release'
  final String title;
  final String content;
  final DateTime date;
  final Map<String, dynamic> rawData;

  NewsItem({
    required this.type,
    required this.title,
    required this.content,
    required this.date,
    required this.rawData,
  });
}

class AnnouncementsChangelogPage extends StatefulWidget {
  const AnnouncementsChangelogPage({super.key});

  @override
  State<AnnouncementsChangelogPage> createState() =>
      _AnnouncementsChangelogPageState();
}

class _AnnouncementsChangelogPageState
    extends State<AnnouncementsChangelogPage> {
  final ApiService _apiService = ApiService();
  final String _githubRepo = 'mathiiiiiis/SonoAPK';

  List<NewsItem> _newsItems = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAllNews();
  }

  Future<void> _loadAllNews() async {
    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        _loadAnnouncements(),
        _loadReleases(),
      ]);

      final announcements = results[0];
      final releases = results[1];

      final allNews = [...announcements, ...releases];
      allNews.sort((a, b) => b.date.compareTo(a.date));

      if (mounted) {
        setState(() {
          _newsItems = allNews;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<List<NewsItem>> _loadAnnouncements() async {
    try {
      final announcements = await _apiService.getAnnouncements(limit: 50);
      return announcements.map((announcement) {
        final createdAt = announcement['published_at'];

        DateTime date;
        try {
          if (createdAt != null && createdAt.toString().isNotEmpty) {
            if (createdAt.toString().contains('T')) {
              date = DateTime.parse(createdAt.toString());
            } else {
              date = DateFormat('yyyy-MM-dd HH:mm:ss').parse(createdAt.toString());
            }
          } else {
            date = DateTime.now();
          }
        } catch (e) {
          date = DateTime.now();
        }

        return NewsItem(
          type: 'announcement',
          title: announcement['title'] ?? 'Untitled',
          content: announcement['content'] ?? '',
          date: date,
          rawData: announcement,
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<NewsItem>> _loadReleases() async {
    try {
      final response = await http
          .get(Uri.parse('https://api.github.com/repos/$_githubRepo/releases'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((release) {
          DateTime date;
          try {
            date = DateTime.parse(release['published_at'] ?? '');
          } catch (e) {
            date = DateTime.now();
          }

          return NewsItem(
            type: 'release',
            title: release['name'] ?? release['tag_name'] ?? 'Release',
            content: release['body'] ?? 'No release notes available.',
            date: date,
            rawData: release,
          );
        }).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM dd, yyyy').format(date.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceDark,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimaryDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'News & Updates',
          style: TextStyle(
            color: AppTheme.textPrimaryDark,
            fontFamily: AppTheme.fontFamily,
            fontSize: AppTheme.fontTitle,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: AppTheme.textPrimaryDark),
            onPressed: _loadAllNews,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: Theme.of(context).primaryColor),
      );
    }

    if (_newsItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_rounded,
              size: 64,
              color: AppTheme.textTertiaryDark,
            ),
            SizedBox(height: AppTheme.spacing),
            Text(
              'No News Available',
              style: TextStyle(
                color: AppTheme.textSecondaryDark,
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.fontSubtitle,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAllNews,
      color: Theme.of(context).primaryColor,
      child: ListView.builder(
        padding: EdgeInsets.all(AppTheme.spacing),
        itemCount: _newsItems.length,
        itemBuilder: (context, index) {
          final item = _newsItems[index];
          if (item.type == 'announcement') {
            return _buildAnnouncementCard(item);
          } else {
            return _buildReleaseCard(item);
          }
        },
      ),
    );
  }

  Widget _buildAnnouncementCard(NewsItem item) {
    return Container(
      margin: EdgeInsets.only(bottom: AppTheme.spacing),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: ExpansionTile(
        tilePadding: EdgeInsets.all(AppTheme.spacing),
        childrenPadding: EdgeInsets.fromLTRB(
          AppTheme.spacing,
          0,
          AppTheme.spacing,
          AppTheme.spacing,
        ),
        backgroundColor: AppTheme.surfaceDark,
        collapsedBackgroundColor: AppTheme.surfaceDark,
        iconColor: Theme.of(context).primaryColor,
        collapsedIconColor: AppTheme.textTertiaryDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        collapsedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        leading: Container(
          padding: EdgeInsets.all(AppTheme.spacingSm),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          ),
          child: Icon(
            Icons.campaign_rounded,
            color: Theme.of(context).primaryColor,
            size: 24,
          ),
        ),
        title: Text(
          item.title,
          style: TextStyle(
            color: AppTheme.textPrimaryDark,
            fontFamily: AppTheme.fontFamily,
            fontSize: AppTheme.fontSubtitle,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Padding(
          padding: EdgeInsets.only(top: AppTheme.spacingXs),
          child: Text(
            _formatDate(item.date),
            style: TextStyle(
              color: AppTheme.textTertiaryDark,
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.fontSm,
            ),
          ),
        ),
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(AppTheme.spacing),
            decoration: BoxDecoration(
              color: AppTheme.textPrimaryDark.opacity10,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Text(
              item.content,
              style: TextStyle(
                color: AppTheme.textSecondaryDark,
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.fontBody,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReleaseCard(NewsItem item) {
    final tagName = item.rawData['tag_name'] ?? 'N/A';
    final htmlUrl = item.rawData['html_url'] ?? '';

    return Container(
      margin: EdgeInsets.only(bottom: AppTheme.spacing),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: ExpansionTile(
        tilePadding: EdgeInsets.all(AppTheme.spacing),
        childrenPadding: EdgeInsets.fromLTRB(
          AppTheme.spacing,
          0,
          AppTheme.spacing,
          AppTheme.spacing,
        ),
        backgroundColor: AppTheme.surfaceDark,
        collapsedBackgroundColor: AppTheme.surfaceDark,
        iconColor: Theme.of(context).primaryColor,
        collapsedIconColor: AppTheme.textTertiaryDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        collapsedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        leading: Container(
          padding: EdgeInsets.all(AppTheme.spacingSm),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          ),
          child: Icon(
            Icons.code_rounded,
            color: Colors.green,
            size: 24,
          ),
        ),
        title: Text(
          item.title,
          style: TextStyle(
            color: AppTheme.textPrimaryDark,
            fontFamily: AppTheme.fontFamily,
            fontSize: AppTheme.fontSubtitle,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Padding(
          padding: EdgeInsets.only(top: AppTheme.spacingXs),
          child: Row(
            children: [
              Flexible(
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingSm,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                  child: Text(
                    tagName,
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              SizedBox(width: AppTheme.spacingSm),
              Flexible(
                child: Text(
                  _formatDate(item.date),
                  style: TextStyle(
                    color: AppTheme.textTertiaryDark,
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.fontSm,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(AppTheme.spacing),
            decoration: BoxDecoration(
              color: AppTheme.textPrimaryDark.opacity10,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: MarkdownBody(
              data: item.content,
              styleSheet: MarkdownStyleSheet.fromTheme(
                Theme.of(context),
              ).copyWith(
                p: TextStyle(
                  color: AppTheme.textSecondaryDark,
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.fontBody,
                  height: 1.5,
                ),
                listBullet: TextStyle(
                  color: AppTheme.textSecondaryDark,
                  fontFamily: AppTheme.fontFamily,
                ),
                h1: TextStyle(
                  color: AppTheme.textPrimaryDark,
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.fontTitle,
                  fontWeight: FontWeight.bold,
                ),
                h2: TextStyle(
                  color: AppTheme.textPrimaryDark,
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.fontSubtitle,
                  fontWeight: FontWeight.bold,
                ),
                code: TextStyle(
                  fontFamily: 'monospace',
                  backgroundColor: AppTheme.backgroundDark,
                  color: Theme.of(context).primaryColor,
                  fontSize: 13,
                ),
              ),
              onTapLink: (text, href, title) async {
                if (href != null) {
                  final Uri url = Uri.parse(href);
                  try {
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    }
                  } catch (e) {
                    //URL launch failed
                  }
                }
              },
            ),
          ),
          if (htmlUrl.isNotEmpty) ...[
            SizedBox(height: AppTheme.spacingSm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () async {
                  final Uri url = Uri.parse(htmlUrl);
                  try {
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    }
                  } catch (e) {
                    //URL launch failed
                  }
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Theme.of(context).primaryColor),
                  padding: EdgeInsets.symmetric(vertical: AppTheme.spacingSm),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.open_in_new_rounded,
                      color: Theme.of(context).primaryColor,
                      size: 16,
                    ),
                    SizedBox(width: AppTheme.spacingSm),
                    Text(
                      'View on GitHub',
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.fontSm,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
