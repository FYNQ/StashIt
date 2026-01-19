// SPDX-License-Identifier: Apache-2.0
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../data/drift/database.dart';
import '../../util/cloud_share_service.dart';
import '../../util/cloud_pull_service.dart';

class CloudScreen extends StatefulWidget {
  final AppDatabase database;
  const CloudScreen({super.key, required this.database});

  @override
  State<CloudScreen> createState() => _CloudScreenState();
}

class _CloudScreenState extends State<CloudScreen> {
  late final CloudShareService _svc;
  late final CloudPullService _pull;
  final _deviceCtrl = TextEditingController(text: 'device-${DateTime.now().millisecondsSinceEpoch}');
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  bool _loading = false;
  bool get _signedIn => CloudHeaders.hasBearer;

  @override
  void initState() {
    super.initState();
    _svc = CloudShareService(widget.database);
    _pull = CloudPullService(widget.database);
  }

  Future<void> _signIn() async {
    setState(() => _loading = true);
    try {
      await _svc.signInDevice(
        deviceId: _deviceCtrl.text.trim(),
        displayName: _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Signed in')));
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sign-in error: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _shareTag(Tag t) async {
    setState(() => _loading = true);
    try {
      final id = await _svc.createOrGetSharedListForTag(tagId: t.id, tagName: t.name);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Shared list ready: $id')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Share failed: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _inviteLink(Tag t) async {
    setState(() => _loading = true);
    try {
      final link = await _svc.createInviteLinkForTag(tagId: t.id);
      if (!mounted) return;
      await Share.share(link, subject: 'Join my shared list "${t.name}"');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Invite failed: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _pullForTag(Tag t) async {
    if (!_signedIn) return;
    setState(() => _loading = true);
    try {
      final listId = await _svc.getOrCreateListIdForTag(tagId: t.id, tagName: t.name);
      final since = await widget.database.getListLastSync(listId);
      await _pull.pullItemsForList(listId: listId, since: since);
      await widget.database.setListLastSync(listId, DateTime.now().toUtc());

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Pulled updates for "${t.name}".')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Pull failed: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _upload(Tag t) async {
    setState(() => _loading = true);
    try {
      final shared = await _svc.isTagShared(t.id);
      if (!shared) await _svc.createOrGetSharedListForTag(tagId: t.id, tagName: t.name);
      await _svc.uploadAllItemsForTag(t.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Uploaded items under "${t.name}".')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _deviceCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cloud & Sharing')),
      body: Column(
        children: [
          if (_loading) const LinearProgressIndicator(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: _signedIn
                ? Row(
                    children: const [
                      Icon(Icons.cloud_done, color: Colors.green),
                      SizedBox(width: 8),
                      Expanded(child: Text('Signed in')),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _deviceCtrl,
                        decoration: const InputDecoration(labelText: 'Device ID', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(labelText: 'Display name (optional)', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _emailCtrl,
                        decoration: const InputDecoration(labelText: 'Email (optional)', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(onPressed: _signIn, child: const Text('Sign in')),
                    ],
                  ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<List<Tag>>(
              stream: widget.database.watchAllTags(),
              builder: (context, snap) {
                final tags = snap.data ?? const <Tag>[];
                if (snap.connectionState == ConnectionState.waiting && tags.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (tags.isEmpty) return const Center(child: Text('Create a tag to share/pull.'));
                return ListView.separated(
                  itemCount: tags.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final t = tags[i];
                    return FutureBuilder<bool>(
                      future: _svc.isTagShared(t.id),
                      builder: (ctx, s) {
                        final isShared = s.data == true;
                        return ListTile(
                          leading: Icon(isShared ? Icons.people : Icons.list_alt),
                          title: Text(t.name),
                          subtitle: Text(isShared ? 'Shared list' : 'Not shared'),
                          trailing: Wrap(
                            spacing: 8,
                            children: [
                              OutlinedButton(onPressed: !_signedIn ? null : () => _shareTag(t), child: Text(isShared ? 'Manage' : 'Share')),
                              OutlinedButton(onPressed: !_signedIn ? null : () => _inviteLink(t), child: const Text('Invite link')),
                              OutlinedButton(onPressed: !_signedIn ? null : () => _pullForTag(t), child: const Text('Pull')),
                              FilledButton(onPressed: !_signedIn ? null : () => _upload(t), child: const Text('Upload now')),
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
