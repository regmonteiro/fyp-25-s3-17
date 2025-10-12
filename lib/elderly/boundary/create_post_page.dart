import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controller/community_controller.dart';

class CreatePostPage extends StatefulWidget {
  const CreatePostPage({Key? key}) : super(key: key);

  @override
  _CreatePostPageState createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final _contentController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  Future<void> _submitPost() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // The CommunityController is now available thanks to the previous MainWrapper fix.
    final controller = context.read<CommunityController>();

    try {
      await controller.createPost(
        content: _contentController.text.trim(),
        // Image URL handling (e.g., from an image picker) would be added here
        imageUrl: null,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post published successfully!')),
      );
      // Ensure the controller resources are disposed or the page is dismissed
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to publish post: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Post'),
        backgroundColor: Colors.blueAccent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _contentController,
                maxLines: 8,
                decoration: InputDecoration(
                  hintText: "What's on your mind? Share health tips, a thought, or an update...",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Content cannot be empty.';
                  }
                  return null;
                },
              ),
              // Removed the redundant SizedBoxes to clean up space
              const SizedBox(height: 20),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton.icon(
                      onPressed: _submitPost,
                      icon: const Icon(Icons.send),
                      label: const Text('Publish Post'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
