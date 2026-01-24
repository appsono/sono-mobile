import 'package:flutter/material.dart';
import 'package:sono/services/settings/playback_settings_service.dart';
import 'package:sono/styles/app_theme.dart';
import 'package:sono/widgets/player/sono_player.dart';
import 'package:sono/widgets/global/sleeptimer.dart';
import 'equalizer_settings_page.dart';

/// playback & audio effects settings page
class PlaybackAudioSettingsPage extends StatefulWidget {
  const PlaybackAudioSettingsPage({super.key});

  @override
  State<PlaybackAudioSettingsPage> createState() =>
      _PlaybackAudioSettingsPageState();
}

class _PlaybackAudioSettingsPageState extends State<PlaybackAudioSettingsPage> {
  final PlaybackSettingsService _playbackSettings =
      PlaybackSettingsService.instance;
  final SonoPlayer _player = SonoPlayer();

  bool _backgroundPlayback = true;
  bool _crossfadeEnabled = false;
  int _crossfadeDuration = 5;
  double _speed = 1.0;
  double _pitch = 1.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final backgroundPlayback =
        await _playbackSettings.getBackgroundPlaybackEnabled();
    final crossfade = await _playbackSettings.getCrossfadeEnabled();
    final duration = await _playbackSettings.getCrossfadeDuration();
    final speed = await _playbackSettings.getSpeed();
    final pitch = await _playbackSettings.getPitch();

