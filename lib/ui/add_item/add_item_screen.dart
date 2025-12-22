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
      ..init(); // <- Load existing tags
  }

Future<void> _openTagPicker() async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      String query = '';
      bool creating = false;
      final localSelected = Set<int>.from(controller.selectedTagIds);

      List<Tag> current() {
        if (query.trim().isEmpty) return controller.allTags;
        final q = query.toLowerCase();
        return controller.allTags
            .where((t) => t.name.toLowerCase().contains(q))
            .toList();
      }

      bool exactExists() {
        final q = query.trim().toLowerCase();
        if (q.isEmpty) return true;
        return controller.allTags.any(
          (t) => t.name.toLowerCase() == q,
        );
      }

      return StatefulBuilder(
        builder: (context, setState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              top: 12,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 12),

                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Select tags',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 12),

                // Search
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search or create…',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => query = v),
                ),
                const SizedBox(height: 12),

                // Create row appears if there's a non-empty query with no exact match
                if (query.trim().isNotEmpty && !exactExists())
                  ListTile(
                    leading: creating
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add),
                    title: Text("Create '$query'"),
                    onTap: creating
                        ? null
                        : () async {
                            setState(() => creating = true);
                            try {
                              final tag = await controller.createAndSelectTag(query);
                              // Ensure it's selected locally too
                              localSelected.add(tag.id);
                              // Clear query so list shows full set again
                              setState(() {
                                query = '';
                              });
                            } finally {
                              setState(() => creating = false);
                            }
                          },
                  ),

                // List existing/matching tags
                Flexible(
                  child: current().isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(24.0),
                          child: Text('No matching tags'),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: current().length,
                          itemBuilder: (_, i) {
                            final tag = current()[i];
                            final checked = localSelected.contains(tag.id);
                            return CheckboxListTile(
                              value: checked,
                              onChanged: (_) {
                                setState(() {
                                  if (checked) {
                                    localSelected.remove(tag.id);
                                  } else {
                                    localSelected.add(tag.id);
                                  }
                                });
                              },
                              title: Text(tag.name),
                            );
                          },
                        ),
                ),

                // Actions
                Row(
                  children: [
                    TextButton(
                      onPressed: () => setState(localSelected.clear),
                      child: const Text('Clear'),
                    ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: () {
                        controller.setSelectedTags(localSelected);
                        Navigator.pop(context);
                      },
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
    },
  );
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

                // Selected tag chips
                if (controller.selectedTagIds.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: -8,
                    children: controller.selectedTagIds.map((id) {
                      final tag = controller.tagById(id);
                      if (tag == null) return const SizedBox.shrink();
                      return InputChip(
                        label: Text(tag.name),
                        onDeleted: () => controller.toggleTag(id),
                      );
                    }).toList(),
                  )
                else
                  const Text('No tags selected'),

                const SizedBox(height: 12),

                // + Add tag button (opens picker)
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add tag'),
                    onPressed: _openTagPicker,
                  ),
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
