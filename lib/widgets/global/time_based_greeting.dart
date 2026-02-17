import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sono/styles/app_theme.dart';

class TimeBasedGreeting extends StatefulWidget {
  /// Optional username to display below the greeting
  final String? userName;

  /// Whether to show the greeting in compact single-line format
  final bool compact;

  const TimeBasedGreeting({super.key, this.userName, this.compact = false});

  @override
  State<TimeBasedGreeting> createState() => _TimeBasedGreetingState();
}

class _TimeBasedGreetingState extends State<TimeBasedGreeting> {
  String greeting = '';
  Timer? timer;

  @override
  void initState() {
    super.initState();
    _updateGreeting();
    _startTimer();
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void _updateGreeting() {
    if (mounted) {
      final newGreeting = _getGreeting();
      if (greeting != newGreeting) {
        setState(() {
          greeting = newGreeting;
        });
      }
    }
  }

  void _startTimer() {
    timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _updateGreeting();
    });
  }

  String _getGreeting() {
    final now = DateTime.now();
    final hour = now.hour;

    if (hour >= 4 && hour < 6) {
      //:00 AM - 5:59 AM
      return "Up early";
    } else if (hour >= 6 && hour < 11) {
      //:00 AM - 10:59 AM
      return "Good morning";
    } else if (hour >= 11 && hour < 14) {
      //1:00 AM - 1:59 PM
      return "Midday";
    } else if (hour >= 14 && hour < 17) {
      //:00 PM - 4:59 PM
      return "Good afternoon";
    } else if (hour >= 17 && hour < 19) {
      //:00 PM - 6:59 PM
      return "Early evening";
    } else if (hour >= 19 && hour < 22) {
      //:00 PM - 9:59 PM
      return "Good evening";
    } else {
      //0:00 PM - 3:59 AM
      return "Good night";
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth > 600;

    if (greeting.isEmpty) {
      return SizedBox(
        width: AppTheme.responsiveDimension(context, 100),
        height: AppTheme.responsiveDimension(context, 20),
        child: Center(
          child: SizedBox(
            width: AppTheme.responsiveDimension(context, 12),
            height: AppTheme.responsiveDimension(context, 12),
            child: CircularProgressIndicator(
              strokeWidth: AppTheme.responsiveDimension(context, 2),
              color: AppTheme.brandPink,
            ),
          ),
        ),
      );
    }

    if (widget.compact || widget.userName == null) {
      return Text(
        widget.userName != null ? '$greeting,' : '$greeting!',
        style: TextStyle(
          fontFamily: 'VarelaRound',
          fontSize: isLargeScreen ? 22.0 : AppTheme.responsiveFontSize(context, 22.0, min: 18.0),
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$greeting,',
          style: TextStyle(
            fontFamily: 'VarelaRound',
            fontSize: isLargeScreen ? 14.0 : AppTheme.responsiveFontSize(context, 14.0, min: 12.0),
            color: Colors.white.withAlpha(179),
            fontWeight: FontWeight.normal,
          ),
        ),
        SizedBox(height: isLargeScreen ? 2.0 : AppTheme.responsiveSpacing(context, 2.0)),
        Text(
          widget.userName!,
          style: TextStyle(
            fontFamily: 'VarelaRound',
            fontSize: isLargeScreen ? 20.0 : AppTheme.responsiveFontSize(context, 20.0, min: 16.0),
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
