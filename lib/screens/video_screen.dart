import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:dio/dio.dart';

class VideoMessageWidget extends StatefulWidget {
  final Map<String, dynamic> data;
  final String? currentUserId;

  const VideoMessageWidget(
      {super.key, required this.data, required this.currentUserId});

  @override
  State<VideoMessageWidget> createState() => _VideoMessageWidgetState();
}

class _VideoMessageWidgetState extends State<VideoMessageWidget> {
  String? localVideoPath;
  String? thumbnailPath;
  bool isDownloading = false;

  @override
  void initState() {
    super.initState();
    _generateThumbnail();
    _checkIfDownloaded();
  }

  Future<void> _checkIfDownloaded() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/${widget.data['mediaUrl'].split('/').last}');
    if (await file.exists()) {
      setState(() {
        localVideoPath = file.path;
      });
    }
  }

  Future<void> _downloadVideo() async {
    if (isDownloading) return;
    final status = await Permission.storage.request();
    if (!status.isGranted) return;

    setState(() {
      isDownloading = true;
    });

    final dir = await getApplicationDocumentsDirectory();
    final filePath = '${dir.path}/${widget.data['mediaUrl'].split('/').last}';

    await Dio().download(widget.data['mediaUrl'], filePath);

    setState(() {
      localVideoPath = filePath;
      isDownloading = false;
    });
  }

  Future<void> _generateThumbnail() async {
    final thumb = await VideoThumbnail.thumbnailFile(
      video: widget.data['mediaUrl'],
      imageFormat: ImageFormat.JPEG,
      maxHeight: 100,
      quality: 50,
    );

    if (thumb != null) {
      setState(() {
        thumbnailPath = thumb;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMe = widget.data['userId'] == widget.currentUserId;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onTap: localVideoPath != null
            ? () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        VideoPlayerScreen(videoPath: localVideoPath!),
                  ),
                );
              }
            : null,
        child: Container(
          width: MediaQuery.sizeOf(context).width * 0.7,
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          decoration: BoxDecoration(
            color: isMe ? Colors.blue[200] : Colors.grey[300],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              thumbnailPath != null
                  ? Image.file(File(thumbnailPath!))
                  : const CircularProgressIndicator(),
              const SizedBox(height: 8),
              localVideoPath == null
                  ? ElevatedButton(
                      onPressed: _downloadVideo,
                      child: isDownloading
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text("Download"),
                    )
                  : const Text("Tap to play", style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

class VideoPlayerScreen extends StatefulWidget {
  final String videoPath;
  const VideoPlayerScreen({required this.videoPath, super.key});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;

  @override
  void initState() {
    super.initState();
    _videoPlayerController = VideoPlayerController.file(File(widget.videoPath))
      ..initialize().then((_) {
        setState(() {
          _chewieController = ChewieController(
            videoPlayerController: _videoPlayerController,
            autoPlay: true,
            looping: true,
          );
        });
      });
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoPlayerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: _chewieController != null
            ? Chewie(controller: _chewieController!)
            : const CircularProgressIndicator(),
      ),
    );
  }
}
