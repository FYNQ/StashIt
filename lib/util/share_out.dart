import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../data/drift/database.dart';

Rect _originFromContext(BuildContext context) {
  final box = context.findRenderObject() as RenderBox?;
  if (box == null) return const Rect.fromLTWH(0, 0, 0, 0);
  final offset = box.localToGlobal(Offset.zero);
  return offset & box.size;
}

/// Share a whole Item (title, link, content, + attachments).
Future<void> shareItem({
  required BuildContext context,
  required AppDatabase db,
  required Item item,
}) async {
  // Compose human-friendly text
  final parts = <String>[];
  if (item.title.trim().isNotEmpty) parts.add(item.title.trim());
  if ((item.link ?? '').trim().isNotEmpty) parts.add(item.link!.trim());
  if ((item.content ?? '').trim().isNotEmpty) parts.add(item.content!.trim());
  final text = parts.join('\n\n');

  // Load attachments
  final atts = await db.getAttachmentsForItem(item.id);
  final files = <XFile>[];
  for (final a in atts) {
    if (File(a.path).existsSync()) {
      files.add(XFile(a.path, mimeType: a.mimeType));
    }
  }

  // Share with or without files
  if (files.isNotEmpty) {
    await Share.shareXFiles(
      files,
      text: text.isNotEmpty ? text : null,
      subject: item.title,
      sharePositionOrigin: _originFromContext(context),
    );
  } else {
    // Fallback to text-only
    final fallback = text.isNotEmpty ? text : item.title;
    await Share.share(
      fallback,
      subject: item.title,
      sharePositionOrigin: _originFromContext(context),
    );
  }
}

/// Share arbitrary attachments + optional text/subject (useful from Add screen).
Future<void> shareAttachments({
  required BuildContext context,
  required List<AttachmentFile> attachments,
  String? text,
  String? subject,
}) async {
  final files = <XFile>[];
  for (final a in attachments) {
    if (File(a.path).existsSync()) {
      files.add(XFile(a.path, mimeType: a.mimeType));
    }
  }

  if (files.isNotEmpty) {
    await Share.shareXFiles(
      files,
      text: (text ?? '').isEmpty ? null : text,
      subject: subject,
      sharePositionOrigin: _originFromContext(context),
    );
  } else if ((text ?? '').isNotEmpty) {
    await Share.share(
      text!,
      subject: subject,
      sharePositionOrigin: _originFromContext(context),
    );
  }
}
