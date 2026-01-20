// SPDX-License-Identifier: Apache-2.0
import 'package:flutter/material.dart';
import 'search_controller.dart';
import '../../data/drift/database.dart';
import '../add_item/item_detail_screen.dart';
import 'tag_filter_bar.dart';
import '../tags/tag_manager_screen.dart';
import '../menu/app_drawer.dart';
import '../../util/cloud_share_service.dart';
import '../../util/cloud_pull_service.dart';

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
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  // Cloud services
  late final CloudShareService _svc;
  late final CloudPullService _pull;
  bool _cloudBusy = false;

  // Key to force TagFilterBar to rebuild (and refetch tags)
  Key _tagBarKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(
      text: widget.controller.query,
    );
    widget.controller.addListener(_syncText);

    _svc = CloudShareService(widget.controller.db);
    _pull = CloudPullService(widget.controller.db);

    // Trigger initial load so recent items appear on first open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.updateQuery(widget.controller.query); // '' loads recent
    });
  }

  void _syncText() {
    final query = widget.controller.query;
    if (_textController.text != query) {
      _textController.value = TextEditingValue(
        text: query,
        selection: TextSelection.collapsed(offset: query.length),
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
      if (!mounted) return;
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
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Deleted $deleted item(s)')),
    );
  }

  Future<void> _pullForTag(int tagId) async {
    if (!CloudHeaders.hasBearer) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in first (Settings & Cloud).')),
      );
      return;
    }
    setState(() => _cloudBusy = true);
    try {
      final tags = await widget.controller.db.getAllTags();
      final t = tags.firstWhere((x) => x.id == tagId);
      final listId = await _svc.getOrCreateListIdForTag(tagId: t.id, tagName: t.name);
      final since = await widget.controller.db.getListLastSync(listId);
      await _pull.pullItemsForList(listId: listId, since: since);
      await widget.controller.db.setListLastSync(listId, DateTime.now().toUtc());

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pulled updates for "${t.name}".')),
      );
      // Refresh list
      await widget.controller.updateQuery(widget.controller.query);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Pull failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _cloudBusy = false);
    }
  }

  Future<void> _pullAll() async {
    if (!CloudHeaders.hasBearer) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in first (Settings & Cloud).')),
      );
      return;
    }
    setState(() => _cloudBusy = true);
    try {
      await _pull.pullAllListsAndItems();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pulled all accessible lists.')),
        );
      }
      await widget.controller.updateQuery(widget.controller.query);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Pull-all failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _cloudBusy = false);
    }
  }

  Future<void> _uploadTag(int tagId) async {
    if (!CloudHeaders.hasBearer) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in first (Settings & Cloud).')),
      );
      return;
    }
    setState(() => _cloudBusy = true);
    try {
      await _svc.uploadAllItemsForTag(tagId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Uploaded items in this tag.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _cloudBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = widget.controller.db;

    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final hasTagFilter = widget.controller.tagId != null;

        return Scaffold(
          key: _scaffoldKey,
          drawer: AppDrawer(db: db),
          appBar: AppBar(
            leadingWidth: 56,
            leading: Builder(
              builder: (ctx) {
                final isDark = Theme.of(ctx).brightness == Brightness.dark;
                final asset = isDark ? 'assets/icon_v2.png' : 'assets/icon_v2.png';
                return InkWell(
                  onTap: () => Scaffold.of(ctx).openDrawer(),
                  borderRadius: BorderRadius.circular(28),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Image.asset(asset, width: 32, height: 32, fit: BoxFit.contain),
                  ),
                );
              },
            ),
            title: null,
            actions: [
              if (_cloudBusy)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              if (hasTagFilter) ...[
                IconButton(
                  tooltip: 'Pull this tag',
                  onPressed: _cloudBusy ? null : () => _pullForTag(widget.controller.tagId!),
                  icon: const Icon(Icons.sync),
                ),
                IconButton(
                  tooltip: 'Upload this tag',
                  onPressed: _cloudBusy ? null : () => _uploadTag(widget.controller.tagId!),
                  icon: const Icon(Icons.cloud_upload_outlined),
                ),
              ] else ...[
                IconButton(
                  tooltip: 'Pull all',
                  onPressed: _cloudBusy ? null : _pullAll,
                  icon: const Icon(Icons.sync),
                ),
              ],
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
                  if (!mounted) return;
                  setState(() {
                    _tagBarKey = UniqueKey();
                  });
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
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              TagFilterBar(key: _tagBarKey, database: db, controller: widget.controller),
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
                      confirmDismiss: (_) async => await _confirmDeleteItem(item.title),
                      onDismissed: (_) async {
                        await widget.controller.deleteItem(item.id);
                        if (!mounted) return;
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
