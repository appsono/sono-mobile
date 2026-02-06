import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sono/services/sas/sas_manager.dart';
import 'package:sono/styles/app_theme.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Single adaptive modal that detects SAS session state and shows appropriate UI:
/// - If hosting: Show host management UI (QR code, connected listeners, stop button)
/// - If connected as client: Show client status UI (connection info, disconnect button)
/// - If idle: Show choice screen (host or join)
class SASAdaptiveModal extends StatefulWidget {
  const SASAdaptiveModal({super.key});

  @override
  State<SASAdaptiveModal> createState() => _SASAdaptiveModalState();
}

class _SASAdaptiveModalState extends State<SASAdaptiveModal> {
  final SASManager _manager = SASManager();

  //choice screen state
  bool _showingJoinUI = false;
  String _manualHost = '';
  String _manualPort = '';

  //host screen state
  SASInfo? _sessionInfo;
  bool _isStartingHost = false;
  String? _hostError;

  //join screen state
  bool _isJoining = false;
  String? _joinError;
  bool _showingScanner = false;
  MobileScannerController? _scannerController;

  //stream delay control
  double _currentDelay = 200.0; //default 200ms

  @override
  void initState() {
    super.initState();
    //if already hosting when modal opens, try to get current session info
    if (_manager.isHost && _manager.sessionInfo != null) {
      _sessionInfo = _manager.sessionInfo;
    }
    //initialize delay from manager
    _currentDelay = _manager.streamDelayMs.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    //adaptive routing based on current SAS state
    if (_manager.isHost) {
      return _buildHostManagementUI();
    } else if (_manager.isConnected) {
      return _buildClientStatusUI();
    } else {
      //ddle state => show choice or join UI
      return _showingJoinUI ? _buildJoinUI() : _buildChoiceUI();
    }
  }

  //============================================================================
  // CHOICE SCREEN (IDLE STATE)
  //============================================================================

