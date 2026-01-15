// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Markus Kreidl

import 'package:flutter/material.dart';
import '../../data/drift/database.dart';
import 'search_controller.dart';

class TagFilterBar extends StatelessWidget {
  final AppDatabase database;
  final ItemSearchController controller;

  const TagFilterBar({
    super.key,
    required this.database,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final selectedId = controller.tagId;

    return StreamBuilder<List<Tag>>(
      stream: database.watchAllTags(),
      builder: (context, snap) {
        final tags = snap.data ?? const <Tag>[];

        if (snap.connectionState == ConnectionState.waiting && tags.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: LinearProgressIndicator(),
          );
        }

        if (tags.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text('No tags yet'),
          );
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              ChoiceChip(
                label: const Text('All'),
                selected: selectedId == null,
                onSelected: (v) => controller.updateTag(null),
              ),
              const SizedBox(width: 8),
              ...tags.map((t) {
                final sel = selectedId == t.id;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(t.name),
                    selected: sel,
                    onSelected: (_) => controller.updateTag(sel ? null : t.id),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}
