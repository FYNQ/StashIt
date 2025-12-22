import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables/items.dart';
import 'tables/items_fts.dart';
import 'tables/tags.dart';
import 'tables/item_tags.dart';
import 'tables/properties.dart';
import 'tables/ocr_blocks.dart';
import 'tables/schedules.dart';
import 'tables/embeddings.dart';
import 'tables/ops_log.dart';

part 'database.g.dart';

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'app_flutter/stashit.db'));
    return NativeDatabase(file);
  });
}

@DriftDatabase(
  tables: [
    Items,
    ItemsFts,
    Tags,
    ItemTags,
    Properties,
    OcrBlocks,
    Schedules,
    Embeddings,
    OpsLog,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  String _deriveTitle(String? text) {
    if (text == null || text.trim().isEmpty) {
      return 'Shared item';
    }
    final t = text.trim();
    return t.length > 50 ? '${t.substring(0, 50)}…' : t;
  }

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();

          // Populate FTS
          await customStatement('''
            INSERT INTO items_fts(rowid, title, content)
            SELECT id, title, content FROM items
            WHERE content IS NOT NULL;
          ''');

          // INSERT trigger
          await customStatement('''
            CREATE TRIGGER items_ai AFTER INSERT ON items
            BEGIN
              INSERT INTO items_fts(rowid, title, content)
              VALUES (new.id, new.title, new.content);
            END;
          ''');

          // UPDATE trigger
          await customStatement('''
            CREATE TRIGGER items_au AFTER UPDATE ON items
            BEGIN
              DELETE FROM items_fts WHERE rowid = old.id;
              INSERT INTO items_fts(rowid, title, content)
              VALUES (new.id, new.title, new.content);
            END;
          ''');

          // DELETE trigger
          await customStatement('''
            CREATE TRIGGER items_ad AFTER DELETE ON items
            BEGIN
              DELETE FROM items_fts WHERE rowid = old.id;
            END;
          ''');
        },
      );

  // --------------------------------------------------
  // INSERT
  // --------------------------------------------------

  Future<int> insertSharedData({
    String? text,
    String? title,
  }) {
    final now = DateTime.now();

    print('Inserted shared item: $title');

    return into(items).insert(
      ItemsCompanion.insert(
        title: title ?? _deriveTitle(text),
        content: Value(text),
        updatedAt: Value(now),
      ),
    );
  }

  // --------------------------------------------------
  // SEARCH
  // --------------------------------------------------

Future<List<Item>> searchItems(String query) async {
  final result = await customSelect(
    'SELECT * FROM items WHERE title LIKE ? OR content LIKE ? ORDER BY updated_at DESC',
    variables: [Variable.withString('%$query%'), Variable.withString('%$query%')],
  ).get();
  
  // ✅ FIX: Use Future.wait to resolve all futures
  return Future.wait(result.map(items.mapFromRow));
}

Future<List<Item>> searchItemsWithTag({
  required String query,
  required int? tagId,
}) async {
  // Handle null tagId case
  if (tagId == null) {
    // If no tag specified, search all items
    return searchItems(query);
  }
  
  final result = await customSelect(
    'SELECT * FROM items WHERE (title LIKE ? OR content LIKE ?) AND tag_id = ? ORDER BY updated_at DESC',
    variables: [
      Variable.withString('%$query%'), 
      Variable.withString('%$query%'),
      Variable.withInt(tagId), // Now tagId is guaranteed to be non-null
    ],
  ).get();
  
  return Future.wait(result.map(items.mapFromRow));
}

  // --------------------------------------------------
  // TAGS
  // --------------------------------------------------

  Future<List<Tag>> getAllTags() => select(tags).get();

  Future<void> attachTag({
    required int itemId,
    required int tagId,
  }) {
    return into(itemTags).insert(
      ItemTagsCompanion.insert(
        itemId: itemId,
        tagId: tagId,
      ),
    );
  }

Future<List<Item>> getRecentItems() async {
  final result = await customSelect(
    'SELECT * FROM items ORDER BY updated_at DESC LIMIT 20',
  ).get();
  
  return Future.wait(result.map(items.mapFromRow));
}


  Future<List<Item>> getAllItems() {
    return (select(items)
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
  }
}

