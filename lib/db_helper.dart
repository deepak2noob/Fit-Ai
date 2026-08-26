import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:math';

class DBHelper {
  static Database? _db;

  // ========== LOCAL SQLITE SETUP ==========
  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  static Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, "app.db");

    return await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        // Users table
        await db.execute('''
          CREATE TABLE users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT UNIQUE,
            password TEXT,
            phone TEXT,
            age INTEGER,
            gender TEXT,
            latitude REAL,
            longitude REAL
          )
        ''');

        // Gyms table
        await db.execute('''
          CREATE TABLE gyms (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            latitude REAL,
            longitude REAL
          )
        ''');
      },
    );
  }

  // ========== USER METHODS ==========

  // Insert a user into the on-device database.
  static Future<int> insertUser(Map<String, dynamic> user) async {
    final db = await database;
    return await db.insert(
      "users",
      user,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Get a user from the on-device database.
  static Future<Map<String, dynamic>?> getUserByName(String name) async {
    final db = await database;
    final res = await db.query(
      "users",
      where: "name = ?",
      whereArgs: [name],
      limit: 1,
    );
    if (res.isNotEmpty) return res.first;
    return null;
  }

  // ✅ Get current logged-in user (local only)
  static Future<Map<String, dynamic>?> getCurrentUser() async {
    final db = await database;
    final res = await db.query("users", limit: 1);
    if (res.isNotEmpty) return res.first;
    return null;
  }

  // Get all users stored on this device.
  static Future<List<Map<String, dynamic>>> getAllUsers() async {
    final db = await database;
    return await db.query("users");
  }

  // Update a user's locally stored location.
  static Future<int> updateUserLocation(
    String name,
    double latitude,
    double longitude,
  ) async {
    final db = await database;

    return await db.update(
      "users",
      {"latitude": latitude, "longitude": longitude},
      where: "name = ?",
      whereArgs: [name],
    );
  }

  // ========== GYM METHODS ==========
  static Future<int> insertGym(Map<String, dynamic> gym) async {
    final db = await database;

    return await db.insert(
      "gyms",
      gym,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<Map<String, dynamic>>> getGyms() async {
    final db = await database;
    return await db.query("gyms");
  }

  // ========== NEAREST BUDDY ==========
  static Future<Map<String, dynamic>?> getNearestBuddy(
    String currentUserName,
    double lat,
    double lon,
  ) async {
    final users = await getAllUsers();

    Map<String, dynamic>? nearest;
    double minDistance = double.infinity;

    for (var user in users) {
      if (user["name"] == currentUserName) continue;

      final uLat = user["latitude"] as double?;
      final uLon = user["longitude"] as double?;
      if (uLat == null || uLon == null) continue;

      final distance = _calculateDistance(lat, lon, uLat, uLon);
      if (distance < minDistance) {
        minDistance = distance;
        nearest = user;
      }
    }

    return nearest;
  }

  // ✅ Haversine formula
  static double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const R = 6371; // Earth radius in km
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);

    final a =
        (sin(dLat / 2) * sin(dLat / 2)) +
        cos(_deg2rad(lat1)) *
            cos(_deg2rad(lat2)) *
            (sin(dLon / 2) * sin(dLon / 2));

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  static double _deg2rad(double deg) => deg * (pi / 180.0);
}
