// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Markus Kreidl

import 'package:flutter/material.dart';
import '../../data/drift/database.dart';

class TagManagerScreen extends StatefulWidget {
  final AppDatabase database;

  const TagManagerScreen({super.key, required this.database});

  @override
  State<TagManagerScreen> createState() => _TagManagerScreenState();
}

class _TagManagerScreenState extends State<TagManagerScreen> {
  late Future<List<Tag>> _futureTags;
  final _controller = TextEditingController();
  bool _working = false;

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

  Future<void> _addTag() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    setState(() => _working = true);
    try {
      await widget.database.upsertTagByName(name);
      _controller.clear();
      await _reload();
    } finally {
      setState(() => _working = false);
    }
  }

  Future<void> _deleteTag(int id) async {
    setState(() => _working = true);
    try {
      await widget.database.deleteTagById(id);
      await _reload();
    } finally {
      setState(() => _working = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tags'),
        actions: [
          IconButton(
            tooltip: 'Reload',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      labelText: 'New tag',
                      border: OutlineInputBorder(),
                    ),
                    enabled: !_working,
                    onSubmitted: (_) => _addTag(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _working ? null : _addTag,
                  child: const Text('Add'),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Tag>>(
              future: _futureTags,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final tags = snap.data ?? const <Tag>[];
                if (tags.isEmpty) {
                  return const Center(child: Text('No tags yet'));
                }
                return ListView.separated(
                  itemCount: tags.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final t = tags[i];
                    return ListTile(
                      leading: const Icon(Icons.label),
                      title: Text(t.name),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: _working ? null : () => _deleteTag(t.id),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
