import 'package:drift/drift.dart';

class ItemsFts extends Table {
  TextColumn get title => text()();
  TextColumn get content => text()();

  @override
  Set<Column> get primaryKey => {};

  @override
  bool get withoutRowId => true;

  @override
  String get tableName => 'items_fts';
}

