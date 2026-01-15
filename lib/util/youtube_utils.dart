// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Markus Kreidl

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class YouTubeMeta {
  final String url;
  final String? title;
  final String? author;
  final String? thumbnailUrl;

  YouTubeMeta({
    required this.url,
    this.title,
    this.author,
    this.thumbnailUrl,
  });
}

final _ytIdRegex = RegExp(
  r'(?:v=|v/|vi/|be/|embed/|shorts/)([A-Za-z0-9_-]{11})|(?:youtu\.be/|youtube\.com/watch\?v=)([A-Za-z0-9_-]{11})',
  caseSensitive: false,
);

bool isYouTubeUrl(String input) {
  final u = input.trim();
  return u.contains('youtu.be') || u.contains('youtube.com');
}

String? extractYouTubeId(String input) {
  final m = _ytIdRegex.firstMatch(input);
  if (m == null) return null;
  return (m.group(1) ?? m.group(2))?.trim();
}

String normalizeYouTubeWatchUrl(String url) {
  final id = extractYouTubeId(url);
  return id == null ? url.trim() : 'https://www.youtube.com/watch?v=$id';
}

Future<YouTubeMeta?> fetchYouTubeMeta(String url) async {
  try {
    final normalized = normalizeYouTubeWatchUrl(url);
    final uri = Uri.parse(
      'https://www.youtube.com/oembed?url=${Uri.encodeQueryComponent(normalized)}&format=json',
    );
    final resp = await http.get(uri).timeout(const Duration(seconds: 8));
    if (resp.statusCode != 200) {
      return YouTubeMeta(url: normalized);
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return YouTubeMeta(
      url: normalized,
      title: data['title'] as String?,
      author: data['author_name'] as String?,
      thumbnailUrl: data['thumbnail_url'] as String?,
    );
  } catch (_) {
    return null;
  }
}

Future<File?> downloadImageToTemp(String url) async {
  try {
    final resp = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200 || resp.bodyBytes.isEmpty) return null;

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/yt_thumb_${DateTime.now().microsecondsSinceEpoch}.jpg');
    await file.writeAsBytes(resp.bodyBytes);
    return file;
  } catch (_) {
    return null;
  }
}
