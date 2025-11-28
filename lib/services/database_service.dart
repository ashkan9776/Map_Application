// services/database_service.dart
import 'package:flutter_application_1/models/favorite_place.dart.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseService {
  static Database? _database;
  static const String _tableName = 'favorite_places';

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  static Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'navigation.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  static Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_tableName(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        address TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        createdAt INTEGER NOT NULL,
        category TEXT
      )
    ''');
  }

  static Future<int> insertFavorite(FavoritePlace place) async {
    final db = await database;
    return await db.insert(_tableName, place.toMap());
  }

  static Future<List<FavoritePlace>> getFavorites() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(_tableName,
        orderBy: 'createdAt DESC');
    return maps.map((map) => FavoritePlace.fromMap(map)).toList();
  }

  static Future<void> deleteFavorite(int id) async {
    final db = await database;
    await db.delete(_tableName, where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> updateFavorite(FavoritePlace place) async {
    final db = await database;
    await db.update(_tableName, place.toMap(),
        where: 'id = ?', whereArgs: [place.id]);
  }
}