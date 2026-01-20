// SPDX-License-Identifier: Apache-2.0
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/drift/database.dart';
import '../media/video_viewer_screen.dart';
import '../media/image_viewer_screen.dart';
import '../media/audio_player_screen.dart';
import '../media/text_viewer_screen.dart';
import '../../util/share_out.dart';

// Cloud (pull/upload)
import '../../util/cloud_share_service.dart';
import '../../util/cloud_pull_service.dart';

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

  // Toggle: Created At / Updated At (hidden by default)
  bool _metaOpen = false;

  // Notes editor state
  late Item _item;
  bool _editingNotes = false;
  late TextEditingController _notesCtrl;

  // Cloud services
  late final CloudShareService _svc;
  late final CloudPullService _pull;
  bool _cloudBusy = false;

  // Auto-delete state
  Schedule? _autoDelete;
  bool _loadingAutoDelete = true;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
    _notesCtrl = TextEditingController(text: _item.content ?? '');
    _futureAttachments = widget.database.getAttachmentsForItem(widget.item.id);

    _svc = CloudShareService(widget.database);
    _pull = CloudPullService(widget.database);

    // Load current auto-delete schedule (if any)
    _loadAutoDelete();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  // -----------------------
  // Auto-delete helpers
  // -----------------------
  Future<void> _loadAutoDelete() async {
    final s = await widget.database.getAutoDeleteScheduleForItem(widget.item.id);
    if (!mounted) return;
    setState(() {
      _autoDelete = s;
      _loadingAutoDelete = false;
    });
  }

  Future<void> _setAutoDelete(Duration after) async {
    setState(() => _loadingAutoDelete = true);
    await widget.database.setAutoDeleteSchedule(itemId: widget.item.id, after: after);
    await _loadAutoDelete();
  }

  Future<void> _clearAutoDelete() async {
    setState(() => _loadingAutoDelete = true);
    await widget.database.clearAutoDeleteSchedule(widget.item.id);
    await _loadAutoDelete();
  }

  String _formatNextFire(int? ms) {
    if (ms == null) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    return dt.toLocal().toString();
  }

  // -----------------------
  // Tags attach/detach
  // -----------------------
  Future<void> _detachTag(int tagId) async {
    await widget.database.detachTag(itemId: widget.item.id, tagId: tagId);
  }

  Future<void> _attachTagFlow() async {
    final allTags = await widget.database.getAllTags();
    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: allTags.length + 1,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              if (i == 0) {
                return ListTile(
                  leading: const Icon(Icons.add),
                  title: const Text('Create new tag'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _createTagAndAttach();
                  },
                );
              }
              final t = allTags[i - 1];
              return ListTile(
                leading: const Icon(Icons.label),
                title: Text(t.name),
                onTap: () async {
                  Navigator.pop(ctx);
                  await widget.database.attachTag(itemId: widget.item.id, tagId: t.id);
                },
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _createTagAndAttach() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('New tag'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'e.g. recipes'),
            onSubmitted: (_) => Navigator.pop(ctx, controller.text.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
    if (name == null || name.trim().isEmpty) return;

    final tag = await widget.database.upsertTagByName(name.trim());
    await widget.database.attachTag(itemId: widget.item.id, tagId: tag.id);
  }

  Future<void> _deleteThisItem() async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete item?'),
            content: Text('This will permanently delete "${widget.item.title}".'),
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

    if (!ok) return;
    await widget.database.deleteItemById(widget.item.id);
    if (mounted) Navigator.pop(context); // back to list
  }

  // --- Link helper (open externally) ---
  Future<void> _openExternalUrl(String raw) async {
    var u = raw.trim();
    if (u.isEmpty) return;
    if (!u.contains('://')) {
      u = 'https://$u';
    }
    final uri = Uri.tryParse(u);
    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid URL')),
      );
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open: $u')),
      );
    }
  }

  // --- Media helpers ---
  bool _isVideoPath(String path, [String? mime]) {
    final mt = (mime ?? '').toLowerCase();
    if (mt.startsWith('video/')) return true;
    final p = path.toLowerCase();
    return p.endsWith('.mp4') || p.endsWith('.mov') || p.endsWith('.m4v') ||
           p.endsWith('.webm') || p.endsWith('.mkv') || p.endsWith('.avi');
  }

  bool _isImagePath(String path, [String? mime]) {
    final mt = (mime ?? '').toLowerCase();
    if (mt.startsWith('image/')) return true;
    final p = path.toLowerCase();
    return p.endsWith('.jpg') || p.endsWith('.jpeg') || p.endsWith('.png') ||
           p.endsWith('.gif') || p.endsWith('.webp') || p.endsWith('.heic') ||
           p.endsWith('.heif') || p.endsWith('.bmp') || p.endsWith('.tif') ||
           p.endsWith('.tiff');
  }

  bool _isAudioPath(String path, [String? mime]) {
    final mt = (mime ?? '').toLowerCase();
    if (mt.startsWith('audio/')) return true;
    final p = path.toLowerCase();
    return p.endsWith('.mp3') || p.endsWith('.m4a') || p.endsWith('.aac') ||
           p.endsWith('.ogg') || p.endsWith('.opus') || p.endsWith('.wav') ||
           p.endsWith('.flac');
  }

  Widget _audioThumbBox() {
    return Stack(
      fit: StackFit.expand,
      children: const [
        ColoredBox(color: Color(0x11000000)),
        Center(child: Icon(Icons.audiotrack, color: Colors.white70, size: 56)),
      ],
    );
  }

  Widget _attachmentThumb(Attachment a) {
    if (_isVideoPath(a.path, a.mimeType)) {
      return Stack(
        fit: StackFit.expand,
        children: const [
          ColoredBox(color: Color(0x11000000)),
          Center(child: Icon(Icons.play_circle_fill, color: Colors.white70, size: 56)),
        ],
      );
    }
    if (_isAudioPath(a.path, a.mimeType)) {
      return _audioThumbBox();
    }
    return Image.file(
      File(a.path),
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const ColoredBox(
        color: Colors.black12,
        child: Center(child: Icon(Icons.image_not_supported)),
      ),
    );
  }

  void _openImageViewer(Attachment tapped, List<Attachment> all) {
    final images = all.where((e) => _isImagePath(e.path, e.mimeType)).toList();
    final paths = images.map((e) => e.path).toList();
    final heroTags = paths; // use file path as hero tag
    final initialIndex = images.indexWhere((e) => e.path == tapped.path);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ImageViewerScreen(
          paths: paths,
          initialIndex: initialIndex < 0 ? 0 : initialIndex,
          heroTags: heroTags,
        ),
      ),
    );
  }

  void _openTextViewer(String text) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TextViewerScreen(text: text),
      ),
    );
  }

  Future<void> _saveNotes() async {
    final newText = _notesCtrl.text.trim();
    await widget.database.updateItemContent(
      id: _item.id,
      content: newText.isEmpty ? null : newText,
    );
    setState(() {
      _item = Item(
        id: _item.id,
        title: _item.title,
        content: newText.isEmpty ? null : newText,
        link: _item.link,
        createdAt: _item.createdAt,
        updatedAt: DateTime.now(),
      );
      _editingNotes = false;
    });
  }

  // --- Cloud: Upload this item (via first tag’s list) ---
  Future<void> _uploadThisItem() async {
    if (!CloudHeaders.hasBearer) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in first (Settings & Cloud).')),
      );
      return;
    }
    setState(() => _cloudBusy = true);
    try {
      final tags = await widget.database.getTagsForItem(widget.item.id);
      if (tags.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Add a tag to this item first.')),
          );
        }
        return;
      }
      final t = tags.first;
      final listId = await _svc.getOrCreateListIdForTag(tagId: t.id, tagName: t.name);
      await _svc.uploadOneItem(_item, listId: listId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Uploaded under "${t.name}".')),
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

  // --- Cloud: Pull items for this item’s first tag’s list ---
  Future<void> _pullForThisItem() async {
    if (!CloudHeaders.hasBearer) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in first (Settings & Cloud).')),
      );
      return;
    }
    setState(() => _cloudBusy = true);
    try {
      final tags = await widget.database.getTagsForItem(widget.item.id);
      if (tags.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Add a tag to this item first.')),
          );
        }
        return;
      }
      final t = tags.first;
      final listId = await _svc.getOrCreateListIdForTag(tagId: t.id, tagName: t.name);
      final since = await widget.database.getListLastSync(listId);
      await _pull.pullItemsForList(listId: listId, since: since);
      await widget.database.setListLastSync(listId, DateTime.now().toUtc());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Pulled updates for "${t.name}".')),
        );
      }
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

  @override
  Widget build(BuildContext context) {
    final hasContent = (_item.content ?? '').trim().isNotEmpty;
    final hasLink = (_item.link ?? '').trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(_item.title),
        actions: [
          if (_cloudBusy)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
        IconButton(
          tooltip: 'Pull',
          onPressed: _cloudBusy ? null : _pullForThisItem,
          icon: const Icon(Icons.sync),
        ),
        IconButton(
          tooltip: 'Upload',
          onPressed: _cloudBusy ? null : _uploadThisItem,
          icon: const Icon(Icons.cloud_upload_outlined),
        ),
          IconButton(
            tooltip: 'Attach tag',
            onPressed: _attachTagFlow,
            icon: const Icon(Icons.label_important_outline),
          ),
          IconButton(
            tooltip: 'Share',
            onPressed: () => shareItem(
              context: context,
              db: widget.database,
              item: _item,
            ),
            icon: const Icon(Icons.share_outlined),
          ),
          IconButton(
            tooltip: 'Delete item',
            onPressed: _deleteThisItem,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: FutureBuilder<List<Attachment>>(
        future: _futureAttachments,
        builder: (context, snapA) {
          final attachments = snapA.data ?? const [];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Notes (Content) section
                if (_editingNotes) ...[
                  const Text("Notes", style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _notesCtrl,
                    minLines: 3,
                    maxLines: 10,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Write your notes…',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.check),
                        label: const Text('Save'),
                        onPressed: _saveNotes,
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        icon: const Icon(Icons.close),
                        label: const Text('Cancel'),
                        onPressed: () => setState(() {
                          _notesCtrl.text = _item.content ?? '';
                          _editingNotes = false;
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ] else ...[
                  if (hasContent) ...[
                    Row(
                      children: [
                        const Text("Notes:", style: TextStyle(fontWeight: FontWeight.w600)),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Edit notes',
                          icon: const Icon(Icons.edit_note),
                          onPressed: () => setState(() => _editingNotes = true),
                        ),
                      ],
                    ),
                    InkWell(
                      onTap: () => _openTextViewer(_item.content!.trim()),
                      child: Text(
                        _item.content!,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(decoration: TextDecoration.underline),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ] else ...[
                    OutlinedButton.icon(
                      onPressed: () => setState(() => _editingNotes = true),
                      icon: const Icon(Icons.add),
                      label: const Text('Add notes'),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],

                // Link (open externally) + info toggle (only if link exists)
                if (hasLink)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Link: ", style: TextStyle(fontWeight: FontWeight.w600)),
                      Expanded(
                        child: InkWell(
                          onTap: () => _openExternalUrl(_item.link!.trim()),
                          child: Text(
                            _item.link!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(decoration: TextDecoration.underline),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: _metaOpen ? 'Hide details' : 'Show details',
                        icon: Icon(_metaOpen ? Icons.info : Icons.info_outline),
                        onPressed: () => setState(() => _metaOpen = !_metaOpen),
                      ),
                    ],
                  ),

                // Metadata (toggle visible)
                AnimatedCrossFade(
                  firstChild: const SizedBox.shrink(),
                  secondChild: Padding(
                    padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Created At: ${_item.createdAt}"),
                        const SizedBox(height: 8),
                        Text("Updated At: ${_item.updatedAt}"),
                      ],
                    ),
                  ),
                  crossFadeState: _metaOpen ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 200),
                ),

                const SizedBox(height: 16),

                // --- Auto-delete section ---
                Row(
                  children: [
                    const Text('Auto-delete', style: TextStyle(fontWeight: FontWeight.bold)),
                    const Spacer(),
                    if (_loadingAutoDelete)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    if (!_loadingAutoDelete)
                      PopupMenuButton<String>(
                        tooltip: 'Set timer',
                        icon: const Icon(Icons.timer_outlined),
                        onSelected: (v) {
                          switch (v) {
                            case 'off':
                              _clearAutoDelete();
                              break;
                            case '1d':
                              _setAutoDelete(const Duration(days: 1));
                              break;
                            case '1w':
                              _setAutoDelete(const Duration(days: 7));
                              break;
                            case '1m':
                              _setAutoDelete(const Duration(days: 30));
                              break;
                          }
                        },
                        itemBuilder: (ctx) => const [
                          PopupMenuItem(value: 'off', child: Text('Off')),
                          PopupMenuItem(value: '1d', child: Text('In 1 day')),
                          PopupMenuItem(value: '1w', child: Text('In 1 week')),
                          PopupMenuItem(value: '1m', child: Text('In 1 month')),
                        ],
                      ),
                  ],
                ),
                if (!_loadingAutoDelete && _autoDelete != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Scheduled for: ${_formatNextFire(_autoDelete?.nextFire)}',
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
                const SizedBox(height: 16),

                // Tags section (live)
                StreamBuilder<List<Tag>>(
                  stream: widget.database.watchTagsForItem(_item.id),
                  builder: (context, snapT) {
                    final tags = snapT.data ?? const <Tag>[];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('Tags', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            if (snapT.connectionState == ConnectionState.waiting)
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (tags.isEmpty)
                          const Text('No tags attached'),
                        if (tags.isNotEmpty)
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: tags.map((t) {
                              return InputChip(
                                label: Text(t.name),
                                onDeleted: () => _detachTag(t.id),
                              );
                            }).toList(),
                          ),
                        const SizedBox(height: 16),
                      ],
                    );
                  },
                ),

                if (snapA.connectionState == ConnectionState.waiting)
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
                      final child = ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: _attachmentThumb(a),
                      );

                      return GestureDetector(
                        onTap: () {
                          if (_isVideoPath(a.path, a.mimeType)) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => VideoViewerScreen(filePath: a.path),
                              ),
                            );
                          } else if (_isImagePath(a.path, a.mimeType)) {
                            _openImageViewer(a, attachments);
                          } else if (_isAudioPath(a.path, a.mimeType)) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AudioPlayerScreen(filePath: a.path),
                              ),
                            );
                          }
                        },
                        child: Hero(tag: a.path, child: child),
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
