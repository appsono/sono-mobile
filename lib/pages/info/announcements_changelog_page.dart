import 'package:flutter/material.dart';
import 'package:sono/styles/app_theme.dart';
import 'package:sono/services/api/api_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sono/widgets/global/skeleton_loader.dart';

class NewsItem {
  final String type; //'announcement' or 'release'
  final String title;
  final String content;
  final DateTime date;
  final String? author;
  final String? avatarUrl;
  final Map<String, dynamic> rawData;

  NewsItem({
    required this.type,
    required this.title,
    required this.content,
    required this.date,
    this.author,
    this.avatarUrl,
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
      return announcements
          .map((announcement) {
            final createdAt =
                announcement['published_date'] ??
                announcement['created_date'] ??
                announcement['updated_date'];

            DateTime? date;
            try {
              if (createdAt != null && createdAt.toString().isNotEmpty) {
                if (createdAt.toString().contains('T')) {
                  date = DateTime.parse(createdAt.toString());
                } else {
                  date = DateFormat(
                    'yyyy-MM-dd HH:mm:ss',
                  ).parse(createdAt.toString());
                }
              }
            } catch (e) {
              date = null;
            }

            final createdBy = announcement['created_by'];
            final author =
                createdBy != null
                    ? (createdBy['display_name'] ?? createdBy['username'])
                    : null;
            final avatarUrl = createdBy?['profile_picture_url'];

            return NewsItem(
              type: 'announcement',
              title: announcement['title'] ?? 'Untitled',
              content: announcement['content'] ?? '',
              date: date ?? DateTime(1970),
              author: author,
              avatarUrl: avatarUrl,
              rawData: announcement,
            );
          })
          .where((item) {
            return item.date.year > 1970;
          })
          .toList();
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
        return data
            .map((release) {
              DateTime? date;
              try {
                final dateStr =
                    release['published_at'] ?? release['created_at'];
                if (dateStr != null && dateStr.toString().isNotEmpty) {
                  date = DateTime.parse(dateStr.toString());
                }
              } catch (e) {
                date = null;
              }

              final author = release['author']?['login'];
              final avatarUrl = release['author']?['avatar_url'];

              return NewsItem(
                type: 'release',
                title: release['name'] ?? release['tag_name'] ?? 'Release',
                content: release['body'] ?? 'No release notes available.',
                date: date ?? DateTime(1970),
                author: author,
                avatarUrl: avatarUrl,
                rawData: release,
              );
            })
            .where((item) {
              return item.date.year > 1970;
            })
            .toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return minutes == 1 ? '1 minute ago' : '$minutes minutes ago';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return hours == 1 ? '1 hour ago' : '$hours hours ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return weeks == 1 ? '1 week ago' : '$weeks weeks ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return months == 1 ? '1 month ago' : '$months months ago';
    } else {
      return DateFormat('MMM dd, yyyy').format(date.toLocal());
    }
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
      return ListView.separated(
        padding: EdgeInsets.all(AppTheme.spacing),
        itemCount: 3,
        separatorBuilder: (context, index) => SizedBox(height: AppTheme.spacing),
        itemBuilder: (context, index) => const SkeletonNewsCard(),
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
      child: ListView.separated(
        padding: EdgeInsets.all(AppTheme.spacing),
        itemCount: _newsItems.length,
        separatorBuilder:
            (context, index) => SizedBox(height: AppTheme.spacing),
        itemBuilder: (context, index) {
          final item = _newsItems[index];
          return _buildNewsCard(item);
        },
      ),
    );
  }

  Widget _buildNewsCard(NewsItem item) {
    final htmlUrl =
        item.type == 'release' ? (item.rawData['html_url'] ?? '') : '';

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: AppTheme.textPrimaryDark.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(AppTheme.spacing),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildTypeBadge(item.type),
                Text(
                  _formatDate(item.date),
                  style: TextStyle(
                    color: AppTheme.textTertiaryDark,
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            SizedBox(height: AppTheme.spacingSm),
            Text(
              item.title,
              style: TextStyle(
                color: AppTheme.textPrimaryDark,
                fontFamily: AppTheme.fontFamily,
                fontSize: 20,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
            SizedBox(height: AppTheme.spacingSm),
            MarkdownBody(
              data: item.content,
              styleSheet: MarkdownStyleSheet.fromTheme(
                Theme.of(context),
              ).copyWith(
                p: TextStyle(
                  color: AppTheme.textSecondaryDark,
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 14,
                  height: 1.6,
                ),
                listBullet: TextStyle(
                  color: AppTheme.textSecondaryDark,
                  fontFamily: AppTheme.fontFamily,
                ),
                h1: TextStyle(
                  color: AppTheme.textPrimaryDark,
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
                h2: TextStyle(
                  color: AppTheme.textPrimaryDark,
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                h3: TextStyle(
                  color: AppTheme.textPrimaryDark,
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                h4: TextStyle(
                  color: AppTheme.textPrimaryDark,
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                code: TextStyle(
                  fontFamily: 'monospace',
                  backgroundColor: AppTheme.backgroundDark,
                  color: Theme.of(context).primaryColor,
                  fontSize: 13,
                ),
                blockquote: TextStyle(
                  color: AppTheme.textSecondaryDark,
                  fontFamily: AppTheme.fontFamily,
                ),
                strong: TextStyle(
                  color: AppTheme.textPrimaryDark,
                  fontWeight: FontWeight.w600,
                ),
                em: const TextStyle(fontStyle: FontStyle.italic),
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
            if (item.author != null || item.avatarUrl != null) ...[
              SizedBox(height: AppTheme.spacing),
              Row(
                children: [
                  if (item.avatarUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        item.avatarUrl!,
                        width: 24,
                        height: 24,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.person_rounded,
                            size: 14,
                            color: AppTheme.textSecondaryDark,
                          );
                        },
                      ),
                    )
                  else
                    Icon(
                      Icons.person_rounded,
                      size: 14,
                      color: AppTheme.textSecondaryDark,
                    ),
                  if (item.author != null) ...[
                    SizedBox(width: 8),
                    Text(
                      item.author!,
                      style: TextStyle(
                        color: AppTheme.textSecondaryDark,
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ],
            if (htmlUrl.isNotEmpty) ...[
              SizedBox(height: AppTheme.spacing),
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: AppTheme.textPrimaryDark.withValues(alpha: 0.1),
                      width: 1,
                    ),
                  ),
                ),
                padding: EdgeInsets.only(top: AppTheme.spacingSm),
                child: InkWell(
                  onTap: () async {
                    final Uri url = Uri.parse(htmlUrl);
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
                  },
                  child: Row(
                    children: [
                      Text(
                        'View on GitHub',
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(width: 6),
                      Icon(
                        Icons.open_in_new_rounded,
                        color: Theme.of(context).primaryColor,
                        size: 14,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTypeBadge(String type) {
    IconData icon;
    Color color;
    String label;

    switch (type) {
      case 'announcement':
        icon = Icons.campaign_rounded;
        color = Theme.of(context).primaryColor;
        label = 'ANNOUNCEMENT';
        break;
      case 'release':
        icon = Icons.code_rounded;
        color = Colors.green;
        label = 'APP RELEASE';
        break;
      default:
        icon = Icons.info_rounded;
        color = Colors.blue;
        label = 'NEWS';
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontFamily: AppTheme.fontFamily,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}