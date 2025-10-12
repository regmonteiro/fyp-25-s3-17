import 'package:flutter/material.dart';
import '../controller/ai_assistant_controller.dart';

class AiAssistantPage extends StatefulWidget {
  const AiAssistantPage({super.key});

  @override
  State<AiAssistantPage> createState() => _AiAssistantPageState();
}

class _AiAssistantPageState extends State<AiAssistantPage> {
  late final AiAssistantController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AiAssistantController(
      dfAgentId: '8e1a3999-53bc-4ecc-b9e8-f3e7fa1dbbfb',
      chatIconUrl: 'assets/images/allCareChatbot.png',
    );
    _controller.init();
    _controller.addListener(_refresh);
  }

  @override
  void dispose() {
    _controller.removeListener(_refresh);
    _controller.dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AllCare ChatBot')),
      body: Column(
        children: [
          // Voice controls
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                IconButton(
                  tooltip: _controller.audioEnabled ? 'Mute audio' : 'Enable audio',
                  icon: Icon(_controller.audioEnabled ? Icons.volume_up : Icons.volume_off),
                  onPressed: _controller.toggleAudio,
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _controller.speechSupported ? _controller.toggleListening : null,
                  icon: Icon(_controller.isListening ? Icons.mic_off : Icons.mic),
                  label: Text(_controller.isListening ? 'Stop' : 'Speak'),
                ),
                const SizedBox(width: 16),
                if (_controller.isSpeaking) const Text('🔊 speaking...'),
                if (_controller.isListening) const Text('🎙️ listening...'),
              ],
            ),
          ),

          if (_controller.transcript.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('You said: "${_controller.transcript}"'),
              ),
            ),

          const Divider(),
          // Host the Dialogflow widget (web only; shows empty box on mobile)
          Expanded(child: _controller.dialogflowHostView()),
        ],
      ),
    );
  }
}
