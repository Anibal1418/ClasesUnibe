import 'package:sqflite/sqflite.dart';

import 'database_factory_io.dart'
    if (dart.library.html) 'database_factory_web.dart'
    as platform;

DatabaseFactory get platformDatabaseFactory => platform.platformDatabaseFactory;

Future<String> platformDatabasePath(String databaseName) =>
    platform.platformDatabasePath(databaseName);
