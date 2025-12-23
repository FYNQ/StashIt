import 'dart:io';
import 'package:flutter/material.dart';
import '../../data/drift/database.dart';
import 'add_item_controller.dart';

class AddItemScreen extends StatefulWidget {
  final AppDatabase database;
  final String? sharedText; // optional
  final List<AttachmentFile> attachments; // new

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

  @override
  void initState() {
    super.initState();
    controller = AddItemController(widget.database)
      ..link = widget.sharedText
      ..attachments = List<AttachmentFile>.from(widget.attachments);
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
