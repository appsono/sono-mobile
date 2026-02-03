import 'package:flutter/material.dart';
import 'package:sono/services/api/api_service.dart';
import 'package:sono/styles/app_theme.dart';
import 'package:webview_flutter/webview_flutter.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final ApiService _apiService = ApiService();
  WebViewController? _webViewController;
  bool _isLoading = true;
  String? _errorMessage;
  double _loadingProgress = 0;
  bool _hasInjectedToken = false;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  Future<void> _initializeWebView() async {
    try {
      final token = await _apiService.getAccessToken();
      if (token == null) {
        setState(() {
          _errorMessage = 'Not authenticated. Please log in again.';
          _isLoading = false;
        });
        return;
      }

      const adminUrl = 'https://web.sono.wtf/admin';

      _webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onProgress: (int progress) {
              setState(() {
                _loadingProgress = progress / 100;
              });
            },
            onPageStarted: (String url) {
              setState(() {
                _isLoading = true;
              });
            },
            onPageFinished: (String url) async {
              //inject the authentication token into localStorage on first load
              if (!_hasInjectedToken && _webViewController != null) {
                _hasInjectedToken = true;
                try {
                  await _webViewController!.runJavaScript('''
                    localStorage.setItem('access_token', '$token');
                    localStorage.setItem('token', '$token');
                    window.location.reload();
                  ''');
                } catch (e) {
                  debugPrint('Failed to inject token: $e');
                }
              }
              setState(() {
                _isLoading = false;
              });
            },
            onHttpError: (HttpResponseError error) {
              setState(() {
                _errorMessage = 'HTTP Error: ${error.response?.statusCode}';
                _isLoading = false;
              });
            },
            onWebResourceError: (WebResourceError error) {
              setState(() {
                _errorMessage = 'Error: ${error.description}';
                _isLoading = false;
              });
            },
            onNavigationRequest: (NavigationRequest request) {
              return NavigationDecision.navigate;
            },
          ),
        )
        ..setBackgroundColor(AppTheme.backgroundDark)
        ..addJavaScriptChannel(
          'Sono',
          onMessageReceived: (JavaScriptMessage message) {
            debugPrint('Message from WebView: ${message.message}');
          },
        );

      await _webViewController?.loadRequest(Uri.parse(adminUrl));

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshPage() async {
    await _webViewController?.reload();
  }

  Future<bool> _handleBackNavigation() async {
    if (_webViewController != null && await _webViewController!.canGoBack()) {
      await _webViewController!.goBack();
      return false;
    }
    return true;
  }

  void _handleBackPress() async {
    final shouldPop = await _handleBackNavigation();
    if (shouldPop && mounted) {
      if (!context.mounted) return;
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        _handleBackPress();
      },
      child: Scaffold(
        backgroundColor: AppTheme.backgroundDark,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            'Admin Dashboard',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.fontTitle,
              color: AppTheme.textPrimaryDark,
              fontWeight: FontWeight.bold,
            ),
          ),
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_rounded,
              color: AppTheme.textPrimaryDark,
            ),
            onPressed: _handleBackPress,
          ),
          actions: [
            IconButton(
              icon: Icon(
                Icons.refresh_rounded,
                color: AppTheme.textPrimaryDark,
              ),
              onPressed: _refreshPage,
              tooltip: 'Refresh',
            ),
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert_rounded,
                color: AppTheme.textPrimaryDark,
              ),
              color: AppTheme.surfaceDark,
              onSelected: (value) async {
                switch (value) {
                  case 'forward':
                    if (_webViewController != null && await _webViewController!.canGoForward()) {
                      await _webViewController!.goForward();
                    }
                    break;
                  case 'reload':
                    await _refreshPage();
                    break;
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'forward',
                  child: Row(
                    children: [
                      Icon(Icons.arrow_forward_rounded,
                          color: AppTheme.textPrimaryDark),
                      SizedBox(width: AppTheme.spacingMd),
                      Text(
                        'Forward',
                        style: TextStyle(color: AppTheme.textPrimaryDark),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'reload',
                  child: Row(
                    children: [
                      Icon(Icons.refresh_rounded,
                          color: AppTheme.textPrimaryDark),
                      SizedBox(width: AppTheme.spacingMd),
                      Text(
                        'Reload',
                        style: TextStyle(color: AppTheme.textPrimaryDark),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(AppTheme.spacingXl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 64,
                color: AppTheme.error,
              ),
              SizedBox(height: AppTheme.spacingLg),
              Text(
                'Failed to load admin dashboard',
                style: TextStyle(
                  fontSize: AppTheme.fontSubtitle,
                  color: AppTheme.textPrimaryDark,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: AppTheme.spacingSm),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: AppTheme.fontBody,
                  color: AppTheme.textSecondaryDark,
                ),
              ),
              SizedBox(height: AppTheme.spacingXl),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _errorMessage = null;
                  });
                  _initializeWebView();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  padding: EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingXl,
                    vertical: AppTheme.spacingMd,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                ),
                child: Text(
                  'RETRY',
                  style: TextStyle(
                    color: AppTheme.textPrimaryDark,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_webViewController == null) {
      return Center(
        child: CircularProgressIndicator(
          color: Theme.of(context).primaryColor,
        ),
      );
    }

    return Stack(
      children: [
        WebViewWidget(controller: _webViewController!),
        if (_isLoading && _loadingProgress < 1.0)
          Column(
            children: [
              LinearProgressIndicator(
                value: _loadingProgress,
                backgroundColor: AppTheme.textPrimaryDark.opacity10,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).primaryColor,
                ),
              ),
            ],
          ),
      ],
    );
  }
}