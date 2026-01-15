// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Markus Kreidl

import 'package:flutter/material.dart';

class InfoScreen extends StatelessWidget {
  const InfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Info')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text('About Stashr', style: text.titleLarge),
            const SizedBox(height: 8),
            const Text(
              'Stashr helps you stash links, notes, and media quickly. '
              'Share into the app from any source, auto-tag by app, and find items fast with search & tags.',
            ),
            const SizedBox(height: 16),
            Text('Features', style: text.titleMedium),
            const SizedBox(height: 8),
            const Bullet('Share from any app'),
            const Bullet('Auto-tag by source app (Android)'),
            const Bullet('Full-text search (FTS) with fallback'),
            const Bullet('Notes, attachments, tags, and share-out'),
          ],
        ),
      ),
    );
  }
}

class Bullet extends StatelessWidget {
  final String text;
  const Bullet(this.text, {super.key});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• '),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
