import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import '../models/artwork_model.dart';
import '../models/user_model.dart';

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthService {
  AuthService({DatabaseHelper? databaseHelper})
    : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _databaseHelper;
  UserModel? _currentUser;

  UserModel? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;

  UserModel? getCurrentUser() => _currentUser;

  Future<bool> validateEmailExists(String email) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty) {
      return false;
    }
    final db = await _databaseHelper.database;
    final rows = await db.query(
      'users',
      columns: const ['id'],
      where: 'email = ? COLLATE NOCASE',
      whereArgs: [normalizedEmail],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<UserModel> registerUser({
    required String name,
    required String email,
    required String password,
  }) async {
    final cleanName = name.trim();
    final cleanEmail = email.trim().toLowerCase();
    _validateRegistration(cleanName, cleanEmail, password);

    final db = await _databaseHelper.database;
    if (await validateEmailExists(cleanEmail)) {
      throw const AuthException('An account with this email already exists.');
    }

    final now = DateTime.now().toUtc();
    final passwordHash = _hashPassword(password);
    try {
      final registeredUser = await db.transaction((txn) async {
        final userId = await txn.insert('users', {
          'name': cleanName,
          'email': cleanEmail,
          'password': passwordHash,
          'created_at': now.toIso8601String(),
        });
        await _seedAccount(txn, userId, now);
        return UserModel(
          id: userId,
          name: cleanName,
          email: cleanEmail,
          password: passwordHash,
          createdAt: now,
        );
      });
      _currentUser = registeredUser;
      return registeredUser;
    } on DatabaseException catch (error) {
      if (error.isUniqueConstraintError()) {
        throw const AuthException('An account with this email already exists.');
      }
      rethrow;
    }
  }

  Future<UserModel> loginUser({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty || password.isEmpty) {
      throw const AuthException('Enter your email and password.');
    }

    final db = await _databaseHelper.database;
    final rows = await db.query(
      'users',
      where: 'email = ? COLLATE NOCASE',
      whereArgs: [cleanEmail],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw const AuthException('No account was found for this email.');
    }
    final user = UserModel.fromMap(rows.first);
    if (!_verifyPassword(password, user.password)) {
      throw const AuthException('The password is incorrect.');
    }
    _currentUser = user;
    return user;
  }

  Future<void> logout() async {
    _currentUser = null;
  }

  void _validateRegistration(String name, String email, String password) {
    if (name.isEmpty) {
      throw const AuthException('Enter your name.');
    }
    final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailPattern.hasMatch(email)) {
      throw const AuthException('Enter a valid email address.');
    }
    if (password.length < 6) {
      throw const AuthException('Password must be at least 6 characters.');
    }
  }

  String _hashPassword(String password) {
    final random = Random.secure();
    final saltBytes = List<int>.generate(16, (_) => random.nextInt(256));
    final salt = base64UrlEncode(saltBytes);
    final digest = sha256.convert([...saltBytes, ...utf8.encode(password)]);
    return 'v1\$$salt\$${digest.toString()}';
  }

  bool _verifyPassword(String password, String encodedHash) {
    final parts = encodedHash.split(r'$');
    if (parts.length != 3 || parts.first != 'v1') {
      return false;
    }
    try {
      final saltBytes = base64Url.decode(base64Url.normalize(parts[1]));
      final actual = sha256.convert([
        ...saltBytes,
        ...utf8.encode(password),
      ]).toString();
      final expected = parts[2];
      if (actual.length != expected.length) {
        return false;
      }
      var difference = 0;
      for (var index = 0; index < actual.length; index++) {
        difference |= actual.codeUnitAt(index) ^ expected.codeUnitAt(index);
      }
      return difference == 0;
    } on FormatException {
      return false;
    }
  }

  Future<void> _seedAccount(
    Transaction txn,
    int userId,
    DateTime createdAt,
  ) async {
    final seedWorks = <ArtworkModel>[
      ArtworkModel(
        userId: userId,
        title: 'The Women',
        category: ArtworkCategory.book,
        creator: 'Kristin Hannah',
        year: 2024,
        description:
            'A sweeping story of courage, friendship, and women at war.',
        imageUrl: 'assets/images/covers/the_women.jpg',
        status: ArtworkStatus.completed,
        rating: 9,
        tags: const ['Historical Fiction', 'War', 'Friendship'],
        isFavorite: true,
        createdAt: createdAt.subtract(const Duration(days: 10)),
      ),
      ArtworkModel(
        userId: userId,
        title: 'Dune: Part Two',
        category: ArtworkCategory.movie,
        creator: 'Denis Villeneuve',
        year: 2024,
        description:
            'Paul Atreides unites with Chani and the Fremen while seeking justice.',
        imageUrl: 'assets/images/covers/dune_part_two.jpeg',
        status: ArtworkStatus.completed,
        rating: 9,
        tags: const ['Science Fiction', 'Epic'],
        isFavorite: true,
        createdAt: createdAt.subtract(const Duration(days: 9)),
      ),
      ArtworkModel(
        userId: userId,
        title: 'The Last of Us',
        category: ArtworkCategory.videoGame,
        creator: 'Naughty Dog',
        year: 2013,
        description:
            'A hardened survivor escorts a teenager across a transformed America.',
        imageUrl: 'assets/images/covers/the_last_of_us.jpg',
        status: ArtworkStatus.completed,
        rating: 10,
        tags: const ['Adventure', 'Drama'],
        isFavorite: true,
        createdAt: createdAt.subtract(const Duration(days: 8)),
      ),
      ArtworkModel(
        userId: userId,
        title: 'Macbeth',
        category: ArtworkCategory.theater,
        creator: 'William Shakespeare',
        year: 1606,
        description:
            'Ambition and prophecy pull a Scottish general toward ruin.',
        imageUrl: 'assets/images/covers/macbeth.jpg',
        status: ArtworkStatus.want,
        rating: 8,
        tags: const ['Tragedy', 'Classic'],
        createdAt: createdAt.subtract(const Duration(days: 7)),
      ),
      ArtworkModel(
        userId: userId,
        title: 'Breaking Bad',
        category: ArtworkCategory.series,
        creator: 'Vince Gilligan',
        year: 2008,
        description:
            'A chemistry teacher enters the drug trade after a life-changing diagnosis.',
        imageUrl: 'assets/images/covers/breaking_bad.png',
        status: ArtworkStatus.completed,
        rating: 10,
        tags: const ['Crime', 'Drama'],
        isFavorite: true,
        createdAt: createdAt.subtract(const Duration(days: 6)),
      ),
      ArtworkModel(
        userId: userId,
        title: 'Shōgun',
        category: ArtworkCategory.series,
        creator: 'Rachel Kondo & Justin Marks',
        year: 2024,
        description:
            'In feudal Japan, an English navigator becomes entangled in a struggle for power.',
        imageUrl: 'assets/images/covers/shogun.jpg',
        status: ArtworkStatus.inProgress,
        rating: 9,
        tags: const ['Historical Fiction', 'Japan'],
        createdAt: createdAt.subtract(const Duration(days: 5)),
      ),
      ArtworkModel(
        userId: userId,
        title: 'Hollow Knight',
        category: ArtworkCategory.videoGame,
        creator: 'Team Cherry',
        year: 2017,
        description: 'Explore a vast ruined kingdom of insects and heroes.',
        imageUrl: 'assets/images/covers/hollow_knight.jpg',
        status: ArtworkStatus.inProgress,
        rating: 9,
        tags: const ['Metroidvania', 'Indie'],
        createdAt: createdAt.subtract(const Duration(days: 4)),
      ),
      ArtworkModel(
        userId: userId,
        title: 'Normal People',
        category: ArtworkCategory.series,
        creator: 'Sally Rooney',
        year: 2020,
        description: 'Two young people weave in and out of each other’s lives.',
        imageUrl: 'assets/images/covers/normal_people.png',
        status: ArtworkStatus.abandoned,
        rating: 7,
        tags: const ['Romance', 'Drama'],
        createdAt: createdAt.subtract(const Duration(days: 3)),
      ),
      ArtworkModel(
        userId: userId,
        title: 'Vagabond',
        category: ArtworkCategory.manga,
        creator: 'Takehiko Inoue',
        year: 1998,
        description: 'A wandering swordsman searches for strength and meaning.',
        imageUrl: 'assets/images/covers/vagabond.png',
        status: ArtworkStatus.want,
        tags: const ['Historical', 'Samurai'],
        createdAt: createdAt.subtract(const Duration(days: 2)),
      ),
      ArtworkModel(
        userId: userId,
        title: 'Frieren: Beyond Journey’s End',
        category: ArtworkCategory.anime,
        creator: 'Keiichirō Saitō',
        year: 2023,
        description:
            'An elven mage retraces a heroic journey and learns about time.',
        imageUrl: 'assets/images/covers/frieren.jpg',
        status: ArtworkStatus.inProgress,
        rating: 9,
        tags: const ['Fantasy', 'Adventure'],
        isFavorite: true,
        createdAt: createdAt.subtract(const Duration(days: 1)),
      ),
    ];

    final artworkIds = <int>[];
    for (final work in seedWorks) {
      artworkIds.add(await txn.insert('artworks', work.toMap()));
    }

    final reviews = [
      {
        'user_id': userId,
        'artwork_id': artworkIds[0],
        'content':
            'A moving, carefully researched story with unforgettable characters.',
        'rating': 9.0,
        'status': ArtworkStatus.completed.databaseValue,
        'is_public': 1,
        'created_at': createdAt
            .subtract(const Duration(days: 2))
            .toIso8601String(),
      },
      {
        'user_id': userId,
        'artwork_id': artworkIds[2],
        'content':
            'A powerful journey whose quiet moments stay with you for years.',
        'rating': 10.0,
        'status': ArtworkStatus.completed.databaseValue,
        'is_public': 1,
        'created_at': createdAt
            .subtract(const Duration(days: 1))
            .toIso8601String(),
      },
      {
        'user_id': userId,
        'artwork_id': artworkIds[4],
        'content':
            'Tense, precise, and brilliantly acted from beginning to end.',
        'rating': 10.0,
        'status': ArtworkStatus.completed.databaseValue,
        'is_public': 0,
        'created_at': createdAt.toIso8601String(),
      },
    ];
    for (final review in reviews) {
      await txn.insert('reviews', review);
    }

    final favoritesListId = await txn.insert('lists', {
      'user_id': userId,
      'title': 'Stories that stayed with me',
      'description': 'Works I keep thinking about long after the ending.',
      'is_public': 1,
      'created_at': createdAt
          .subtract(const Duration(days: 2))
          .toIso8601String(),
    });
    final nextListId = await txn.insert('lists', {
      'user_id': userId,
      'title': 'Up next',
      'description': 'Books, games, and shows I want to experience soon.',
      'is_public': 0,
      'created_at': createdAt
          .subtract(const Duration(days: 1))
          .toIso8601String(),
    });
    for (final artworkId in [artworkIds[0], artworkIds[2], artworkIds[4]]) {
      await txn.insert('list_items', {
        'list_id': favoritesListId,
        'artwork_id': artworkId,
      });
    }
    for (final artworkId in [artworkIds[3], artworkIds[8]]) {
      await txn.insert('list_items', {
        'list_id': nextListId,
        'artwork_id': artworkId,
      });
    }
  }
}
