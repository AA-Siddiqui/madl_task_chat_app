import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get_thumbnail_video/video_thumbnail.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:task_chat_app/screens/video_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import '../auth/auth_service.dart';
import '../widgets/message_bubble.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final messageCtrl = TextEditingController();

  Future<Position> getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    return await Geolocator.getCurrentPosition();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final user = auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text("Chat"),
        actions: [
          IconButton(onPressed: () => auth.signOut(), icon: Icon(Icons.logout))
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }
                final messages = snapshot.data!.docs;
                return ListView(
                  reverse: true,
                  children: messages.map((message) {
                    final data = message.data() as Map<String, dynamic>;

                    switch (data['type']) {
                      case 'video':
                        return VideoMessageWidget(
                          data: data,
                          currentUserId: user?.uid,
                        );

                      case 'image':
                        return ImageMessageWidget(
                          data: data,
                          isMe: data['userId'] == user?.uid,
                        );
                      case 'location':
                        GeoPoint geoPoint = message['location'];
                        double lat = geoPoint.latitude;
                        double lng = geoPoint.longitude;
                        return Align(
                          alignment: data['userId'] == user?.uid
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: GestureDetector(
                            onTap: () {
                              String googleMapsUrl =
                                  'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
                              launchUrl(Uri.parse(googleMapsUrl));
                            },
                            child: Container(
                              width: MediaQuery.sizeOf(context).width * 0.7,
                              height: MediaQuery.sizeOf(context).width * 0.5,
                              padding: EdgeInsets.all(12),
                              margin: EdgeInsets.symmetric(
                                  vertical: 4, horizontal: 8),
                              decoration: BoxDecoration(
                                color: data['userId'] == user?.uid
                                    ? Colors.blue[200]
                                    : Colors.grey[300],
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: FlutterMap(
                                options: MapOptions(
                                  cameraConstraint:
                                      CameraConstraint.containCenter(
                                    bounds: LatLngBounds(
                                      LatLng(
                                        lat,
                                        lng,
                                      ),
                                      LatLng(
                                        lat,
                                        lng,
                                      ),
                                    ),
                                  ),
                                  onTap: (tapPosition, point) {
                                    String googleMapsUrl =
                                        'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
                                    launchUrl(Uri.parse(googleMapsUrl));
                                  },
                                  initialCenter: LatLng(
                                    lat,
                                    lng,
                                  ),
                                  initialZoom: 15,
                                ),
                                children: [
                                  TileLayer(
                                    urlTemplate:
                                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                  ),
                                  MarkerLayer(
                                    markers: [
                                      Marker(
                                        point: LatLng(
                                          lat,
                                          lng,
                                        ),
                                        child: Icon(
                                          Icons.location_pin,
                                          color: Colors.blue,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      default:
                        break;
                    }

                    return MessageBubble(
                      data: data,
                      isMe: data['userId'] == user?.uid,
                    );
                  }).toList(),
                );
              },
            ),
          ),
          Divider(height: 1),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 8,
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: () {
                    showModalBottomSheet(
                      isDismissible: true,
                      context: context,
                      builder: (context) {
                        return Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: Icon(Icons.upload_file),
                                onPressed: () {
                                  _uploadImage(context);
                                  Navigator.pop(context);
                                },
                              ),
                              IconButton(
                                icon: Icon(Icons.camera),
                                onPressed: () {
                                  _uploadImage(
                                    context,
                                    ImageSource.camera,
                                  );
                                  Navigator.pop(context);
                                },
                              ),
                              IconButton(
                                icon: Icon(Icons.video_call),
                                onPressed: () {
                                  _uploadVideo(context);
                                  Navigator.pop(context);
                                },
                              ),
                              IconButton(
                                icon: Icon(Icons.video_camera_back),
                                onPressed: () {
                                  _uploadVideo(
                                    context,
                                    ImageSource.camera,
                                  );
                                  Navigator.pop(context);
                                },
                              ),
                              IconButton(
                                icon: Icon(Icons.location_pin),
                                onPressed: () async {
                                  Position position =
                                      await getCurrentLocation();
                                  FirebaseFirestore.instance
                                      .collection('messages')
                                      .add({
                                    'type': 'location',
                                    'location': GeoPoint(
                                        position.latitude, position.longitude),
                                    'timestamp': FieldValue.serverTimestamp(),
                                    'userId': user?.uid,
                                  });
                                  Navigator.pop(context);
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                  icon: Icon(Icons.attachment),
                ),
                Expanded(
                  child: TextField(
                    controller: messageCtrl,
                    decoration: InputDecoration(
                      hintText: 'Send a message...',
                      border: InputBorder.none,
                    ),
                    onSubmitted: (value) {
                      _sendMessage();
                      FocusScope.of(context).unfocus();
                    },
                    textInputAction: TextInputAction.send,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: _sendMessage,
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  void _sendMessage() {
    if (messageCtrl.text.trim().isEmpty) return;
    final auth = Provider.of<AuthService>(context, listen: false);
    final user = auth.currentUser;
    FirebaseFirestore.instance.collection('messages').add({
      'text': messageCtrl.text,
      'type': 'text',
      'userId': user?.uid,
      'timestamp': FieldValue.serverTimestamp(),
    });
    messageCtrl.clear();
  }

  void _uploadImage(BuildContext context,
      [ImageSource source = ImageSource.gallery]) async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final user = auth.currentUser;
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);

    if (pickedFile != null) {
      final file = File(pickedFile.path);
      final fileName =
          '${user?.uid}/${DateTime.now().millisecondsSinceEpoch}.png';

      final storageResponse = await Supabase.instance.client.storage
          .from('images')
          .upload(fileName, file);

      print('Upload response: $storageResponse');

      if (storageResponse.isNotEmpty) {
        final publicUrl = Supabase.instance.client.storage
            .from('images')
            .getPublicUrl(fileName);

        await FirebaseFirestore.instance.collection('messages').add({
          'userId': user?.uid,
          'timestamp': FieldValue.serverTimestamp(),
          'mediaUrl': publicUrl,
          'type': 'image',
        });
        setState(() {});
      }
    }
  }

  void _uploadVideo(BuildContext context,
      [ImageSource source = ImageSource.gallery]) async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final user = auth.currentUser;
    final picker = ImagePicker();
    final pickedFile = await picker.pickVideo(source: source);

    if (pickedFile != null) {
      final file = File(pickedFile.path);
      final fileName = '${user?.uid}/${DateTime.now().millisecondsSinceEpoch}';
      final thumbnailImageRequest = VideoThumbnail.thumbnailFile(
        video: pickedFile.path,
        maxHeight: 200,
        quality: 50,
      ).then(
        (value) async {
          return await Supabase.instance.client.storage
              .from('thumbnails')
              .upload(
                '$fileName.png',
                File(value.path),
              );
        },
      );

      final videoStorageResponse = await Supabase.instance.client.storage
          .from('videos')
          .upload("$fileName.mp4", file);

      final thumbnailImageResponse = await thumbnailImageRequest;

      print('Video upload response: $videoStorageResponse');
      print('Image upload response: $thumbnailImageResponse');

      if (videoStorageResponse.isNotEmpty) {
        final videoUrl = Supabase.instance.client.storage
            .from('videos')
            .getPublicUrl("$fileName.mp4");
        final thumbnailUrl = Supabase.instance.client.storage
            .from('thumbnails')
            .getPublicUrl("$fileName.png");

        await FirebaseFirestore.instance.collection('messages').add({
          'userId': user?.uid,
          'timestamp': FieldValue.serverTimestamp(),
          'mediaUrl': videoUrl,
          'thumbnailUrl': thumbnailUrl,
          'type': 'video',
        });
        setState(() {});
      }
    }
  }
}

class ImageMessageWidget extends StatelessWidget {
  const ImageMessageWidget({
    super.key,
    required this.data,
    required this.isMe,
  });

  final Map<String, dynamic> data;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => Scaffold(
                backgroundColor: Colors.black,
                body: Center(
                  child: Image.network(data['mediaUrl']),
                ),
              ),
            ),
          );
        },
        child: Container(
          width: MediaQuery.sizeOf(context).width * 0.7,
          height: MediaQuery.sizeOf(context).width * 0.5,
          padding: EdgeInsets.all(12),
          margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          decoration: BoxDecoration(
            color: isMe ? Colors.blue[200] : Colors.grey[300],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Image.network(
            data['mediaUrl'],
            fit: BoxFit.fitWidth,
          ),
        ),
      ),
    );
  }
}
