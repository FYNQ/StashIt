import 'package:flutter/material.dart';
import 'search_controller.dart';
import '../../data/drift/database.dart';
import '../add_item/item_detail_screen.dart';
import 'tag_filter_bar.dart';
import '../tags/tag_manager_screen.dart';

class SearchScreen extends StatefulWidget {
  final ItemSearchController controller;

  const SearchScreen({
    super.key,
    required this.controller,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(
      text: widget.controller.query,
    );
    widget.controller.addListener(_syncText);
  }

  void _syncText() {
    final query = widget.controller.query;
    if (_textController.text != query) {
      _textController.text = query;
      _textController.selection = TextSelection.fromPosition(
        TextPosition(offset: query.length),
      );
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncText);
    _textController.dispose();
    super.dispose();
  }

  Future<bool> _confirmDeleteItem(String title) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete item?'),
            content: Text('This will delete: "$title"'),
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
  }

  Future<void> _deleteAllForSelectedTag(AppDatabase db) async {
    final tagId = widget.controller.tagId;
    if (tagId == null) return;

    final count = await db.countItemsByTag(tagId);
    if (count == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No items under this tag')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete all items under this tag?'),
            content: Text('This will permanently delete $count item(s).'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete all'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    final deleted = await widget.controller.deleteAllForCurrentTag();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Deleted $deleted item(s)')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = widget.controller.db;

    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final hasTagFilter = widget.controller.tagId != null;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Search'),
            actions: [
              if (hasTagFilter)
                IconButton(
                  tooltip: 'Delete all in this tag',
                  onPressed: () => _deleteAllForSelectedTag(db),
                  icon: const Icon(Icons.delete_sweep_outlined),
                ),
              IconButton(
                tooltip: 'Manage tags',
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TagManagerScreen(database: db),
                    ),
                  );
                  setState(() {});
                },
                icon: const Icon(Icons.label),
              ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: _textController,
                  onChanged: widget.controller.updateQuery,
                  decoration: const InputDecoration(
                    hintText: 'Search…',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),

              // Tag filter bar
              TagFilterBar(database: db, controller: widget.controller),
              const SizedBox(height: 8),

              if (widget.controller.isLoading)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),

              Expanded(
                child: ListView.builder(
                  itemCount: widget.controller.results.length,
                  itemBuilder: (context, index) {
                    final item = widget.controller.results[index];
                    return Dismissible(
                      key: ValueKey(item.id),
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.only(left: 16),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      secondaryBackground: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 16),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      confirmDismiss: (_) async =>
                          await _confirmDeleteItem(item.title),
                      onDismissed: (_) async {
                        await widget.controller.deleteItem(item.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Item deleted')),
                        );
                      },
                      child: ListTile(
                        title: Text(item.title),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            final ok = await _confirmDeleteItem(item.title);
                            if (ok) {
                              await widget.controller.deleteItem(item.id);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Item deleted')),
                                );
                              }
                            }
                          },
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ItemDetailScreen(
                                item: item,
                                database: widget.controller.db,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
