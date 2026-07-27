import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:your_art_archive/database/database_helper.dart';
import 'package:your_art_archive/models/list_model.dart';
import 'package:your_art_archive/services/artwork_service.dart';
import 'package:your_art_archive/services/auth_service.dart';
import 'package:your_art_archive/services/list_service.dart';

void main() {
  sqfliteFfiInit();

  late DatabaseHelper databaseHelper;
  late int userId;
  late ArtworkService artworkService;
  late ListService listService;

  setUp(() async {
    databaseHelper = DatabaseHelper(
      databaseFactory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    userId = (await AuthService(databaseHelper: databaseHelper).registerUser(
      name: 'Laura',
      email: 'laura@example.com',
      password: 'secret12',
    )).id!;
    artworkService = ArtworkService(
      userId: userId,
      databaseHelper: databaseHelper,
    );
    listService = ListService(userId: userId, databaseHelper: databaseHelper);
  });

  tearDown(() => databaseHelper.close());

  test('list CRUD and membership ignore duplicate additions', () async {
    final list = await listService.createList(
      ListModel(
        userId: userId,
        title: 'For class',
        description: 'A focused selection',
        isPublic: true,
      ),
    );
    final artwork = (await artworkService.getAllArtworks()).first;

    await listService.addArtworkToList(
      listId: list.id!,
      artworkId: artwork.id!,
    );
    await listService.addArtworkToList(
      listId: list.id!,
      artworkId: artwork.id!,
    );
    expect(await listService.getArtworksInList(list.id!), hasLength(1));
    expect(
      await listService.isArtworkInList(
        listId: list.id!,
        artworkId: artwork.id!,
      ),
      isTrue,
    );

    final updated = await listService.updateList(
      list.copyWith(title: 'Updated class list'),
    );
    expect(updated.title, 'Updated class list');
    expect(updated.artworkCount, 1);

    await listService.removeArtworkFromList(
      listId: list.id!,
      artworkId: artwork.id!,
    );
    expect(await listService.getArtworksInList(list.id!), isEmpty);
    await listService.deleteList(list.id!);
    expect(await listService.getListById(list.id!), isNull);
  });

  test('deleting artwork cascades list membership', () async {
    final list = (await listService.getAllLists()).first;
    final artwork = (await artworkService.getAllArtworks()).last;
    await listService.addArtworkToList(
      listId: list.id!,
      artworkId: artwork.id!,
    );

    await artworkService.deleteArtwork(artwork.id!);

    expect(
      await listService.isArtworkInList(
        listId: list.id!,
        artworkId: artwork.id!,
      ),
      isFalse,
    );
  });

  test('profile statistics reflect persisted rows', () async {
    final stats = await artworkService.getProfileStats();

    expect(stats.totalWorks, 10);
    expect(stats.completed, 4);
    expect(stats.reviews, 3);
    expect(stats.favorites, 5);
    expect(stats.lists, 2);
  });
}
