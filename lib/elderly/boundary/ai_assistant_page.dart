import 'package:flutter/material.dart';
import '../controller/ai_assistant_controller.dart';

class AIAssistantPage extends StatefulWidget {
  const AIAssistantPage({Key? key}) : super(key: key);

  @override
  State<AIAssistantPage> createState() => _AIAssistantPageState();
}

class _AIAssistantPageState extends State<AIAssistantPage> {
  // We manage UI-related state here.
  final TextEditingController _textController = TextEditingController();
  bool _isListening = false;
  String _responseText = "Hello, how can I help you?";

  // Create an instance of the controller.
  final AIAssistantController _controller = AIAssistantController();

  void _toggleListening() {
    setState(() {
      _isListening = !_isListening;
    });
    // This action could also be delegated to the controller if it involved business logic.
    if (_isListening) {
      print("Listening for voice input...");
    } else {
      print("Stopped listening.");
    }
  }

  void _sendQuery() async {
    if (_textController.text.isNotEmpty) {
      final query = _textController.text;
      _textController.clear();
      
      // Update UI to show that a response is pending.
      setState(() {
        _responseText = "Thinking...";
      });

      // Delegate the business logic to the controller.
      final response = await _controller.getAIResponse(query);
      
      // Update UI with the controller's response.
      setState(() {
        _responseText = response;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            // In a real app, this would likely navigate back.
            print("Closing AI Assistant.");
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildAIAssistantHeader(context),
            const SizedBox(height: 32),
            _buildTextInputField(),
            const SizedBox(height: 24),
            Text(
              _responseText,
              style: const TextStyle(fontSize: 18, color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _buildSuggestedPrompts(),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildAIAssistantHeader(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.purple, Colors.orange.shade700],
            ),
          ),
          child: const Icon(
            Icons.chat_bubble_outline,
            size: 60,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          "Hello, how can I help you?",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildTextInputField() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1F4287),
        borderRadius: BorderRadius.circular(30),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              decoration: const InputDecoration(
                hintText: "Type your query...",
                hintStyle: TextStyle(color: Colors.white54),
                border: InputBorder.none,
              ),
              style: const TextStyle(color: Colors.white),
            ),
          ),
          IconButton(
            icon: Icon(
              _isListening ? Icons.stop : Icons.mic,
              color: Colors.white,
            ),
            onPressed: _toggleListening,
          ),
          IconButton(
            icon: const Icon(Icons.send, color: Colors.white),
            onPressed: _sendQuery,
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestedPrompts() {
    final List<String> prompts = [
      "What is the weather today?",
      "Set a reminder for my medication",
      "Tell me a short story",
      "What are the benefits of walking?",
    ];

    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      children: prompts.map((prompt) {
        return ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2E8BC0), // Button color
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          onPressed: () {
            _textController.text = prompt;
            _sendQuery();
          },
          child: Text(prompt, style: const TextStyle(color: Colors.white)),
        );
      }).toList(),
    );
  }
}