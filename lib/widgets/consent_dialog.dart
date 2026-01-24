import 'package:flutter/material.dart';
import 'package:sono/services/api/api_service.dart';
import 'package:sono/styles/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ConsentDialog extends StatefulWidget {
  final String consentType;
  final String consentVersion;
  final String title;
  final String content;
  final VoidCallback? onAccepted;
  final VoidCallback? onDeclined;
  final VoidCallback? onViewFullDocument;

  const ConsentDialog({
    super.key,
    required this.consentType,
    required this.consentVersion,
    required this.title,
    required this.content,
    this.onAccepted,
    this.onDeclined,
    this.onViewFullDocument,
  });

  @override
  State<ConsentDialog> createState() => _ConsentDialogState();

  /// Show consent dialog if user hasnt accepted the current version
  /// Checks both local cache and API for consent status
  static Future<bool?> showIfNeeded({
    required BuildContext context,
    required String consentType,
    required String consentVersion,
    required String title,
    required String content,
    VoidCallback? onAccepted,
    VoidCallback? onDeclined,
    VoidCallback? onViewFullDocument,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'consent_${consentType}_$consentVersion';

    //check API for consent status first (API is source of truth)
    try {
      final apiService = ApiService();
      final consents = await apiService.getUserConsents();

      //check if user has consented to this specific type and version
      final hasConsentedOnApi = consents.any(
        (consent) =>
            consent['consent_type'] == consentType &&
            consent['consent_version'] == consentVersion,
      );

      if (hasConsentedOnApi) {
        //update local cache to match API
        await prefs.setBool(cacheKey, true);
        return true;
      } else {
        //API says no consent => clear local cache to be safe
        await prefs.remove(cacheKey);
      }
    } catch (e) {
      //if API check fails => check local cache as fallback
      debugPrint('Failed to check consent status from API: $e');
      final hasAcceptedLocally = prefs.getBool(cacheKey) ?? false;
      if (hasAcceptedLocally) {
        debugPrint('Using cached consent status as fallback');
        return true;
      }
    }

    //user hasnt consented => show bottom sheet
    if (context.mounted) {
      return await showModalBottomSheet<bool>(
        context: context,
        isDismissible: false,
        enableDrag: false,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder:
            (context) => ConsentDialog(
              consentType: consentType,
              consentVersion: consentVersion,
              title: title,
              content: content,
              onAccepted: onAccepted,
              onDeclined: onDeclined,
              onViewFullDocument: onViewFullDocument,
            ),
      );
    }

    return null;
  }
}

class _ConsentDialogState extends State<ConsentDialog> {
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  bool _hasScrolledToBottom = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    //check if content requires scrolling after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        final maxScroll = _scrollController.position.maxScrollExtent;
        //if content doesnt need scrolling (maxScroll <= 10) => auto-enable accept button
        if (maxScroll <= 10 && !_hasScrolledToBottom) {
          setState(() {
            _hasScrolledToBottom = true;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 50) {
      if (!_hasScrolledToBottom) {
        setState(() {
          _hasScrolledToBottom = true;
        });
      }
    }
  }

  Future<void> _acceptConsent() async {
    setState(() => _isLoading = true);
    try {
      await _apiService.recordConsent(
        consentType: widget.consentType,
        consentVersion: widget.consentVersion,
      );

      //save to SharedPreferences to track locally
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(
        'consent_${widget.consentType}_${widget.consentVersion}',
        true,
      );

      if (mounted) {
        Navigator.pop(context, true);
        widget.onAccepted?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to record consent: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _declineConsent() {
    Navigator.pop(context, false);
    widget.onDeclined?.call();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final maxHeight = screenHeight * 0.85;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: AppTheme.backgroundDark,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppTheme.radiusXl),
          topRight: Radius.circular(AppTheme.radiusXl),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              margin: EdgeInsets.symmetric(vertical: AppTheme.spacingMd),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textTertiaryDark,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppTheme.spacingXl),
            child: Row(
              children: [
                Icon(
                  Icons.policy_rounded,
                  color: Theme.of(context).primaryColor,
                  size: 32,
                ),
                SizedBox(width: AppTheme.spacingMd),
                Expanded(
                  child: Text(
                    widget.title,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.fontTitle,
                      color: AppTheme.textPrimaryDark,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: AppTheme.spacingLg),
          Flexible(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: AppTheme.spacingXl),
              child: Container(
                padding: EdgeInsets.all(AppTheme.spacing),
                decoration: BoxDecoration(
                  color: AppTheme.textPrimaryDark.opacity10,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    padding: EdgeInsets.all(AppTheme.spacingSm),
                    child: Text(
                      widget.content,
                      style: TextStyle(
                        fontSize: AppTheme.fontBody,
                        color: AppTheme.textSecondaryDark,
                        fontFamily: AppTheme.fontFamily,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (widget.onViewFullDocument != null)
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppTheme.spacingXl,
                vertical: AppTheme.spacingSm,
              ),
              child: TextButton(
                onPressed: widget.onViewFullDocument,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: AppTheme.spacingSm),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.open_in_new_rounded,
                      size: 18,
                      color: Theme.of(context).primaryColor,
                    ),
                    SizedBox(width: AppTheme.spacingXs),
                    Text(
                      'Read Full ${widget.title}',
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontSize: AppTheme.fontBody,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (!_hasScrolledToBottom)
            Padding(
              padding: EdgeInsets.only(
                top: AppTheme.spacingSm,
                left: AppTheme.spacingXl,
                right: AppTheme.spacingXl,
              ),
              child: Text(
                'Please scroll to the bottom to continue',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: AppTheme.fontSm,
                  color: AppTheme.textTertiaryDark,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          Padding(
            padding: EdgeInsets.all(AppTheme.spacingXl),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : _declineConsent,
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        vertical: AppTheme.spacingMd,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                      side: BorderSide(color: AppTheme.textTertiaryDark),
                    ),
                    child: Text(
                      'DECLINE',
                      style: TextStyle(
                        color: AppTheme.textSecondaryDark,
                        fontSize: AppTheme.fontBody,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: AppTheme.spacingMd),
                Expanded(
                  child: ElevatedButton(
                    onPressed:
                        _isLoading || !_hasScrolledToBottom
                            ? null
                            : _acceptConsent,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      disabledBackgroundColor:
                          AppTheme.textTertiaryDark.opacity50,
                      padding: EdgeInsets.symmetric(
                        vertical: AppTheme.spacingMd,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                    ),
                    child:
                        _isLoading
                            ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: AppTheme.textPrimaryDark,
                                strokeWidth: 2,
                              ),
                            )
                            : Text(
                              'ACCEPT',
                              style: TextStyle(
                                color: AppTheme.textPrimaryDark,
                                fontSize: AppTheme.fontBody,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}