import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'html_stub.dart' if (dart.library.html) 'dart:html' as html;
import 'platform_view_stub.dart'
  if (dart.library.html) 'platform_view_web.dart' as pv;


class AiAssistantController with ChangeNotifier {
  bool audioEnabled = true;
  bool isSpeaking = false;
  bool isListening = false;
  bool speechSupported = true;
  String transcript = '';

  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();

  final String dfAgentId;
  final String chatTitle;
  final String chatIconUrl;
  final String languageCode;
  final String _viewType = 'df-messenger-host';

  AiAssistantController({
    required this.dfAgentId,
    this.chatTitle = 'AllCare Voice Assistant',
    required this.chatIconUrl,
    this.languageCode = 'en',
  });

  Future<void> init() async {
    if (!kIsWeb) {
      speechSupported = await _speech.initialize(onError: (e) {}, onStatus: (s) {});
    } else {
      speechSupported = true;
    }

    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.9);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);
    _tts.setStartHandler(() { isSpeaking = true; notifyListeners(); });
    _tts.setCompletionHandler(() { isSpeaking = false; notifyListeners(); });
    _tts.setErrorHandler((_) { isSpeaking = false; notifyListeners(); });

    if (kIsWeb) {
      _registerWebView();
      _ensureDfMessengerBootstrapped();
    }
  }

  Future<void> speak(String text) async {
    if (!audioEnabled) return;
    try { await _tts.stop(); await _tts.speak(text); } catch (_) { isSpeaking = false; notifyListeners(); }
  }

  Future<void> toggleListening() async {
    if (!speechSupported) return;
    if (isListening) { await _speech.stop(); isListening = false; notifyListeners(); return; }

    transcript = '';
    isListening = await _speech.listen(
      onResult: (r) {
        transcript = r.recognizedWords;
        notifyListeners();
        if (r.finalResult && transcript.trim().isNotEmpty) {
          sendMessageToBot(transcript.trim());
        }
      },
      listenMode: stt.ListenMode.confirmation,
      localeId: 'en_US',
      partialResults: true,
    );
    notifyListeners();
  }

  Future<void> stopListening() async { if (!isListening) return; await _speech.stop(); isListening = false; notifyListeners(); }
  Future<void> toggleAudio() async { if (isSpeaking) { await _tts.stop(); isSpeaking = false; } audioEnabled = !audioEnabled; notifyListeners(); }

  void _registerWebView() {
  if (!kIsWeb) return;

  pv.registerViewFactory(_viewType, (int _) {
    final container = html.DivElement()
      ..style.width = '100%'
      ..style.height = '100%';
    return container;
  });
}

  void _ensureDfMessengerBootstrapped() {
    if (!kIsWeb) return;

    final existsScript = html.document.querySelector(
      "script[src*='dialogflow-console/fast/messenger/bootstrap.js']",
    );
    if (existsScript == null) {
      final s = html.ScriptElement()
        ..src = 'https://www.gstatic.com/dialogflow-console/fast/messenger/bootstrap.js?v=1'
        ..async = true;
      html.document.body?.append(s);
    }

    final existingDf = html.document.querySelector('df-messenger');
    if (existingDf != null) return;

    final df = html.Element.tag('df-messenger')
      ..setAttribute('intent', 'WELCOME')
      ..setAttribute('chat-title', chatTitle)
      ..setAttribute('agent-id', dfAgentId)
      ..setAttribute('language-code', languageCode)
      ..setAttribute('expand', 'true');

    if (chatIconUrl.isNotEmpty) df.setAttribute('chat-icon', chatIconUrl);

    html.document.body?.append(df);

    df.addEventListener('df-response-received', (event) {
      if (!audioEnabled) return;
      try {
        final detail = (event as dynamic).detail;
        final response = detail?['response'];
        final queryResult = response?['queryResult'];
        final msgs = (queryResult?['fulfillmentMessages'] as List?) ?? [];
        final lines = <String>[];
        for (final m in msgs) {
          final text = (m['text']?['text'] as List?)?.cast<String>() ?? const [];
          if (text.isNotEmpty) lines.add(text.first);
        }
        final say = lines.join('. ');
        if (say.isNotEmpty) speak(say);
      } catch (_) {}
    });
  }

  void sendMessageToBot(String message) {
    if (!kIsWeb) { debugPrint('Mobile stub: send "$message" to Dialogflow via API.'); return; }
    try {
      final dfMessenger = html.document.querySelector('df-messenger');
      final sr = (dfMessenger as dynamic)?.shadowRoot;
      if (dfMessenger == null || sr == null) { debugPrint('df-messenger or shadowRoot not found'); return; }
      final chat = sr.querySelector('df-messenger-chat');
      final chatSR = (chat as dynamic)?.shadowRoot;
      if (chat == null || chatSR == null) { debugPrint('df-messenger-chat not found'); return; }
      final userInput = chatSR.querySelector('df-messenger-user-input');
      final uiSR = (userInput as dynamic)?.shadowRoot;
      if (userInput == null || uiSR == null) { debugPrint('df-messenger-user-input not found'); return; }

      final inputEl = uiSR.querySelector('input') as html.InputElement?;
      final sendBtn = uiSR.querySelector('button') as html.ButtonElement?;
      if (inputEl == null || sendBtn == null) { debugPrint('input or send button not found'); return; }

      inputEl.value = message;
      inputEl.dispatchEvent(html.Event('input', bubbles: true));
      Future.delayed(const Duration(milliseconds: 150), () => sendBtn.click());
    } catch (e) { debugPrint('sendMessageToBot error: $e'); }
  }

  Widget dialogflowHostView({double height = 0}) {
    if (!kIsWeb) return const SizedBox.shrink();
    return SizedBox(height: height, width: double.infinity, child: HtmlElementView(viewType: _viewType));
  }

  @override
  void dispose() {
    _tts.stop();
    _speech.cancel();
    super.dispose();
  }
}