    setState(() {
      _backgroundPlayback = backgroundPlayback;
      _crossfadeEnabled = crossfade;
      _crossfadeDuration = duration;
      _speed = speed;
      _pitch = pitch;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Playback & Audio',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontFamily: 'VarelaRound',
          ),
        ),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'PLAYBACK',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      fontFamily: 'VarelaRound',
                    ),
                  ),
                  const SizedBox(height: 12),

                  _buildSwitchTile(
                    icon: Icons.play_circle_rounded,
                    title: 'Background Playback',
                    subtitle: 'Continue playing when app is in background',
                    value: _backgroundPlayback,
                    onChanged: (value) async {
                      setState(() => _backgroundPlayback = value);
                      await _playbackSettings.setBackgroundPlaybackEnabled(
                        value,
                      );
                    },
                  ),

                  const SizedBox(height: 5),

                  _buildSwitchTile(
                    icon: Icons.waves_rounded,
                    title: 'Crossfade',
                    subtitle: 'Fade between tracks',
                    value: _crossfadeEnabled,
                    onChanged: (value) async {
                      setState(() => _crossfadeEnabled = value);
                      await _playbackSettings.setCrossfadeEnabled(value);
                      _player.setCrossfadeEnabled(value);
                    },
                  ),

                  if (_crossfadeEnabled) ...[
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Crossfade Duration',
                            style: TextStyle(
                              color: Colors.white.withAlpha(
                                (0.9 * 255).round(),
                              ),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'VarelaRound',
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Slider(
                                  value: _crossfadeDuration.toDouble(),
                                  min: 1,
                                  max: 10,
                                  divisions: 9,
                                  activeColor: AppTheme.brandPink,
                                  inactiveColor: Colors.white.withAlpha(
                                    (0.2 * 255).round(),
                                  ),
                                  label: '$_crossfadeDuration seconds',
                                  onChanged: (value) {
                                    setState(
                                      () => _crossfadeDuration = value.round(),
                                    );
                                  },
                                  onChangeEnd: (value) async {
                                    final duration = value.round();
                                    await _playbackSettings
                                        .setCrossfadeDuration(duration);
                                    _player.setCrossfadeDuration(
                                      Duration(seconds: duration),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(
                                    (0.1 * 255).round(),
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusSm,
                                  ),
                                ),
                                child: Text(
                                  '${_crossfadeDuration}s',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'VarelaRound',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 5),

                  _buildNavigationTile(
                    icon: Icons.timer_rounded,
                    title: 'Sleep Timer',
                    subtitle: 'Stop playback after a set time',
                    onTap: () {
                      showSleepTimerOptions(context, _player);
                    },
                  ),

                  const SizedBox(height: 24),

                  const Text(
                    'SPEED & PITCH',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      fontFamily: 'VarelaRound',
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildSliderControl(
                    icon: Icons.speed_rounded,
                    label: 'Playback Speed',
                    value: _speed,
                    min: 0.5,
                    max: 2.0,
                    divisions: 30,
                    displayValue: '${_speed.toStringAsFixed(2)}x',
                    onChanged: (value) {
                      setState(() => _speed = value);
                    },
                    onChangeEnd: (value) async {
                      await _playbackSettings.setSpeed(value);
                      await _player.setSpeed(value);
                    },
                    onReset: () async {
                      setState(() => _speed = 1.0);
                      await _playbackSettings.setSpeed(1.0);
                      await _player.setSpeed(1.0);
                    },
                  ),

                  const SizedBox(height: 5),

                  _buildSliderControl(
                    icon: Icons.graphic_eq_rounded,
                    label: 'Playback Pitch',
                    value: _pitch,
                    min: 0.5,
                    max: 2.0,
                    divisions: 30,
                    displayValue: '${_pitch.toStringAsFixed(2)}x',
                    onChanged: (value) {
                      setState(() => _pitch = value);
                    },
                    onChangeEnd: (value) async {
                      await _playbackSettings.setPitch(value);
                      await _player.setPitch(value);
                    },
                    onReset: () async {
                      setState(() => _pitch = 1.0);
                      await _playbackSettings.setPitch(1.0);
                      await _player.setPitch(1.0);
                    },
                  ),

                  const SizedBox(height: 24),

                  const Text(
                    'AUDIO EFFECTS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      fontFamily: 'VarelaRound',
                    ),
                  ),
                  const SizedBox(height: 12),

                  _buildNavigationTile(
                    icon: Icons.equalizer_rounded,
                    title: 'Equalizer',
                    subtitle: 'Adjust frequency bands',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const EqualizerSettingsPage(),
                        ),
                      );
                    },
                  ),
                ],
              ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withAlpha((0.05 * 255).round()),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: Colors.white.withAlpha((0.1 * 255).round()),
          width: 0.5,
        ),
      ),
      child: SwitchListTile(
        secondary: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color:
                value
                    ? AppTheme.brandPink.withAlpha((0.15 * 255).round())
                    : Colors.white.withAlpha((0.1 * 255).round()),
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          ),
          child: Icon(
            icon,
            color:
                value
                    ? AppTheme.brandPink
                    : Colors.white.withAlpha((0.7 * 255).round()),
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'VarelaRound',
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: Colors.white.withAlpha((0.7 * 255).round()),
            fontFamily: 'VarelaRound',
          ),
        ),
        value: value,
        activeTrackColor: AppTheme.brandPink.withAlpha((0.5 * 255).round()),
        activeThumbColor: AppTheme.brandPink,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildSliderControl({
    required IconData icon,
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String displayValue,
    required Function(double) onChanged,
    required Function(double) onChangeEnd,
    required VoidCallback onReset,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha((0.05 * 255).round()),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: Colors.white.withAlpha((0.1 * 255).round()),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.brandPink.withAlpha((0.15 * 255).round()),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Icon(icon, color: AppTheme.brandPink, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'VarelaRound',
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha((0.1 * 255).round()),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Text(
                  displayValue,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'VarelaRound',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: value,
                  min: min,
                  max: max,
                  divisions: divisions,
                  activeColor: AppTheme.brandPink,
                  inactiveColor: Colors.white.withAlpha((0.2 * 255).round()),
                  label: displayValue,
                  onChanged: onChanged,
                  onChangeEnd: onChangeEnd,
                ),
              ),
              TextButton(
                onPressed: onReset,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  minimumSize: const Size(60, 32),
                ),
                child: Text(
                  'Reset',
                  style: TextStyle(
                    color: AppTheme.brandPink,
                    fontFamily: 'VarelaRound',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha((0.05 * 255).round()),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(
              color: Colors.white.withAlpha((0.1 * 255).round()),
              width: 0.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.brandPink.withAlpha((0.15 * 255).round()),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Icon(icon, color: AppTheme.brandPink, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'VarelaRound',
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withAlpha((0.7 * 255).round()),
                        fontSize: 14,
                        fontFamily: 'VarelaRound',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white.withAlpha((0.5 * 255).round()),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}