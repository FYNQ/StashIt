import 'package:flutter/foundation.dart';
import '../../data/drift/database.dart';

class AddItemController extends ChangeNotifier {
  final AppDatabase db;

  String? link;
  String title = '';
  bool isSaving = false;

  // Tags state
  List<Tag> allTags = [];
  final Set<int> selectedTagIds = {};
  String newTagName = '';

  AddItemController(this.db);

  // Load all tags to display in the picker
  Future<void> init() async {
    allTags = await db.getAllTags();
    notifyListeners();
  }

  void toggleTag(int tagId) {
    if (selectedTagIds.contains(tagId)) {
      selectedTagIds.remove(tagId);
    } else {
      selectedTagIds.add(tagId);
    }
    notifyListeners();
  }


// Refresh all tags (useful after creates from the bottom sheet)
Future<void> refreshTags() async {
  allTags = await db.getAllTags();
  notifyListeners();
}

// Create a tag and select it
Future<Tag> createAndSelectTag(String name) async {
  final tag = await db.upsertTagByName(name);
  // Merge into local list if missing
  if (!allTags.any((t) => t.id == tag.id)) {
    allTags = [...allTags, tag];
  }
  selectedTagIds.add(tag.id);
  notifyListeners();
  return tag;
}


  // Apply a whole set (used by the bottom sheet when tapping Done)
  void setSelectedTags(Iterable<int> ids) {
    selectedTagIds
      ..clear()
      ..addAll(ids);
    notifyListeners();
  }
  // Helper to render chips safely
  Tag? tagById(int id) {
    try {
      return allTags.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> addNewTag() async {
    final name = newTagName.trim();
    if (name.isEmpty) return;

    // Create or fetch existing
    final tag = await db.upsertTagByName(name);
    // Merge into list if not present
    if (!allTags.any((t) => t.id == tag.id)) {
      allTags = [...allTags, tag];
    }
    // Select it
    selectedTagIds.add(tag.id);
    // Clear input
    newTagName = '';
    notifyListeners();
  }

  Future<void> save() async {
    if (link == null || link!.isEmpty) return;

    isSaving = true;
    notifyListeners();
    try {
      final itemId = await db.insertSharedData(
        text: link,
        title: title.isEmpty ? null : title,
      );

      // Attach selected tags
      for (final tagId in selectedTagIds) {
        await db.attachTag(itemId: itemId, tagId: tagId);
      }
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }
}
