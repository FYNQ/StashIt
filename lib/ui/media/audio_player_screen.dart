// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Markus Kreidl

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

class AudioPlayerScreen extends StatefulWidget {
  final String filePath;

  const AudioPlayerScreen({Key? key, required this.filePath}) : super(key: key);

  @override
  State<AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends State<AudioPlayerScreen> {
  late final Player _player;
  bool _ready = false;
  Duration _dur = Duration.zero;
  Duration _pos = Duration.zero;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _player = Player();

    _player.stream.position.listen((p) {
      if (!mounted) return;
      setState(() => _pos = p);
    });
    _player.stream.duration.listen((d) {
      if (!mounted) return;
      setState(() => _dur = d);
    });
    _player.stream.playing.listen((v) {
      if (!mounted) return;
      setState(() => _playing = v);
    });

    _init();
  }

  Future<void> _init() async {
    final file = File(widget.filePath);
    if (!file.existsSync()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Audio file not found')),
        );
      }
      return;
    }
    try {
      await _player.open(Media(widget.filePath));
      if (mounted) setState(() => _ready = true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load audio: $e')),
      );
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return h > 0 ? '${two(h)}:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Audio')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.audiotrack, size: 96),
            const SizedBox(height: 16),
            if (_ready) ...[
              Slider(
                value: _pos.inMilliseconds.clamp(0, _dur.inMilliseconds).toDouble(),
                onChanged: (v) async {
                  await _player.seek(Duration(milliseconds: v.floor()));
                },
                min: 0,
                max: _dur.inMilliseconds.toDouble(),
              ),
              Text('${_fmt(_pos)} / ${_fmt(_dur)}'),
            ],
            ElevatedButton(
              onPressed: !_ready ? null : () => _playing ? _player.pause() : _player.play(),
              child: Text(_playing ? 'Pause' : 'Play'),
            ),
          ],
        ),
      ),
    );
  }
}
