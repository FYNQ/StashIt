// SPDX-License-Identifier: Apache-2.0
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import '../util/cloud_share_service.dart';
import '../util/cloud_pull_service.dart';
import '../data/drift/database.dart';

class DeepLinkHandler {
  static StreamSubscription<Uri>? _sub;
  static AppLinks? _appLinks;

  static Future<void> init({
    required BuildContext context,
    required AppDatabase db,
  }) async {
    // Create singleton instance
    _appLinks ??= AppLinks();

    // Handle cold start link
    try {
      final Uri? initialUri = await _appLinks!.getInitialAppLink();
      if (initialUri != null) {
        await _handleUri(context, db, initialUri);
      }
    } catch (_) {
      // Ignore parsing errors
    }

    // Live stream
    await _sub?.cancel();
    _sub = _appLinks!.uriLinkStream.listen(
      (Uri uri) async {
        await _handleUri(context, db, uri);
      },
      onError: (_) {},
    );
  }

  static Future<void> _handleUri(
    BuildContext context,
    AppDatabase db,
    Uri uri,
  ) async {
    if (uri.scheme != 'stashr') return;

    // Example: stashr://invite?token=XYZ
    if (uri.host == 'invite') {
      final token = uri.queryParameters['token'];
      if ((token ?? '').isEmpty) return;

      final svc = CloudShareService(db);
      final pull = CloudPullService(db);

      try {
        // Exchange token for list ID
        final listId = await svc.acceptInviteToken(token!);

        // Ask which Tag to map to this list (new or existing)
        final tagName = await _askTagNameOrPick(context, db);
        if (tagName == null || tagName.trim().isEmpty) return;

        final tag = await db.upsertTagByName(tagName.trim());
        await svc.setTagCloudListId(tag.id, listId);
        await svc.setTagShared(tag.id, true);

        // Initial pull
        final since = await db.getListLastSync(listId);
        await pull.pullItemsForList(listId: listId, since: since);
        await db.setListLastSync(listId, DateTime.now().toUtc());

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Joined "$tagName" and synced.')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Invite failed: $e')),
          );
        }
      }
    }
  }

  static Future<String?> _askTagNameOrPick(
    BuildContext context,
    AppDatabase db,
  ) async {
    final all = await db.getAllTags();
    return await showDialog<String>(
      context: context,
      builder: (ctx) {
        final textCtrl = TextEditingController();
        int? picked;
        return AlertDialog(
          title: const Text('Choose tag for shared list'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (all.isNotEmpty)
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(
                    labelText: 'Use existing tag',
                  ),
                  items: all
                      .map((t) => DropdownMenuItem(
                            value: t.id,
                            child: Text(t.name),
                          ))
                      .toList(),
                  onChanged: (v) => picked = v,
                ),
              const SizedBox(height: 8),
              TextField(
                controller: textCtrl,
                decoration: const InputDecoration(
                  labelText: 'Or type new tag',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (picked != null) {
                  final t = all.firstWhere((x) => x.id == picked);
                  Navigator.pop(ctx, t.name);
                  return;
                }
                Navigator.pop(ctx, textCtrl.text.trim());
              },
              child: const Text('Use'),
            ),
          ],
        );
      },
    );
  }

  static Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
  }
}
