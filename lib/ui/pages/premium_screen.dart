// SPDX-License-Identifier: Apache-2.0
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../../data/drift/database.dart';
import '../../util/purchase_service.dart';

class PremiumScreen extends StatefulWidget {
  final AppDatabase database;
  const PremiumScreen({super.key, required this.database});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  bool _loading = true;
  bool _premium = false;
  List<ProductDetails> _products = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final svc = PurchaseService.I;
    if (svc.products.isEmpty) {
      await svc.refreshProducts();
    }
    final premium = await widget.database.isPremiumActive();
    if (!mounted) return;
    setState(() {
      _products = svc.products;
      _premium = premium;
      _loading = false;
    });
  }

  ProductDetails? _byId(String id) {
    return _products.where((p) => p.id == id).cast<ProductDetails?>().firstWhere((e) => true, orElse: () => null);
  }

  Future<void> _buy(ProductDetails? p) async {
    if (p == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product not available yet.')));
      return;
    }
    setState(() => _loading = true);
    try {
      await PurchaseService.I.buy(p);
      // The purchase stream will update entitlement; we reflect optimistic UI after a short delay.
      await Future.delayed(const Duration(seconds: 1));
    } finally {
      if (!mounted) return;
      await _load();
    }
  }

  Future<void> _restore() async {
    setState(() => _loading = true);
    try {
      await PurchaseService.I.restore();
      await Future.delayed(const Duration(seconds: 1));
    } finally {
      if (!mounted) return;
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final monthly = _byId('premium_monthly');
    final yearly = _byId('premium_yearly');

    return Scaffold(
      appBar: AppBar(title: const Text('Go Premium')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_loading)
              const LinearProgressIndicator(),

            const SizedBox(height: 12),

            if (_premium)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: const Text(
                  'Premium is active! 🎉',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: const Text(
                  'Unlock Premium: cloud upload, sharing, AI features, and more.',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),

            const SizedBox(height: 16),

            // Price tiles
            Row(
              children: [
                Expanded(
                  child: _PlanCard(
                    title: 'Monthly',
                    price: monthly?.price ?? '—',
                    subtitle: 'Cancel anytime',
                    onPressed: () => _buy(monthly),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PlanCard(
                    title: 'Yearly',
                    price: yearly?.price ?? '—',
                    subtitle: 'Save 15–30%',
                    onPressed: () => _buy(yearly),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            Row(
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Restore purchases'),
                  onPressed: _restore,
                ),
                const Spacer(),
                Icon(
                  PurchaseService.I.isStoreAvailable ? Icons.store : Icons.store_outlined,
                  color: PurchaseService.I.isStoreAvailable ? Colors.green : Colors.grey,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Features list
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Premium includes:', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8),
            const _Bullet('Settings + avatar'),
            const _Bullet('Cloud upload'),
            const _Bullet('Multi-user sharing'),
            const _Bullet('AI features'),
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String title;
  final String price;
  final String subtitle;
  final VoidCallback onPressed;

  const _PlanCard({
    required this.title,
    required this.price,
    required this.subtitle,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(price, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onPressed,
              child: const Text('Upgrade'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet(this.text);

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
