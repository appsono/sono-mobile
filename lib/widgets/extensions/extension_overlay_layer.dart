import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sono_extensions/sono_extensions.dart';

import '../../pages/extensions/extension_screen_page.dart';

/// A persistent widget shown above the mini player when any enabled extension
/// declares ui_overlay: true in its manifest
///
/// Displays a compact banner for first active overlay extension
/// Tapping it opens [ExtensionScreenPage] full-screen
class ExtensionOverlayLayer extends StatelessWidget {
  const ExtensionOverlayLayer({super.key});

  @override
  Widget build(BuildContext context) {
    final registry = context.watch<ExtensionRegistry>();

    //find first active extension that wants an overlay
    ExtensionManifest? overlayManifest;
    LuaRuntime? overlayRuntime;
    for (final m in registry.installed) {
      if (m.uiOverlay && registry.isActive(m.id)) {
        final rt = registry.runtimeOf(m.id);
        if (rt != null) {
          overlayManifest = m;
          overlayRuntime = rt;
          break;
        }
      }
    }

    if (overlayManifest == null || overlayRuntime == null) {
      return const SizedBox.shrink();
    }

    final manifest = overlayManifest;
    final runtime = overlayRuntime;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 70,
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ExtensionScreenPage(manifest: manifest, runtime: runtime),
          ),
        ),
        child: Container(
          height: 44,
          color: const Color(0xFF1A1A1A),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Icon(Icons.extension, color: Color(0xFFFF4893), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  manifest.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white54, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
