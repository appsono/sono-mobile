class PlaylistModel {
  final int id;
  final String name;
  final String? description;
  final int? coverSongId;
  final String? customCoverPath;
  final int? mediastoreId;
  final bool isFavorite;
  final PlaylistSyncStatus syncStatus;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PlaylistModel({
    required this.id,
    required this.name,
    this.description,
    this.coverSongId,
    this.customCoverPath,
    this.mediastoreId,
    required this.isFavorite,
    required this.syncStatus,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PlaylistModel.fromMap(Map<String, dynamic> map) {
    return PlaylistModel(
      id: map['id'] as int,
      name: map['name'] as String,
      description: map['description'] as String?,
      coverSongId: map['cover_song_id'] as int?,
      customCoverPath: map['custom_cover_path'] as String?,
      mediastoreId: map['mediastore_id'] as int?,
      isFavorite: (map['is_favorite'] as int) == 1,
      syncStatus: PlaylistSyncStatus.fromString(
        map['sync_status'] as String? ?? 'synced',
      ),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'cover_song_id': coverSongId,
      'custom_cover_path': customCoverPath,
      'mediastore_id': mediastoreId,
      'is_favorite': isFavorite ? 1 : 0,
      'sync_status': syncStatus.value,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  PlaylistModel copyWith({
    int? id,
    String? name,
    String? description,
    int? coverSongId,
    String? customCoverPath,
    int? mediastoreId,
    bool? isFavorite,
    PlaylistSyncStatus? syncStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PlaylistModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      coverSongId: coverSongId ?? this.coverSongId,
      customCoverPath: customCoverPath ?? this.customCoverPath,
      mediastoreId: mediastoreId ?? this.mediastoreId,
      isFavorite: isFavorite ?? this.isFavorite,
      syncStatus: syncStatus ?? this.syncStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  ///Check if playlist has a custom cover image
  bool get hasCustomCover =>
      customCoverPath != null && customCoverPath!.isNotEmpty;

  ///Check if playlist has any cover (custom or song artwork)
  bool get hasCover => hasCustomCover || coverSongId != null;

  bool get isSynced => syncStatus == PlaylistSyncStatus.synced;

  bool get needsSync =>
      syncStatus == PlaylistSyncStatus.failed ||
      syncStatus == PlaylistSyncStatus.pending;
}

enum PlaylistSyncStatus {
  synced('synced'), //successfully synced with MediaStore
  pending('pending'), //waiting to sync
  failed('failed'), //sync failed, needs retry
  databaseOnly('database_only'); //intentionally not synced to MediaStore

  final String value;
  const PlaylistSyncStatus(this.value);

  static PlaylistSyncStatus fromString(String value) {
    switch (value) {
      case 'synced':
        return PlaylistSyncStatus.synced;
      case 'pending':
        return PlaylistSyncStatus.pending;
      case 'failed':
        return PlaylistSyncStatus.failed;
      case 'database_only':
        return PlaylistSyncStatus.databaseOnly;
      default:
        return PlaylistSyncStatus.synced;
    }
  }
}

class PlaylistSongModel {
  final int id;
  final int playlistId;
  final int songId;
  final int position;
  final DateTime addedAt;

  const PlaylistSongModel({
    required this.id,
    required this.playlistId,
    required this.songId,
    required this.position,
    required this.addedAt,
  });

  factory PlaylistSongModel.fromMap(Map<String, dynamic> map) {
    return PlaylistSongModel(
      id: map['id'] as int,
      playlistId: map['playlist_id'] as int,
      songId: map['song_id'] as int,
      position: map['position'] as int,
      addedAt: DateTime.fromMillisecondsSinceEpoch(map['added_at'] as int),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'playlist_id': playlistId,
      'song_id': songId,
      'position': position,
      'added_at': addedAt.millisecondsSinceEpoch,
    };
  }
}
