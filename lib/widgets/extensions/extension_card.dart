import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sono_extensions/sono_extensions.dart';

import '../../pages/extensions/extension_detail_page.dart';

/// A list tile representing one installed extension
///
/// Shows name, version, author and an enable/disable toggle
/// Tapping navigates to [ExtensionDetailPage]
class ExtensionCard extends StatelessWidget {
  const ExtensionCard({super.key, required this.manifest});

  final ExtensionManifest manifest;

  @override
  Widget build(BuildContext context) {
    final registry = context.watch<ExtensionRegistry>();
    final state = registry.stateOf(manifest.id);
    final isActive = state == ExtensionState.active;
    final isLoading = state == ExtensionState.loading;
    final hasError = state == ExtensionState.error;

    return Card(
      color: const Color(0xFF1E1E1E),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ExtensionDetailPage(manifest: manifest),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              //extension icon placeholder
              //TODO: work on making icons for extensions possible
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.extension,
                  color: Color(0xFFFF4893),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      manifest.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${manifest.version} · ${manifest.author}',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                    if (hasError)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          registry.errorOf(manifest.id) ?? 'Unknown error',
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (isLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFFFF4893),
                  ),
                )
              else
                Switch(
                  value: isActive,
                  activeThumbColor: const Color(0xFFFF4893),
                  onChanged: (v) => registry.setEnabled(
                    manifest.id,
                    enabled: v,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
