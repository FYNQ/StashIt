import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class LinkViewerScreen extends StatelessWidget {
  final String url;
  const LinkViewerScreen({super.key, required this.url});

  Future<void> _openExternal(BuildContext context) async {
    final u = url.trim();
    if (u.isEmpty) return;
    final uri = Uri.tryParse(u);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid URL')),
      );
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not launch: $u')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final display = url.trim();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Link'),
        actions: [
          IconButton(
            tooltip: 'Open externally',
            icon: const Icon(Icons.open_in_new),
            onPressed: () => _openExternal(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: InkWell(
          onTap: () => _openExternal(context),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.link),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  display.isEmpty ? '(empty)' : display,
                  style: const TextStyle(
                    decoration: TextDecoration.underline,
                    color: Colors.blueAccent,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
