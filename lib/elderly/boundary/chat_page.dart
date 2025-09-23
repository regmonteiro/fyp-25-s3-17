import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../controller/community_controller.dart';

class ChatPage extends StatefulWidget {
  final String friendUid;
  final String friendDisplayName;

  const ChatPage({
    super.key,
    required this.friendUid,
    required this.friendDisplayName,
  });

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final CommunityController _controller = CommunityController();
  final TextEditingController _textController = TextEditingController();

  void _sendMessage() {
    if (_textController.text.isNotEmpty) {
      _controller.sendMessage(widget.friendUid, _textController.text);
      _textController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.friendDisplayName),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _controller.getChatStream(widget.friendUid),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final messages = snapshot.data!.docs.reversed;
                return ListView(
                  children: messages.map((doc) {
                    final isCurrentUser = doc['senderId'] == _controller.currentUserId;
                    return Align(
                      alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        decoration: BoxDecoration(
                          color: isCurrentUser ? Colors.blueAccent : Colors.grey[300],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          doc['text'],
                          style: TextStyle(color: isCurrentUser ? Colors.white : Colors.black),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: InputDecoration(
                      hintText: "Send a message...",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}