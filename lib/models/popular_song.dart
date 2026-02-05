import 'package:on_audio_query/on_audio_query.dart';

class PopularSong {
  final String title;
  final String artist;
  final int? rank;
  final int? streams;
  final String? externalUrl;

  //for library matching
  bool isInLibrary;
  SongModel? localSong;

  PopularSong({
    required this.title,
    required this.artist,
    this.rank,
    this.streams,
    this.externalUrl,
    this.isInLibrary = false,
    this.localSong,
  });

  factory PopularSong.fromJson(Map<String, dynamic> json) {
    String title = '';
    String artist = '';

    //first: check if individual title/artist fields exist (from cache)
    if (json.containsKey('title') && json['title'] != null && json['title'].toString().isNotEmpty) {
      title = json['title'] as String;
      artist = json['artist'] as String? ?? '';
    } else {
      //otherwise => parse artist_and_title field (from API)
      final artistAndTitle = json['artist_and_title'] as String?;
      if (artistAndTitle != null && artistAndTitle.isNotEmpty) {
        if (artistAndTitle.contains(' - ')) {
          final parts = artistAndTitle.split(' - ');
          if (parts.length >= 2) {
            artist = parts[0].trim();
            title = parts.sublist(1).join(' - ').trim(); //handles titles with " - " in them
          }
        } else {
          //fallback: if no separator => use the whole string as title
          title = artistAndTitle.trim();
        }
      }
    }

    return PopularSong(
      title: title,
      artist: artist,
      rank: json['rank'] as int?,
      streams: json['streams'] as int?,
      externalUrl: json['external_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'artist': artist,
      'rank': rank,
      'streams': streams,
      'external_url': externalUrl,
      //store original artist_and_title for reconstruction (if needed)
      'artist_and_title': artist.isNotEmpty && title.isNotEmpty
          ? '$artist - $title'
          : title.isNotEmpty ? title : artist,
    };
  }

  PopularSong copyWith({
    String? title,
    String? artist,
    int? rank,
    int? streams,
    String? externalUrl,
    bool? isInLibrary,
    SongModel? localSong,
  }) {
    return PopularSong(
      title: title ?? this.title,
      artist: artist ?? this.artist,
      rank: rank ?? this.rank,
      streams: streams ?? this.streams,
      externalUrl: externalUrl ?? this.externalUrl,
      isInLibrary: isInLibrary ?? this.isInLibrary,
      localSong: localSong ?? this.localSong,
    );
  }
}
