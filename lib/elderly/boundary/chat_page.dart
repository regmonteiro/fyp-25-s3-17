import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
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
  final TextEditingController _textController = TextEditingController();

  void _sendMessage(BuildContext context) {
    if (_textController.text.isNotEmpty) {
      // Use Provider to access the controller
      final controller = context.read<CommunityController>();
      controller.sendMessage(widget.friendUid, _textController.text);
      _textController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use Provider to access the controller
    final controller = context.read<CommunityController>();
    final currentUserId = controller.currentUserId;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.friendDisplayName),
        backgroundColor: Colors.blueAccent,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: controller.getChatStream(widget.friendUid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text('Start a conversation with ${widget.friendDisplayName}!'),
                  );
                }
                
                final messages = snapshot.data!.docs;
                
                return ListView.builder(
                  reverse: true, // Display newest messages at the bottom
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final doc = messages[index];
                    final isCurrentUser = doc['senderId'] == currentUserId;
                    
                    return Align(
                      alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        decoration: BoxDecoration(
                          color: isCurrentUser ? Colors.blueAccent : Colors.grey[300],
                          // Use dynamic corner radii for a bubble effect
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(isCurrentUser ? 12 : 0),
                            topRight: Radius.circular(isCurrentUser ? 0 : 12),
                            bottomLeft: const Radius.circular(12),
                            bottomRight: const Radius.circular(12),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            Text(
                              doc['text'],
                              style: TextStyle(color: isCurrentUser ? Colors.white : Colors.black, fontSize: 15),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              (doc['timestamp'] as Timestamp).toDate().toString().substring(11, 16), // Show time (HH:mm)
                              style: TextStyle(
                                color: isCurrentUser ? Colors.white70 : Colors.black54,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
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
                      fillColor: Colors.grey[100],
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.blueAccent,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: () => _sendMessage(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}