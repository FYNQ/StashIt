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

    // For receiving shared files when app is in background or foreground
    _intentDataStreamSubscription =
        ReceiveSharingIntent.getMediaStream().listen((List<SharedMediaFile> files) {
      setState(() {
        sharedFiles = files.map((f) => f.path).toList();
      });
      print("Shared files: $sharedFiles");
    }, onError: (err) {
      print("getMediaStream error: $err");
    });

    // For receiving shared text/links
    ReceiveSharingIntent.getTextStream().listen((String value) {
      setState(() {
        sharedText = value;
      });
      print("Shared text: $sharedText");
    }, onError: (err) {
      print("getTextStream error: $err");
    });

    // When app is launched via share
    ReceiveSharingIntent.getInitialMedia().then((List<SharedMediaFile> files) {
      if (files.isNotEmpty) {
        setState(() {
          sharedFiles = files.map((f) => f.path).toList();
        });
      }
    });

    ReceiveSharingIntent.getInitialText().then((String? text) {
      if (text != null) {
        setState(() {
          sharedText = text;
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
      appBar: AppBar(title: Text("Shared to StashIt")),
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

