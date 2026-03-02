import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';
import 'package:sono_extensions/sono_extensions.dart';

import 'package:sono/styles/app_theme.dart';
import 'package:sono/widgets/extensions/extension_card.dart';

class ExtensionsPage extends StatefulWidget {
  const ExtensionsPage({super.key});

  @override
  State<ExtensionsPage> createState() => _ExtensionsPageState();
}

class _ExtensionsPageState extends State<ExtensionsPage> {
  bool _loaded = false;
  bool _installing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInstalled());
  }

  Future<void> _loadInstalled() async {
    await context.read<ExtensionRegistry>().loadInstalled();
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _installFromFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
    if (result == null || result.files.single.path == null) return;

    final filePath = result.files.single.path!;
    if (!filePath.endsWith('.sopk')) {
      _showSnack('Please select a .sopk file');
      return;
    }
    await _doInstall(filePath, cleanup: false);
  }

  Future<void> _installDemo() async {
    final registry = context.read<ExtensionRegistry>();
    if (registry.installed.any((m) => m.id == 'wtf.sono.track_viz')) {
      _showSnack('Track Viz is already installed');
      return;
    }
    final tmpPath = await _buildDemoSopk();
    await _doInstall(tmpPath, cleanup: true);
  }

  Future<void> _doInstall(String path, {required bool cleanup}) async {
    if (mounted) setState(() => _installing = true);
    try {
      final manifest = await context.read<ExtensionRegistry>().install(path);
      _showSnack('Installed: ${manifest.name}');
    } catch (e) {
      _showSnack('Install failed: $e');
    } finally {
      if (cleanup) {
        try {
          File(path).deleteSync();
        } catch (_) {}
      }
      if (mounted) setState(() => _installing = false);
    }
  }

  Future<String> _buildDemoSopk() async {
    final archive = Archive();
    void add(String name, String content) {
      final bytes = utf8.encode(content);
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
    }
    add('manifest.json', _kTrackVizManifest);
    add('main.lua', _kTrackVizLua);

    final file = File(
      '${Directory.systemTemp.path}/track_viz_${DateTime.now().millisecondsSinceEpoch}.sopk',
    );
    await file.writeAsBytes(ZipEncoder().encode(archive)!);
    return file.path;
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final registry = context.watch<ExtensionRegistry>();
    final installed = registry.installed;

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: const Text('Extensions'),
        backgroundColor: AppTheme.backgroundDark,
        foregroundColor: Colors.white,
        actions: [
          if (_installing)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.brandPink,
                ),
              ),
            ),
        ],
      ),
      body:
          !_loaded
              ? const Center(
                child: CircularProgressIndicator(color: AppTheme.brandPink),
              )
              : installed.isEmpty
              ? _EmptyState(
                onInstallDemo: _installing ? null : _installDemo,
              )
              : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: installed.length,
                itemBuilder:
                    (_, i) => ExtensionCard(manifest: installed[i]),
              ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _installing ? null : _installFromFile,
        backgroundColor: AppTheme.brandPink,
        foregroundColor: Colors.white,
        icon: const Icon(Symbols.file_open, size: 20),
        label: const Text('Install .sopk'),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({this.onInstallDemo});

  final VoidCallback? onInstallDemo;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Symbols.extension,
              size: 72,
              color: Colors.white.withValues(alpha: 0.15),
            ),
            const SizedBox(height: 20),
            Text(
              'No extensions installed',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 17,
                fontWeight: FontWeight.w600,
                fontFamily: AppTheme.fontFamily,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Install a .sopk package via the button below,\nor try the bundled demo.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 13,
                fontFamily: AppTheme.fontFamily,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            OutlinedButton.icon(
              onPressed: onInstallDemo,
              icon: const Icon(Symbols.auto_awesome, size: 17),
              label: const Text('Try Track Viz'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.brandPink,
                side: BorderSide(
                  color: AppTheme.brandPink.withValues(alpha: 0.5),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 13,
                ),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  fontFamily: AppTheme.fontFamily,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Demo extension: Track Viz
const _kTrackVizManifest = '''
{
  "id": "wtf.sono.track_viz",
  "name": "Track Viz",
  "version": "1.2.1",
  "sono_sdk": ">=1.0.0",
  "author": "Sono",
  "description": "The first ever Sono extension. A real-time FFT visualizer.",
  "entry": "main.lua",
  "type": "tool",
  "permissions": ["player.read", "audio.fft", "ui.screen"],
  "hooks": ["onTrackChanged", "onPlaybackStateChanged"],
  "ui_mode": "canvas"
}
''';

const _kTrackVizLua = r'''
local BAR_N = 28
local heights = {}
local track = nil
local is_playing = false
local frame = 0

for i = 1, BAR_N do heights[i] = 0 end

local function fmt_ms(ms)
  local s = math.floor(ms / 1000)
  local m = math.floor(s / 60)
  return string.format("%d:%02d", m, s % 60)
end

function sono_init()
  track = sono.player.getCurrentTrack()
  is_playing = sono.player.isPlaying()
end

function sono_onTrackChanged(t)
  track = t
  for i = 1, BAR_N do heights[i] = 0 end
end

function sono_onPlaybackStateChanged(playing)
  is_playing = playing
end

function sono_onDraw(w, h)
  frame = frame + 1

  sono.canvas.clear(14, 14, 14, 255)

  local VIS_H = h * 0.42
  local BASE_Y = h * 0.60
  local BAR_W = w / BAR_N
  local PAD = 24

  -- sample FFT and map bins => bars
  local spectrum = sono.audio.getSpectrum()
  local spec_n = #spectrum

  for i = 1, BAR_N do
    local target = 0

    if spec_n > 0 then
      local lo = math.max(1, math.floor((i - 1) / BAR_N * spec_n) + 1)
      local hi = math.max(lo, math.floor(i / BAR_N * spec_n))
      local sum = 0
      for j = lo, hi do sum = sum + (spectrum[j] or 0) end
      target = sum / (hi - lo + 1)
    else
      -- fallback: ripple wave so bars aren't frozen
      local phase = (i / BAR_N) * math.pi * 2 - frame * 0.04
      target = (math.sin(phase) + 1) * 0.5 * 0.4
    end

    -- fast attack, slow decay
    if target > heights[i] then
      heights[i] = heights[i] * 0.25 + target * 0.75
    else
      heights[i] = heights[i] * 0.88 + target * 0.12
    end
    if heights[i] < 0.015 then heights[i] = 0.015 end
  end

  -- draw bars
  for i = 1, BAR_N do
    local bh = heights[i] * VIS_H
    local x = (i - 1) * BAR_W + BAR_W * 0.12
    local bw = BAR_W * 0.76
    local alpha = 140 + math.floor(heights[i] * 115)

    sono.canvas.drawRect(x, BASE_Y - bh, bw, bh, 255, 72, 147, alpha)
    sono.canvas.drawRect(x, BASE_Y + 2, bw, bh * 0.22, 255, 72, 147, 28)
  end

  sono.canvas.drawLine(0, BASE_Y, w, BASE_Y, 255, 72, 147, 50, 1)

  -- progress bar + time + track info
  if track ~= nil then
    local pos = sono.player.getPosition()
    local dur = sono.player.getDuration()
    if dur and dur > 0 and pos then
      local prog  = pos / dur
      local bar_y = BASE_Y + VIS_H * 0.12 + 14
      sono.canvas.drawRect(PAD, bar_y, w - PAD * 2, 2, 45, 45, 45, 180)
      sono.canvas.drawRect(PAD, bar_y, (w - PAD * 2) * prog, 2, 255, 72, 147, 220)
      sono.canvas.drawText(fmt_ms(pos), PAD, bar_y + 6, 170, 170, 170, 155, 11)
      sono.canvas.drawText(fmt_ms(dur), w - PAD - 38, bar_y + 6, 170, 170, 170, 155, 11)
    end

    sono.canvas.drawText(track.title  or "Unknown", PAD, h * 0.745, 255, 255, 255, 235, 18)
    sono.canvas.drawText(track.artist or "", PAD, h * 0.745 + 26, 200, 200, 200, 165, 13)
  else
    sono.canvas.drawText("Nothing playing", PAD, BASE_Y + 18, 130, 130, 130, 190, 15)
  end

  sono.canvas.drawText("Track Viz", w - 82, 18, 255, 72, 147, 120, 12)
end
''';
