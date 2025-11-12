import 'package:flutter/material.dart';
import '../../controller/account/support_controller.dart';
import '../../../widgets/feedback_section.dart';


class SupportFeedbackPage extends StatefulWidget {
  const SupportFeedbackPage({Key? key}) : super(key: key);

  @override
  State<SupportFeedbackPage> createState() => _SupportFeedbackPageState();
}

class _SupportFeedbackPageState extends State<SupportFeedbackPage> {
  final _ctrl = SupportController();
  int _stars = 5;
  final _comment = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Support / Feedback")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text("Leave a review:", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) {
                    final idx = i + 1;
                    return IconButton(
                      icon: Icon(idx <= _stars ? Icons.star : Icons.star_border),
                      onPressed: () => setState(()=> _stars = idx),
                    );
                  }),
                ),
                TextField(
                  controller: _comment,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: "Your feedback...",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () async {
                    await _ctrl.addReview(stars: _stars, comment: _comment.text.trim());
                    _comment.clear();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Thanks for your feedback!")));
                    }
                  },
                  child: const Text("Submit"),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text("Chat with our bot"),
                  onPressed: () {
                    // Hook to your chatbot page/route.
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Open chatbot page here")));
                  },
                ),
              ],
            ),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text("What others are saying", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: StreamBuilder(
              stream: _ctrl.reviewsStream(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) return const Center(child: Text("No reviews yet."));
                return ListView(
                  children: docs.map((d) {
                    final r = d.data();
                    final stars = (r['stars'] ?? 0) as int;
                    final comment = (r['comment'] ?? '') as String;
                    return ListTile(
                      leading: Text("⭐" * stars),
                      title: Text(comment.isEmpty ? "(No comment)" : comment),
                      subtitle: Text(r['createdAt']?.toDate().toString().split(".").first ?? ""),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
