import 'package:flutter/material.dart';
import 'search_controller.dart';
import '../../data/drift/database.dart';
import '../add_item/item_detail_screen.dart'; // ItemDetailScreen

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

    // Keep text field in sync with controller
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
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Search'),
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
                        // Navigate to detail screen with DB (for attachments)
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
