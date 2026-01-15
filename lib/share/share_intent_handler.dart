// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Markus Kreidl

import 'dart:async';
import 'package:flutter/services.dart';

class ShareIntentHandler {
  static const _channel = EventChannel('stashr/share');
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

