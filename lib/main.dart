import 'package:flutter/material.dart';
import 'data/drift/database.dart';
import 'ui/search/search_screen.dart';
import 'ui/search/search_controller.dart';
import 'share/share_intent_handler.dart';
import 'package:drift/drift.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final db = AppDatabase();
  final controller = ItemSearchController(db);

  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SearchScreen(controller: controller),
    ),
  );

  // 🔽 everything below runs AFTER UI is shown
  ShareIntentHandler.init();

  ShareIntentHandler.stream.listen((shared) async {
    final now = DateTime.now();

    if (shared.text != null && shared.text!.isNotEmpty) {
      await db.into(db.items).insert(
        ItemsCompanion.insert(
          title: shared.text!.length > 50
              ? shared.text!.substring(0, 50)
              : shared.text!,
          content: Value(shared.text),
          createdAt: Value(now),
        ),
      );
    }

    for (final file in shared.files) {
      await db.into(db.items).insert(
        ItemsCompanion.insert(
          title: file.path.split('/').last,
          content: Value(file.path),
          createdAt: Value(now),
        ),
      );
    }
  });
}

