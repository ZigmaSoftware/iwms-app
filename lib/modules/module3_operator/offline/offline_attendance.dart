import 'package:iwms_citizen_app/modules/module3_operator/offline/offline_login.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';


Future<void> saveOfflineAttendance({
  required String empId,
  required String name,
  required String imagePath,
  required String latitude,
  required String longitude,
}) async {
  final db = await DB.instance.database;

  await db.insert("offline_attendance", {
    "emp_id": empId,
    "name": name,
    "image_path": imagePath,
    "latitude": latitude,
    "longitude": longitude,
    "timestamp": DateTime.now().toIso8601String(),
    "synced": 0,
  });
}

Future<List<Map<String, dynamic>>> getPendingAttendance() async {
  final db = await DB.instance.database;
  return await db.query("offline_attendance", where: "synced = 0");
}

Future<void> markAttendanceSynced(int id) async {
  final db = await DB.instance.database;

  await db.update(
    "offline_attendance",
    {"synced": 1},
    where: "id = ?",
    whereArgs: [id],
  );
}
