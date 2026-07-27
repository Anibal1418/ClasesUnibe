import 'dart:convert';

enum ArtworkCategory { book, movie, series, videoGame, manga, anime, theater }

extension ArtworkCategoryPresentation on ArtworkCategory {
  String get label => switch (this) {
    ArtworkCategory.book => 'Book',
    ArtworkCategory.movie => 'Movie',
    ArtworkCategory.series => 'Series',
    ArtworkCategory.videoGame => 'Video Game',
    ArtworkCategory.manga => 'Manga',
    ArtworkCategory.anime => 'Anime',
    ArtworkCategory.theater => 'Theater',
  };

  String get databaseValue => switch (this) {
    ArtworkCategory.book => 'book',
    ArtworkCategory.movie => 'movie',
    ArtworkCategory.series => 'series',
    ArtworkCategory.videoGame => 'video_game',
    ArtworkCategory.manga => 'manga',
    ArtworkCategory.anime => 'anime',
    ArtworkCategory.theater => 'theater',
  };
}

ArtworkCategory artworkCategoryFromValue(Object? value) {
  final normalized = value?.toString().trim().toLowerCase().replaceAll(
    RegExp(r'[\s-]+'),
    '_',
  );
  return switch (normalized) {
    'book' || 'books' => ArtworkCategory.book,
    'movie' || 'movies' || 'film' => ArtworkCategory.movie,
    'series' || 'tv' || 'tv_series' => ArtworkCategory.series,
    'video_game' ||
    'videogame' ||
    'game' ||
    'games' => ArtworkCategory.videoGame,
    'manga' => ArtworkCategory.manga,
    'anime' => ArtworkCategory.anime,
    'theater' || 'theatre' || 'play' => ArtworkCategory.theater,
    _ => ArtworkCategory.book,
  };
}

enum ArtworkStatus { inProgress, completed, want, abandoned }

extension ArtworkStatusPresentation on ArtworkStatus {
  String get label => switch (this) {
    ArtworkStatus.inProgress => 'In Progress',
    ArtworkStatus.completed => 'Completed',
    ArtworkStatus.want => 'Want',
    ArtworkStatus.abandoned => 'Abandoned',
  };

  String get databaseValue => switch (this) {
    ArtworkStatus.inProgress => 'in_progress',
    ArtworkStatus.completed => 'completed',
    ArtworkStatus.want => 'want',
    ArtworkStatus.abandoned => 'abandoned',
  };
}

ArtworkStatus artworkStatusFromValue(Object? value) {
  final normalized = value?.toString().trim().toLowerCase().replaceAll(
    RegExp(r'[\s-]+'),
    '_',
  );
  return switch (normalized) {
    'in_progress' ||
    'progress' ||
    'currently_experiencing' => ArtworkStatus.inProgress,
    'completed' || 'complete' || 'seen' => ArtworkStatus.completed,
    'abandoned' || 'dropped' => ArtworkStatus.abandoned,
    _ => ArtworkStatus.want,
  };
}

class ArtworkModel {
  ArtworkModel({
    this.id,
    required this.userId,
    required this.title,
    required this.category,
    this.creator,
    this.year,
    this.description,
    this.imageUrl,
    this.status = ArtworkStatus.want,
    this.rating,
    List<String> tags = const [],
    this.isFavorite = false,
    DateTime? createdAt,
  }) : tags = List.unmodifiable(tags),
       createdAt = createdAt ?? DateTime.now();

  final int? id;
  final int userId;
  final String title;
  final ArtworkCategory category;
  final String? creator;
  final int? year;
  final String? description;
  final String? imageUrl;
  final ArtworkStatus status;
  final double? rating;
  final List<String> tags;
  final bool isFavorite;
  final DateTime createdAt;

  factory ArtworkModel.fromMap(Map<String, Object?> map) {
    return ArtworkModel(
      id: map['id'] as int?,
      userId: map['user_id'] as int,
      title: map['title'] as String,
      category: artworkCategoryFromValue(map['category']),
      creator: map['creator'] as String?,
      year: map['year'] as int?,
      description: map['description'] as String?,
      imageUrl: map['image_url'] as String?,
      status: artworkStatusFromValue(map['status']),
      rating: (map['rating'] as num?)?.toDouble(),
      tags: _decodeTags(map['tags']),
      isFavorite: _decodeBool(map['is_favorite']),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, Object?> toMap() {
    final map = <String, Object?>{
      'id': id,
      'user_id': userId,
      'title': title,
      'category': category.databaseValue,
      'creator': creator,
      'year': year,
      'description': description,
      'image_url': imageUrl,
      'status': status.databaseValue,
      'rating': rating,
      'tags': jsonEncode(tags),
      'is_favorite': isFavorite ? 1 : 0,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
    if (id == null) {
      map.remove('id');
    }
    return map;
  }

  ArtworkModel copyWith({
    int? id,
    int? userId,
    String? title,
    ArtworkCategory? category,
    String? creator,
    int? year,
    String? description,
    String? imageUrl,
    ArtworkStatus? status,
    double? rating,
    bool clearRating = false,
    List<String>? tags,
    bool? isFavorite,
    DateTime? createdAt,
  }) {
    return ArtworkModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      category: category ?? this.category,
      creator: creator ?? this.creator,
      year: year ?? this.year,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      status: status ?? this.status,
      rating: clearRating ? null : (rating ?? this.rating),
      tags: tags ?? this.tags,
      isFavorite: isFavorite ?? this.isFavorite,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static List<String> _decodeTags(Object? raw) {
    if (raw == null || raw.toString().trim().isEmpty) {
      return const [];
    }
    try {
      final decoded = jsonDecode(raw.toString());
      if (decoded is List) {
        return decoded
            .whereType<Object>()
            .map((item) => item.toString())
            .toList(growable: false);
      }
    } on FormatException {
      // Older/local rows may contain comma-separated values.
    }
    return raw
        .toString()
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList(growable: false);
  }

  static bool _decodeBool(Object? value) =>
      value == true || value == 1 || value == '1';
}
