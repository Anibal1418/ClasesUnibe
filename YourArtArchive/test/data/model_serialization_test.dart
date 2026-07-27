import 'package:flutter_test/flutter_test.dart';
import 'package:your_art_archive/models/artwork_model.dart';
import 'package:your_art_archive/models/list_model.dart';
import 'package:your_art_archive/models/review_model.dart';
import 'package:your_art_archive/models/user_model.dart';

void main() {
  test('artwork round-trips enums, tags, favorite, and nullable rating', () {
    final artwork = ArtworkModel(
      id: 4,
      userId: 2,
      title: 'A Work',
      category: ArtworkCategory.videoGame,
      status: ArtworkStatus.inProgress,
      tags: const ['indie', 'story rich'],
      isFavorite: true,
      createdAt: DateTime.utc(2026, 1, 2),
    );

    final restored = ArtworkModel.fromMap(artwork.toMap());

    expect(restored.id, 4);
    expect(restored.category, ArtworkCategory.videoGame);
    expect(restored.status, ArtworkStatus.inProgress);
    expect(restored.tags, ['indie', 'story rich']);
    expect(restored.isFavorite, isTrue);
    expect(restored.rating, isNull);
  });

  test('category and status parsing accepts display and database forms', () {
    expect(artworkCategoryFromValue('Video Game'), ArtworkCategory.videoGame);
    expect(artworkCategoryFromValue('theatre'), ArtworkCategory.theater);
    expect(artworkStatusFromValue('In Progress'), ArtworkStatus.inProgress);
    expect(artworkStatusFromValue('dropped'), ArtworkStatus.abandoned);
  });

  test('remaining models round-trip their SQLite maps', () {
    final now = DateTime.utc(2026, 2, 3);
    final user = UserModel(
      id: 1,
      name: 'Laura',
      email: 'laura@example.com',
      password: 'hash',
      createdAt: now,
    );
    final review = ReviewModel(
      id: 2,
      userId: 1,
      artworkId: 3,
      content: 'Wonderful.',
      rating: 8,
      status: ArtworkStatus.completed,
      isPublic: false,
      createdAt: now,
    );
    final list = ListModel(
      id: 4,
      userId: 1,
      title: 'Favorites',
      description: 'Keepers',
      isPublic: true,
      createdAt: now,
    );

    expect(UserModel.fromMap(user.toMap()).email, user.email);
    expect(ReviewModel.fromMap(review.toMap()).isPublic, isFalse);
    expect(ListModel.fromMap(list.toMap()).isPublic, isTrue);
  });
}
