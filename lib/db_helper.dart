import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class DBHelper {
  static Database? _db;

  // 🔹 Firestore reference
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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

  // ✅ Insert new user (both local + Firestore)
  static Future<int> insertUser(Map<String, dynamic> user) async {
    final db = await database;

    // Save locally
    int id = await db.insert("users", user,
        conflictAlgorithm: ConflictAlgorithm.replace);

    // Save to Firestore
    await _firestore.collection("users").doc(user["name"]).set({
      "name": user["name"],
      "password": user["password"],
      "phone": user["phone"],
      "age": user["age"],
      "gender": user["gender"],
      "latitude": user["latitude"],
      "longitude": user["longitude"],
    });

    return id;
  }

  // ✅ Get user by name (check Firestore first, fallback to SQLite)
  static Future<Map<String, dynamic>?> getUserByName(String name) async {
    try {
      final doc = await _firestore.collection("users").doc(name).get();
      if (doc.exists) return doc.data();
    } catch (_) {}

    final db = await database;
    final res =
        await db.query("users", where: "name = ?", whereArgs: [name], limit: 1);
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

  // ✅ Get all users (Firestore preferred, fallback local)
  static Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      final snapshot = await _firestore.collection("users").get();
      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (_) {
      final db = await database;
      return await db.query("users");
    }
  }

  // ✅ Update user location (both local + Firestore)
  static Future<int> updateUserLocation(
      String name, double latitude, double longitude) async {
    final db = await database;

    // Local update
    int updated = await db.update(
      "users",
      {"latitude": latitude, "longitude": longitude},
      where: "name = ?",
      whereArgs: [name],
    );

    // Firestore update
    await _firestore.collection("users").doc(name).update({
      "latitude": latitude,
      "longitude": longitude,
    });

    return updated;
  }

  // ========== GYM METHODS ==========
  static Future<int> insertGym(Map<String, dynamic> gym) async {
    final db = await database;

    // Save local
    int id = await db.insert("gyms", gym,
        conflictAlgorithm: ConflictAlgorithm.replace);

    // Save Firestore
    await _firestore.collection("gyms").add(gym);

    return id;
  }

  static Future<List<Map<String, dynamic>>> getGyms() async {
    try {
      final snapshot = await _firestore.collection("gyms").get();
      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (_) {
      final db = await database;
      return await db.query("gyms");
    }
  }

  // ========== NEAREST BUDDY ==========
  static Future<Map<String, dynamic>?> getNearestBuddy(
      String currentUserName, double lat, double lon) async {
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
      double lat1, double lon1, double lat2, double lon2) {
    const R = 6371; // Earth radius in km
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);

    final a = (sin(dLat / 2) * sin(dLat / 2)) +
        cos(_deg2rad(lat1)) *
            cos(_deg2rad(lat2)) *
            (sin(dLon / 2) * sin(dLon / 2));

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  static double _deg2rad(double deg) => deg * (pi / 180.0);
}
