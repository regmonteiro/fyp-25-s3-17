import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_page.dart';
import '../controller/community_controller.dart';
import 'find_friends_page.dart';

class CommunityPage extends StatefulWidget {
  const CommunityPage({super.key});

  @override
  _CommunityPageState createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  final CommunityController _controller = CommunityController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Community'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // Navigate to the new FindFriendsPage
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FindFriendsPage()),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _controller.getFriendsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading friends.'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No friends added yet.'));
          }

          final friends = snapshot.data!.docs;

          return ListView.builder(
            itemCount: friends.length,
            itemBuilder: (context, index) {
              final friend = friends[index];
              return ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.blueAccent,
                  child: Icon(Icons.person, color: Colors.white),
                ),
                title: Text(friend['displayName'] ?? 'User'),
                subtitle: const Text('Tap to chat'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatPage(
                        friendUid: friend['uid'],
                        friendDisplayName: friend['displayName'],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}