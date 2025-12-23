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

  @override
  void initState() {
    super.initState();
    _futureAttachments = widget.database.getAttachmentsForItem(widget.item.id);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return Scaffold(
      appBar: AppBar(
        title: Text(item.title),
      ),
      body: FutureBuilder<List<Attachment>>(
        future: _futureAttachments,
        builder: (context, snap) {
          final attachments = snap.data ?? const [];

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

                if (snap.connectionState == ConnectionState.waiting)
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
