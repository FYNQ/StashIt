// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Markus Kreidl

import 'package:drift/drift.dart';

class Properties extends Table {
  TextColumn get itemId => text()();
  TextColumn get name => text()();
  TextColumn get value => text().nullable()();
  TextColumn get type => text().withDefault(Constant('string'))();

  @override
  Set<Column> get primaryKey => {itemId, name};
}

