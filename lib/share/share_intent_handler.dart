import 'dart:async';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

class SharedData {
  final String? text;
  final List<SharedMediaFile> files;

  SharedData({this.text, this.files = const []});
}

class ShareIntentHandler {
  static final _controller = StreamController<SharedData>.broadcast();
  static Stream<SharedData> get stream => _controller.stream;

  static void init() {
    // Cold start
    ReceiveSharingIntent.instance
        .getInitialMedia()
        .then(_handleMedia);

    // While app is running
    ReceiveSharingIntent.instance
        .getMediaStream()
        .listen(_handleMedia);
  }

  static void _handleMedia(List<SharedMediaFile> files) {
    if (files.isEmpty) return;

    String? text;
    final attachments = <SharedMediaFile>[];

    for (final file in files) {
      if (file.mimeType == 'text/plain') {
        text ??= file.path; // Chrome link lives here
      } else {
        attachments.add(file);
      }
    }

    _controller.add(
      SharedData(
        text: text,
        files: attachments,
      ),
    );
  }

  static void dispose() {
    _controller.close();
  }
}

