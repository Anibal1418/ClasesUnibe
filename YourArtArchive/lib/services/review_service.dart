import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import '../models/artwork_model.dart';
import '../models/review_model.dart';
import 'data_service_exception.dart';

class ReviewService {
  ReviewService({required this.userId, DatabaseHelper? databaseHelper})
    : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  final int userId;
  final DatabaseHelper _databaseHelper;

  Future<ReviewModel> createReview(ReviewModel review) async {
    _validateReview(review);
    final db = await _databaseHelper.database;
    final id = await db.transaction((txn) async {
      await _requireOwnedArtwork(txn, review.artworkId);
      final ownedReview = review.copyWith(userId: userId);
      final values = ownedReview.toMap()..remove('id');
      final reviewId = await txn.insert('reviews', values);
      await _syncArtworkFromReview(txn, ownedReview);
      return reviewId;
    });
    final created = await getReviewById(id);
    if (created == null) {
      throw const DataServiceException('Review could not be loaded.');
    }
    return created;
  }

  Future<ReviewModel?> getReviewById(int id) async {
    final db = await _databaseHelper.database;
    final rows = await db.rawQuery(
      '''
      SELECT r.*, a.title AS artwork_title, u.name AS reviewer_name
      FROM reviews r
      INNER JOIN artworks a ON a.id = r.artwork_id
      INNER JOIN users u ON u.id = r.user_id
      WHERE r.id = ? AND r.user_id = ? AND a.user_id = ?
      LIMIT 1
      ''',
      [id, userId, userId],
    );
    return rows.isEmpty ? null : ReviewModel.fromMap(rows.first);
  }

  Future<List<ReviewModel>> getReviewsByArtworkId(int artworkId) async {
    final db = await _databaseHelper.database;
    final rows = await db.rawQuery(
      '''
      SELECT r.*, a.title AS artwork_title, u.name AS reviewer_name
      FROM reviews r
      INNER JOIN artworks a ON a.id = r.artwork_id
      INNER JOIN users u ON u.id = r.user_id
      WHERE r.artwork_id = ? AND r.user_id = ? AND a.user_id = ?
      ORDER BY r.created_at DESC, r.id DESC
      ''',
      [artworkId, userId, userId],
    );
    return rows.map(ReviewModel.fromMap).toList(growable: false);
  }

  Future<List<ReviewModel>> getAllReviews() async {
    final db = await _databaseHelper.database;
    final rows = await db.rawQuery(
      '''
      SELECT r.*, a.title AS artwork_title, u.name AS reviewer_name
      FROM reviews r
      INNER JOIN artworks a ON a.id = r.artwork_id
      INNER JOIN users u ON u.id = r.user_id
      WHERE r.user_id = ? AND a.user_id = ?
      ORDER BY r.created_at DESC, r.id DESC
      ''',
      [userId, userId],
    );
    return rows.map(ReviewModel.fromMap).toList(growable: false);
  }

  Future<ReviewModel> updateReview(ReviewModel review) async {
    final id = review.id;
    if (id == null) {
      throw const DataServiceException(
        'The review must have an id before it can be updated.',
      );
    }
    _validateReview(review);
    final db = await _databaseHelper.database;
    await db.transaction((txn) async {
      await _requireOwnedArtwork(txn, review.artworkId);
      final ownedReview = review.copyWith(userId: userId);
      final values = ownedReview.toMap()..remove('id');
      final changed = await txn.update(
        'reviews',
        values,
        where: 'id = ? AND user_id = ?',
        whereArgs: [id, userId],
      );
      if (changed == 0) {
        throw const DataServiceException('Review not found.');
      }
      await _syncArtworkFromReview(txn, ownedReview);
    });
    final updated = await getReviewById(id);
    if (updated == null) {
      throw const DataServiceException('Review not found.');
    }
    return updated;
  }

  Future<void> deleteReview(int id) async {
    final db = await _databaseHelper.database;
    final deleted = await db.delete(
      'reviews',
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, userId],
    );
    if (deleted == 0) {
      throw const DataServiceException('Review not found.');
    }
  }

  void _validateReview(ReviewModel review) {
    if (review.content.trim().isEmpty) {
      throw const DataServiceException('Write a review before posting.');
    }
    if (review.rating < 1 || review.rating > 10) {
      throw const DataServiceException('Rating must be between 1 and 10.');
    }
  }

  Future<void> _requireOwnedArtwork(Transaction txn, int artworkId) async {
    final rows = await txn.query(
      'artworks',
      columns: const ['id'],
      where: 'id = ? AND user_id = ?',
      whereArgs: [artworkId, userId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw const DataServiceException('Artwork not found.');
    }
  }

  Future<void> _syncArtworkFromReview(
    Transaction txn,
    ReviewModel review,
  ) async {
    final values = <String, Object?>{'rating': review.rating};
    if (review.status != null) {
      values['status'] = review.status!.databaseValue;
    }
    await txn.update(
      'artworks',
      values,
      where: 'id = ? AND user_id = ?',
      whereArgs: [review.artworkId, userId],
    );
  }
}
