enum MusicServerType {
  subsonic,
  //future: jellyfin, emby, etc.
}

class MusicServerModel {
  final int? id;
  final String name;
  final String url;
  final MusicServerType type;
  final String username;
  final String password;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  MusicServerModel({
    this.id,
    required this.name,
    required this.url,
    required this.type,
    required this.username,
    required this.password,
    this.isActive = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory MusicServerModel.fromMap(Map<String, dynamic> map) {
    return MusicServerModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      url: map['url'] as String,
      type: MusicServerType.values.firstWhere(
        (t) => t.name == map['type'],
        orElse: () => MusicServerType.subsonic,
      ),
      username: map['username'] as String,
      password: map['password'] as String,
      isActive: (map['is_active'] as int?) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'url': url,
      'type': type.name,
      'username': username,
      'password': password,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  MusicServerModel copyWith({
    int? id,
    String? name,
    String? url,
    MusicServerType? type,
    String? username,
    String? password,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MusicServerModel(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      type: type ?? this.type,
      username: username ?? this.username,
      password: password ?? this.password,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
