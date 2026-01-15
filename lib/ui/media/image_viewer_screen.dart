// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Markus Kreidl

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

class ImageViewerScreen extends StatefulWidget {
  final List<String> paths;             // All image paths to browse
  final int initialIndex;               // Start at tapped image
  final List<Object>? heroTags;         // Optional hero tags (defaults to paths)

  const ImageViewerScreen({
    super.key,
    required this.paths,
    this.initialIndex = 0,
    this.heroTags,
  });

  @override
  State<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<ImageViewerScreen> {
  late final PageController _pageController;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, (widget.paths.length - 1).clamp(0, 1 << 30));
    _pageController = PageController(initialPage: _index);
  }

  @override
  Widget build(BuildContext context) {
    final heroTags = widget.heroTags ?? widget.paths;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_index + 1} / ${widget.paths.length}'),
      ),
      body: PhotoViewGallery.builder(
        backgroundDecoration: const BoxDecoration(color: Colors.black),
        pageController: _pageController,
        itemCount: widget.paths.length,
        onPageChanged: (i) => setState(() => _index = i),
        builder: (ctx, i) {
          final path = widget.paths[i];
          final tag = heroTags[i];

          return PhotoViewGalleryPageOptions(
            imageProvider: FileImage(File(path)),
            heroAttributes: PhotoViewHeroAttributes(tag: tag),
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 4.0,
            initialScale: PhotoViewComputedScale.contained,
          );
        },
        loadingBuilder: (ctx, evt) => const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}
