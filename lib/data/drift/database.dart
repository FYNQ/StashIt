// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Markus Kreidl

import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import 'tables/items.dart';
// Removed: import 'tables/items_fts.dart';
import 'tables/tags.dart';
import 'tables/item_tags.dart';
import 'tables/properties.dart';
import 'tables/ocr_blocks.dart';
import 'tables/schedules.dart';
import 'tables/embeddings.dart';
import 'tables/ops_log.dart';
import 'tables/attachments.dart';

part 'database.g.dart';

// Simple DTO used when passing attachments from UI/controllers to DB
class AttachmentFile {
  final String path;
  final String? mimeType;
  AttachmentFile(this.path, {this.mimeType});
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'stashit.db'));
    return NativeDatabase(file);
  });
}

@DriftDatabase(
  tables: [
    Items,
    // Removed ItemsFts (we’ll create it via SQL)
    Tags,
    ItemTags,
    Properties,
    OcrBlocks,
    Schedules,
    Embeddings,
    OpsLog,
    Attachments,
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

  // Convert user input into FTS prefix query: "foo bar" -> "foo* AND bar*"
  String _ftsPrefixQuery(String input) {
    final parts = input
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .map((p) {
          final cleaned = p.replaceAll('"', '');
          return '$cleaned*';
        })
        .toList();
    if (parts.isEmpty) return '';
    return parts.join(' AND ');
  }

  // --- UPDATE: item content (notes) ---
  Future<void> updateItemContent({
    required int id,
    String? content,
  }) async {
    await (update(items)..where((t) => t.id.equals(id))).write(
      ItemsCompanion(
        content: Value(content),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  // --------------------------------------------------
  // FTS ENSURE + REBUILD
  // --------------------------------------------------

  Future<void> ensureFtsSetup() async {
    await customStatement('''
      CREATE VIRTUAL TABLE IF NOT EXISTS items_fts
      USING fts5(title, content);
    ''');

    Future<void> _try(String sql) async {
      try {
        await customStatement(sql);
      } catch (_) {}
    }

    await _try('''
      CREATE TRIGGER IF NOT EXISTS items_ai AFTER INSERT ON items
      BEGIN
        INSERT INTO items_fts(rowid, title, content)
        VALUES (
          new.id,
          new.title,
          trim(coalesce(new.content, '') || ' ' || coalesce(new.link, ''))
        );
      END;
    ''');

    await _try('''
      CREATE TRIGGER IF NOT EXISTS items_au AFTER UPDATE ON items
      BEGIN
        DELETE FROM items_fts WHERE rowid = old.id;
        INSERT INTO items_fts(rowid, title, content)
        VALUES (
          new.id,
          new.title,
          trim(coalesce(new.content, '') || ' ' || coalesce(new.link, ''))
        );
      END;
    ''');

    await _try('''
      CREATE TRIGGER IF NOT EXISTS items_ad AFTER DELETE ON items
      BEGIN
        DELETE FROM items_fts WHERE rowid = old.id;
      END;
    ''');

    final row = await customSelect('SELECT COUNT(*) AS c FROM items_fts').getSingleOrNull();
    final ftsCount = (row?.data['c'] as int?) ?? 0;
    if (ftsCount == 0) {
      await rebuildFts();
    }
  }

  Future<void> rebuildFts() async {
    await customStatement('DELETE FROM items_fts;');
    await customStatement('''
      INSERT INTO items_fts(rowid, title, content)
      SELECT id, title, trim(coalesce(content, '') || ' ' || coalesce(link, ''))
      FROM items;
    ''');
  }

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();

          await customStatement('''
            CREATE VIRTUAL TABLE items_fts
            USING fts5(title, content);
          ''');

          await customStatement('''
            INSERT INTO items_fts(rowid, title, content)
            SELECT id, title, trim(coalesce(content, '') || ' ' || coalesce(link, ''))
            FROM items;
          ''');

          await customStatement('''
            CREATE TRIGGER items_ai AFTER INSERT ON items
            BEGIN
              INSERT INTO items_fts(rowid, title, content)
              VALUES (
                new.id,
                new.title,
                trim(coalesce(new.content, '') || ' ' || coalesce(new.link, ''))
              );
            END;
          ''');

          await customStatement('''
            CREATE TRIGGER items_au AFTER UPDATE ON items
            BEGIN
              DELETE FROM items_fts WHERE rowid = old.id;
              INSERT INTO items_fts(rowid, title, content)
              VALUES (
                new.id,
                new.title,
                trim(coalesce(new.content, '') || ' ' || coalesce(new.link, ''))
              );
            END;
          ''');

          await customStatement('''
            CREATE TRIGGER items_ad AFTER DELETE ON items
            BEGIN
              DELETE FROM items_fts WHERE rowid = old.id;
            END;
          ''');
        },
      );

  // --------------------------------------------------
  // BULK DELETE HELPERS
  // --------------------------------------------------

  Future<List<int>> getItemIdsByTag(int tagId) async {
    final rows = await (select(itemTags)..where((t) => t.tagId.equals(tagId))).get();
    return rows.map((r) => r.itemId).toSet().toList();
  }

  Future<int> countItemsByTag(int tagId) async {
    final ids = await getItemIdsByTag(tagId);
    return ids.length;
  }

  // --------------------------------------------------
  // INSERT
  // --------------------------------------------------

  Future<int> insertSharedData({
    String? text,
    String? title,
    String? link,
  }) async {
    final now = DateTime.now();

    final id = await into(items).insert(
      ItemsCompanion.insert(
        title: title ?? _deriveTitle(text ?? link),
        content: Value(text),
        link: Value(link),
        updatedAt: Value(now),
      ),
    );

    return id;
  }

  // --------------------------------------------------
  // ATTACHMENTS
  // --------------------------------------------------

  Future<void> addAttachments({
    required int itemId,
    required List<AttachmentFile> files,
  }) async {
    if (files.isEmpty) return;

    final rows = <AttachmentsCompanion>[];
    for (final f in files) {
      final savedPath = await _copyIntoAttachmentsDir(f.path);
      rows.add(
        AttachmentsCompanion.insert(
          itemId: itemId,
          path: savedPath,
          mimeType: Value(f.mimeType),
        ),
      );
    }

    await batch((b) {
      b.insertAll(attachments, rows);
    });
  }

  Future<List<Attachment>> getAttachmentsForItem(int itemId) {
    return (select(attachments)
          ..where((t) => t.itemId.equals(itemId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  Future<String> _copyIntoAttachmentsDir(String source) async {
    final dir = await getApplicationDocumentsDirectory();
    final attachmentsDir = Directory(p.join(dir.path, 'attachments'));
    if (!attachmentsDir.existsSync()) {
      attachmentsDir.createSync(recursive: true);
    }
    final ext = p.extension(source);
    final fileName = '${DateTime.now().microsecondsSinceEpoch}$ext';
    final destPath = p.join(attachmentsDir.path, fileName);

    final srcFile = File(source);
    final destFile = File(destPath);
    await srcFile.copy(destFile.path);
    return destFile.path;
  }

  // --------------------------------------------------
  // TAGS
  // --------------------------------------------------

  Future<List<Tag>> getAllTags() => select(tags).get();

  Stream<List<Tag>> watchAllTags() {
    final q = select(tags)..orderBy([(t) => OrderingTerm.asc(t.name)]);
    return q.watch();
  }

  Stream<List<Tag>> watchTagsForItem(int itemId) {
    return customSelect(
      '''
      SELECT tags.*
      FROM tags
      JOIN item_tags ON item_tags.tag_id = tags.id
      WHERE item_tags.item_id = ?
      ORDER BY tags.name
      ''',
      variables: [Variable.withInt(itemId)],
      readsFrom: {tags, itemTags},
    ).watch().asyncMap((rows) async {
      return Future.wait(rows.map(tags.mapFromRow));
    });
  }

  Future<List<Tag>> getTagsForItem(int itemId) async {
    final result = await customSelect(
      '''
      SELECT tags.*
      FROM tags
      JOIN item_tags ON item_tags.tag_id = tags.id
      WHERE item_tags.item_id = ?
      ORDER BY tags.name
      ''',
      variables: [Variable.withInt(itemId)],
      readsFrom: {tags, itemTags},
    ).get();
    return Future.wait(result.map(tags.mapFromRow));
  }

  Future<void> attachTag({
    required int itemId,
    required int tagId,
  }) {
    return into(itemTags).insert(
      ItemTagsCompanion.insert(itemId: itemId, tagId: tagId),
      mode: InsertMode.insertOrIgnore,
    );
  }

  Future<void> detachTag({
    required int itemId,
    required int tagId,
  }) async {
    await (delete(itemTags)
          ..where((t) => t.itemId.equals(itemId) & t.tagId.equals(tagId)))
        .go();
  }

  Future<Tag?> getTagByName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;
    return (select(tags)..where((t) => t.name.equals(trimmed))).getSingleOrNull();
  }

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
      final fallback = await getTagByName(trimmed);
      if (fallback != null) return fallback;
      rethrow;
    }
  }

  Future<void> deleteTagById(int tagId) async {
    await transaction(() async {
      await (delete(itemTags)..where((t) => t.tagId.equals(tagId))).go();
      await (delete(tags)..where((t) => t.id.equals(tagId))).go();
    });
  }

  // --------------------------------------------------
  // AUTO-DELETE SCHEDULES (per item)
  // --------------------------------------------------

  int _nowMs() => DateTime.now().millisecondsSinceEpoch;

  Future<Schedule?> getAutoDeleteScheduleForItem(int itemId) async {
    return (select(schedules)
          ..where((s) =>
              s.itemId.equals(itemId.toString()) &
              s.type.equals('auto_delete')))
        .getSingleOrNull();
  }

  Future<void> setAutoDeleteSchedule({
    required int itemId,
    required Duration after,
  }) async {
    final next = _nowMs() + after.inMilliseconds;

    await (delete(schedules)
          ..where((s) =>
              s.itemId.equals(itemId.toString()) &
              s.type.equals('auto_delete')))
        .go();

    final id = 'del_${itemId}_${DateTime.now().microsecondsSinceEpoch}';
    await into(schedules).insert(
      SchedulesCompanion.insert(
        id: id,
        itemId: itemId.toString(),
        type: 'auto_delete',
        nextFire: const Value.absent(),
        createdAt: _nowMs(),
      ),
    );

    await (update(schedules)..where((s) => s.id.equals(id))).write(
      SchedulesCompanion(nextFire: Value(next)),
    );
  }

  Future<void> clearAutoDeleteSchedule(int itemId) async {
    await (delete(schedules)
          ..where((s) =>
              s.itemId.equals(itemId.toString()) &
              s.type.equals('auto_delete')))
        .go();
  }

  Future<int> pruneDueAutoDeletes() async {
    final now = _nowMs();
    final due = await (select(schedules)
          ..where((s) =>
              s.type.equals('auto_delete') &
              s.nextFire.isNotNull() &
              s.nextFire.isSmallerOrEqualValue(now)))
        .get();

    if (due.isEmpty) return 0;

    await transaction(() async {
      for (final sch in due) {
        final itemId = int.tryParse(sch.itemId);
        if (itemId != null) {
          await deleteItemById(itemId);
        }
        await (delete(schedules)..where((s) => s.id.equals(sch.id))).go();
      }
    });

    return due.length;
  }

  // --------------------------------------------------
  // DELETE
  // --------------------------------------------------

  Future<void> deleteItemById(int id) async {
    await transaction(() async {
      await (delete(schedules)..where((s) => s.itemId.equals(id.toString()))).go();

      await (delete(itemTags)..where((t) => t.itemId.equals(id))).go();
      await (delete(attachments)..where((t) => t.itemId.equals(id))).go();
      await (delete(items)..where((t) => t.id.equals(id))).go();
    });
  }

  Future<void> deleteItemsByIds(Iterable<int> ids) async {
    final idList = ids.toList();
    if (idList.isEmpty) return;

    await transaction(() async {
      final sidList = idList.map((e) => e.toString()).toList();
      await (delete(schedules)..where((s) => s.itemId.isIn(sidList))).go();

      await (delete(itemTags)..where((t) => t.itemId.isIn(idList))).go();
      await (delete(attachments)..where((t) => t.itemId.isIn(idList))).go();
      await (delete(items)..where((t) => t.id.isIn(idList))).go();
    });
  }

  // --------------------------------------------------
  // SEARCH + FILTER
  // --------------------------------------------------

  Future<List<Item>> getRecentItems({int limit = 50}) {
    final q = select(items)
      ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
      ..limit(limit);
    return q.get();
  }

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

  Future<List<Item>> searchItems(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return getRecentItems();
    }

    final fts = _ftsPrefixQuery(trimmed);

    final result = await customSelect(
      '''
      SELECT items.*
      FROM items
      JOIN items_fts ON items_fts.rowid = items.id
      WHERE items_fts MATCH ?
      ORDER BY bm25(items_fts)
      ''',
      variables: [Variable.withString(fts)],
      readsFrom: {items},
    ).get();

    if (result.isNotEmpty) {
      return Future.wait(result.map(items.mapFromRow));
    }

    debugPrint('FTS returned no results, falling back to LIKE for "$trimmed"');
    final like = '%$trimmed%';
    final q = select(items)
      ..where((t) =>
          t.title.like(like) |
          t.content.like(like) |
          t.link.like(like))
      ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
    return q.get();
  }

  Future<List<Item>> searchItemsWithTag({
    required String query,
    required int? tagId,
  }) async {
    if (tagId == null) return searchItems(query);

    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return getItemsByTag(tagId);
    }

    final fts = _ftsPrefixQuery(trimmed);

    final result = await customSelect(
      '''
      SELECT DISTINCT items.*
      FROM items
      JOIN items_fts ON items_fts.rowid = items.id
      JOIN item_tags ON item_tags.item_id = items.id
      WHERE item_tags.tag_id = ?
        AND items_fts MATCH ?
      ORDER BY bm25(items_fts)
      ''',
      variables: [
        Variable.withInt(tagId),
        Variable.withString(fts),
      ],
      readsFrom: {items, itemTags},
    ).get();

    if (result.isNotEmpty) {
      return Future.wait(result.map(items.mapFromRow));
    }

    debugPrint('FTS tag search returned no results, fallback LIKE for "$trimmed"');
    final like = '%$trimmed%';
    final result2 = await customSelect(
      '''
      SELECT items.*
      FROM items
      JOIN item_tags ON item_tags.item_id = items.id
      WHERE item_tags.tag_id = ?
        AND (
          items.title LIKE ? OR
          items.content LIKE ? OR
          items.link LIKE ?
        )
      ORDER BY items.updated_at DESC
      ''',
      variables: [
        Variable.withInt(tagId),
        Variable.withString(like),
        Variable.withString(like),
        Variable.withString(like),
      ],
      readsFrom: {items, itemTags},
    ).get();

    return Future.wait(result2.map(items.mapFromRow));
  }

  Future<List<Item>> searchItemsPaged({
    required String query,
    int? tagId,
    required int limit,
    required int offset,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    final fts = _ftsPrefixQuery(trimmed);

    final sql = StringBuffer('''
      SELECT DISTINCT items.*
      FROM items
      JOIN items_fts ON items_fts.rowid = items.id
    ''');

    final vars = <Variable>[];

    if (tagId != null) {
      sql.write('JOIN item_tags ON item_tags.item_id = items.id ');
    }

    sql.write('WHERE items_fts MATCH ? ');
    vars.add(Variable.withString(fts));

    if (tagId != null) {
      sql.write('AND item_tags.tag_id = ? ');
      vars.add(Variable.withInt(tagId));
    }

    sql.write('ORDER BY bm25(items_fts) LIMIT ? OFFSET ?');
    vars.add(Variable.withInt(limit));
    vars.add(Variable.withInt(offset));

    try {
      final result = await customSelect(
        sql.toString(),
        variables: vars,
        readsFrom: {items, if (tagId != null) itemTags},
      ).get();

      if (result.isNotEmpty) {
        return Future.wait(result.map(items.mapFromRow));
      }
    } catch (e) {
      debugPrint('FTS paged search failed: $e');
    }

    final like = '%$trimmed%';
    if (tagId == null) {
      final result = await customSelect(
        '''
        SELECT items.*
        FROM items
        WHERE items.title LIKE ? OR items.content LIKE ? OR items.link LIKE ?
        ORDER BY items.updated_at DESC
        LIMIT ? OFFSET ?
        ''',
        variables: [
          Variable.withString(like),
          Variable.withString(like),
          Variable.withString(like),
          Variable.withInt(limit),
          Variable.withInt(offset),
        ],
        readsFrom: {items},
      ).get();
      return Future.wait(result.map(items.mapFromRow));
    } else {
      final result = await customSelect(
        '''
        SELECT items.*
        FROM items
        JOIN item_tags ON item_tags.item_id = items.id
        WHERE item_tags.tag_id = ?
          AND (items.title LIKE ? OR items.content LIKE ? OR items.link LIKE ?)
        ORDER BY items.updated_at DESC
        LIMIT ? OFFSET ?
        ''',
        variables: [
          Variable.withInt(tagId),
          Variable.withString(like),
          Variable.withString(like),
          Variable.withString(like),
          Variable.withInt(limit),
          Variable.withInt(offset),
        ],
        readsFrom: {items, itemTags},
      ).get();
      return Future.wait(result.map(items.mapFromRow));
    }
  }

  // --------------------------------------------------
  // UTIL
  // --------------------------------------------------

  Future<List<Item>> getAllItems() {
    return (select(items)..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])).get();
  }

  // --------------------------------------------------
  // APP SETTINGS: Donation flag (Properties table)
  // --------------------------------------------------

  static const _appItemId = 'app';
  static const _donatedKey = 'donated_eur';

  Future<void> _setAppProperty({
    required String name,
    required String value,
    String type = 'string',
  }) async {
    // Primary key is (itemId, name). Use insertOrReplace to upsert.
    await into(properties).insert(
      PropertiesCompanion.insert(
        itemId: _appItemId,
        name: name,
        value: Value(value),
        type: Value(type),
      ),
      mode: InsertMode.insertOrReplace,
    );
  }

  Future<String?> _getAppProperty(String name) async {
    final row = await (select(properties)
          ..where((p) => p.itemId.equals(_appItemId) & p.name.equals(name))
          ..limit(1))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> _clearAppProperty(String name) async {
    await (delete(properties)
          ..where((p) => p.itemId.equals(_appItemId) & p.name.equals(name)))
        .go();
  }

  /// Set a donation amount (EUR). Pass null to clear.
  Future<void> setDonatedAmount(int? eur) async {
    if (eur == null) {
      await _clearAppProperty(_donatedKey);
      return;
    }
    await _setAppProperty(name: _donatedKey, value: eur.toString(), type: 'int');
  }

  /// Get the stored donation amount (EUR), or null if none set.
  Future<int?> getDonatedAmount() async {
    final v = await _getAppProperty(_donatedKey);
    if (v == null) return null;
    return int.tryParse(v);
  }
}
