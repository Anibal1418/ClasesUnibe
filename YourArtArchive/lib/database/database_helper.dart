import 'package:sqflite/sqflite.dart';

import 'database_factory.dart';

class DatabaseHelper {
  DatabaseHelper({DatabaseFactory? databaseFactory, String? databasePath})
    : _injectedFactory = databaseFactory,
      _injectedPath = databasePath;

  static const databaseName = 'your_art_archive.db';
  static const databaseVersion = 1;
  static final DatabaseHelper instance = DatabaseHelper();

  final DatabaseFactory? _injectedFactory;
  final String? _injectedPath;

  Database? _database;
  Future<Database>? _openingDatabase;

  Future<Database> get database {
    final openDatabase = _database;
    if (openDatabase != null && openDatabase.isOpen) {
      return Future.value(openDatabase);
    }
    return _openingDatabase ??= _open();
  }

  Future<Database> _open() async {
    try {
      final factory = _injectedFactory ?? platformDatabaseFactory;
      final path = _injectedPath ?? await platformDatabasePath(databaseName);
      final opened = await factory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: databaseVersion,
          onConfigure: (db) async {
            await db.execute('PRAGMA foreign_keys = ON');
          },
          onCreate: _createSchema,
        ),
      );
      _database = opened;
      return opened;
    } finally {
      _openingDatabase = null;
    }
  }

  Future<void> _createSchema(Database db, int version) async {
    final batch = db.batch();
    batch.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT NOT NULL COLLATE NOCASE UNIQUE,
        password TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    batch.execute('''
      CREATE TABLE artworks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        category TEXT NOT NULL,
        creator TEXT,
        year INTEGER,
        description TEXT,
        image_url TEXT,
        status TEXT NOT NULL,
        rating REAL CHECK (rating IS NULL OR (rating >= 1 AND rating <= 10)),
        tags TEXT,
        is_favorite INTEGER NOT NULL DEFAULT 0 CHECK (is_favorite IN (0, 1)),
        created_at TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');
    batch.execute('''
      CREATE TABLE reviews (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        artwork_id INTEGER NOT NULL,
        content TEXT NOT NULL,
        rating REAL NOT NULL CHECK (rating >= 1 AND rating <= 10),
        status TEXT,
        is_public INTEGER NOT NULL CHECK (is_public IN (0, 1)),
        created_at TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY (artwork_id) REFERENCES artworks(id) ON DELETE CASCADE
      )
    ''');
    batch.execute('''
      CREATE TABLE lists (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        description TEXT,
        is_public INTEGER NOT NULL CHECK (is_public IN (0, 1)),
        created_at TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');
    batch.execute('''
      CREATE TABLE list_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        list_id INTEGER NOT NULL,
        artwork_id INTEGER NOT NULL,
        FOREIGN KEY (list_id) REFERENCES lists(id) ON DELETE CASCADE,
        FOREIGN KEY (artwork_id) REFERENCES artworks(id) ON DELETE CASCADE,
        UNIQUE (list_id, artwork_id)
      )
    ''');
    batch.execute('CREATE INDEX idx_artworks_user ON artworks(user_id)');
    batch.execute(
      'CREATE INDEX idx_artworks_user_status ON artworks(user_id, status)',
    );
    batch.execute('CREATE INDEX idx_reviews_user ON reviews(user_id)');
    batch.execute('CREATE INDEX idx_reviews_artwork ON reviews(artwork_id)');
    batch.execute('CREATE INDEX idx_lists_user ON lists(user_id)');
    batch.execute('CREATE INDEX idx_list_items_list ON list_items(list_id)');
    await batch.commit(noResult: true);
  }

  Future<void> close() async {
    final openDatabase = _database;
    _database = null;
    _openingDatabase = null;
    if (openDatabase != null && openDatabase.isOpen) {
      await openDatabase.close();
    }
  }
}
