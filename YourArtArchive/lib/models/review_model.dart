import 'artwork_model.dart';

class ReviewModel {
  ReviewModel({
    this.id,
    required this.userId,
    required this.artworkId,
    required this.content,
    required this.rating,
    this.status,
    this.isPublic = true,
    DateTime? createdAt,
    this.artworkTitle,
    this.reviewerName,
  }) : createdAt = createdAt ?? DateTime.now();

  final int? id;
  final int userId;
  final int artworkId;
  final String content;
  final double rating;
  final ArtworkStatus? status;
  final bool isPublic;
  final DateTime createdAt;
  final String? artworkTitle;
  final String? reviewerName;

  factory ReviewModel.fromMap(Map<String, Object?> map) {
    return ReviewModel(
      id: map['id'] as int?,
      userId: map['user_id'] as int,
      artworkId: map['artwork_id'] as int,
      content: map['content'] as String,
      rating: (map['rating'] as num).toDouble(),
      status: map['status'] == null
          ? null
          : artworkStatusFromValue(map['status']),
      isPublic:
          map['is_public'] == true ||
          map['is_public'] == 1 ||
          map['is_public'] == '1',
      createdAt: DateTime.parse(map['created_at'] as String),
      artworkTitle: map['artwork_title'] as String?,
      reviewerName: map['reviewer_name'] as String?,
    );
  }

  Map<String, Object?> toMap() {
    final map = <String, Object?>{
      'id': id,
      'user_id': userId,
      'artwork_id': artworkId,
      'content': content,
      'rating': rating,
      'status': status?.databaseValue,
      'is_public': isPublic ? 1 : 0,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
    if (id == null) {
      map.remove('id');
    }
    return map;
  }

  ReviewModel copyWith({
    int? id,
    int? userId,
    int? artworkId,
    String? content,
    double? rating,
    ArtworkStatus? status,
    bool? isPublic,
    DateTime? createdAt,
    String? artworkTitle,
    String? reviewerName,
  }) {
    return ReviewModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      artworkId: artworkId ?? this.artworkId,
      content: content ?? this.content,
      rating: rating ?? this.rating,
      status: status ?? this.status,
      isPublic: isPublic ?? this.isPublic,
      createdAt: createdAt ?? this.createdAt,
      artworkTitle: artworkTitle ?? this.artworkTitle,
      reviewerName: reviewerName ?? this.reviewerName,
    );
  }
}
