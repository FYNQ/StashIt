import 'package:drift/drift.dart';

class Embeddings extends Table {
  TextColumn get itemId => text()();
  TextColumn get model => text()();
  IntColumn get dims => integer()();
  BlobColumn get vector => blob()();

  @override
  Set<Column> get primaryKey => {itemId};
}

