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
      ..link = widget.sharedText;
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
              children: [
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
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Title',
                  ),
                  onChanged: (v) => controller.title = v,
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    // tag picker later
                  },
                  child: const Text('Tags'),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: controller.isSaving
                      ? null
                      : () async {
                          await controller.save();
                          if (mounted) Navigator.pop(context);
                        },
                  child: controller.isSaving
                      ? const CircularProgressIndicator()
                      : const Text('Save'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

