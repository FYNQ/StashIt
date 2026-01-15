// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Markus Kreidl

import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:media_kit/media_kit.dart'; // REQUIRED for media_kit init
import 'data/drift/database.dart';
import 'ui/search/search_screen.dart';
import 'ui/search/search_controller.dart';
import 'ui/add_item/add_item_screen.dart';
import 'share/share_intent_handler.dart';
import 'util/auto_delete_service.dart'; // <-- ADD THIS

late final AppDatabase database;
late final ItemSearchController searchController;

/// 🔑 GLOBAL navigator key
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize media_kit once before any Player is created 🎧
  MediaKit.ensureInitialized();

  database = AppDatabase();
  // Ensure FTS table + triggers exist, and index is populated
  await database.ensureFtsSetup();

  // Start auto-delete pruning service
  await AutoDeleteService.start(database); // <-- ADD THIS

  searchController = ItemSearchController(database);

  await ShareIntentHandler.init();

  // 1. Capture Initial Media/Text (Cold Start)
  List<SharedMediaFile> initialMedia = await ReceiveSharingIntent.instance.getInitialMedia();

  runApp(const StashItApp());

  // 2. Handle Initial Data after app boot
  if (initialMedia.isNotEmpty) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final nav = navigatorKey.currentState;
      if (nav == null) return;

      // For plain text, the content is in .path
      final firstFile = initialMedia.first;

      if (firstFile.type == SharedMediaType.text || firstFile.type == SharedMediaType.url) {
        nav.push(
          MaterialPageRoute(
            builder: (_) => AddItemScreen(
              database: database,
              sharedText: firstFile.path,
            ),
          ),
        ).then((saved) {
          if (saved == true) {
            // Refresh the search with current query (respects tag filter too)
            searchController.updateQuery(searchController.query);
          }
        });
      } else {
        final atts = initialMedia
            .map((f) => AttachmentFile(f.path, mimeType: f.mimeType))
            .toList();

        nav.push(
          MaterialPageRoute(
            builder: (_) => AddItemScreen(
              database: database,
              attachments: atts,
            ),
          ),
        ).then((saved) {
          if (saved == true) {
            searchController.updateQuery(searchController.query);
          }
        });
      }
    });
  }

  // 3. Live Media/Text Stream (App in background/foreground)
  ReceiveSharingIntent.instance.getMediaStream().listen((List<SharedMediaFile> files) {
    if (files.isEmpty) return;
    final nav = navigatorKey.currentState;
    if (nav == null) return;

    final first = files.first;
    if (first.type == SharedMediaType.text || first.type == SharedMediaType.url) {
      nav.push(
        MaterialPageRoute(
          builder: (_) => AddItemScreen(
            database: database,
            sharedText: first.path,
          ),
        ),
      ).then((saved) {
        if (saved == true) {
          searchController.updateQuery(searchController.query);
        }
      });
    } else {
      final atts = files
          .map((f) => AttachmentFile(f.path, mimeType: f.mimeType))
          .toList();

      nav.push(MaterialPageRoute(
        builder: (_) => AddItemScreen(
          database: database,
          attachments: atts,
        ),
      )).then((saved) {
        if (saved == true) {
          searchController.updateQuery(searchController.query);
        }
      });
    }
  }, onError: (err) {
    debugPrint("getMediaStream error: $err");
  });
}

class StashItApp extends StatelessWidget {
  const StashItApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Stashr',
      theme: ThemeData(useMaterial3: true),
      home: SearchScreen(
        controller: searchController,
      ),
    );
  }
}
