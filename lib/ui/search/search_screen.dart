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

  @override
  Widget build(BuildContext context) {
    final db = widget.controller.db;

    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Search'),
            actions: [
              IconButton(
                tooltip: 'Manage tags',
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TagManagerScreen(database: db),
                    ),
                  );
                  // Optional: reload filter chips after returning
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
                    return ListTile(
                      title: Text(item.title),
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
