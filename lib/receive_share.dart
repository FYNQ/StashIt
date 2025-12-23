import 'dart:async';
import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

class ReceiveSharePage extends StatefulWidget {
  @override
  _ReceiveSharePageState createState() => _ReceiveSharePageState();
}

class _ReceiveSharePageState extends State<ReceiveSharePage> {
  StreamSubscription? _intentDataStreamSubscription;
  List<String> sharedFiles = [];
  String? sharedText;

  @override
  void initState() {
    super.initState();

    // Unified stream for both files and text
    _intentDataStreamSubscription =
        ReceiveSharingIntent.instance.getMediaStream().listen((List<SharedMediaFile> files) {
      setState(() {
        // If it's text, we extract it from the path
        if (files.isNotEmpty && (files.first.type == SharedMediaType.text || files.first.type == SharedMediaType.url)) {
          sharedText = files.first.path;
        } else {
          sharedFiles = files.map((f) => f.path).toList();
        }
      });
    }, onError: (err) {
      print("getMediaStream error: $err");
    });

    // Handle initial media/text
    ReceiveSharingIntent.instance.getInitialMedia().then((List<SharedMediaFile> files) {
      if (files.isNotEmpty) {
        setState(() {
          if (files.first.type == SharedMediaType.text || files.first.type == SharedMediaType.url) {
            sharedText = files.first.path;
          } else {
            sharedFiles = files.map((f) => f.path).toList();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _intentDataStreamSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Shared to StashIt")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (sharedText != null)
              Text("Shared Text/Link: $sharedText"),
            if (sharedFiles.isNotEmpty)
              ...sharedFiles.map((path) => Text("Shared File: $path")).toList(),
          ],
        ),
      ),
    );
  }
}
