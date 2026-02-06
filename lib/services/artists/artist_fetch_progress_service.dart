import 'package:flutter/foundation.dart';

/// Service to track artist image fetch progress globally
class ArtistFetchProgressService extends ChangeNotifier {
  static final ArtistFetchProgressService _instance =
      ArtistFetchProgressService._internal();
  factory ArtistFetchProgressService() => _instance;
  ArtistFetchProgressService._internal();

  bool _isFetching = false;
  int _currentProgress = 0;
  int _totalArtists = 0;
  final List<String> _logs = [];
  String? _currentArtist;
  DateTime? _startTime;
  int _successCount = 0;
  int _failureCount = 0;

  bool get isFetching => _isFetching;
  int get currentProgress => _currentProgress;
  int get totalArtists => _totalArtists;
  List<String> get logs => List.unmodifiable(_logs);
  String? get currentArtist => _currentArtist;
  DateTime? get startTime => _startTime;
  int get successCount => _successCount;
  int get failureCount => _failureCount;

  double get progress {
    if (_totalArtists == 0) return 0.0;
    return _currentProgress / _totalArtists;
  }

  String get statusText {
    if (!_isFetching && _currentProgress == 0) {
      return 'Not started';
    }
    if (!_isFetching && _currentProgress == _totalArtists) {
      return 'Completed';
    }
    if (_isFetching) {
      return 'Fetching... $_currentProgress/$_totalArtists';
    }
    return 'Paused at $_currentProgress/$_totalArtists';
  }

  void startFetch(int total) {
    _isFetching = true;
    _currentProgress = 0;
    _totalArtists = total;
    _logs.clear();
    _startTime = DateTime.now();
    _successCount = 0;
    _failureCount = 0;
    _addLog('Started fetching $total artists from API');
    notifyListeners();
  }

  void updateProgress(int current, int total, String? artistName) {
    _currentProgress = current;
    _totalArtists = total;
    _currentArtist = artistName;

    if (current % 10 == 0 || current == total) {
      _addLog('Progress: $current/$total artists processed');
    }

    notifyListeners();
  }

  void incrementSuccess(String artistName) {
    _successCount++;
    _addLog('Fetched image for: $artistName');
    notifyListeners();
  }

  void incrementFailure(String artistName, String reason) {
    _failureCount++;
    if (kDebugMode) {
      _addLog('Failed for $artistName: $reason');
    }
    notifyListeners();
  }

  void completeFetch() {
    _isFetching = false;
    final duration = DateTime.now().difference(_startTime ?? DateTime.now());
    _addLog(
      'Completed! Total: $_totalArtists, Success: $_successCount, Failed: $_failureCount',
    );
    _addLog('Time taken: ${duration.inMinutes}m ${duration.inSeconds % 60}s');
    _currentArtist = null;
    notifyListeners();
  }

  void cancelFetch() {
    _isFetching = false;
    _addLog('Fetch cancelled by user');
    _currentArtist = null;
    notifyListeners();
  }

  void _addLog(String message) {
    final timestamp = DateTime.now();
    final timeStr =
        '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}';
    _logs.add('[$timeStr] $message');

    //keep only last 100 logs to prevent memory issues
    if (_logs.length > 100) {
      _logs.removeAt(0);
    }
  }

  void clearLogs() {
    _logs.clear();
    notifyListeners();
  }
}
