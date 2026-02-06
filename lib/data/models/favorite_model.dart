class FavoriteModel {
  final int id;
  final int songId;
  final DateTime addedAt;

  FavoriteModel({
    required this.id,
    required this.songId,
    required this.addedAt,
  });

  factory FavoriteModel.fromMap(Map<String, dynamic> map) {
    return FavoriteModel(
      id: map['id'] as int,
      songId: map['song_id'] as int,
      addedAt: DateTime.fromMillisecondsSinceEpoch(map['added_at'] as int),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'song_id': songId,
      'added_at': addedAt.millisecondsSinceEpoch,
    };
  }
}

class FavoriteArtistModel {
  final int id;
  final int artistId;
  final String artistName;
  final DateTime addedAt;

  FavoriteArtistModel({
    required this.id,
    required this.artistId,
    required this.artistName,
    required this.addedAt,
  });

  factory FavoriteArtistModel.fromMap(Map<String, dynamic> map) {
    return FavoriteArtistModel(
      id: map['id'] as int,
      artistId: map['artist_id'] as int,
      artistName: map['artist_name'] as String,
      addedAt: DateTime.fromMillisecondsSinceEpoch(map['added_at'] as int),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'artist_id': artistId,
      'artist_name': artistName,
      'added_at': addedAt.millisecondsSinceEpoch,
    };
  }
}

class FavoriteAlbumModel {
  final int id;
  final int albumId;
  final String albumName;
  final DateTime addedAt;

  FavoriteAlbumModel({
    required this.id,
    required this.albumId,
    required this.albumName,
    required this.addedAt,
  });

  factory FavoriteAlbumModel.fromMap(Map<String, dynamic> map) {
    return FavoriteAlbumModel(
      id: map['id'] as int,
      albumId: map['album_id'] as int,
      albumName: map['album_name'] as String,
      addedAt: DateTime.fromMillisecondsSinceEpoch(map['added_at'] as int),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'album_id': albumId,
      'album_name': albumName,
      'added_at': addedAt.millisecondsSinceEpoch,
    };
  }
}
