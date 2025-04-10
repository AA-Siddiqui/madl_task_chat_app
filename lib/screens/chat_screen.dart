import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../auth/auth_service.dart';
import '../widgets/message_bubble.dart';

class ChatScreen extends StatelessWidget {
  final messageCtrl = TextEditingController();

  ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final user = auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text("Global Chat"),
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
                  children: messages.map((msg) {
                    final data = msg.data() as Map<String, dynamic>;
                    return MessageBubble(
                      text: data['text'],
                      isMe: data['userId'] == user?.uid,
                    );
                  }).toList(),
                );
              },
            ),
          ),
          Divider(height: 1),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Expanded(
                    child: TextField(
                        controller: messageCtrl,
                        decoration:
                            InputDecoration(hintText: 'Send a message...'))),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: () {
                    if (messageCtrl.text.trim().isEmpty) return;
                    FirebaseFirestore.instance.collection('messages').add({
                      'text': messageCtrl.text,
                      'userId': user?.uid,
                      'timestamp': FieldValue.serverTimestamp(),
                    });
                    messageCtrl.clear();
                  },
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
