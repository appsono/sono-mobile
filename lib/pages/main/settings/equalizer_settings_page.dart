import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:sono/widgets/player/sono_player.dart';
import 'package:sono/services/settings/audio_effects_service.dart';
import 'package:sono/styles/app_theme.dart';
import 'package:sono/widgets/global/bottom_sheet.dart';

/// equalizer settings page
class EqualizerSettingsPage extends StatefulWidget {
  const EqualizerSettingsPage({super.key});

  @override
  State<EqualizerSettingsPage> createState() => _EqualizerSettingsPageState();
}

class _EqualizerSettingsPageState extends State<EqualizerSettingsPage> {
  final SonoPlayer _player = SonoPlayer();
  final AudioEffectsService _audioEffectsService = AudioEffectsService.instance;

  bool _isEnabled = false;
  bool _isLoading = true;
  AndroidEqualizerParameters? _equalizerParams;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadEqualizer();
  }

  Future<void> _loadEqualizer() async {
    try {
      if (!Platform.isAndroid) {
        setState(() {
          _errorMessage = 'Equalizer is currently only supported on Android.';
          _isLoading = false;
        });
        return;
      }

      final params = await _player.getEqualizerParameters();
      if (params == null) {
        setState(() {
          _errorMessage = 'Equalizer not available on this device.';
          _isLoading = false;
        });
        return;
      }

      final enabled = await _audioEffectsService.getEqualizerEnabled();

      setState(() {
        _equalizerParams = params;
        _isEnabled = enabled;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading equalizer: $e';
        _isLoading = false;
      });
    }
  }

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
          'Equalizer',
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
              : _errorMessage != null
              ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_rounded,
                        size: 64,
                        color: Colors.red.withAlpha((0.7 * 255).round()),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontFamily: 'VarelaRound',
                        ),
                      ),
                    ],
                  ),
                ),
              )
              : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Container(
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
                                _isEnabled
                                    ? AppTheme.brandPink.withAlpha(
                                      (0.15 * 255).round(),
                                    )
                                    : Colors.white.withAlpha(
                                      (0.1 * 255).round(),
                                    ),
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusSm,
                            ),
                          ),
                          child: Icon(
                            Icons.equalizer_rounded,
                            color:
                                _isEnabled
                                    ? AppTheme.brandPink
                                    : Colors.white.withAlpha(
                                      (0.7 * 255).round(),
                                    ),
                            size: 20,
                          ),
                        ),
                        title: const Text(
                          'Enable Equalizer',
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'VarelaRound',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: const Text(
                          'Adjust audio frequency response',
                          style: TextStyle(
                            color: Colors.white70,
                            fontFamily: 'VarelaRound',
                          ),
                        ),
                        value: _isEnabled,
                        activeTrackColor: AppTheme.brandPink.withAlpha(
                          (0.5 * 255).round(),
                        ),
                        activeThumbColor: AppTheme.brandPink,
                        onChanged: (value) async {
                          setState(() => _isEnabled = value);
                          await _player.setEqualizerEnabled(value);
                        },
                      ),
                    ),
                  ),

                  Expanded(
                    child:
                        _equalizerParams == null
                            ? const Center(
                              child: Text(
                                'No equalizer available',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'VarelaRound',
                                ),
                              ),
                            )
                            : ListView(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.all(16),
                              children: [
                                ..._equalizerParams!.bands.asMap().entries.map((
                                  entry,
                                ) {
                                  final index = entry.key;
                                  final band = entry.value;
                                  return _buildBandSlider(index, band);
                                }),

                                const SizedBox(height: 24),

                                Center(
                                  child: ElevatedButton.icon(
                                    onPressed: _resetToFlat,
                                    icon: const Icon(Icons.restart_alt_rounded),
                                    label: const Text(
                                      'Reset to Flat',
                                      style: TextStyle(
                                        fontFamily: 'VarelaRound',
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.brandPink,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 12,
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 16),

                                Text(
                                  'Range: ${_equalizerParams!.minDecibels.toStringAsFixed(1)} dB to ${_equalizerParams!.maxDecibels.toStringAsFixed(1)} dB',
                                  style: TextStyle(
                                    color: Colors.white.withAlpha(
                                      (0.7 * 255).round(),
                                    ),
                                    fontSize: 12,
                                    fontFamily: 'VarelaRound',
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 32),
                              ],
                            ),
                  ),
                ],
              ),
    );
  }

  Widget _buildBandSlider(int index, AndroidEqualizerBand band) {
    //format frequency (e.g., 60 Hz, 1.2 kHz)
    final freqHz = band.centerFrequency;
    final freqLabel =
        freqHz >= 1000
            ? '${(freqHz / 1000).toStringAsFixed(1)} kHz'
            : '${freqHz.toStringAsFixed(0)} Hz';

    return StreamBuilder<double>(
      stream: band.gainStream,
      initialData: band.gain,
      builder: (context, snapshot) {
        final gain = snapshot.data ?? 0.0;

        return Container(
          margin: const EdgeInsets.only(bottom: 5),
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppTheme.brandPink.withAlpha(
                            (0.15 * 255).round(),
                          ),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusSm,
                          ),
                        ),
                        child: const Icon(
                          Icons.graphic_eq_rounded,
                          color: AppTheme.brandPink,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        freqLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'VarelaRound',
                        ),
                      ),
                    ],
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
                      '${gain >= 0 ? "+" : ""}${gain.toStringAsFixed(1)} dB',
                      style: const TextStyle(
                        color: AppTheme.brandPink,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'VarelaRound',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Slider(
                value: gain,
                min: _equalizerParams!.minDecibels,
                max: _equalizerParams!.maxDecibels,
                divisions: 100,
                activeColor: AppTheme.brandPink,
                inactiveColor: Colors.white.withAlpha((0.2 * 255).round()),
                onChanged:
                    _isEnabled
                        ? (value) async {
                          await band.setGain(value);
                          await _player.setEqualizerBandLevel(index, value);
                        }
                        : null,
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _resetToFlat() async {
    if (_equalizerParams == null) return;

    final confirmed = await showSonoBottomSheet<bool>(
      context: context,
      title: 'Reset Equalizer',
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.restart_alt_rounded,
              size: 48,
              color: AppTheme.brandPink.withAlpha((0.7 * 255).round()),
            ),
            const SizedBox(height: 16),
            const Text(
              'Reset all frequency bands to 0 dB?',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontFamily: 'VarelaRound',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            'CANCEL',
            style: TextStyle(
              color: Colors.white.withAlpha((0.7 * 255).round()),
              fontFamily: 'VarelaRound',
            ),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.brandPink,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: const Text(
            'RESET',
            style: TextStyle(fontFamily: 'VarelaRound'),
          ),
        ),
      ],
    );

    if (confirmed == true) {
      for (int i = 0; i < _equalizerParams!.bands.length; i++) {
        await _equalizerParams!.bands[i].setGain(0.0);
        await _player.setEqualizerBandLevel(i, 0.0);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Equalizer reset to flat',
              style: TextStyle(fontFamily: 'VarelaRound'),
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
