import 'package:flutter/material.dart';
import 'data/drift/database.dart';
import 'ui/search/search_screen.dart';
import 'ui/search/search_controller.dart';
import 'ui/add_item/add_item_screen.dart';
import 'share/share_intent_handler.dart';

late final AppDatabase database;
late final ItemSearchController searchController;

/// 🔑 GLOBAL navigator key
final GlobalKey<NavigatorState> navigatorKey =
    GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  database = AppDatabase();
  searchController = ItemSearchController(database);

  await ShareIntentHandler.init();

  runApp(const StashItApp());

  // 🔴 LISTEN AFTER runApp
  ShareIntentHandler.stream.listen((sharedText) {
    if (sharedText == null || sharedText.isEmpty) return;

    final nav = navigatorKey.currentState;
    if (nav == null) return;

    nav.push(
      MaterialPageRoute(
        builder: (_) => AddItemScreen(
          database: database,
          sharedText: sharedText,
        ),
      ),
    );
  });
}

class StashItApp extends StatelessWidget {
  const StashItApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, // 🔴 REQUIRED
      debugShowCheckedModeBanner: false,
      title: 'StashIt',
      theme: ThemeData(useMaterial3: true),
      home: SearchScreen(
        controller: searchController,
      ),
    );
  }
}

