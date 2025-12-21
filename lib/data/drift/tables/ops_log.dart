import 'package:drift/drift.dart';

class OpsLog extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get entity => text()();
  TextColumn get entityId => text()();
  TextColumn get operation => text()(); // insert, update, delete
  TextColumn get payload => text().nullable()();
  IntColumn get ts => integer()();
}

