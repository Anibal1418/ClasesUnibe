import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:your_art_archive/database/database_helper.dart';
import 'package:your_art_archive/services/auth_service.dart';

void main() {
  sqfliteFfiInit();

  late DatabaseHelper databaseHelper;
  late AuthService authService;

  setUp(() {
    databaseHelper = DatabaseHelper(
      databaseFactory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    authService = AuthService(databaseHelper: databaseHelper);
  });

  tearDown(() => databaseHelper.close());

  test(
    'registration hashes password and transactionally seeds each account',
    () async {
      final user = await authService.registerUser(
        name: 'Laura Martínez',
        email: 'Laura@Example.com',
        password: 'secret12',
      );
      final db = await databaseHelper.database;

      expect(user.id, isNotNull);
      expect(user.email, 'laura@example.com');
      expect(user.password, isNot('secret12'));
      expect(user.password, startsWith(r'v1$'));
      expect(
        (await db.rawQuery(
          'SELECT COUNT(*) AS count FROM artworks WHERE user_id = ?',
          [user.id],
        )).single['count'],
        10,
      );
      expect(
        (await db.rawQuery(
          'SELECT COUNT(*) AS count FROM reviews WHERE user_id = ?',
          [user.id],
        )).single['count'],
        3,
      );
      expect(
        (await db.rawQuery(
          'SELECT COUNT(*) AS count FROM lists WHERE user_id = ?',
          [user.id],
        )).single['count'],
        2,
      );
    },
  );

  test(
    'login is case-insensitive, rejects bad credentials, and logs out',
    () async {
      final registered = await authService.registerUser(
        name: 'Laura',
        email: 'laura@example.com',
        password: 'secret12',
      );
      await authService.logout();
      expect(authService.currentUser, isNull);

      final loggedIn = await authService.loginUser(
        email: 'LAURA@EXAMPLE.COM',
        password: 'secret12',
      );
      expect(loggedIn.id, registered.id);
      expect(authService.getCurrentUser()?.id, registered.id);

      await expectLater(
        authService.loginUser(
          email: 'laura@example.com',
          password: 'incorrect',
        ),
        throwsA(isA<AuthException>()),
      );
    },
  );

  test('email uniqueness is case-insensitive', () async {
    await authService.registerUser(
      name: 'Laura',
      email: 'laura@example.com',
      password: 'secret12',
    );
    expect(await authService.validateEmailExists('LAURA@example.com'), isTrue);

    await expectLater(
      authService.registerUser(
        name: 'Other Laura',
        email: 'LAURA@EXAMPLE.COM',
        password: 'another12',
      ),
      throwsA(isA<AuthException>()),
    );
  });

  test('foreign keys are enabled', () async {
    final db = await databaseHelper.database;
    final rows = await db.rawQuery('PRAGMA foreign_keys');
    expect(rows.single.values.single, 1);
  });
}
