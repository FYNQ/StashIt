// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Markus Kreidl

import 'package:drift/drift.dart';
import 'items.dart';
import 'tags.dart';

class ItemTags extends Table {
  IntColumn get itemId =>
      integer().references(Items, #id)();

  IntColumn get tagId =>
      integer().references(Tags, #id)();

  @override
  Set<Column> get primaryKey => {itemId, tagId};
}

