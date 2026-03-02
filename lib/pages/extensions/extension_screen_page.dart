import 'package:flutter/material.dart';
import 'package:sono_extensions/sono_extensions.dart';

import '../../widgets/extensions/extension_canvas_widget.dart';
import '../../widgets/extensions/extension_rfw_widget.dart';

/// Full-screen page that hosts a canvas or RFW extension UI
///
/// Pushed via [Navigator.push] from Extensions management page or from
/// overlay tap. Close button calls [Navigator.pop]
class ExtensionScreenPage extends StatelessWidget {
  const ExtensionScreenPage({
    super.key,
    required this.manifest,
    required this.runtime,
  });

  final ExtensionManifest manifest;
  final LuaRuntime runtime;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        foregroundColor: Colors.white,
        title: Text(
          manifest.name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    switch (manifest.uiMode) {
      case 'canvas':
        return ExtensionCanvasWidget(runtime: runtime);
      case 'rfw':
        return ExtensionRfwWidget(
          runtime: runtime,
          extensionDir: runtime.extensionDir,
          uiFile: manifest.uiFile,
        );
      default:
        return const Center(
          child: Text(
            'No UI defined for this extension.',
            style: TextStyle(color: Colors.white54),
          ),
        );
    }
  }
}
