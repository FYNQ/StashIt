import 'dart:io';
import 'package:flutter/material.dart';
import '../../data/drift/database.dart';
import 'add_item_controller.dart';
import '../media/video_viewer_screen.dart';
import '../media/image_viewer_screen.dart';
import '../../util/share_out.dart';


class AddItemScreen extends StatefulWidget {
  final AppDatabase database;
  final String? sharedText;
  final List<AttachmentFile> attachments;

  const AddItemScreen({
    super.key,
    required this.database,
    this.sharedText,
    this.attachments = const [],
  });

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  late final AddItemController controller;
  late Future<List<Tag>> _futureTags;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    controller = AddItemController(widget.database)
      ..link = widget.sharedText
      ..attachments = List<AttachmentFile>.from(widget.attachments);

    _futureTags = widget.database.getAllTags();

    // Prefill from YouTube link (async)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      setState(() => _working = true);
      try {
        await controller.prefillFromLink();
        setState(() {
          _futureTags = widget.database.getAllTags();
        });
      } finally {
        if (mounted) setState(() => _working = false);
      }
    });
  }

  Future<void> _reloadTags() async {
    setState(() {
      _futureTags = widget.database.getAllTags();
    });
  }

  Future<void> _createTagInline() async {
    final textCtrl = TextEditingController();

    final name = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Create new tag'),
          content: TextField(
            controller: textCtrl,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'e.g. recipes, work, personal',
            ),
            onSubmitted: (_) => Navigator.pop(ctx, textCtrl.text.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, textCtrl.text.trim()),
              child: const Text('Create'),
            ),
          ],
        );
      },
    );

    if (name == null || name.isEmpty) return;

    setState(() => _working = true);
    try {
      final tag = await widget.database.upsertTagByName(name);
      controller.tagIds.add(tag.id); // auto-select the new tag
      await _reloadTags();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create tag: $e')),
      );
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  // -------------------
  // Media helpers
  // -------------------
  bool _isVideo(AttachmentFile a) {
    final mt = (a.mimeType ?? '').toLowerCase();
    if (mt.startsWith('video/')) return true;
    final p = a.path.toLowerCase();
    return p.endsWith('.mp4') || p.endsWith('.mov') || p.endsWith('.m4v') ||
           p.endsWith('.webm') || p.endsWith('.mkv') || p.endsWith('.avi');
  }

  bool _isImage(AttachmentFile a) {
    final mt = (a.mimeType ?? '').toLowerCase();
    if (mt.startsWith('image/')) return true;
    final p = a.path.toLowerCase();
    return p.endsWith('.jpg') || p.endsWith('.jpeg') || p.endsWith('.png') ||
           p.endsWith('.gif') || p.endsWith('.webp') || p.endsWith('.heic') ||
           p.endsWith('.heif') || p.endsWith('.bmp') || p.endsWith('.tif') ||
           p.endsWith('.tiff');
  }

  Widget _thumbFor(AttachmentFile a) {
    if (_isVideo(a)) {
      return Stack(
        fit: StackFit.expand,
        children: const [
          ColoredBox(color: Color(0x11000000)),
          Center(child: Icon(Icons.play_circle_fill, color: Colors.white70, size: 56)),
        ],
      );
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

  void _openImageViewer(AttachmentFile tapped) {
    final images = controller.attachments.where(_isImage).toList();
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
  // -------------------

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final hasLink = (controller.link ?? '').trim().isNotEmpty;
        final hasAttachments = controller.attachments.isNotEmpty;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Add item'),
			actions: [
				IconButton(
				  tooltip: 'Share',
				  onPressed: () {
					final textParts = <String>[];
					if (controller.title.trim().isNotEmpty) {
					  textParts.add(controller.title.trim());
					}
					if ((controller.link ?? '').trim().isNotEmpty) {
					  textParts.add(controller.link!.trim());
					}
					final text = textParts.join('\n\n');
					shareAttachments(
					  context: context,
					  attachments: controller.attachments,
					  text: text.isEmpty ? null : text,
					  subject: controller.title.isEmpty ? null : controller.title,
					);
				  },
				  icon: const Icon(Icons.share_outlined),
				),
			  ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasLink) ...[
                  TextField(
                    enabled: false,
                    controller: TextEditingController(
                      text: controller.link ?? '',
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Link',
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Title',
                  ),
                  onChanged: (v) => controller.title = v,
                ),

                const SizedBox(height: 12),

                Row(
                  children: [
                    const Text('Tags', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    if (_working)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _working ? null : _createTagInline,
                      icon: const Icon(Icons.add),
                      label: const Text('New tag'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                FutureBuilder<List<Tag>>(
                  future: _futureTags,
                  builder: (context, snap) {
                    final tags = snap.data ?? const <Tag>[];
                    if (snap.connectionState == ConnectionState.waiting && tags.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: LinearProgressIndicator(),
                      );
                    }
                    if (tags.isEmpty) {
                      return const Text(
                        'No tags yet. Create one with "New tag".',
                        style: TextStyle(color: Colors.black54),
                      );
                    }
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: tags.map((t) {
                        final selected = controller.tagIds.contains(t.id);
                        return FilterChip(
                          label: Text(t.name),
                          selected: selected,
                          onSelected: (v) {
                            setState(() {
                              if (v) {
                                controller.tagIds.add(t.id);
                              } else {
                                controller.tagIds.remove(t.id);
                              }
                            });
                          },
                        );
                      }).toList(),
                    );
                  },
                ),

                const SizedBox(height: 12),

                if (hasAttachments) ...[
                  const Text('Attachments', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 160,
                    child: GridView.builder(
                      scrollDirection: Axis.horizontal,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 1,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 1.2,
                      ),
                      itemCount: controller.attachments.length,
                      itemBuilder: (_, i) {
                        final a = controller.attachments[i];
                        final child = ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: _thumbFor(a),
                        );

                        return GestureDetector(
                          onTap: () {
                            if (_isVideo(a)) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => VideoViewerScreen(filePath: a.path),
                                ),
                              );
                            } else if (_isImage(a)) {
                              _openImageViewer(a);
                            }
                          },
                          child: Hero(tag: a.path, child: child),
                        );
                      },
                    ),
                  ),
                ],

                const Spacer(),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: controller.isSaving
                        ? null
                        : () async {
                            await controller.save();
                            if (mounted) Navigator.pop(context);
                          },
                    child: controller.isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
