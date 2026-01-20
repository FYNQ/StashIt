// SPDX-License-Identifier: Apache-2.0
import 'package:flutter/material.dart';
import '../../data/drift/database.dart';
import '../../util/cloud_share_service.dart';

class SettingsScreen extends StatefulWidget {
  final AppDatabase database;
  const SettingsScreen({super.key, required this.database});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final CloudShareService _svc;
  final _deviceCtrl = TextEditingController(text: 'device-${DateTime.now().millisecondsSinceEpoch}');
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _svc = CloudShareService(widget.database);
  }

  Future<void> _signIn() async {
    setState(() => _working = true);
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
      if (mounted) setState(() => _working = false);
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
    final signedIn = CloudHeaders.hasBearer;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings & Cloud')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_working) const LinearProgressIndicator(),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Status: ${signedIn ? 'Signed in' : 'Not signed in'}',
                style: TextStyle(
                  color: signedIn ? Colors.green : Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (!signedIn)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _deviceCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Device ID',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Display name (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _emailCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Email (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _working ? null : _signIn,
                    child: const Text('Sign in'),
                  ),
                ],
              )
            else
              const Text(
                'You are signed in. You can now use Pull/Upload in Search & Item screens.',
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }
}
