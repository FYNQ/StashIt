import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../data/drift/database.dart';
import '../../util/youtube_utils.dart';

class AddItemController extends ChangeNotifier {
  final AppDatabase db;

  String? link; // optional shared text/link
  String title = '';
  bool isSaving = false;

  // Incoming attachments (e.g., screenshots)
  List<AttachmentFile> attachments = [];

  // Selected tags to attach on save
  final Set<int> tagIds = <int>{};

  AddItemController(this.db);

  // Prefill from YouTube link: title, thumbnail, tag
  Future<void> prefillFromLink() async {
    final raw = (link ?? '').trim();
    if (raw.isEmpty || !isYouTubeUrl(raw)) return;

    final meta = await fetchYouTubeMeta(raw);
    if (meta == null) return;

    // Prefill title if empty
    if (title.trim().isEmpty && (meta.title ?? '').isNotEmpty) {
      title = meta.title!.trim();
    }

    // Download thumbnail and include as pending attachment (preview + save)
    final thumbUrl = meta.thumbnailUrl;
    if (thumbUrl != null && thumbUrl.isNotEmpty) {
      final file = await downloadImageToTemp(thumbUrl);
      if (file != null && file.existsSync()) {
        attachments.add(AttachmentFile(file.path, mimeType: 'image/jpeg'));
      }
    }

    // Auto-tag: youtube
    try {
      final tag = await db.upsertTagByName('youtube');
      tagIds.add(tag.id);
    } catch (_) {
      // ignore
    }

    // Normalize link to watch URL
    link = meta.url;

    notifyListeners();
  }

  Future<void> save() async {
    final rawLink = (link ?? '').trim();
    final hasLink = rawLink.isNotEmpty;
    final hasAttachments = attachments.isNotEmpty;
    if (!hasLink && !hasAttachments && title.trim().isEmpty) return;

    isSaving = true;
    notifyListeners();

    try {
      // If no title and only attachments, default to 'Screenshot'
      final effectiveTitle = title.isNotEmpty
          ? title
          : (hasLink ? null : 'Screenshot');

      // Save item: store URL into the link column (and no content for YouTube)
      final itemId = await db.insertSharedData(
        text: null,
        title: effectiveTitle,
        link: hasLink ? rawLink : null,
      );

      if (hasAttachments) {
        await db.addAttachments(itemId: itemId, files: attachments);
      }

      if (tagIds.isNotEmpty) {
        for (final id in tagIds) {
          await db.attachTag(itemId: itemId, tagId: id);
        }
      }
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }
}
