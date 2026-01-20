// SPDX-License-Identifier: Apache-2.0
import 'package:flutter/material.dart';
import '../../data/drift/database.dart';
import '../pages/info_screen.dart';
import '../pages/coffee_screen.dart';
import '../pages/premium_screen.dart';
import '../pages/settings_screen.dart';

class AppDrawer extends StatelessWidget {
  final AppDatabase db;
  const AppDrawer({super.key, required this.db});

  void _go(BuildContext context, Widget page) {
    Navigator.pop(context); // close drawer
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [scheme.primaryContainer, scheme.surface],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: scheme.primary.withOpacity(0.1),
                    child: Icon(Icons.inventory_2_outlined, size: 32, color: scheme.primary),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Stashr',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings & Cloud'),
              onTap: () => _go(context, SettingsScreen(database: db)),
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Info'),
              onTap: () => _go(context, const InfoScreen()),
            ),
            ListTile(
              leading: const Icon(Icons.local_cafe_outlined),
              title: const Text('Support / Donate'),
              onTap: () => _go(context, CoffeeScreen(database: db)),
            ),
            ListTile(
              leading: const Icon(Icons.workspace_premium_outlined),
              title: const Text('Upgrade to premium'),
              // NOTE: pass database here (no const!)
              onTap: () => _go(context, PremiumScreen(database: db)),
            ),
            const Spacer(),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text(
                'Made with ❤️',
                style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
