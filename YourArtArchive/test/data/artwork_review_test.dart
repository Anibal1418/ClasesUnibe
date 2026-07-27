import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:your_art_archive/database/database_helper.dart';
import 'package:your_art_archive/models/artwork_model.dart';
import 'package:your_art_archive/models/review_model.dart';
import 'package:your_art_archive/services/artwork_service.dart';
import 'package:your_art_archive/services/auth_service.dart';
import 'package:your_art_archive/services/data_service_exception.dart';
import 'package:your_art_archive/services/review_service.dart';

void main() {
  sqfliteFfiInit();

  late DatabaseHelper databaseHelper;
  late AuthService auth;
  late int firstUserId;
  late ArtworkService artworks;
  late ReviewService reviews;

  setUp(() async {
    databaseHelper = DatabaseHelper(
      databaseFactory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    auth = AuthService(databaseHelper: databaseHelper);
    firstUserId = (await auth.registerUser(
      name: 'Laura',
      email: 'laura@example.com',
      password: 'secret12',
    )).id!;
    artworks = ArtworkService(
      userId: firstUserId,
      databaseHelper: databaseHelper,
    );
    reviews = ReviewService(
      userId: firstUserId,
      databaseHelper: databaseHelper,
    );
  });

  tearDown(() => databaseHelper.close());

  test(
    'artwork CRUD, search, filters, and favorite operate on SQLite',
    () async {
      final created = await artworks.createArtwork(
        ArtworkModel(
          userId: firstUserId,
          title: 'Educational Prototype',
          creator: 'UNIBE',
          category: ArtworkCategory.movie,
          status: ArtworkStatus.want,
          tags: const ['class project'],
        ),
      );

      expect(created.id, isNotNull);
      expect(
        (await artworks.searchArtworks('UNIBE')).map((work) => work.id),
        contains(created.id),
      );
      expect(
        (await artworks.filterByCategory(
          ArtworkCategory.movie,
        )).map((work) => work.id),
        contains(created.id),
      );
      expect(
        (await artworks.filterByStatus(
          ArtworkStatus.want,
        )).map((work) => work.id),
        contains(created.id),
      );

      final favorite = await artworks.toggleFavorite(created.id!);
      expect(favorite.isFavorite, isTrue);
      final updated = await artworks.updateArtwork(
        favorite.copyWith(
          title: 'Updated Prototype',
          status: ArtworkStatus.completed,
          rating: 8,
        ),
      );
      expect(updated.title, 'Updated Prototype');
      expect((await artworks.getArtworkById(created.id!))?.rating, 8);

      await artworks.deleteArtwork(created.id!);
      expect(await artworks.getArtworkById(created.id!), isNull);
    },
  );

  test('accounts cannot read or mutate one another’s artwork', () async {
    final secondUserId = (await auth.registerUser(
      name: 'Alex',
      email: 'alex@example.com',
      password: 'secret34',
    )).id!;
    final secondArtworks = ArtworkService(
      userId: secondUserId,
      databaseHelper: databaseHelper,
    );
    final firstWork = (await artworks.getAllArtworks()).first;

    expect(await secondArtworks.getArtworkById(firstWork.id!), isNull);
    await expectLater(
      secondArtworks.deleteArtwork(firstWork.id!),
      throwsA(isA<DataServiceException>()),
    );
    expect(await artworks.getArtworkById(firstWork.id!), isNotNull);
    expect(await secondArtworks.getAllArtworks(), hasLength(10));
  });

  test(
    'multiple reviews are allowed and synchronize artwork rating/status',
    () async {
      final artwork = (await artworks.getAllArtworks()).first;
      final originalReviewCount = (await reviews.getReviewsByArtworkId(
        artwork.id!,
      )).length;

      final first = await reviews.createReview(
        ReviewModel(
          userId: firstUserId,
          artworkId: artwork.id!,
          content: 'A new perspective.',
          rating: 7,
          status: ArtworkStatus.inProgress,
        ),
      );
      await reviews.createReview(
        ReviewModel(
          userId: firstUserId,
          artworkId: artwork.id!,
          content: 'Even better on reflection.',
          rating: 9,
          status: ArtworkStatus.completed,
        ),
      );

      expect(
        await reviews.getReviewsByArtworkId(artwork.id!),
        hasLength(originalReviewCount + 2),
      );
      expect((await reviews.getReviewById(first.id!))?.reviewerName, 'Laura');
      var syncedArtwork = await artworks.getArtworkById(artwork.id!);
      expect(syncedArtwork?.rating, 9);
      expect(syncedArtwork?.status, ArtworkStatus.completed);

      await reviews.updateReview(
        first.copyWith(
          content: 'Changed my mind.',
          rating: 6,
          status: ArtworkStatus.abandoned,
        ),
      );
      syncedArtwork = await artworks.getArtworkById(artwork.id!);
      expect(syncedArtwork?.rating, 6);
      expect(syncedArtwork?.status, ArtworkStatus.abandoned);
    },
  );

  test('deleting artwork cascades its reviews', () async {
    final artwork = (await artworks.getAllArtworks()).firstWhere(
      (work) => (work.id ?? 0) > 0,
    );
    final db = await databaseHelper.database;

    await artworks.deleteArtwork(artwork.id!);

    expect(
      (await db.rawQuery(
        'SELECT COUNT(*) AS count FROM reviews WHERE artwork_id = ?',
        [artwork.id],
      )).single['count'],
      0,
    );
  });
}
