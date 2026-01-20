// SPDX-License-Identifier: Apache-2.0
import 'package:flutter/material.dart';
import 'util/cloud_config.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:media_kit/media_kit.dart'; // REQUIRED for media_kit init
import 'data/drift/database.dart';
import 'ui/search/search_screen.dart';
import 'ui/search/search_controller.dart';
import 'ui/add_item/add_item_screen.dart';
import 'share/share_intent_handler.dart';
import 'util/auto_delete_service.dart';
import 'util/purchase_service.dart';
import 'share/deep_link_handler.dart';

late final AppDatabase database;
late final ItemSearchController searchController;

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  MediaKit.ensureInitialized();

  // Init Supabase (Cloud)
//  await Cloud.init();
  //await Cloud.init(apiBase: 'http://10.0.0.59:8000');
  await Cloud.init(apiBase: 'http://192.168.178.16:8000');

  database = AppDatabase();
  await database.ensureFtsSetup();

  // Start services
  await AutoDeleteService.start(database);

  // Initialize IAP service (subscriptions)
  final purchases = PurchaseService(database);
  await purchases.init();

  searchController = ItemSearchController(database);

  await ShareIntentHandler.init();

  // Cold start: initial share
  final initialMedia = await ReceiveSharingIntent.instance.getInitialMedia();

  runApp(const StashItApp());

  // Initialize deep links after first frame
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final nav = navigatorKey.currentState;
    if (nav != null) {
      DeepLinkHandler.init(
        context: nav.context,
        db: database,
      );
    }
  });

  if (initialMedia.isNotEmpty) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final nav = navigatorKey.currentState;
      if (nav == null) return;

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

  // Live share stream
  ReceiveSharingIntent.instance.getMediaStream().listen((files) {
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
      final atts = files.map((f) => AttachmentFile(f.path, mimeType: f.mimeType)).toList();
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
