// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Markus Kreidl

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class CoffeeScreen extends StatelessWidget {
  const CoffeeScreen({super.key});

  Future<void> _open(BuildContext context, String url) async {
    Uri? uri;
    try {
      uri = Uri.parse(url);
    } catch (_) {}
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid URL')),
      );
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open: $url')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const url = 'https://www.buymeacoffee.com/your-page'; // TODO: replace
    return Scaffold(
      appBar: AppBar(title: const Text('Buy me a coffee')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'If you enjoy Stashr, consider supporting development with a coffee!',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.local_cafe_outlined),
              label: const Text('Open Buy Me a Coffee'),
              onPressed: () => _open(context, url),
            ),
          ],
        ),
      ),
    );
  }
}
