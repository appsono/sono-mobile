import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sono/data/models/music_server_model.dart';
import 'package:sono/services/servers/server_service.dart';
import 'package:sono/styles/app_theme.dart';
import 'package:sono/widgets/servers/add_server_dialog.dart';

class ServersSettingsPage extends StatelessWidget {
  const ServersSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Music Servers',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontFamily: 'VarelaRound',
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddServerDialog(context),
        backgroundColor: AppTheme.brandPink,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
      body: Consumer<MusicServerService>(
        builder: (context, service, _) {
          if (service.servers.isEmpty) {
            return _buildEmptyState(context);
          }
          return ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: service.servers.length,
            itemBuilder: (context, index) {
              final server = service.servers[index];
              return _buildServerTile(context, server, service);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.dns_rounded,
              size: 64,
              color: Colors.white.withAlpha((0.3 * 255).round()),
            ),
            const SizedBox(height: 16),
            const Text(
              'No servers configured',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                fontFamily: 'VarelaRound',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add a Subsonic-compatible server to browse and stream music from it.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withAlpha((0.6 * 255).round()),
                fontSize: 14,
                fontFamily: 'VarelaRound',
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showAddServerDialog(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Add Server',
                style: TextStyle(fontFamily: 'VarelaRound'),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.brandPink,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServerTile(
    BuildContext context,
    MusicServerModel server,
    MusicServerService service,
  ) {
    final isActive = server.isActive;
    final reachability = service.reachabilityOf(server.id!);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            if (isActive) {
              await service.disconnectServer();
              if (context.mounted) {
                _showSnackBar(context, 'Disconnected from ${server.name}');
              }
            } else {
              final error = await service.setActiveServer(server.id!);
              if (context.mounted) {
                if (error != null) {
                  _showSnackBar(context, error, isError: true);
                } else {
                  _showSnackBar(context, 'Connected to ${server.name}');
                }
              }
            }
          },
          onLongPress: () => _confirmDeleteServer(context, server, service),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha((0.05 * 255).round()),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(
                color:
                    isActive
                        ? AppTheme.success.withAlpha((0.5 * 255).round())
                        : Colors.white.withAlpha((0.1 * 255).round()),
                width: isActive ? 1.0 : 0.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color:
                        isActive
                            ? AppTheme.success.withAlpha((0.15 * 255).round())
                            : Colors.white.withAlpha((0.1 * 255).round()),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                  child: Icon(
                    isActive ? Icons.cloud_done_rounded : Icons.dns_rounded,
                    color:
                        isActive
                            ? AppTheme.success
                            : Colors.white.withAlpha((0.7 * 255).round()),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        server.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'VarelaRound',
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        server.url,
                        style: TextStyle(
                          color: Colors.white.withAlpha((0.5 * 255).round()),
                          fontSize: 13,
                          fontFamily: 'VarelaRound',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            '${server.type.name.toUpperCase()} \u2022 ${server.username}',
                            style: TextStyle(
                              color: Colors.white.withAlpha(
                                (0.4 * 255).round(),
                              ),
                              fontSize: 12,
                              fontFamily: 'VarelaRound',
                            ),
                          ),
                          const SizedBox(width: 6),
                          _buildReachabilityDot(reachability),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withAlpha((0.15 * 255).round()),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    child: const Text(
                      'Active',
                      style: TextStyle(
                        color: AppTheme.success,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'VarelaRound',
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReachabilityDot(ServerReachability reachability) {
    if (reachability == ServerReachability.checking) {
      return SizedBox(
        width: 8,
        height: 8,
        child: CircularProgressIndicator(
          strokeWidth: 1.5,
          color: Colors.white.withAlpha((0.4 * 255).round()),
        ),
      );
    }
    final color = switch (reachability) {
      ServerReachability.reachable => AppTheme.success,
      ServerReachability.unreachable => AppTheme.error,
      _ => Colors.white.withAlpha((0.25 * 255).round()),
    };
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  void _showAddServerDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddServerDialog(),
    );
  }

  Future<void> _confirmDeleteServer(
    BuildContext context,
    MusicServerModel server,
    MusicServerService service,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: AppTheme.backgroundDark,
            title: const Text(
              'Remove Server',
              style: TextStyle(color: Colors.white, fontFamily: 'VarelaRound'),
            ),
            content: Text(
              'Remove "${server.name}"? This will not delete any data on the server.',
              style: TextStyle(
                color: Colors.white.withAlpha((0.8 * 255).round()),
                fontFamily: 'VarelaRound',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(fontFamily: 'VarelaRound'),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: AppTheme.error),
                child: const Text(
                  'Remove',
                  style: TextStyle(fontFamily: 'VarelaRound'),
                ),
              ),
            ],
          ),
    );

    if (confirmed == true && context.mounted) {
      await service.removeServer(server.id!);
      if (context.mounted) {
        _showSnackBar(context, 'Server removed');
      }
    }
  }

  void _showSnackBar(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontFamily: 'VarelaRound'),
        ),
        backgroundColor: isError ? AppTheme.error : AppTheme.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
