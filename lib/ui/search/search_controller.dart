import 'dart:async';
import '../../data/drift/database.dart';

class ItemSearchController {
  final AppDatabase db;

  ItemSearchController(this.db);

  final StreamController<List<Item>> _resultsController = StreamController.broadcast();
  Stream<List<Item>> get resultsStream => _resultsController.stream;

  String lastQuery = '';
  int? selectedTagId;
  int offset = 0;
  final int pageSize = 20;
  bool isLoading = false;
  bool hasMore = true;
  Timer? _debounce;

  void search(String query, {int? tagId}) {
    lastQuery = query;
    selectedTagId = tagId;
    offset = 0;
    hasMore = true;

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      await _loadMore(reset: true);
    });
  }

  Future<void> loadMore() async {
    await _loadMore();
  }

  Future<void> _loadMore({bool reset = false}) async {
    if (isLoading || !hasMore) return;
    isLoading = true;

    if (reset) {
      offset = 0;
      hasMore = true;
    }

    final results = await db.searchItemsPaged(
      query: lastQuery,
      tagId: selectedTagId,
      limit: pageSize,
      offset: offset,
    );

    if (reset) {
      _resultsController.add(results);
    } else {
      final current = await resultsStream.first;
      _resultsController.add([...current, ...results]);
    }

    if (results.length < pageSize) {
      hasMore = false;
    }

    offset += results.length;
    isLoading = false;
  }

  void dispose() {
    _resultsController.close();
    _debounce?.cancel();
  }
}

