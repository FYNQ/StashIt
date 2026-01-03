import 'dart:async';
import '../data/drift/database.dart';

class AutoDeleteService {
  static Timer? _timer;

  static Future<void> start(AppDatabase db) async {
    // Run once at start
    try {
      await db.pruneDueAutoDeletes();
    } catch (_) {}

    // Then every minute while app is running
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) async {
      try {
        await db.pruneDueAutoDeletes();
      } catch (_) {
        // ignore errors
      }
    });
  }

  static void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
