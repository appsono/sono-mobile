String formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = (duration.inMinutes % 60);
  final seconds = (duration.inSeconds % 60);

  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  } else {
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
