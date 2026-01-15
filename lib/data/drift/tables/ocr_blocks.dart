// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Markus Kreidl

import 'package:drift/drift.dart';

class OcrBlocks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get itemId => text()();

  TextColumn get content => text()();

  RealColumn get x => real().nullable()();
  RealColumn get y => real().nullable()();
  RealColumn get w => real().nullable()();
  RealColumn get h => real().nullable()();
}
