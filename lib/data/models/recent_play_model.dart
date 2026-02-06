class RecentPlayModel {
  final int id;
  final int songId;
  final DateTime playedAt;
  final String? context;

  RecentPlayModel({
    required this.id,
    required this.songId,
    required this.playedAt,
    this.context,
  });

  factory RecentPlayModel.fromMap(Map<String, dynamic> map) {
    return RecentPlayModel(
      id: map['id'] as int,
      songId: map['song_id'] as int,
      playedAt: DateTime.fromMillisecondsSinceEpoch(map['played_at'] as int),
      context: map['context'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'song_id': songId,
      'played_at': playedAt.millisecondsSinceEpoch,
      'context': context,
    };
  }
}
