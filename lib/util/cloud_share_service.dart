// SPDX-License-Identifier: Apache-2.0
import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart' as d;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'cloud_config.dart';
import '../data/drift/database.dart';

class CloudHeaders {
  static bool get hasBearer => (Cloud.headersJson()['Authorization'] ?? '').isNotEmpty;
}

class CloudShareService {
  final AppDatabase db;
  CloudShareService(this.db);

  bool get isSignedIn => CloudHeaders.hasBearer;

  // Device-based sign-in → sets bearer token in memory
  Future<void> signInDevice({
    required String deviceId,
    String? displayName,
    String? email,
  }) async {
    final resp = await Cloud.client.post(
      Cloud.uri('/auth/device'),
      headers: Cloud.headersJson(),
      body: jsonEncode({
        'deviceId': deviceId,
        'displayName': displayName,
        'email': email,
      }),
    );
    if (resp.statusCode != 200) {
      throw 'Sign-in failed (HTTP ${resp.statusCode}): ${resp.body}';
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    Cloud.setBearer(data['token'] as String?);
  }

  // Local properties mapping
  Future<void> _setMap(String key, String value) async {
    await db.into(db.properties).insert(
      PropertiesCompanion.insert(
        itemId: 'app',
        name: key,
        value: d.Value(value),
        type: d.Value('string'),
      ),
      mode: d.InsertMode.insertOrReplace,
    );
  }

  // Cache my role locally
  Future<void> setMyRoleForList(String listId, String role) async {
    await db.into(db.properties).insert(
      PropertiesCompanion.insert(
        itemId: 'app',
        name: 'list:$listId/my_role',
        value: d.Value(role),
        type: d.Value('string'),
      ),
      mode: d.InsertMode.insertOrReplace,
    );
  }

  Future<String?> getMyRoleForList(String listId) async {
    final row = await (db.select(db.properties)
          ..where((p) => p.itemId.equals('app') & p.name.equals('list:$listId/my_role'))
          ..limit(1))
        .getSingleOrNull();
    return row?.value;
  }

  // Members API
  Future<void> updateMemberRole({
    required String listId,
    required String userId,
    required String role, // OWNER | MANAGER | EDITOR | VIEWER (server refuses OWNER changes)
  }) async {
    final resp = await Cloud.client.patch(
      Cloud.uri('/lists/$listId/members/$userId'),
      headers: Cloud.headersJson(),
      body: jsonEncode({'role': role}),
    );
    if (resp.statusCode != 200) {
      throw 'Update role failed (HTTP ${resp.statusCode}): ${resp.body}';
    }
  }

  Future<void> removeMember({
    required String listId,
    required String userId,
  }) async {
    final resp = await Cloud.client.delete(
      Cloud.uri('/lists/$listId/members/$userId'),
      headers: Cloud.headersJson(),
    );
    if (resp.statusCode != 204) {
      throw 'Remove member failed (HTTP ${resp.statusCode}): ${resp.body}';
    }
  }

  Future<Map<String, dynamic>> getListMembers(String listId) async {
    final resp = await Cloud.client.get(
      Cloud.uri('/lists/$listId/members'),
      headers: Cloud.headersJson(),
    );
    if (resp.statusCode != 200) {
      throw 'Members fetch failed (HTTP ${resp.statusCode}).';
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  Future<String?> _getMap(String key) async {
    final row = await (db.select(db.properties)
          ..where((p) => p.itemId.equals('app') & p.name.equals(key))
          ..limit(1))
        .getSingleOrNull();
    return row?.value;
  }

  String _tagListKey(int tagId) => 'tag:$tagId/cloud_list_id';
  String _tagSharedKey(int tagId) => 'tag:$tagId/shared';
  String _itemCloudKey(int itemId) => 'item:$itemId/cloud_item_uuid';

  Future<void> setTagShared(int tagId, bool v) async => _setMap(_tagSharedKey(tagId), v ? '1' : '0');
  Future<bool> isTagShared(int tagId) async => (await _getMap(_tagSharedKey(tagId))) == '1';
  Future<void> setTagCloudListId(int tagId, String listId) async => _setMap(_tagListKey(tagId), listId);
  Future<String?> getTagCloudListId(int tagId) async => _getMap(_tagListKey(tagId));
  Future<void> setItemCloudUuid(int itemId, String cloudUuid) async => _setMap(_itemCloudKey(itemId), cloudUuid);
  Future<String?> getItemCloudUuid(int itemId) async => _getMap(_itemCloudKey(itemId));

  Future<String> getOrCreateListIdForTag({required int tagId, required String tagName}) async {
    final existing = await getTagCloudListId(tagId);
    if (existing != null && existing.isNotEmpty) return existing;
    return await createOrGetSharedListForTag(tagId: tagId, tagName: tagName);
  }

  // Lists from Tags
  Future<String> createOrGetSharedListForTag({required int tagId, required String tagName}) async {
    final existing = await getTagCloudListId(tagId);
    if (existing != null && existing.isNotEmpty) {
      await setTagShared(tagId, true);
      return existing;
    }
    final resp = await Cloud.client.post(
      Cloud.uri('/lists'),
      headers: Cloud.headersJson(),
      body: jsonEncode({'name': tagName.trim().isEmpty ? 'Shared List' : tagName.trim()}),
    );
    if (resp.statusCode != 200) throw 'Create list failed (HTTP ${resp.statusCode}): ${resp.body}';
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final listId = data['id'] as String;
    await setTagCloudListId(tagId, listId);
    await setTagShared(tagId, true);
    return listId;
  }

  // Invite links
  Future<String> createInviteLinkForTag({required int tagId, int ttlDays = 7}) async {
    final listId = await getTagCloudListId(tagId);
    if (listId == null || listId.isEmpty) throw 'Not shared yet';
    final resp = await Cloud.client.post(
      Cloud.uri('/lists/$listId/invite', {'ttlDays': ttlDays}),
      headers: Cloud.headersJson(),
    );
    if (resp.statusCode != 200) throw 'Invite failed (HTTP ${resp.statusCode}): ${resp.body}';
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final token = data['token'] as String;
    return 'stashr://invite?token=$token';
  }

  Future<String> acceptInviteToken(String token) async {
    final resp = await Cloud.client.post(
      Cloud.uri('/invites/accept'),
      headers: Cloud.headersJson(),
      body: jsonEncode({'token': token}),
    );
    if (resp.statusCode != 200) throw 'Accept failed (HTTP ${resp.statusCode}): ${resp.body}';
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return data['listId'] as String;
  }

  // Upload items + attachments
  Future<void> uploadAllItemsForTag(int tagId) async {
    final listId = await getTagCloudListId(tagId);
    if (listId == null || listId.isEmpty) throw 'Not shared yet';
    final items = await db.getItemsByTag(tagId, limit: 100000);
    for (final it in items) {
      await uploadOneItem(it, listId: listId);
    }
  }

  Future<void> uploadOneItem(Item it, {required String listId}) async {
    final resp = await Cloud.client.post(
      Cloud.uri('/items'),
      headers: Cloud.headersJson(),
      body: jsonEncode({
        'listId': listId,
        'title': it.title,
        'content': it.content,
        'link': it.link,
      }),
    );
    if (resp.statusCode != 200) throw 'Item create failed (HTTP ${resp.statusCode}): ${resp.body}';
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final cloudItemId = data['id'] as String;

    final atts = await db.getAttachmentsForItem(it.id);
    for (final a in atts) {
      final file = File(a.path);
      if (!file.existsSync()) continue;

      final req = http.MultipartRequest('POST', Cloud.uri('/attachments/upload'))
        ..headers.addAll({
          if (Cloud.headersJson()['Authorization'] != null)
            'Authorization': Cloud.headersJson()['Authorization']!,
        })
        ..fields['itemId'] = cloudItemId
        ..fields['mimeType'] = a.mimeType ?? 'application/octet-stream'
        ..files.add(await http.MultipartFile.fromPath('file', a.path, filename: p.basename(a.path)));

      final respUp = await req.send();
      if (respUp.statusCode != 200) {
        final txt = await respUp.stream.bytesToString();
        throw 'Attachment upload failed (HTTP ${respUp.statusCode}): $txt';
        }
    }
  }
}
