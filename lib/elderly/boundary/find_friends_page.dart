import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controller/community_controller.dart';
import '../../models/user_profile.dart';

class FindFriendsPage extends StatefulWidget {
  const FindFriendsPage({super.key});

  @override
  _FindFriendsPageState createState() => _FindFriendsPageState();
}

class _FindFriendsPageState extends State<FindFriendsPage> {
  final TextEditingController _searchController = TextEditingController();

  List<UserProfile> _searchResults = [];
  bool _isLoading = false;

  void _searchUsers(BuildContext context, String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final controller = context.read<CommunityController>();

    try {
      final result = await controller.searchUsers(query);
      
      setState(() {

        _searchResults = result
          .where((user) => user.uid != controller.currentUserId)
          .toList();
      });
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error searching users. Check your connection.')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _linkFriend(BuildContext context, String friendId, String displayName) async {
    final controller = context.read<CommunityController>();
    try {
      await controller.linkUserForChat(friendId);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$displayName is now linked! You can start chatting.')),
        );
      }
      _searchUsers(context, _searchController.text);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to link user: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Connections'),
        backgroundColor: Colors.blueAccent,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search by First Name or Email',
                hintText: 'e.g., Jane or jane@example.com',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.search, color: Colors.blueAccent),
              ),
              onSubmitted: (query) => _searchUsers(context, query),
            ),
          ),
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_searchResults.isEmpty && _searchController.text.isNotEmpty)
            const Expanded(child: Center(child: Text('No users found matching your search.')))
          else
            Expanded(
              child: ListView.builder(
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final userProfile = _searchResults[index];
                  final displayName = userProfile.displayName;

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue.shade100,
                      child: Text(
                        displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                        style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(displayName),
                    subtitle: Text(userProfile.role ?? 'User'),
                    trailing: IconButton(
                      icon: const Icon(Icons.link, color: Colors.green),
                      onPressed: () => _linkFriend(context, userProfile.uid, displayName),
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
