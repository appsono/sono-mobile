import 'package:sono/models/popular_song.dart';

class KworbResponse {
  final List<PopularSong> topSongs;
  final int? monthlyListeners;

  KworbResponse({
    required this.topSongs,
    this.monthlyListeners,
  });

  factory KworbResponse.fromJson(Map<String, dynamic> json) {
    //parse top_songs array
    List<PopularSong> songs = [];
    final topSongsJson = json['top_songs'] as List<dynamic>?;
    if (topSongsJson != null) {
      songs = topSongsJson
          .map((item) => PopularSong.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    //parse monthly_listeners array (take first element)
    int? listeners;
    final monthlyListenersJson = json['monthly_listeners'] as List<dynamic>?;
    if (monthlyListenersJson != null && monthlyListenersJson.isNotEmpty) {
      final firstListener = monthlyListenersJson[0] as Map<String, dynamic>;
      listeners = firstListener['listeners'] as int?;
    }

    return KworbResponse(
      topSongs: songs,
      monthlyListeners: listeners,
    );
  }
}
