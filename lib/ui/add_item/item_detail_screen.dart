import 'dart:io';
import 'package:flutter/material.dart';
import '../../data/drift/database.dart';

class ItemDetailScreen extends StatefulWidget {
  final Item item;
  final AppDatabase database;

  const ItemDetailScreen({
    Key? key,
    required this.item,
    required this.database,
  }) : super(key: key);

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  late Future<List<Attachment>> _futureAttachments;
  late Future<List<Tag>> _futureTags;

  @override
  void initState() {
    super.initState();
    _futureAttachments = widget.database.getAttachmentsForItem(widget.item.id);
    _futureTags = widget.database.getTagsForItem(widget.item.id);
  }

  Future<void> _reloadTags() async {
    setState(() {
      _futureTags = widget.database.getTagsForItem(widget.item.id);
    });
  }

  Future<void> _detachTag(int tagId) async {
    await widget.database.detachTag(itemId: widget.item.id, tagId: tagId);
    await _reloadTags();
  }

  Future<void> _attachTagFlow() async {
    final allTags = await widget.database.getAllTags();
    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: allTags.length + 1,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              if (i == 0) {
                return ListTile(
                  leading: const Icon(Icons.add),
                  title: const Text('Create new tag'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _createTagAndAttach();
                  },
                );
              }
              final t = allTags[i - 1];
              return ListTile(
                leading: const Icon(Icons.label),
                title: Text(t.name),
                onTap: () async {
                  Navigator.pop(ctx);
                  await widget.database.attachTag(itemId: widget.item.id, tagId: t.id);
                  await _reloadTags();
                },
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _createTagAndAttach() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('New tag'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'e.g. recipes'),
            onSubmitted: (_) => Navigator.pop(ctx, controller.text.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
    if (name == null || name.trim().isEmpty) return;

    final tag = await widget.database.upsertTagByName(name.trim());
    await widget.database.attachTag(itemId: widget.item.id, tagId: tag.id);
    await _reloadTags();
  }

  Future<void> _deleteThisItem() async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete item?'),
            content: Text('This will permanently delete "${widget.item.title}".'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;

    if (!ok) return;
    await widget.database.deleteItemById(widget.item.id);
    if (mounted) Navigator.pop(context); // back to list
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return Scaffold(
      appBar: AppBar(
        title: Text(item.title),
        actions: [
          IconButton(
            tooltip: 'Attach tag',
            onPressed: _attachTagFlow,
            icon: const Icon(Icons.label_important_outline),
          ),
          IconButton(
            tooltip: 'Delete item',
            onPressed: _deleteThisItem,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: FutureBuilder<List<Attachment>>(
        future: _futureAttachments,
        builder: (context, snapA) {
          final attachments = snapA.data ?? const [];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Title: ${item.title}", style: const TextStyle(fontSize: 24)),
                const SizedBox(height: 8),
                Text("Content: ${item.content ?? 'No content available'}"),
                const SizedBox(height: 8),
                Text("Link: ${item.link ?? 'No link available'}"),
                const SizedBox(height: 8),
                Text("Created At: ${item.createdAt}"),
                const SizedBox(height: 8),
                Text("Updated At: ${item.updatedAt}"),
                const SizedBox(height: 16),

                // Tags section
                FutureBuilder<List<Tag>>(
                  future: _futureTags,
                  builder: (context, snapT) {
                    final tags = snapT.data ?? const <Tag>[];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('Tags', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            if (snapT.connectionState == ConnectionState.waiting)
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (tags.isEmpty)
                          const Text('No tags attached'),
                        if (tags.isNotEmpty)
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: tags.map((t) {
                              return InputChip(
                                label: Text(t.name),
                                onDeleted: () => _detachTag(t.id),
                              );
                            }).toList(),
                          ),
                        const SizedBox(height: 16),
                      ],
                    );
                  },
                ),

                if (snapA.connectionState == ConnectionState.waiting)
                  const Center(child: CircularProgressIndicator()),

                if (attachments.isNotEmpty) ...[
                  const Text('Attachments', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: attachments.length,
                    itemBuilder: (_, i) {
                      final a = attachments[i];
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(a.path),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const ColoredBox(
                            color: Colors.black12,
                            child: Center(child: Icon(Icons.image_not_supported)),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