  Widget _buildChoiceUI() {
    return Container(
      padding: EdgeInsets.all(AppTheme.spacingLg),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLg),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Sono Audio Stream',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryDark,
            ),
          ),
          SizedBox(height: AppTheme.spacingSm),
          Text(
            'Stream your music to other devices in real-time',
            style: TextStyle(fontSize: 14, color: AppTheme.textSecondaryDark),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppTheme.spacingXl),

          _buildChoiceButton(
            icon: Icons.cast_rounded,
            title: 'Host SAS Session',
            description: 'Stream your music to other devices',
            color: AppTheme.brandPink,
            onTap: _startHosting,
          ),

          SizedBox(height: AppTheme.spacingMd),

          _buildChoiceButton(
            icon: Icons.phone_android_rounded,
            title: 'Join SAS Session',
            description: 'Connect to another device\'s stream',
            color: AppTheme.brandPinkSwatch[300]!,
            onTap: () {
              setState(() => _showingJoinUI = true);
            },
          ),

          SizedBox(height: AppTheme.spacingLg),
        ],
      ),
    );
  }

  Widget _buildChoiceButton({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: Container(
          padding: EdgeInsets.all(AppTheme.spacingMd),
          decoration: BoxDecoration(
            color: AppTheme.elevatedSurfaceDark,
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              SizedBox(width: AppTheme.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimaryDark,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondaryDark,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: AppTheme.textSecondaryDark,
              ),
            ],
          ),
        ),
      ),
    );
  }

  //============================================================================
  // HOST MANAGEMENT UI
  //============================================================================

  Widget _buildHostManagementUI() {
    if (_isStartingHost) {
      return _buildLoadingUI('Starting host session...');
    }

    if (_hostError != null) {
      return _buildErrorUI(_hostError!, onRetry: _startHosting);
    }

    if (_sessionInfo == null) {
      return _buildLoadingUI('Loading session info...');
    }

    return Container(
      padding: EdgeInsets.all(AppTheme.spacingLg),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLg),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Hosting SAS Session',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryDark,
            ),
          ),
          SizedBox(height: AppTheme.spacingMd),

          Container(
            padding: EdgeInsets.all(AppTheme.spacingMd),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radius),
            ),
            child: QrImageView(
              data: _sessionInfo!.deepLink,
              version: QrVersions.auto,
              size: 200,
            ),
          ),

          SizedBox(height: AppTheme.spacingMd),

          _buildInfoRow('Host', _sessionInfo!.host),
          _buildInfoRow('Port', _sessionInfo!.port.toString()),
          _buildInfoRow('Session', _sessionInfo!.sessionId),

          SizedBox(height: AppTheme.spacingMd),

          Container(
            padding: EdgeInsets.all(AppTheme.spacingMd),
            decoration: BoxDecoration(
              color: AppTheme.elevatedSurfaceDark,
              borderRadius: BorderRadius.circular(AppTheme.radius),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_rounded, color: AppTheme.brandPink, size: 20),
                SizedBox(width: AppTheme.spacingSm),
                Text(
                  '${_manager.connectedClientsCount} ${_manager.connectedClientsCount == 1 ? 'listener' : 'listeners'} connected',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimaryDark,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: AppTheme.spacingLg),

          Container(
            padding: EdgeInsets.all(AppTheme.spacingMd),
            margin: EdgeInsets.only(bottom: AppTheme.spacingMd),
            decoration: BoxDecoration(
              color: AppTheme.elevatedSurfaceDark,
              borderRadius: BorderRadius.circular(AppTheme.radius),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Stream Delay',
                  style: TextStyle(
                    color: AppTheme.textPrimaryDark,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: AppTheme.spacingSm),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: _currentDelay,
                        min: 0,
                        max: 5000,
                        divisions: 50,
                        label: '${_currentDelay.toInt()}ms',
                        activeColor: AppTheme.brandPink,
                        onChanged:
                            (value) => setState(() => _currentDelay = value),
                        onChangeEnd:
                            (value) => _manager.setStreamDelay(value.toInt()),
                      ),
                    ),
                    SizedBox(width: AppTheme.spacingSm),
                    Text(
                      '${_currentDelay.toInt()}ms',
                      style: TextStyle(
                        color: AppTheme.brandPink,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppTheme.spacingSm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildDelayPreset(0, 'None'),
                    _buildDelayPreset(200, 'Low'),
                    _buildDelayPreset(500, 'Med'),
                    _buildDelayPreset(1000, 'High'),
                  ],
                ),
              ],
            ),
          ),

          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  label: 'Share Link',
                  icon: Icons.share_rounded,
                  onTap: _shareLink,
                  isPrimary: false,
                ),
              ),
              SizedBox(width: AppTheme.spacingMd),
              Expanded(
                child: _buildActionButton(
                  label: 'Copy Link',
                  icon: Icons.copy_rounded,
                  onTap: _copyLink,
                  isPrimary: false,
                ),
              ),
            ],
          ),

          SizedBox(height: AppTheme.spacingMd),

          _buildActionButton(
            label: 'Stop Hosting',
            icon: Icons.stop_rounded,
            onTap: _stopHosting,
            isPrimary: false,
            color: Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 14, color: AppTheme.textSecondaryDark),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimaryDark,
            ),
          ),
        ],
      ),
    );
  }

  //============================================================================
  // CLIENT STATUS UI
  //============================================================================

  Widget _buildClientStatusUI() {
    return Container(
      padding: EdgeInsets.all(AppTheme.spacingLg),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLg),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_done_rounded, size: 64, color: AppTheme.brandPink),
          SizedBox(height: AppTheme.spacingMd),
          Text(
            'Connected to SAS',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryDark,
            ),
          ),
          SizedBox(height: AppTheme.spacingSm),
          Text(
            'Streaming audio from host device',
            style: TextStyle(fontSize: 14, color: AppTheme.textSecondaryDark),
          ),

          SizedBox(height: AppTheme.spacingXl),

          ValueListenableBuilder<StreamHealthStatus>(
            valueListenable: _manager.streamHealth,
            builder: (context, health, child) {
              return _buildHealthIndicator(health.quality);
            },
          ),

          SizedBox(height: AppTheme.spacingMd),

          ValueListenableBuilder<String?>(
            valueListenable: _manager.clientSongTitle,
            builder: (context, title, child) {
              return ValueListenableBuilder<String?>(
                valueListenable: _manager.clientSongArtist,
                builder: (context, artist, child) {
                  if (title == null) {
                    return SizedBox.shrink();
                  }
                  return Container(
                    padding: EdgeInsets.all(AppTheme.spacingMd),
                    decoration: BoxDecoration(
                      color: AppTheme.elevatedSurfaceDark,
                      borderRadius: BorderRadius.circular(AppTheme.radius),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Now Playing',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondaryDark,
                          ),
                        ),
                        SizedBox(height: AppTheme.spacingSm),
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimaryDark,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (artist != null) ...[
                          SizedBox(height: 2),
                          Text(
                            artist,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.textSecondaryDark,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  );
                },
              );
            },
          ),

          SizedBox(height: AppTheme.spacingXl),

          _buildActionButton(
            label: 'Disconnect',
            icon: Icons.logout_rounded,
            onTap: _disconnectFromSession,
            isPrimary: false,
            color: Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildHealthIndicator(ConnectionQuality quality) {
    Color color;
    String label;
    IconData icon;

    switch (quality) {
      case ConnectionQuality.excellent:
        color = Colors.green;
        label = 'Excellent';
        icon = Icons.signal_cellular_alt_rounded;
      case ConnectionQuality.good:
        color = Colors.lightGreen;
        label = 'Good';
        icon = Icons.signal_cellular_alt_2_bar_rounded;
      case ConnectionQuality.fair:
        color = Colors.orange;
        label = 'Fair';
        icon = Icons.signal_cellular_alt_1_bar_rounded;
      case ConnectionQuality.poor:
        color = Colors.deepOrange;
        label = 'Poor';
        icon = Icons.signal_cellular_connected_no_internet_0_bar_rounded;
      case ConnectionQuality.critical:
        color = Colors.red;
        label = 'Critical';
        icon = Icons.signal_cellular_nodata_rounded;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 20),
        SizedBox(width: AppTheme.spacingSm),
        Text(
          'Connection: $label',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }

  //============================================================================
  // JOIN UI
  //============================================================================

  Widget _buildJoinUI() {
    return Container(
      padding: EdgeInsets.all(AppTheme.spacingLg),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLg),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimaryDark),
                onPressed: () {
                  setState(() {
                    _showingJoinUI = false;
                    _joinError = null;
                  });
                },
              ),
              Expanded(
                child: Text(
                  'Join SAS Session',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryDark,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(width: 48),
            ],
          ),

          SizedBox(height: AppTheme.spacingLg),

          if (_joinError != null) ...[
            Container(
              padding: EdgeInsets.all(AppTheme.spacingMd),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radius),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline_rounded, color: Colors.red, size: 20),
                  SizedBox(width: AppTheme.spacingSm),
                  Expanded(
                    child: Text(
                      _joinError!,
                      style: TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: AppTheme.spacingMd),
          ],

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed:
                  () => setState(() => _showingScanner = !_showingScanner),
              icon: Icon(
                _showingScanner ? Icons.keyboard_rounded : Icons.qr_code_scanner_rounded,
              ),
              label: Text(_showingScanner ? 'Manual Entry' : 'Scan QR Code'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.brandPink,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: AppTheme.spacingMd),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                ),
              ),
            ),
          ),

          SizedBox(height: AppTheme.spacingLg),

          if (_showingScanner)
            _buildQRScanner()
          else ...[
            Text(
              'Enter connection details',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimaryDark,
              ),
            ),
            SizedBox(height: AppTheme.spacingMd),

            _buildTextField(
              label: 'Host IP Address',
              hint: 'e.g., 192.168.1.100',
              onChanged: (value) => _manualHost = value,
            ),
            SizedBox(height: AppTheme.spacingSm),
            _buildTextField(
              label: 'Port',
              hint: 'e.g., 35000',
              onChanged: (value) => _manualPort = value,
              keyboardType: TextInputType.number,
            ),

            SizedBox(height: AppTheme.spacingLg),

            _buildActionButton(
              label: _isJoining ? 'Connecting...' : 'Join Session',
              icon: Icons.login_rounded,
              onTap: _isJoining ? null : _joinManually,
              isPrimary: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required String hint,
    required ValueChanged<String> onChanged,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: AppTheme.textSecondaryDark,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 4),
        TextField(
          onChanged: onChanged,
          keyboardType: keyboardType,
          style: TextStyle(color: AppTheme.textPrimaryDark),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: AppTheme.textSecondaryDark.withValues(alpha: 0.5),
            ),
            filled: true,
            fillColor: AppTheme.elevatedSurfaceDark,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              borderSide: BorderSide.none,
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: AppTheme.spacingMd,
              vertical: AppTheme.spacingSm,
            ),
          ),
        ),
      ],
    );
  }

  //============================================================================
  // UTILITY UI COMPONENTS
  //============================================================================

  Widget _buildLoadingUI(String message) {
    return Container(
      padding: EdgeInsets.all(AppTheme.spacingXl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppTheme.brandPink),
          SizedBox(height: AppTheme.spacingMd),
          Text(
            message,
            style: TextStyle(fontSize: 14, color: AppTheme.textSecondaryDark),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorUI(String error, {VoidCallback? onRetry}) {
    return Container(
      padding: EdgeInsets.all(AppTheme.spacingLg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded, color: Colors.red, size: 48),
          SizedBox(height: AppTheme.spacingMd),
          Text(
            'Error',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryDark,
            ),
          ),
          SizedBox(height: AppTheme.spacingSm),
          Text(
            error,
            style: TextStyle(fontSize: 14, color: AppTheme.textSecondaryDark),
            textAlign: TextAlign.center,
          ),
          if (onRetry != null) ...[
            SizedBox(height: AppTheme.spacingLg),
            _buildActionButton(
              label: 'Retry',
              icon: Icons.refresh_rounded,
              onTap: onRetry,
              isPrimary: true,
            ),
          ],
          SizedBox(height: AppTheme.spacingMd),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    VoidCallback? onTap,
    bool isPrimary = true,
    Color? color,
  }) {
    final buttonColor =
        color ??
        (isPrimary ? AppTheme.brandPink : AppTheme.elevatedSurfaceDark);
    final textColor = isPrimary ? Colors.white : AppTheme.textPrimaryDark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            vertical: AppTheme.spacingMd,
            horizontal: AppTheme.spacingLg,
          ),
          decoration: BoxDecoration(
            color:
                onTap == null
                    ? buttonColor.withValues(alpha: 0.3)
                    : buttonColor,
            borderRadius: BorderRadius.circular(AppTheme.radius),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: textColor, size: 20),
              SizedBox(width: AppTheme.spacingSm),
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQRScanner() {
    return Container(
      height: 400,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.brandPink),
      ),
      clipBehavior: Clip.antiAlias,
      child: MobileScanner(
        controller:
            _scannerController ??= MobileScannerController(
              detectionSpeed: DetectionSpeed.noDuplicates,
            ),
        onDetect: (capture) {
          for (final barcode in capture.barcodes) {
            if (barcode.rawValue != null) {
              _handleScannedQRCode(barcode.rawValue!);
              break;
            }
          }
        },
      ),
    );
  }

  void _handleScannedQRCode(String qrData) {
    try {
      final uri = Uri.parse(qrData);
      if (uri.scheme == 'sonoapp' && (uri.host == 'jam' || uri.host == 'sas')) {
        final host = uri.queryParameters['host'];
        final portStr = uri.queryParameters['port'];

        if (host != null && portStr != null) {
          setState(() {
            _manualHost = host;
            _manualPort = portStr;
            _showingScanner = false;
          });
          _joinManually();
        } else {
          setState(() => _joinError = 'Invalid QR code format');
        }
      } else {
        setState(() => _joinError = 'Not a Sono SAS QR code');
      }
    } catch (e) {
      setState(() => _joinError = 'Invalid QR code: $e');
    }
  }

  Widget _buildDelayPreset(int delayMs, String label) {
    final isSelected = (_currentDelay.toInt() - delayMs).abs() < 50;
    return Expanded(
      child: OutlinedButton(
        onPressed: () {
          setState(() => _currentDelay = delayMs.toDouble());
          _manager.setStreamDelay(delayMs);
        },
        style: OutlinedButton.styleFrom(
          backgroundColor:
              isSelected
                  ? AppTheme.brandPink.withValues(alpha: 0.2)
                  : Colors.transparent,
          side: BorderSide(
            color: isSelected ? AppTheme.brandPink : AppTheme.textSecondaryDark,
          ),
          padding: EdgeInsets.symmetric(vertical: AppTheme.spacingSm),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppTheme.brandPink : AppTheme.textSecondaryDark,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  //============================================================================
  // ACTIONS
  //============================================================================

  Future<void> _startHosting() async {
    setState(() {
      _isStartingHost = true;
      _hostError = null;
    });

    try {
      final info = await _manager.startHost();
      if (mounted) {
        setState(() {
          _sessionInfo = info;
          _isStartingHost = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hostError = 'Failed to start session: $e';
          _isStartingHost = false;
        });
      }
    }
  }

  Future<void> _stopHosting() async {
    await _manager.stopHost();
    if (mounted) {
      Navigator.pop(context);
    }
  }

  void _shareLink() {
    if (_sessionInfo != null) {
      SharePlus.instance.share(
        ShareParams(
          text: 'Join my Sono Audio Stream! ${_sessionInfo!.deepLink}',
          subject: 'Sono Audio Stream',
        ),
      );
    }
  }

  void _copyLink() {
    if (_sessionInfo != null) {
      Clipboard.setData(ClipboardData(text: _sessionInfo!.deepLink));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Link copied to clipboard!'),
          duration: Duration(seconds: 2),
          backgroundColor: AppTheme.brandPink,
        ),
      );
    }
  }

  Future<void> _joinManually() async {
    if (_manualHost.isEmpty || _manualPort.isEmpty) {
      setState(() {
        _joinError = 'Please enter host IP and port';
      });
      return;
    }

    setState(() {
      _isJoining = true;
      _joinError = null;
    });

    try {
      final port = int.parse(_manualPort);
      await _manager.joinSession(_manualHost, port);
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _joinError = 'Failed to connect: $e';
          _isJoining = false;
        });
      }
    }
  }

  Future<void> _disconnectFromSession() async {
    await _manager.leaveSession();
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _scannerController?.dispose();
    super.dispose();
  }
}

/// Helper function to show the adaptive modal
void showSASAdaptiveModal(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => SASAdaptiveModal(),
  );
}