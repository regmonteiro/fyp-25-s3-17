import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../controller/community_controller.dart';

class FindFriendsPage extends StatefulWidget {
  const FindFriendsPage({super.key});

  @override
  _FindFriendsPageState createState() => _FindFriendsPageState();
}

class _FindFriendsPageState extends State<FindFriendsPage> {
  final TextEditingController _searchController = TextEditingController();
  final CommunityController _controller = CommunityController();
  List<QueryDocumentSnapshot> _searchResults = [];
  bool _isLoading = false;

  void _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _controller.searchUsers(query);
      setState(() {
        _searchResults = result.docs;
      });
    } catch (e) {
      print('Error searching users: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Friends'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search by name or email',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => _searchUsers(_searchController.text),
                ),
              ),
              onSubmitted: _searchUsers,
            ),
          ),
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: ListView.builder(
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final user = _searchResults[index];
                  // Exclude the current user from search results
                  if (user.id == _controller.currentUserId) {
                    return const SizedBox.shrink();
                  }

                  return ListTile(
                    title: Text(user['displayName'] ?? user['email'] ?? 'User'),
                    trailing: IconButton(
                      icon: const Icon(Icons.person_add),
                      onPressed: () async {
                        // TODO: Implement friend request logic
                        // This can be a simple 'add as friend' button for now
                        await _controller.addFriend(user.id, user['displayName'] ?? user['email']);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Added ${user['displayName']} as a friend!')),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}