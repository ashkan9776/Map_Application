// services/database_service.dart
import 'package:map_application/models/favorite_place.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// A class containing constants for the favorite places table.
class _FavoritesTable {
  static const String tableName = 'favorite_places';

  static const String colId = 'id';
  static const String colName = 'name';
  static const String colAddress = 'address';
  static const String colLatitude = 'latitude';
  static const String colLongitude = 'longitude';
  static const String colCreatedAt = 'createdAt';
  static const String colCategory = 'category';
}

/// A singleton service for managing the local SQLite database.
class DatabaseService {
  static Database? _database;
  static const int _dbVersion = 1;

  /// Provides access to the singleton database instance.
  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  /// Initializes the database.
  /// Creates the database file and the necessary tables if they don't exist.
  static Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'navigation_app.db');
    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _createDB,
      onUpgrade: _onUpgradeDB,
    );
  }

  /// Called when the database is created for the first time.
  static Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE ${_FavoritesTable.tableName}(
        ${_FavoritesTable.colId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${_FavoritesTable.colName} TEXT NOT NULL,
        ${_FavoritesTable.colAddress} TEXT NOT NULL,
        ${_FavoritesTable.colLatitude} REAL NOT NULL,
        ${_FavoritesTable.colLongitude} REAL NOT NULL,
        ${_FavoritesTable.colCreatedAt} INTEGER NOT NULL,
        ${_FavoritesTable.colCategory} TEXT
      )
    ''');
  }

  /// Called when the database needs to be upgraded.
  /// Use this to handle schema changes over time.
  static Future<void> _onUpgradeDB(Database db, int oldVersion, int newVersion) async {
    // In the future, if you change the _dbVersion, you can add migration
    // logic here. For example:
    // if (oldVersion < 2) {
    //   await db.execute("ALTER TABLE ${_FavoritesTable.tableName} ADD COLUMN new_field TEXT;");
    // }
  }

  /// Inserts a new favorite place into the database.
  static Future<int> insertFavorite(FavoritePlace place) async {
    final db = await database;
    return await db.insert(
      _FavoritesTable.tableName,
      place.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace, // Replace if ID already exists
    );
  }

  /// Retrieves all favorite places from the database, ordered by creation date.
  static Future<List<FavoritePlace>> getFavorites() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _FavoritesTable.tableName,
      orderBy: '${_FavoritesTable.colCreatedAt} DESC',
    );
    return maps.map((map) => FavoritePlace.fromMap(map)).toList();
  }

  /// Deletes a favorite place from the database by its ID.
  static Future<int> deleteFavorite(int id) async {
    final db = await database;
    return await db.delete(
      _FavoritesTable.tableName,
      where: '${_FavoritesTable.colId} = ?',
      whereArgs: [id],
    );
  }

  /// Updates an existing favorite place in the database.
  static Future<int> updateFavorite(FavoritePlace place) async {
    final db = await database;
    return await db.update(
      _FavoritesTable.tableName,
      place.toMap(),
      where: '${_FavoritesTable.colId} = ?',
      whereArgs: [place.id],
    );
  }
}
