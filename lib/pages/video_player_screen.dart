import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

class VideoPlayerScreen extends StatefulWidget {
  final Uint8List videoBytes;

  const VideoPlayerScreen({Key? key, required this.videoBytes}) : super(key: key);

  @override
  _VideoPlayerScreenState createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _videoPlayerController;
  late ChewieController _chewieController;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/video_${DateTime.now().millisecondsSinceEpoch}.mp4');
    await file.writeAsBytes(widget.videoBytes);

    _videoPlayerController = VideoPlayerController.file(file);
    await _videoPlayerController.initialize();

    _chewieController = ChewieController(
      videoPlayerController: _videoPlayerController,
      autoPlay: true,
      looping: false,
      allowFullScreen: true,
      allowMuting: true,
      errorBuilder: (context, errorMessage) {
        return Center(
          child: Text(
            'Error loading video: $errorMessage',
            style: const TextStyle(color: Colors.white),
          ),
        );
      },
    );

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Video'),
      ),
      body: Center(
        child: _videoPlayerController.value.isInitialized
            ? Chewie(controller: _chewieController)
            : const CircularProgressIndicator(),
      ),
    );
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    _chewieController.dispose();
    super.dispose();
  }
}