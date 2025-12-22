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


// Delete a single item (and its tag links)
Future<void> deleteItemById(int id) async {
  await transaction(() async {
    await (delete(itemTags)..where((t) => t.itemId.equals(id))).go();
    await (delete(items)..where((t) => t.id.equals(id))).go();
  });
}

// Delete multiple items (and their tag links)
Future<void> deleteItemsByIds(Iterable<int> ids) async {
  final idList = ids.toList();
  if (idList.isEmpty) return;

  await transaction(() async {
    await (delete(itemTags)..where((t) => t.itemId.isIn(idList))).go();
    await (delete(items)..where((t) => t.id.isIn(idList))).go();
  });
}


// Get recent items limited to a specific tag
Future<List<Item>> getItemsByTag(int tagId, {int limit = 50}) async {
  final result = await customSelect(
    '''
    SELECT items.*
    FROM items
    JOIN item_tags ON item_tags.item_id = items.id
    WHERE item_tags.tag_id = ?
    ORDER BY items.updated_at DESC
    LIMIT ?
    ''',
    variables: [
      Variable.withInt(tagId),
      Variable.withInt(limit),
    ],
    readsFrom: {items, itemTags},
  ).get();

  return await Future.wait(result.map(items.mapFromRow));
}

// Fetch a tag by name
Future<Tag?> getTagByName(String name) async {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return null;
  return (select(tags)..where((t) => t.name.equals(trimmed))).getSingleOrNull();
}


// Create if missing; return the tag. Handles UNIQUE(name) races.
Future<Tag> upsertTagByName(String name, {String? color}) async {
  final trimmed = name.trim();
  if (trimmed.isEmpty) {
    throw ArgumentError('Tag name cannot be empty');
  }

  final existing = await getTagByName(trimmed);
  if (existing != null) return existing;

  try {
    final id = await into(tags).insert(
      TagsCompanion.insert(
        name: trimmed,
        color: Value(color),
      ),
    );
    return (select(tags)..where((t) => t.id.equals(id))).getSingle();
  } catch (_) {
    // Likely UNIQUE constraint hit due to race; fetch again
    final fallback = await getTagByName(trimmed);
    if (fallback != null) return fallback;
    rethrow;
  }
}

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
    variables: [
      Variable.withString('%$query%'),
      Variable.withString('%$query%'),
    ],
  ).get();

  // Await each row mapping
  return await Future.wait(result.map(items.mapFromRow));
}
Future<List<Item>> searchItemsWithTag({
  required String query,
  required int? tagId,
}) async {
  if (tagId == null) {
    // No tag filter → normal search
    return searchItems(query);
  }

  final trimmed = query.trim();

  if (trimmed.isEmpty) {
    // Empty query + tag selected → only show items with that tag
    return getItemsByTag(tagId);
  }

  final result = await customSelect(
    '''
    SELECT items.*
    FROM items
    JOIN item_tags ON item_tags.item_id = items.id
    WHERE item_tags.tag_id = ?
      AND (items.title LIKE ? OR items.content LIKE ?)
    ORDER BY items.updated_at DESC
    ''',
    variables: [
      Variable.withInt(tagId),
      Variable.withString('%$trimmed%'),
      Variable.withString('%$trimmed%'),
    ],
    readsFrom: {items, itemTags},
  ).get();

  return await Future.wait(result.map(items.mapFromRow));
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

  return await Future.wait(result.map(items.mapFromRow));
}


  Future<List<Item>> getAllItems() {
    return (select(items)
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
  }
}

