// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Markus Kreidl

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/drift/database.dart';

class CoffeeScreen extends StatefulWidget {
  final AppDatabase database;

  const CoffeeScreen({super.key, required this.database});

  @override
  State<CoffeeScreen> createState() => _CoffeeScreenState();
}

class _CoffeeScreenState extends State<CoffeeScreen> {
  int? _donatedEur;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDonation();
  }

  Future<void> _loadDonation() async {
    final amt = await widget.database.getDonatedAmount();
    if (!mounted) return;
    setState(() {
      _donatedEur = amt;
      _loading = false;
    });
  }

  Future<void> _saveDonation(int amount) async {
    await widget.database.setDonatedAmount(amount);
    await _loadDonation();
  }

  Future<void> _openExternalUrl(String url) async {
    Uri? uri;
    try {
      uri = Uri.parse(url);
    } catch (_) {}
    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid URL')),
      );
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open: $url')),
      );
    }
  }

  Future<void> _donate(int amountEur) async {
    // TODO: Replace with your real PayPal business ID (merchant ID or email).
    const business = 'YOUR_PAYPAL_ID_OR_EMAIL';
    final url =
        'https://www.paypal.com/donate?business=$business&currency_code=EUR&amount=$amountEur';

    // Try opening PayPal. On success, persist the donation flag/amount.
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open PayPal')),
      );
      return;
    }
    // Optimistically mark as donated.
    await _saveDonation(amountEur);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Thanks for your support! (€$amountEur)')),
    );
  }

  @override
  Widget build(BuildContext context) {
    const bmcUrl = 'https://www.buymeacoffee.com/your-page'; // optional extra

    return Scaffold(
      appBar: AppBar(title: const Text('Support the project')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: LinearProgressIndicator(),
              ),

            if (!_loading && _donatedEur != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Text(
                  'Thanks for donating €$_donatedEur! ❤️',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],

            const Text(
              'If you enjoy Stashr, consider supporting development. '
              'Pick a quick PayPal amount below:',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  icon: const Icon(Icons.favorite_border),
                  label: const Text('€5'),
                  onPressed: () => _donate(5),
                ),
                FilledButton.icon(
                  icon: const Icon(Icons.favorite),
                  label: const Text('€10'),
                  onPressed: () => _donate(10),
                ),
                FilledButton.icon(
                  icon: const Icon(Icons.favorite),
                  label: const Text('€15'),
                  onPressed: () => _donate(15),
                ),
              ],
            ),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 12),

            // Optional: keep your BuyMeACoffee link as an alternative
            const Text('Prefer Buy Me a Coffee?'),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.local_cafe_outlined),
              label: const Text('Open Buy Me a Coffee'),
              onPressed: () => _openExternalUrl(bmcUrl),
            ),
          ],
        ),
      ),
    );
  }
}
