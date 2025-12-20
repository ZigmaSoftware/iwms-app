import 'dart:math';
class UniqueIdService {
  static String generateScreenUniqueId() {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final rand = Random.secure();
  final now = DateTime.now();

  final year = now.year.toString();
  final secondPart = now.second.toString().padLeft(2, '0');
  final milliPart = now.millisecond.toString().padLeft(3, '0');
  final randomStr = List.generate(10, (_) => chars[rand.nextInt(chars.length)]).join();

  // 🔹 final ID format:
  // scr2025s45m512abcxyz91  (prefix + year + second + millisecond + random)
  return 'scr${year}s${secondPart}m$milliPart$randomStr';
}
}