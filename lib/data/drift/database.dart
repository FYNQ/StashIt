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
    // Android/iOS-safe SQLite directory
    final dir = await getApplicationDocumentsDirectory();
    // Full path to DB file
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

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();

          // FTS triggers
          await customStatement('''
            INSERT INTO items_fts(rowid, content)
            SELECT rowid, content FROM items WHERE content IS NOT NULL;
          ''');

          await customStatement('''
            CREATE TRIGGER items_ai AFTER INSERT ON items
            WHEN new.content IS NOT NULL
            BEGIN
              INSERT INTO items_fts(rowid, content)
              VALUES (new.rowid, new.content);
            END;
          ''');

          await customStatement('''
            CREATE TRIGGER items_au AFTER UPDATE ON items
            BEGIN
              DELETE FROM items_fts WHERE rowid = old.rowid;
              INSERT INTO items_fts(rowid, content)
              SELECT new.rowid, new.content
              WHERE new.content IS NOT NULL;
            END;
          ''');

          await customStatement('''
            CREATE TRIGGER items_ad AFTER DELETE ON items
            BEGIN
              DELETE FROM items_fts WHERE rowid = old.rowid;
            END;
          ''');
        },
      );

Future<void> insertSharedItem({
  required String title,
  String? content,
}) {
  return into(items).insert(
    ItemsCompanion.insert(
      title: title,
      content: Value(content),
    ),
  );
}


  /// Search all items matching query
  Future<List<Item>> searchItems(String query) async {
    if (query.trim().isEmpty) return [];

    final result = await customSelect(
      '''
      SELECT items.*
      FROM items
      JOIN items_fts ON items_fts.rowid = items.rowid
      WHERE items_fts MATCH ?
      ORDER BY bm25(items_fts)
      ''',
      variables: [Variable.withString(query)],
      readsFrom: {items, itemsFts},
    ).get();

	return await Future.wait(result.map(items.mapFromRow));
  }

  /// Search items with optional tag filtering
  Future<List<Item>> searchItemsWithTag({
    required String query,
    int? tagId,
  }) async {
    if (query.trim().isEmpty) return [];

    final sql = StringBuffer('''
      SELECT DISTINCT items.*
      FROM items
      JOIN items_fts ON items_fts.rowid = items.rowid
    ''');

    final vars = <Variable>[];
    if (tagId != null) {
      sql.write('JOIN item_tags ON item_tags.item_id = items.id ');
    }

    sql.write('WHERE items_fts MATCH ? ');
    vars.add(Variable.withString(query));

    if (tagId != null) {
      sql.write('AND item_tags.tag_id = ? ');
      vars.add(Variable.withInt(tagId));
    }

    sql.write('ORDER BY bm25(items_fts)');

    final result = await customSelect(sql.toString(), variables: vars, readsFrom: {items, itemTags}).get();
	return await Future.wait(result.map(items.mapFromRow));
  }

/// Insert data from share ...
Future<int> insertSharedData({
  String? text,
  String? title,
}) async {
  final now = DateTime.now();

  return into(items).insert(
    ItemsCompanion.insert(
      title: title ?? _deriveTitle(text),
      content: Value(text),
      updatedAt: Value(now),
    ),
  );
}

String _deriveTitle(String? text) {
  if (text == null || text.trim().isEmpty) {
    return 'Shared item';
  }

  final trimmed = text.trim();
  return trimmed.length > 50
      ? '${trimmed.substring(0, 50)}…'
      : trimmed;
}


  /// Search with pagination
  Future<List<Item>> searchItemsPaged({
    required String query,
    int? tagId,
    required int limit,
    required int offset,
  }) async {
    if (query.trim().isEmpty) return [];

    final sql = StringBuffer('''
      SELECT DISTINCT items.*
      FROM items
      JOIN items_fts ON items_fts.rowid = items.rowid
    ''');

    final vars = <Variable>[];
    if (tagId != null) {
      sql.write('JOIN item_tags ON item_tags.item_id = items.id ');
    }

    sql.write('WHERE items_fts MATCH ? ');
    vars.add(Variable.withString(query));

    if (tagId != null) {
      sql.write('AND item_tags.tag_id = ? ');
      vars.add(Variable.withInt(tagId));
    }

    sql.write('ORDER BY bm25(items_fts) LIMIT ? OFFSET ?');
    vars.add(Variable.withInt(limit));
    vars.add(Variable.withInt(offset));

    final result = await customSelect(sql.toString(), variables: vars, readsFrom: {items, itemTags}).get();
	return await Future.wait(result.map(items.mapFromRow));
  }

  Future<List<Tag>> getAllTags() => select(tags).get();
}


