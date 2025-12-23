import 'dart:io';
import 'package:flutter/material.dart';
import '../../data/drift/database.dart';
import 'add_item_controller.dart';

class AddItemScreen extends StatefulWidget {
  final AppDatabase database;
  final String? sharedText;
  final List<AttachmentFile> attachments;

  const AddItemScreen({
    super.key,
    required this.database,
    this.sharedText,
    this.attachments = const [],
  });

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  late final AddItemController controller;
  late Future<List<Tag>> _futureTags;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    controller = AddItemController(widget.database)
      ..link = widget.sharedText
      ..attachments = List<AttachmentFile>.from(widget.attachments);
    _futureTags = widget.database.getAllTags();
  }

  Future<void> _reloadTags() async {
    setState(() {
      _futureTags = widget.database.getAllTags();
    });
  }

  Future<void> _createTagInline() async {
    final textCtrl = TextEditingController();

    final name = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Create new tag'),
          content: TextField(
            controller: textCtrl,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'e.g. recipes, work, personal',
            ),
            onSubmitted: (_) => Navigator.pop(ctx, textCtrl.text.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, textCtrl.text.trim()),
              child: const Text('Create'),
            ),
          ],
        );
      },
    );

    if (name == null || name.isEmpty) return;

    setState(() => _working = true);
    try {
      final tag = await widget.database.upsertTagByName(name);
      controller.tagIds.add(tag.id); // auto-select the new tag
      await _reloadTags();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create tag: $e')),
      );
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final hasLink = (controller.link ?? '').trim().isNotEmpty;
        final hasAttachments = controller.attachments.isNotEmpty;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Add item'),
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasLink) ...[
                  TextField(
                    enabled: false,
                    controller: TextEditingController(
                      text: controller.link ?? '',
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Link',
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Title',
                  ),
                  onChanged: (v) => controller.title = v,
                ),

                const SizedBox(height: 12),

                // Tags section (select existing + create new)
                Row(
                  children: [
                    const Text(
                      'Tags',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    if (_working)
                      const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _working ? null : _createTagInline,
                      icon: const Icon(Icons.add),
                      label: const Text('New tag'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                FutureBuilder<List<Tag>>(
                  future: _futureTags,
                  builder: (context, snap) {
                    final tags = snap.data ?? const <Tag>[];
                    if (snap.connectionState == ConnectionState.waiting &&
                        tags.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: LinearProgressIndicator(),
                      );
                    }
                    if (tags.isEmpty) {
                      return const Text(
                        'No tags yet. Create one with "New tag".',
                        style: TextStyle(color: Colors.black54),
                      );
                    }
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: tags.map((t) {
                        final selected = controller.tagIds.contains(t.id);
                        return FilterChip(
                          label: Text(t.name),
                          selected: selected,
                          onSelected: (v) {
                            setState(() {
                              if (v) {
                                controller.tagIds.add(t.id);
                              } else {
                                controller.tagIds.remove(t.id);
                              }
                            });
                          },
                        );
                      }).toList(),
                    );
                  },
                ),

                const SizedBox(height: 12),

                if (hasAttachments) ...[
                  const Text('Attachments', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 160,
                    child: GridView.builder(
                      scrollDirection: Axis.horizontal,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 1,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 1.2,
                      ),
                      itemCount: controller.attachments.length,
                      itemBuilder: (_, i) {
                        final a = controller.attachments[i];
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
                  ),
                ],

                const Spacer(),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: controller.isSaving
                        ? null
                        : () async {
                            await controller.save();
                            if (mounted) Navigator.pop(context);
                          },
                    child: controller.isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
