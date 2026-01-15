// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Markus Kreidl

import 'package:drift/drift.dart';

class Schedules extends Table {
  TextColumn get id => text()();
  TextColumn get itemId => text()();
  TextColumn get type => text()(); // alarm, notify, calendar
  TextColumn get rule => text().nullable()();
  IntColumn get nextFire => integer().nullable()();
  TextColumn get androidId => text().nullable()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

