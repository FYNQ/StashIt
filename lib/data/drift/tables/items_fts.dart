import 'package:drift/drift.dart';
import '../database.dart';

class ItemsFts extends Table {
  IntColumn get rowid => integer().autoIncrement()();
  TextColumn get content => text().nullable()();
}

