// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Markus Kreidl

import 'package:drift/drift.dart';

class Embeddings extends Table {
  TextColumn get itemId => text()();
  TextColumn get model => text()();
  IntColumn get dims => integer()();
  BlobColumn get vector => blob()();

  @override
  Set<Column> get primaryKey => {itemId};
}

