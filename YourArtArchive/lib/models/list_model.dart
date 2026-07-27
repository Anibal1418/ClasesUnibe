class ListModel {
  ListModel({
    this.id,
    required this.userId,
    required this.title,
    this.description,
    this.isPublic = false,
    DateTime? createdAt,
    this.artworkCount = 0,
  }) : createdAt = createdAt ?? DateTime.now();

  final int? id;
  final int userId;
  final String title;
  final String? description;
  final bool isPublic;
  final DateTime createdAt;
  final int artworkCount;

  factory ListModel.fromMap(Map<String, Object?> map) {
    return ListModel(
      id: map['id'] as int?,
      userId: map['user_id'] as int,
      title: map['title'] as String,
      description: map['description'] as String?,
      isPublic:
          map['is_public'] == true ||
          map['is_public'] == 1 ||
          map['is_public'] == '1',
      createdAt: DateTime.parse(map['created_at'] as String),
      artworkCount: (map['artwork_count'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, Object?> toMap() {
    final map = <String, Object?>{
      'id': id,
      'user_id': userId,
      'title': title,
      'description': description,
      'is_public': isPublic ? 1 : 0,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
    if (id == null) {
      map.remove('id');
    }
    return map;
  }

  ListModel copyWith({
    int? id,
    int? userId,
    String? title,
    String? description,
    bool? isPublic,
    DateTime? createdAt,
    int? artworkCount,
  }) {
    return ListModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      isPublic: isPublic ?? this.isPublic,
      createdAt: createdAt ?? this.createdAt,
      artworkCount: artworkCount ?? this.artworkCount,
    );
  }
}

class ProfileStats {
  const ProfileStats({
    required this.totalWorks,
    required this.completed,
    required this.reviews,
    required this.favorites,
    required this.lists,
  });

  final int totalWorks;
  final int completed;
  final int reviews;
  final int favorites;
  final int lists;

  factory ProfileStats.fromMap(Map<String, Object?> map) {
    int value(String key) => (map[key] as num?)?.toInt() ?? 0;
    return ProfileStats(
      totalWorks: value('total_works'),
      completed: value('completed'),
      reviews: value('reviews'),
      favorites: value('favorites'),
      lists: value('lists'),
    );
  }
}
