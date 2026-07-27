import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart' as sqflite;

sqflite.DatabaseFactory get platformDatabaseFactory => sqflite.databaseFactory;

Future<String> platformDatabasePath(String databaseName) async {
  return path.join(await sqflite.getDatabasesPath(), databaseName);
}
