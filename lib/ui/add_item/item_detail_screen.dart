import 'dart:io';
import 'package:flutter/material.dart';
import '../../data/drift/database.dart';
import '../media/video_viewer_screen.dart';
import '../media/image_viewer_screen.dart';
import '../media/audio_player_screen.dart';
import '../media/link_viewer_screen.dart';
import '../media/text_viewer_screen.dart';
import '../../util/share_out.dart';

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

  Future<void> _detachTag(int tagId) async {
    await widget.database.detachTag(itemId: widget.item.id, tagId: tagId);
    // Stream will auto-update tags UI.
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
                  // Stream will auto-update tags UI.
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
    // Stream will auto-update tags UI.
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
  // --- end helpers ---

  void _openTextViewer(String text) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TextViewerScreen(
          text: text,
        ),
      ),
    );
  }

  void _openLinkViewer(String url) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LinkViewerScreen(url: url),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return Scaffold(
      appBar: AppBar(
        title: Text(item.title),
        actions: [
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
              item: widget.item,
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
                Text("Title: ${item.title}", style: const TextStyle(fontSize: 24)),
                const SizedBox(height: 8),

                // Content viewer
                if ((item.content ?? '').trim().isEmpty)
                  const Text("Content: No content available")
                else
                  InkWell(
                    onTap: () => _openTextViewer(item.content!.trim()),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Content:", style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text(
                          item.content!,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(decoration: TextDecoration.underline),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 8),

                // Link viewer
                if ((item.link ?? '').trim().isEmpty)
                  const Text("Link: No link available")
                else
                  InkWell(
                    onTap: () => _openLinkViewer(item.link!.trim()),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Link: ", style: TextStyle(fontWeight: FontWeight.w600)),
                        Expanded(
                          child: Text(
                            item.link!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(decoration: TextDecoration.underline),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 8),
                Text("Created At: ${item.createdAt}"),
                const SizedBox(height: 8),
                Text("Updated At: ${item.updatedAt}"),
                const SizedBox(height: 16),

                // Tags section (live)
                StreamBuilder<List<Tag>>(
                  stream: widget.database.watchTagsForItem(item.id),
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
