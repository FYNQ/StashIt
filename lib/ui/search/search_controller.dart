import 'package:flutter/foundation.dart';
import '../../data/drift/database.dart';

class ItemSearchController extends ChangeNotifier {
  final AppDatabase db;

  ItemSearchController(this.db);

  /// Current search query
  String _query = '';

  /// Optional tag filter
  int? _tagId;

  /// Loading state (THIS controls the spinner)
  bool _isLoading = false;

  /// Current results
  List<Item> _results = [];

  // --------------------
  // Public getters
  // --------------------

  bool get isLoading => _isLoading;
  List<Item> get results => List.unmodifiable(_results);
  String get query => _query;
  int? get tagId => _tagId;

  // --------------------
  // Public API
  // --------------------

  /// Called when the search text changes
  Future<void> updateQuery(String query) async {
    _query = query;
    await _search();
  }

  /// Called when a tag filter is selected / cleared
  Future<void> updateTag(int? tagId) async {
    _tagId = tagId;
    await _search();
  }

  /// Clear search completely
  void clear() {
    _query = '';
    _tagId = null;
    _results = [];
    _isLoading = false;
    notifyListeners();
  }

  // --------------------
  // Internal logic
  // --------------------

Future<void> _search() async {
  _isLoading = true;
  notifyListeners();

  try {
    final trimmed = _query.trim();

if (trimmed.isEmpty) {
  _isLoading = true;
  notifyListeners();

  try {
    _results = await db.getRecentItems();
  } finally {
    _isLoading = false;
    notifyListeners();
  }
  return;
}


    if (_tagId == null) {
      _results = await db.searchItems(trimmed);
    } else {
      _results = await db.searchItemsWithTag(
        query: trimmed,
        tagId: _tagId,
      );
    }
  } catch (e, st) {
    debugPrint('Search failed: $e');
    debugPrintStack(stackTrace: st);
    _results = [];
  } finally {
    _isLoading = false;
    notifyListeners();
  }
}

}

