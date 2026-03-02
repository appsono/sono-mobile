import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';
import 'package:sono_extensions/sono_extensions.dart';

import 'extension_screen_page.dart';

/// Detail page for a single installed extension
///
/// Shows full manifest info, enable/disable toggle, uninstall button and,
/// if extension declares a UI mode, an "Open UI" button
class ExtensionDetailPage extends StatelessWidget {
  const ExtensionDetailPage({super.key, required this.manifest});

  final ExtensionManifest manifest;

  @override
  Widget build(BuildContext context) {
    final registry = context.watch<ExtensionRegistry>();
    final state = registry.stateOf(manifest.id);
    final isActive = state == ExtensionState.active;
    final isLoading = state == ExtensionState.loading;
    final hasError = state == ExtensionState.error;
    final errorMsg = registry.errorOf(manifest.id);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
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
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header card
          _InfoCard(children: [
            _InfoRow(label: 'Version', value: manifest.version),
            _InfoRow(label: 'Author', value: manifest.author),
            _InfoRow(label: 'ID', value: manifest.id),
            if (manifest.description.isNotEmpty)
              _InfoRow(label: 'Description', value: manifest.description),
          ]),
          const SizedBox(height: 12),

          // Enable / disable
          _SectionCard(
            child: Row(
              children: [
                const Icon(Symbols.toggle_on, color: Colors.white70, size: 22),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Enable extension',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
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
                    activeTrackColor: const Color(0xFFFF4893).withAlpha(80),
                    onChanged: (v) =>
                        registry.setEnabled(manifest.id, enabled: v),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Error message
          if (hasError && errorMsg != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withAlpha(30),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.withAlpha(80)),
              ),
              child: Text(
                errorMsg,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Open UI button (only if extension has a UI mode and is active)
          if (manifest.hasUi && isActive) ...[
            _ActionButton(
              icon: Symbols.open_in_full,
              label: 'Open UI',
              color: const Color(0xFFFF4893),
              onTap: () {
                final runtime = registry.runtimeOf(manifest.id);
                if (runtime == null) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ExtensionScreenPage(
                      manifest: manifest,
                      runtime: runtime,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
          ],

          // Permissions
          if (manifest.permissions.isNotEmpty) ...[
            const SizedBox(height: 4),
            const Text(
              'Permissions',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            _InfoCard(
              children: manifest.permissions
                  .map((p) => _PermissionRow(permission: p))
                  .toList(),
            ),
            const SizedBox(height: 12),
          ],

          // Uninstall
          _ActionButton(
            icon: Symbols.delete,
            label: 'Uninstall',
            color: Colors.redAccent,
            onTap: () => _confirmUninstall(context, registry),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmUninstall(
    BuildContext context,
    ExtensionRegistry registry,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          'Uninstall extension?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Remove "${manifest.name}"? This cannot be undone.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Uninstall',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await registry.uninstall(manifest.id);
      if (context.mounted) Navigator.pop(context);
    }
  }
}

// ---------------------------------------------------------------------------
// Private helper widgets

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({required this.permission});
  final ExtensionPermission permission;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const Icon(Symbols.security, color: Colors.white54, size: 14),
          const SizedBox(width: 8),
          Text(
            permission.id,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
