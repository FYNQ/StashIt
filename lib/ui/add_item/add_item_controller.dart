import 'package:flutter/foundation.dart';
import '../../data/drift/database.dart';

class AddItemController extends ChangeNotifier {
  final AppDatabase db;

  String? link;
  String title = '';
  int? tagId;
  bool isSaving = false;

  AddItemController(this.db);

  Future<void> save() async {
    if (link == null || link!.isEmpty) return;

    isSaving = true;
    notifyListeners();

    await db.insertSharedData(
      text: link,
      title: title.isEmpty ? null : title,
    );

    isSaving = false;
    notifyListeners();
  }
}

