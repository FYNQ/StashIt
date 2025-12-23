import 'package:flutter/material.dart';
import '../../data/drift/database.dart';

class SearchTile extends StatelessWidget {
  final Item item;

  const SearchTile({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final title = item.title; // non-nullable
    final content = item.content ?? '';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        title: Text(title),
        subtitle: Text(
          content,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
