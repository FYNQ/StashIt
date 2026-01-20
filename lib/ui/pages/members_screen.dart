// SPDX-License-Identifier: Apache-2.0
import 'package:flutter/material.dart';
import '../../data/drift/database.dart';
import '../../util/cloud_share_service.dart';

class MembersScreen extends StatefulWidget {
  final AppDatabase database;
  final int tagId; // current tag

  const MembersScreen({
    super.key,
    required this.database,
    required this.tagId,
  });

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  late final CloudShareService _svc;
  bool _loading = true;
  String? _listId;
  List<Map<String, dynamic>> _members = const [];
  String? _myRole;

  @override
  void initState() {
    super.initState();
    _svc = CloudShareService(widget.database);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final listId = await _svc.getTagCloudListId(widget.tagId);
      if (listId == null) throw 'This tag is not shared yet.';
      _listId = listId;

      // Expect server returns: { members: [...], me: { role: '...' } }
      final data = await _svc.getListMembers(listId);
      final members = (data['members'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
      final myRole = (data['me'] as Map<String, dynamic>?)?['role'] as String?;

      // Cache my role locally for UI gating elsewhere
      if (myRole != null) {
        await _svc.setMyRoleForList(listId, myRole);
      }

      if (!mounted) return;
      setState(() {
        _members = members;
        _myRole = myRole;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _canManage => _myRole == 'OWNER' || _myRole == 'MANAGER';

  Future<void> _changeRole(String userId, String role) async {
    if (_listId == null) return;
    setState(() => _loading = true);
    try {
      await _svc.updateMemberRole(listId: _listId!, userId: userId, role: role);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _remove(String userId) async {
    if (_listId == null) return;
    setState(() => _loading = true);
    try {
      await _svc.removeMember(listId: _listId!, userId: userId);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Members${_myRole != null ? ' ($_myRole)' : ''}'),
      ),
      body: Column(
        children: [
          if (_loading) const LinearProgressIndicator(),
          Expanded(
            child: ListView.separated(
              itemCount: _members.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final m = _members[i];
                final name = (m['name'] ?? m['email'] ?? m['userId'] ?? '') as String;
                final role = (m['role'] ?? 'VIEWER') as String;
                final userId = (m['userId'] ?? '') as String;

                return ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(name.isEmpty ? userId : name),
                  subtitle: Text(role),
                  trailing: !_canManage
                      ? null
                      : PopupMenuButton<String>(
                          onSelected: (v) {
                            if (v == 'remove') {
                              _remove(userId);
                            } else {
                              _changeRole(userId, v);
                            }
                          },
                          itemBuilder: (ctx) => const [
                            PopupMenuItem(value: 'OWNER', child: Text('Owner')),
                            PopupMenuItem(value: 'MANAGER', child: Text('Manager')),
                            PopupMenuItem(value: 'EDITOR', child: Text('Editor')),
                            PopupMenuItem(value: 'VIEWER', child: Text('Viewer')),
                            PopupMenuDivider(),
                            PopupMenuItem(value: 'remove', child: Text('Remove from list')),
                          ],
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
