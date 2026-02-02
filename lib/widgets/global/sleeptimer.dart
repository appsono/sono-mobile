import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:sono/styles/text.dart';
import 'package:sono/styles/app_theme.dart';
import 'package:sono/widgets/player/sono_player.dart';

void showSleepTimerOptions(BuildContext context, SonoPlayer sonoPlayer) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppTheme.surfaceDark,
    builder: (context) {
      return SafeArea(
        child: Wrap(
          children: <Widget>[
            ListTile(
              leading: const Icon(
                Icons.timer_10_rounded,
                color: AppTheme.textSecondaryDark,
              ),
              title: const Text(
                '15 Minutes',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'VarelaRound',
                ),
              ),
              onTap: () {
                sonoPlayer.setSleepTimer(const Duration(minutes: 15));
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.timer_rounded,
                color: AppTheme.textSecondaryDark,
              ),
              title: const Text(
                '30 Minutes',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'VarelaRound',
                ),
              ),
              onTap: () {
                sonoPlayer.setSleepTimer(const Duration(minutes: 30));
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.hourglass_bottom_rounded,
                color: AppTheme.textSecondaryDark,
              ),
              title: const Text(
                '60 Minutes',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'VarelaRound',
                ),
              ),
              onTap: () {
                sonoPlayer.setSleepTimer(const Duration(minutes: 60));
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.tune_rounded,
                color: AppTheme.textSecondaryDark,
              ),
              title: const Text(
                'Custom Duration...',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'VarelaRound',
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _showCustomSleepTimerSheet(context, sonoPlayer);
              },
            ),
            const Divider(color: Colors.white24),
            ListTile(
              leading: const Icon(
                Icons.cancel_rounded,
                color: Colors.redAccent,
              ),
              title: const Text(
                'Cancel Timer',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontFamily: 'VarelaRound',
                ),
              ),
              onTap: () {
                sonoPlayer.setSleepTimer(null);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      );
    },
  );
}

void _showCustomSleepTimerSheet(BuildContext context, SonoPlayer sonoPlayer) {
  final customSheet = _CustomSleepTimerSheet(sonoPlayer: sonoPlayer);

  showModalBottomSheet(
    context: context,
    backgroundColor: AppTheme.elevatedSurfaceDark,
    isScrollControlled: true,
    enableDrag: true,
    isDismissible: true,
    builder: (context) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: customSheet, //use the cached widget instance
      );
    },
  );
}

class _CustomSleepTimerSheet extends StatefulWidget {
  final SonoPlayer sonoPlayer;
  const _CustomSleepTimerSheet({required this.sonoPlayer});

  @override
  State<_CustomSleepTimerSheet> createState() => _CustomSleepTimerSheetState();
}

class _CustomSleepTimerSheetState extends State<_CustomSleepTimerSheet> {
  final _hoursController = TextEditingController();
  final _minutesController = TextEditingController();
  final _minutesFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    final currentRemaining = widget.sonoPlayer.sleepTimerRemaining.value;
    if (currentRemaining != null && currentRemaining.inMinutes > 0) {
      _hoursController.text = currentRemaining.inHours.toString();
      _minutesController.text =
          currentRemaining.inMinutes.remainder(60).toString();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted) {
          FocusScope.of(context).requestFocus(_minutesFocusNode);
        }
      });
    });
  }

  @override
  void dispose() {
    _hoursController.dispose();
    _minutesController.dispose();
    _minutesFocusNode.dispose();
    super.dispose();
  }

  void _setTimer() {
    final hours = int.tryParse(_hoursController.text) ?? 0;
    final minutes = int.tryParse(_minutesController.text) ?? 0;
    final totalDuration = Duration(hours: hours, minutes: minutes);

    if (totalDuration.inSeconds > 0) {
      widget.sonoPlayer.setSleepTimer(totalDuration);
    } else {
      widget.sonoPlayer.setSleepTimer(null);
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Set Custom Sleep Timer',
            style: AppStyles.sonoPlayerTitle.copyWith(fontSize: 18),
          ),
          SizedBox(height: AppTheme.spacingLg),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              SizedBox(
                width: 80,
                child: TextField(
                  controller: _hoursController,
                  style: const TextStyle(color: Colors.white, fontSize: 22),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    labelText: "Hours",
                    labelStyle: TextStyle(
                      color: Colors.white.withAlpha((255 * 0.7).round()),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                child: Text(
                  ':',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(
                width: 80,
                child: TextField(
                  controller: _minutesController,
                  focusNode: _minutesFocusNode,
                  style: const TextStyle(color: Colors.white, fontSize: 22),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    labelText: "Minutes",
                    labelStyle: TextStyle(
                      color: Colors.white.withAlpha((255 * 0.7).round()),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
            ],
          ),
          SizedBox(height: AppTheme.spacingXl),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: AppTheme.textSecondaryDark),
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
              SizedBox(width: AppTheme.spacingXs),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                ),
                onPressed: _setTimer,
                child: const Text('Set Timer'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}