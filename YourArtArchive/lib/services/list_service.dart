import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import '../models/artwork_model.dart';
import '../models/list_model.dart';
import 'data_service_exception.dart';

class ListService {
  ListService({required this.userId, DatabaseHelper? databaseHelper})
    : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  final int userId;
  final DatabaseHelper _databaseHelper;

  Future<ListModel> createList(ListModel list) async {
    _validateList(list);
    final db = await _databaseHelper.database;
    final ownedList = list.copyWith(userId: userId);
    final values = ownedList.toMap()..remove('id');
    final id = await db.insert('lists', values);
    return ownedList.copyWith(id: id);
  }

  Future<List<ListModel>> getAllLists() async {
    final db = await _databaseHelper.database;
    final rows = await db.rawQuery(
      '''
      SELECT l.*, COUNT(li.id) AS artwork_count
      FROM lists l
      LEFT JOIN list_items li ON li.list_id = l.id
      WHERE l.user_id = ?
      GROUP BY l.id
      ORDER BY l.created_at DESC, l.id DESC
      ''',
      [userId],
    );
    return rows.map(ListModel.fromMap).toList(growable: false);
  }

  Future<ListModel?> getListById(int id) async {
    final db = await _databaseHelper.database;
    final rows = await db.rawQuery(
      '''
      SELECT l.*, COUNT(li.id) AS artwork_count
      FROM lists l
      LEFT JOIN list_items li ON li.list_id = l.id
      WHERE l.id = ? AND l.user_id = ?
      GROUP BY l.id
      LIMIT 1
      ''',
      [id, userId],
    );
    return rows.isEmpty ? null : ListModel.fromMap(rows.first);
  }

  Future<ListModel> updateList(ListModel list) async {
    final id = list.id;
    if (id == null) {
      throw const DataServiceException(
        'The list must have an id before it can be updated.',
      );
    }
    _validateList(list);
    final db = await _databaseHelper.database;
    final ownedList = list.copyWith(userId: userId);
    final values = ownedList.toMap()..remove('id');
    final changed = await db.update(
      'lists',
      values,
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, userId],
    );
    if (changed == 0) {
      throw const DataServiceException('List not found.');
    }
    final updated = await getListById(id);
    if (updated == null) {
      throw const DataServiceException('List not found.');
    }
    return updated;
  }

  Future<void> deleteList(int id) async {
    final db = await _databaseHelper.database;
    final deleted = await db.delete(
      'lists',
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, userId],
    );
    if (deleted == 0) {
      throw const DataServiceException('List not found.');
    }
  }

  Future<void> addArtworkToList({
    required int listId,
    required int artworkId,
  }) async {
    final db = await _databaseHelper.database;
    await db.transaction((txn) async {
      await _requireOwnedList(txn, listId);
      await _requireOwnedArtwork(txn, artworkId);
      await txn.insert('list_items', {
        'list_id': listId,
        'artwork_id': artworkId,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    });
  }

  Future<void> removeArtworkFromList({
    required int listId,
    required int artworkId,
  }) async {
    final db = await _databaseHelper.database;
    await db.transaction((txn) async {
      await _requireOwnedList(txn, listId);
      await txn.delete(
        'list_items',
        where: 'list_id = ? AND artwork_id = ?',
        whereArgs: [listId, artworkId],
      );
    });
  }

  Future<List<ArtworkModel>> getArtworksInList(int listId) async {
    final db = await _databaseHelper.database;
    final rows = await db.rawQuery(
      '''
      SELECT a.*
      FROM artworks a
      INNER JOIN list_items li ON li.artwork_id = a.id
      INNER JOIN lists l ON l.id = li.list_id
      WHERE li.list_id = ? AND l.user_id = ? AND a.user_id = ?
      ORDER BY li.id DESC
      ''',
      [listId, userId, userId],
    );
    return rows.map(ArtworkModel.fromMap).toList(growable: false);
  }

  Future<bool> isArtworkInList({
    required int listId,
    required int artworkId,
  }) async {
    final db = await _databaseHelper.database;
    final rows = await db.rawQuery(
      '''
      SELECT li.id
      FROM list_items li
      INNER JOIN lists l ON l.id = li.list_id
      INNER JOIN artworks a ON a.id = li.artwork_id
      WHERE li.list_id = ? AND li.artwork_id = ?
        AND l.user_id = ? AND a.user_id = ?
      LIMIT 1
      ''',
      [listId, artworkId, userId, userId],
    );
    return rows.isNotEmpty;
  }

  void _validateList(ListModel list) {
    if (list.title.trim().isEmpty) {
      throw const DataServiceException('Enter a list title.');
    }
  }

  Future<void> _requireOwnedList(Transaction txn, int listId) async {
    final rows = await txn.query(
      'lists',
      columns: const ['id'],
      where: 'id = ? AND user_id = ?',
      whereArgs: [listId, userId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw const DataServiceException('List not found.');
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
}
