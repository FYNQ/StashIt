import 'package:flutter/material.dart';
import '../../data/drift/database.dart';

class ItemDetailScreen extends StatelessWidget {
  final Item item;

  const ItemDetailScreen({Key? key, required this.item}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(item.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Title: ${item.title}", style: TextStyle(fontSize: 24)),
            SizedBox(height: 8),
            Text("Content: ${item.content ?? 'No content available'}"),
            SizedBox(height: 8),
            Text("Link: ${item.link ?? 'No link available'}"),
            SizedBox(height: 8),
            Text("Created At: ${item.createdAt}"),
            SizedBox(height: 8),
            Text("Updated At: ${item.updatedAt}"),
          ],
        ),
      ),
    );
  }
}
