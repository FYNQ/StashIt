// SPDX-License-Identifier: Apache-2.0
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'cloud_config.dart';
import '../data/drift/database.dart';

class CloudPullService {
  final AppDatabase db;
  CloudPullService(this.db);

  Future<void> pullAllListsAndItems({DateTime? since}) async {
    final listsResp = await Cloud.client.get(
      Cloud.uri('/lists'),
      headers: Cloud.headersJson(),
    );
    if (listsResp.statusCode != 200) {
      throw 'Lists fetch failed: ${listsResp.body}';
    }
    final listsData = jsonDecode(listsResp.body) as Map<String, dynamic>;
    final lists = (listsData['lists'] as List).cast<Map<String, dynamic>>();

    for (final l in lists) {
      final listId = l['id'] as String;
      await pullItemsForList(listId: listId, since: since);
    }
  }

  Future<void> pullItemsForList({
    required String listId,
    DateTime? since,
  }) async {
    final q = <String, dynamic>{};
    if (since != null) q['since'] = since.toUtc().toIso8601String();

    final itemsResp = await Cloud.client.get(
      Cloud.uri('/lists/$listId/items', q),
      headers: Cloud.headersJson(),
    );
    if (itemsResp.statusCode != 200) {
      throw 'Items fetch failed: ${itemsResp.body}';
    }
    final data = jsonDecode(itemsResp.body) as Map<String, dynamic>;
    final items = (data['items'] as List).cast<Map<String, dynamic>>();

    for (final it in items) {
      await _upsertLocalItemFromCloud(it);
    }
  }

  Future<void> _upsertLocalItemFromCloud(Map<String, dynamic> cloud) async {
    final cloudId = cloud['id'] as String;
    final title = (cloud['title'] ?? '') as String;
    final content = cloud['content'] as String?;
    final link = cloud['link'] as String?;
    final attachments = (cloud['attachments'] as List).cast<Map<String, dynamic>>();

    // Resolve mapping cloud UUID -> local ID
    int? localId = await db.getLocalIdForCloudItem(cloudId);

    if (localId == null) {
      localId = await db.insertSharedData(
        text: content,
        title: title.isEmpty ? 'Shared item' : title,
        link: link,
      );
      await db.setCloudItemMapping(cloudId: cloudId, localId: localId);
    } else {
      await db.updateItemContent(id: localId, content: content);
    }

    // Attachments: download new ones & add
    final existing = await db.getAttachmentsForItem(localId);
    final existingNames = existing.map((a) => p.basename(a.path)).toSet();

    for (final a in attachments) {
      final url = (a['url'] ?? '') as String;
      if (url.isEmpty) continue;

      final fileName = p.basename(url);
      if (existingNames.contains(fileName)) continue;

      try {
        final file = await _downloadToAppAttachments(url);
        if (file != null) {
          await db.addAttachments(
            itemId: localId,
            files: [AttachmentFile(file.path, mimeType: a['mimeType'] as String?)],
          );
        }
      } catch (_) {}
    }
  }

  Future<File?> _downloadToAppAttachments(String relativeOrAbsoluteUrl) async {
    final base = Cloud.uri('/').toString().replaceAll(RegExp(r'/$'), '');
    final full = relativeOrAbsoluteUrl.startsWith('http')
        ? relativeOrAbsoluteUrl
        : '$base$relativeOrAbsoluteUrl';

    final resp = await http.get(Uri.parse(full));
    if (resp.statusCode != 200 || resp.bodyBytes.isEmpty) return null;

    final dir = await getApplicationDocumentsDirectory();
    final attsDir = Directory(p.join(dir.path, 'attachments'));
    if (!attsDir.existsSync()) attsDir.createSync(recursive: true);

    final fileName = p.basename(relativeOrAbsoluteUrl);
    final dest = File(p.join(attsDir.path, fileName));
    await dest.writeAsBytes(resp.bodyBytes);
    return dest;
  }
}
