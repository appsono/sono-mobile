import 'package:on_audio_query/on_audio_query.dart';

class RemoteArtist {
  final String id;
  final String name;
  final int albumCount;
  final String? coverArtId;
  final int serverId;
  final bool starred;

  RemoteArtist({
    required this.id,
    required this.name,
    this.albumCount = 0,
    this.coverArtId,
    required this.serverId,
    this.starred = false,
  });
}

class RemoteAlbum {
  final String id;
  final String name;
  final String? artistName;
  final String? artistId;
  final int? year;
  final int songCount;
  final int? duration;
  final String? coverArtId;
  final int serverId;
  final bool starred;

  RemoteAlbum({
    required this.id,
    required this.name,
    this.artistName,
    this.artistId,
    this.year,
    this.songCount = 0,
    this.duration,
    this.coverArtId,
    required this.serverId,
    this.starred = false,
  });
}

class RemoteSong {
  final String id;
  final String title;
  final String? artist;
  final String? album;
  final String? albumId;
  final int? trackNumber;
  final int? duration; //seconds
  final String? coverArtId;
  final int? bitRate;
  final String? suffix;
  final int serverId;
  final bool starred;

  RemoteSong({
    required this.id,
    required this.title,
    this.artist,
    this.album,
    this.albumId,
    this.trackNumber,
    this.duration,
    this.coverArtId,
    this.bitRate,
    this.suffix,
    required this.serverId,
    this.starred = false,
  });

  /// Convert to SongModel for player queue compatibility
  /// Uses a synthetic negative ID to avoid collision with local MediaStore IDs
  SongModel toSongModel(String streamUrl, {String? coverArtUrl}) {
    final syntheticId = -('$serverId:$id'.hashCode.abs() + 1);
    final displayName = '$title.${suffix ?? 'mp3'}';
    return SongModel({
      '_id': syntheticId,
      'title': title,
      'artist': artist ?? 'Unknown Artist',
      'album': album,
      'duration': (duration ?? 0) * 1000,
      '_uri': streamUrl,
      '_data': streamUrl,
      '_display_name': displayName,
      '_display_name_wo_ext': title,
      '_size': 0,
      'file_extension': '.${suffix ?? 'mp3'}',
      'track': trackNumber,
      'remote_artwork_url': coverArtUrl,
      'remote_song_id': id,
      'remote_server_id': serverId,
      'remote_starred': starred,
    });
  }
}

class RemoteSearchResult {
  final List<RemoteArtist> artists;
  final List<RemoteAlbum> albums;
  final List<RemoteSong> songs;

  RemoteSearchResult({
    this.artists = const [],
    this.albums = const [],
    this.songs = const [],
  });
}
