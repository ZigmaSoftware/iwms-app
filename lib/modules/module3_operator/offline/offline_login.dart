// import 'dart:convert';

// import 'package:crypto/crypto.dart';
// import 'package:iwms_citizen_app/data/models/user_model.dart';
// import 'package:sqflite/sqflite.dart';
// import 'package:path/path.dart';

// class DB {
//   DB._();
//   static final DB instance = DB._();

//   Database? _database;

//   Future<Database> get database async {
//     if (_database != null) return _database!;

//     final dbPath = await getDatabasesPath();
//     final path = join(dbPath, "operator_app.db");

//     _database = await openDatabase(
//       path,
//       version: 1,
//       onCreate: _createDB,
//     );

//     return _database!;
//   }

//   Future _createDB(Database db, int version) async {
//     await db.execute("""
//       CREATE TABLE operator_user (
//         id INTEGER PRIMARY KEY AUTOINCREMENT,
//         unique_id TEXT,
//         username TEXT UNIQUE,
//         emp_id TEXT,
//         name TEXT,
//         role TEXT,
//         access_token TEXT,
//         password_hash TEXT
//       );
//     """);

//   }
// }
// Future<void> saveOperatorToDB(Map<String, dynamic> apiData, String password) async {
//   final db = await DB.instance.database;
//   final passHash = sha256.convert(utf8.encode(password)).toString();

//   await db.insert(
//     "operator_user",
//     {
//       "unique_id": apiData["unique_id"]?.toString(),
//       "username": apiData["name"]?.toString(),
//       "name": apiData["name"]?.toString(),
//       "role": apiData["role"]?.toString(),
//       "access_token": apiData["access_token"]?.toString(),
//       "emp_id": apiData["emp_id"]?.toString(),
//       "password_hash": passHash,
//     },
//     conflictAlgorithm: ConflictAlgorithm.replace,
//   );
// }
// Future<Map<String, dynamic>?> getOperatorFromDB(String username) async {
//   final db = await DB.instance.database;

//   final res = await db.query(
//     "operator_user",
//     where: "username = ?",
//     whereArgs: [username],
//     limit: 1,
//   );

//   if (res.isEmpty) return null;

//   return res.first;
// }
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DB {
  DB._();
  static final DB instance = DB._();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, "operator_app.db");

    _database = await openDatabase(
      path,
      version: 3,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );

    return _database!;
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute("""
      CREATE TABLE operator_user (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        unique_id TEXT,
        username TEXT UNIQUE,
        emp_id TEXT,
        employee_id TEXT,
        name TEXT,
        role TEXT,
        access_token TEXT,
        password_hash TEXT
      );
    """);

    await db.execute("""
      CREATE TABLE offline_attendance (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
      emp_id TEXT,
      employee_id TEXT,
        name TEXT,
        image_path TEXT,
        latitude TEXT,
        longitude TEXT,
        timestamp TEXT,
        synced INTEGER DEFAULT 0
      );
    """);
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute("""
        CREATE TABLE IF NOT EXISTS offline_attendance (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          emp_id TEXT,
          name TEXT,
          image_path TEXT,
          latitude TEXT,
          longitude TEXT,
          timestamp TEXT,
          synced INTEGER DEFAULT 0
        );
      """);
    }

    if (oldVersion < 3) {
      try {
        await db.execute("""
          ALTER TABLE operator_user ADD COLUMN employee_id TEXT;
        """);
      } catch (_) {}
    }
  }
}

// -------------------------------------------------------
// SAVE USER
// -------------------------------------------------------
Future<void> saveOperatorToDB(
  Map<String, dynamic> apiData,
  String password, {
  String? username,
}) async {
  final db = await DB.instance.database;
  final passHash = sha256.convert(utf8.encode(password)).toString();

  await db.insert(
    "operator_user",
    {
      "unique_id": apiData["unique_id"]?.toString(),
      "username": username?.trim().isNotEmpty == true
          ? username!.trim()
          : apiData["username"]?.toString() ?? apiData["name"]?.toString(),
      "name": apiData["name"]?.toString(),
      "role": apiData["role"]?.toString(),
      "access_token": apiData["access_token"]?.toString(),
      "emp_id": apiData["emp_id"]?.toString(),
      "employee_id": apiData["employee_id"]?.toString(),
      "password_hash": passHash,
    },
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
}

// -------------------------------------------------------
// GET USER
// -------------------------------------------------------
Future<Map<String, dynamic>?> getOperatorFromDB(String username) async {
  final db = await DB.instance.database;

  final res = await db.query(
    "operator_user",
    where: "username = ?",
    whereArgs: [username],
    limit: 1,
  );

  if (res.isEmpty) return null;

  return res.first;
}
