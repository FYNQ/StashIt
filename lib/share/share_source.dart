import 'dart:io';
import 'package:flutter/services.dart';

class ShareSenderInfo {
  final String? package;
  final String? label;
  const ShareSenderInfo({this.package, this.label});
}

class ShareSource {
  static const MethodChannel _ch = MethodChannel('stashit/share_meta');

  static Future<ShareSenderInfo?> lastSenderInfo() async {
    if (!Platform.isAndroid) return null;
    try {
      final map = await _ch.invokeMapMethod<String, dynamic>('getLastSenderInfo');
      if (map == null) return null;
      return ShareSenderInfo(
        package: (map['package'] as String?)?.trim(),
        label: (map['label'] as String?)?.trim(),
      );
    } catch (_) {
      return null;
    }
  }
}
