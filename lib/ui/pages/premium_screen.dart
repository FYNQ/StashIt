import 'package:flutter/material.dart';

class PremiumScreen extends StatelessWidget {
  const PremiumScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Upgrade to premium')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text('Go Premium ✨', style: text.headlineSmall),
            const SizedBox(height: 8),
            const Text(
              'Unlock advanced features:\n'
              '• Priority search & large indices\n'
              '• Offline backups & restore\n'
              '• Advanced media playback\n'
              '• Early access features',
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.workspace_premium_outlined),
              label: const Text('Upgrade'),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Premium flow not implemented yet.')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
