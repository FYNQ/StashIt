import 'package:drift/drift.dart';

class ItemTags extends Table {
  TextColumn get itemId => text()();
  IntColumn get tagId => integer()();

  @override
  Set<Column> get primaryKey => {itemId, tagId};
}

