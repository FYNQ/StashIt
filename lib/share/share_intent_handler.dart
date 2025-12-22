import 'dart:async';
import 'package:flutter/services.dart';

class ShareIntentHandler {
  static const _channel = EventChannel('stashit/share');
  static final _controller = StreamController<String>.broadcast();

  static Stream<String> get stream => _controller.stream;

  static Future<void> init() async {
    _channel.receiveBroadcastStream().listen((event) {
      if (event is String && event.isNotEmpty) {
        _controller.add(event);
      }
    });
  }
}

