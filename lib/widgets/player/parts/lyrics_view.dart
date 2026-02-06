import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import 'package:sono/widgets/player/sono_player.dart';

//represents single lyrics line
class LyricLine {
  final Duration timestamp;
  final String text;

  LyricLine(this.timestamp, this.text);
}

class SyncedLyricsViewer extends StatefulWidget {
  final String lrcLyrics;
  final ValueListenable<Duration> positionListenable;
  final TextStyle? style;
  final TextStyle? highlightedStyle;

  const SyncedLyricsViewer({
    super.key,
    required this.lrcLyrics,
    required this.positionListenable,
    this.style,
    this.highlightedStyle,
  });

  @override
  State<SyncedLyricsViewer> createState() => _SyncedLyricsViewerState();
}

class _SyncedLyricsViewerState extends State<SyncedLyricsViewer> {
  late List<LyricLine> _lyrics;
  int _currentLineIndex = -1;
  final ItemScrollController _itemScrollController = ItemScrollController();

  @override
  void initState() {
    super.initState();
    _lyrics = _parseLrc(widget.lrcLyrics);
    widget.positionListenable.addListener(_onPositionChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _onPositionChanged();
      }
    });
  }

  @override
  void dispose() {
    widget.positionListenable.removeListener(_onPositionChanged);
    super.dispose();
  }

  void _onPositionChanged() {
    _updateCurrentLine(widget.positionListenable.value);
  }

  void _updateCurrentLine(Duration position) {
    if (!mounted || _lyrics.isEmpty) return;

    int newIndex = _lyrics.lastIndexWhere((line) => position >= line.timestamp);

    if (newIndex != _currentLineIndex) {
      setState(() {
        _currentLineIndex = newIndex;
      });
      if (newIndex != -1) {
        _itemScrollController.scrollTo(
          index: newIndex,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
          alignment: 0.4,
        );
      }
    }
  }

  List<LyricLine> _parseLrc(String lrc) {
    final lines = <LyricLine>[];
    final regex = RegExp(r"\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)");

    for (final lineStr in lrc.split('\n')) {
      final match = regex.firstMatch(lineStr);
      if (match != null) {
        final min = int.parse(match.group(1)!);
        final sec = int.parse(match.group(2)!);
        final ms = int.parse(match.group(3)!.padRight(3, '0'));
        final text = match.group(4)!.trim();

        if (text.isNotEmpty) {
          final timestamp = Duration(
            minutes: min,
            seconds: sec,
            milliseconds: ms,
          );
          lines.add(LyricLine(timestamp, text));
        }
      }
    }
    lines.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return lines;
  }

  @override
  Widget build(BuildContext context) {
    final defaultStyle =
        widget.style ??
        const TextStyle(color: Colors.white70, fontSize: 18, height: 1.6);
    final highlightedStyle =
        widget.highlightedStyle ??
        TextStyle(
          color: Theme.of(context).primaryColor,
          fontSize: 19,
          fontWeight: FontWeight.bold,
          height: 1.6,
        );

    if (_lyrics.isEmpty) {
      return Center(
        child: Text("No synced lyrics available.", style: defaultStyle),
      );
    }

    return ScrollablePositionedList.builder(
      itemCount: _lyrics.length + 1, //add 1 for attribution footer
      itemScrollController: _itemScrollController,
      itemBuilder: (context, index) {
        //if last item show attribution footer
        if (index >= _lyrics.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 32.0,
              horizontal: 16.0,
            ),
            child: Text(
              "Lyrics provided by lrclib.net",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'VarelaRound',
                color: Colors.white.withAlpha((255 * 0.4).round()),
                fontSize: 12,
              ),
            ),
          );
        }

        final isCurrent = index == _currentLineIndex;
        final lyricLine = _lyrics[index];

        return InkWell(
          onTap: () {
            //go to the timestamp of the tapped line
            SonoPlayer().seek(lyricLine.timestamp);
          },
          splashColor: Theme.of(
            context,
          ).primaryColor.withAlpha((255 * 0.1).round()),
          highlightColor: Theme.of(
            context,
          ).primaryColor.withAlpha((255 * 0.05).round()),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 6.0,
              horizontal: 16.0,
            ),
            child: AnimatedDefaultTextStyle(
              style: isCurrent ? highlightedStyle : defaultStyle,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              textAlign: TextAlign.left,
              child: Text(lyricLine.text),
            ),
          ),
        );
      },
    );
  }
}
