import 'package:flutter/material.dart';
import 'search_controller.dart';
import '../../data/drift/database.dart';
import '../add_item/item_detail_screen.dart';

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

  // Tags data
  List<Tag> _tags = [];
  bool _loadingTags = true;

  // Selection mode
  bool _selectionMode = false;
  final Set<int> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.controller.query);

    // Keep text field in sync with controller
    widget.controller.addListener(_syncText);

    // Load tags once
    _loadTags();

    // Kick initial search to show recent items on first load
    widget.controller.updateQuery(widget.controller.query);
  }

  Future<void> _loadTags() async {
    setState(() => _loadingTags = true);
    try {
      _tags = await widget.controller.db.getAllTags();
    } finally {
      if (mounted) setState(() => _loadingTags = false);
    }
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

  // ----------------------------
  // Selection helpers
  // ----------------------------
  void _enterSelectionMode(int id) {
    setState(() {
      _selectionMode = true;
      _selectedIds
        ..clear()
        ..add(id);
    });
  }

  void _toggleSelect(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _selectionMode = false;
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectedIds
        ..clear()
        ..addAll(widget.controller.results.map((e) => e.id));
      _selectionMode = _selectedIds.isNotEmpty;
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedIds.clear();
      _selectionMode = false;
    });
  }

  // ----------------------------
  // Delete helpers
  // ----------------------------
  Future<void> _confirmDeleteOne(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete item'),
        content: const Text('Are you sure you want to delete this item?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      await widget.controller.deleteItem(id);
      if (mounted) _clearSelection();
    }
  }

  Future<void> _confirmDeleteMany() async {
    if (_selectedIds.isEmpty) return;
    final count = _selectedIds.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete items'),
        content: Text('Delete $count selected item(s)? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      final ids = Set<int>.from(_selectedIds);
      await widget.controller.deleteItems(ids);
      if (mounted) _clearSelection();
    }
  }

  // ----------------------------
  // Tag chip helpers
  // ----------------------------
  Widget _buildTagChips() {
    if (_loadingTags) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(minHeight: 2),
      );
    }

    final currentTagId = widget.controller.tagId;

    final chips = <Widget>[
      ChoiceChip(
        label: const Text('All'),
        selected: currentTagId == null,
        onSelected: (_) => widget.controller.updateTag(null),
      ),
      ..._tags.map((t) {
        final selected = currentTagId == t.id;
        return ChoiceChip(
          label: Text(t.name),
          selected: selected,
          onSelected: (_) => widget.controller.updateTag(selected ? null : t.id),
        );
      }),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          for (final chip in chips) Padding(
            padding: const EdgeInsets.only(right: 8),
            child: chip,
          ),
        ],
      ),
    );
  }

  // ----------------------------
  // AppBar (normal vs selection)
  // ----------------------------
  PreferredSizeWidget _buildAppBar() {
    if (_selectionMode) {
      return AppBar(
        title: Text('${_selectedIds.length} selected'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _clearSelection,
          tooltip: 'Cancel selection',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.select_all),
            onPressed: _selectAll,
            tooltip: 'Select all',
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _confirmDeleteMany,
            tooltip: 'Delete selected',
          ),
        ],
      );
    }

    return AppBar(
      title: const Text('Search'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final items = widget.controller.results;

        return Scaffold(
          appBar: _buildAppBar(),
          body: Column(
            children: [
              // Search box
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: _textController,
                  onChanged: widget.controller.updateQuery,
                  decoration: const InputDecoration(
                    hintText: 'Search…',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),

              // Tags row
              _buildTagChips(),

              if (widget.controller.isLoading)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),

              Expanded(
                child: ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final selected = _selectedIds.contains(item.id);

                    return ListTile(
                      leading: _selectionMode
                          ? Checkbox(
                              value: selected,
                              onChanged: (_) => _toggleSelect(item.id),
                            )
                          : null,
                      title: Text(item.title),
                      subtitle: item.content?.isNotEmpty == true
                          ? Text(
                              item.content!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            )
                          : null,
                      onTap: () {
                        if (_selectionMode) {
                          _toggleSelect(item.id);
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ItemDetailScreen(item: item),
                            ),
                          );
                        }
                      },
                      onLongPress: () => _enterSelectionMode(item.id),
                      trailing: !_selectionMode
                          ? IconButton(
                              icon: const Icon(Icons.delete_outline),
                              tooltip: 'Delete',
                              onPressed: () => _confirmDeleteOne(item.id),
                            )
                          : null,
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
