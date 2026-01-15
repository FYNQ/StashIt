// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Markus Kreidl

import 'package:drift/drift.dart';
import 'items.dart';

class Attachments extends Table {
  IntColumn get id => integer().autoIncrement()();

  // Link to an Item
  IntColumn get itemId => integer().references(Items, #id)();

  // Absolute file path saved into app's storage
  TextColumn get path => text()();

  // Optional MIME type, e.g. image/png
  TextColumn get mimeType => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
