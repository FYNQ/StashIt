import 'package:flutter/material.dart';
import '../../data/drift/database.dart';
import 'search_controller.dart';

class TagFilterBar extends StatefulWidget {
  final AppDatabase database;
  final ItemSearchController controller;

  const TagFilterBar({
    super.key,
    required this.database,
    required this.controller,
  });

  @override
  State<TagFilterBar> createState() => _TagFilterBarState();
}

class _TagFilterBarState extends State<TagFilterBar> {
  late Future<List<Tag>> _futureTags;

  @override
  void initState() {
    super.initState();
    _futureTags = widget.database.getAllTags();
  }

  Future<void> _reload() async {
    setState(() {
      _futureTags = widget.database.getAllTags();
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedId = widget.controller.tagId;

    return FutureBuilder<List<Tag>>(
      future: _futureTags,
      builder: (context, snap) {
        final tags = snap.data ?? const <Tag>[];
        if (tags.isEmpty) {
          return Row(
            children: [
              const SizedBox(width: 12),
              const Text('No tags yet'),
              TextButton(
                onPressed: _reload,
                child: const Text('Refresh'),
              ),
            ],
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
                onSelected: (v) => widget.controller.updateTag(null),
              ),
              const SizedBox(width: 8),
              ...tags.map((t) {
                final sel = selectedId == t.id;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(t.name),
                    selected: sel,
                    onSelected: (_) => widget.controller.updateTag(sel ? null : t.id),
                  ),
                );
              }),
              IconButton(
                tooltip: 'Reload tags',
                onPressed: _reload,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        );
      },
    );
  }
}
