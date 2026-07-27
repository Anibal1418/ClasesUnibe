import '../database/database_helper.dart';
import '../models/artwork_model.dart';
import '../models/list_model.dart';
import 'data_service_exception.dart';

class ArtworkService {
  ArtworkService({required this.userId, DatabaseHelper? databaseHelper})
    : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  final int userId;
  final DatabaseHelper _databaseHelper;

  Future<ArtworkModel> createArtwork(ArtworkModel artwork) async {
    _validateArtwork(artwork);
    final db = await _databaseHelper.database;
    final ownedArtwork = artwork.copyWith(userId: userId);
    final values = ownedArtwork.toMap()..remove('id');
    final id = await db.insert('artworks', values);
    return ownedArtwork.copyWith(id: id);
  }

  Future<List<ArtworkModel>> getAllArtworks({
    String? query,
    ArtworkCategory? category,
    ArtworkStatus? status,
    bool favoriteOnly = false,
    int? limit,
  }) async {
    final db = await _databaseHelper.database;
    final clauses = <String>['user_id = ?'];
    final arguments = <Object?>[userId];
    final cleanQuery = query?.trim();
    if (cleanQuery != null && cleanQuery.isNotEmpty) {
      clauses.add(
        '(title LIKE ? COLLATE NOCASE OR '
        'creator LIKE ? COLLATE NOCASE OR tags LIKE ? COLLATE NOCASE)',
      );
      final pattern = '%$cleanQuery%';
      arguments.addAll([pattern, pattern, pattern]);
    }
    if (category != null) {
      clauses.add('category = ?');
      arguments.add(category.databaseValue);
    }
    if (status != null) {
      clauses.add('status = ?');
      arguments.add(status.databaseValue);
    }
    if (favoriteOnly) {
      clauses.add('is_favorite = 1');
    }
    final rows = await db.query(
      'artworks',
      where: clauses.join(' AND '),
      whereArgs: arguments,
      orderBy: 'created_at DESC, id DESC',
      limit: limit,
    );
    return rows.map(ArtworkModel.fromMap).toList(growable: false);
  }

  Future<ArtworkModel?> getArtworkById(int id) async {
    final db = await _databaseHelper.database;
    final rows = await db.query(
      'artworks',
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, userId],
      limit: 1,
    );
    return rows.isEmpty ? null : ArtworkModel.fromMap(rows.first);
  }

  Future<ArtworkModel> updateArtwork(ArtworkModel artwork) async {
    final id = artwork.id;
    if (id == null) {
      throw const DataServiceException(
        'The artwork must have an id before it can be updated.',
      );
    }
    _validateArtwork(artwork);
    final db = await _databaseHelper.database;
    final ownedArtwork = artwork.copyWith(userId: userId);
    final values = ownedArtwork.toMap()..remove('id');
    final changed = await db.update(
      'artworks',
      values,
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, userId],
    );
    if (changed == 0) {
      throw const DataServiceException('Artwork not found.');
    }
    return ownedArtwork;
  }

  Future<void> deleteArtwork(int id) async {
    final db = await _databaseHelper.database;
    final deleted = await db.delete(
      'artworks',
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, userId],
    );
    if (deleted == 0) {
      throw const DataServiceException('Artwork not found.');
    }
  }

  Future<List<ArtworkModel>> searchArtworks(String query) {
    return getAllArtworks(query: query);
  }

  Future<List<ArtworkModel>> filterByCategory(ArtworkCategory category) {
    return getAllArtworks(category: category);
  }

  Future<List<ArtworkModel>> filterByStatus(ArtworkStatus status) {
    return getAllArtworks(status: status);
  }

  Future<List<ArtworkModel>> getFavorites({int? limit}) {
    return getAllArtworks(favoriteOnly: true, limit: limit);
  }

  Future<List<ArtworkModel>> getRecentlyAdded({int limit = 10}) {
    return getAllArtworks(limit: limit);
  }

  Future<List<ArtworkModel>> getContinueExploring({int limit = 10}) {
    return getAllArtworks(status: ArtworkStatus.inProgress, limit: limit);
  }

  Future<ArtworkModel> toggleFavorite(int artworkId) async {
    final db = await _databaseHelper.database;
    await db.rawUpdate(
      '''
      UPDATE artworks
      SET is_favorite = CASE is_favorite WHEN 1 THEN 0 ELSE 1 END
      WHERE id = ? AND user_id = ?
      ''',
      [artworkId, userId],
    );
    final updated = await getArtworkById(artworkId);
    if (updated == null) {
      throw const DataServiceException('Artwork not found.');
    }
    return updated;
  }

  Future<ProfileStats> getProfileStats() async {
    final db = await _databaseHelper.database;
    final rows = await db.rawQuery(
      '''
      SELECT
        (SELECT COUNT(*) FROM artworks WHERE user_id = ?) AS total_works,
        (SELECT COUNT(*) FROM artworks
          WHERE user_id = ? AND status = ?) AS completed,
        (SELECT COUNT(*) FROM reviews WHERE user_id = ?) AS reviews,
        (SELECT COUNT(*) FROM artworks
          WHERE user_id = ? AND is_favorite = 1) AS favorites,
        (SELECT COUNT(*) FROM lists WHERE user_id = ?) AS lists
      ''',
      [
        userId,
        userId,
        ArtworkStatus.completed.databaseValue,
        userId,
        userId,
        userId,
      ],
    );
    return ProfileStats.fromMap(rows.single);
  }

  void _validateArtwork(ArtworkModel artwork) {
    if (artwork.title.trim().isEmpty) {
      throw const DataServiceException('Enter a title.');
    }
    final rating = artwork.rating;
    if (rating != null && (rating < 1 || rating > 10)) {
      throw const DataServiceException('Rating must be between 1 and 10.');
    }
    final year = artwork.year;
    if (year != null && (year < 1 || year > 9999)) {
      throw const DataServiceException('Enter a valid year.');
    }
  }
}
