import 'package:flutter/material.dart';
import 'package:sono/data/models/music_server_model.dart';
import 'package:sono/services/servers/server_service.dart';
import 'package:sono/styles/app_theme.dart';

class AddServerDialog extends StatefulWidget {
  const AddServerDialog({super.key});

  @override
  State<AddServerDialog> createState() => _AddServerDialogState();
}

class _AddServerDialogState extends State<AddServerDialog> {
  final _nameController = TextEditingController();
  final _urlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final MusicServerType _serverType = MusicServerType.subsonic;
  bool _isTesting = false;
  bool _isSaving = false;
  bool _testPassed = false;
  String? _testError;

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool get _canTest =>
      _urlController.text.trim().isNotEmpty &&
      _usernameController.text.trim().isNotEmpty &&
      _passwordController.text.trim().isNotEmpty;

  bool get _canSave =>
      _testPassed && _nameController.text.trim().isNotEmpty;

  String _normalizeUrl(String url) {
    var normalized = url.trim().replaceAll(RegExp(r'/+$'), '');
    if (!normalized.startsWith('http://') &&
        !normalized.startsWith('https://')) {
      normalized = 'https://$normalized';
    }
    return normalized;
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTesting = true;
      _testPassed = false;
      _testError = null;
    });

    final server = MusicServerModel(
      name: 'test',
      url: _normalizeUrl(_urlController.text),
      type: _serverType,
      username: _usernameController.text.trim(),
      password: _passwordController.text.trim(),
    );

    final protocol =
        MusicServerService.instance.createProtocol(server);
    final error = await protocol.ping();

    if (mounted) {
      setState(() {
        _isTesting = false;
        _testPassed = error == null;
        _testError = error;
      });
    }
  }

  Future<void> _save() async {
    if (!_canSave) return;

    setState(() => _isSaving = true);

    final server = MusicServerModel(
      name: _nameController.text.trim(),
      url: _normalizeUrl(_urlController.text),
      type: _serverType,
      username: _usernameController.text.trim(),
      password: _passwordController.text.trim(),
    );

    final error = await MusicServerService.instance.addServer(server);

    if (mounted) {
      if (error != null) {
        setState(() {
          _isSaving = false;
          _testError = error;
        });
      } else {
        Navigator.pop(context);
      }
    }
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: Colors.white.withAlpha((0.4 * 255).round()),
        fontFamily: 'VarelaRound',
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        borderSide: BorderSide(
          color: Colors.white.withAlpha((0.2 * 255).round()),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        borderSide: const BorderSide(color: AppTheme.brandPink),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: AppTheme.backgroundDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha((0.3 * 255).round()),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              'Add Music Server',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                fontFamily: 'VarelaRound',
              ),
            ),

            const SizedBox(height: 4),

            Text(
              'Connect to a Subsonic-compatible server (Navidrome, Airsonic, Gonic, etc.)',
              style: TextStyle(
                color: Colors.white.withAlpha((0.6 * 255).round()),
                fontSize: 13,
                fontFamily: 'VarelaRound',
              ),
            ),

            const SizedBox(height: 24),

            TextField(
              controller: _nameController,
              style: const TextStyle(
                  color: Colors.white, fontFamily: 'VarelaRound'),
              decoration: _inputDecoration('Server name (e.g. Home Navidrome)'),
              textInputAction: TextInputAction.next,
              onChanged: (_) => setState(() {}),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: _urlController,
              style: const TextStyle(
                  color: Colors.white, fontFamily: 'VarelaRound'),
              decoration:
                  _inputDecoration('Server URL (e.g. https://music.example.com)'),
              keyboardType: TextInputType.url,
              autocorrect: false,
              textInputAction: TextInputAction.next,
              onChanged: (_) => setState(() {
                _testPassed = false;
                _testError = null;
              }),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: _usernameController,
              style: const TextStyle(
                  color: Colors.white, fontFamily: 'VarelaRound'),
              decoration: _inputDecoration('Username'),
              autocorrect: false,
              textInputAction: TextInputAction.next,
              onChanged: (_) => setState(() {
                _testPassed = false;
                _testError = null;
              }),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: _passwordController,
              style: const TextStyle(
                  color: Colors.white, fontFamily: 'VarelaRound'),
              decoration: _inputDecoration('Password'),
              obscureText: true,
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() {
                _testPassed = false;
                _testError = null;
              }),
            ),

            const SizedBox(height: 16),

            if (_testError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _testError!,
                  style: const TextStyle(
                    color: AppTheme.error,
                    fontSize: 13,
                    fontFamily: 'VarelaRound',
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

            if (_testPassed)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        color: AppTheme.success, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Connection successful',
                      style: TextStyle(
                        color: AppTheme.success,
                        fontSize: 13,
                        fontFamily: 'VarelaRound',
                      ),
                    ),
                  ],
                ),
              ),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: (_canTest && !_isTesting && !_isSaving)
                        ? _testConnection
                        : null,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                        color: Colors.white.withAlpha((0.3 * 255).round()),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusSm),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: _isTesting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Test Connection',
                            style: TextStyle(fontFamily: 'VarelaRound')),
                  ),
                ),

                const SizedBox(width: 12),
                
                Expanded(
                  child: ElevatedButton(
                    onPressed: (_canSave && !_isSaving) ? _save : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.brandPink,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          AppTheme.brandPink.withAlpha((0.3 * 255).round()),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusSm),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Save',
                            style: TextStyle(fontFamily: 'VarelaRound')),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
