import 'package:flutter/foundation.dart';
import '../../data/drift/database.dart';

class AddItemController extends ChangeNotifier {
  final AppDatabase db;

  String? link; // optional shared text/link
  String title = '';
  bool isSaving = false;

  // New: incoming attachments (e.g., screenshots)
  List<AttachmentFile> attachments = [];

  AddItemController(this.db);

  Future<void> save() async {
    final hasLink = link != null && link!.trim().isNotEmpty;
    final hasAttachments = attachments.isNotEmpty;
    if (!hasLink && !hasAttachments) return;

    isSaving = true;
    notifyListeners();

    try {
      final effectiveTitle = title.isNotEmpty ? title : (hasLink ? null : 'Screenshot');

      final itemId = await db.insertSharedData(
        text: hasLink ? link : null,
        title: effectiveTitle,
      );

      if (hasAttachments) {
        await db.addAttachments(itemId: itemId, files: attachments);
      }
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }
}
