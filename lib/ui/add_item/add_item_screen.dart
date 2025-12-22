import 'package:flutter/material.dart';
import '../../data/drift/database.dart';
import 'add_item_controller.dart';

class AddItemScreen extends StatefulWidget {
  final AppDatabase database;
  final String sharedText;

  const AddItemScreen({
    super.key,
    required this.database,
    required this.sharedText,
  });

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  late final AddItemController controller;

  @override
  void initState() {
    super.initState();
    controller = AddItemController(widget.database)
      ..link = widget.sharedText
      ..init(); // <- load tags
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Add item'),
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Link (read-only)
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

                // Title input
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Title',
                  ),
                  onChanged: (v) => controller.title = v,
                ),
                const SizedBox(height: 16),

                // Tags section
                const Text('Tags', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),

                // Existing tags as chips
                if (controller.allTags.isEmpty)
                  const Text('No tags yet. Create one below 👇')
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: -8,
                    children: controller.allTags.map((tag) {
                      final selected = controller.selectedTagIds.contains(tag.id);
                      return FilterChip(
                        label: Text(tag.name),
                        selected: selected,
                        onSelected: (_) => controller.toggleTag(tag.id),
                      );
                    }).toList(),
                  ),

                const SizedBox(height: 12),

                // Create new tag
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: (v) => controller.newTagName = v,
                        decoration: const InputDecoration(
                          hintText: 'New tag name',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: controller.newTagName.trim().isEmpty
                          ? null
                          : () async {
                              await controller.addNewTag();
                            },
                      icon: const Icon(Icons.add),
                      label: const Text('Add tag'),
                    ),
                  ],
                ),

                const Spacer(),

                // Save button
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
