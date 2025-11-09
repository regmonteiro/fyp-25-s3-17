import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';

class AssistantChat extends StatefulWidget {
  final String userEmail;
  const AssistantChat({required this.userEmail, super.key});

  @override
  State<AssistantChat> createState() => _AssistantChatState();
}

enum Sender { user, bot }

class Message {
  final Sender sender;
  final String text;
  const Message(this.sender, this.text);
}

class _AssistantChatState extends State<AssistantChat> {
  final TextEditingController _controller = TextEditingController();

  late final FirebaseFunctions _functions;
  late final stt.SpeechToText _stt;
  late final FlutterTts _tts;

  bool _listening = false;
  bool _isLoading = false;

  // Supported UI languages: "en","zh","ms","ta","ko"
  String _lang = "en";

  final List<Message> _messages = [
    const Message(Sender.bot, "Hello! I am your AI assistant.")
  ];

  // ───────────────────────── init / dispose ─────────────────────────
  @override
  void initState() {
    super.initState();

    // Tie Functions to the initialized Firebase app + correct region
    final app = Firebase.app();
    _functions = FirebaseFunctions.instanceFor(app: app, region: 'asia-southeast1');

    _stt = stt.SpeechToText();
    _tts = FlutterTts();

    _bootstrapLangThenTts();
  }

  Future<void> _bootstrapLangThenTts() async {
    // Detect device locale -> propose default
    final deviceLocale = ui.PlatformDispatcher.instance.locale; // e.g., en_SG
    final detected = _appLangFromDeviceLocale(deviceLocale);

    // Load saved preference; if none, use detected
    final p = await SharedPreferences.getInstance();
    final saved = p.getString("selectedLang");
    setState(() => _lang = (saved ?? detected));

    await _configureTtsLanguage();
  }

  @override
  void dispose() {
    _controller.dispose();
    _tts.stop();
    super.dispose();
  }

  // ───────────────────────── language helpers ─────────────────────────
  String _appLangFromDeviceLocale(ui.Locale l) {
    final lang = l.languageCode.toLowerCase();
    if (lang == 'zh') return 'zh';
    if (lang == 'ms') return 'ms';
    if (lang == 'ta') return 'ta';
    if (lang == 'ko') return 'ko';
    return 'en';
  }

  // Map UI language -> STT/TTS locale
  String _speechLocaleFor(String appLang) {
    switch (appLang) {
      case 'zh':
        return 'zh-CN';
      case 'ms':
        return 'ms-MY';
      case 'ta':
        return 'ta-IN';
      case 'ko':
        return 'ko-KR';
      default:
        return 'en-US';
    }
  }

  String _ttsLanguageFor(String appLang) => _speechLocaleFor(appLang);

  Future<void> _setLang(String code) async {
    final p = await SharedPreferences.getInstance();
    await p.setString("selectedLang", code);
    if (!mounted) return;
    setState(() => _lang = code);
    await _configureTtsLanguage();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Language set to $code")),
    );
  }

  Future<void> _configureTtsLanguage() async {
    final ttsLang = _ttsLanguageFor(_lang);
    await _tts.setLanguage(ttsLang);
    await _tts.setSpeechRate(0.50);
    await _tts.setPitch(1.0);

    // Best-effort voice match
    try {
      final voices = await _tts.getVoices;
      if (voices is List) {
        final list = voices.cast<Map>();
        final match = list.firstWhere(
          (v) => (v['locale'] as String?)?.toLowerCase() == ttsLang.toLowerCase(),
          orElse: () => list.first,
        );
        final name = match['name'];
        if (name is String && name.isNotEmpty) {
          await _tts.setVoice({'name': name, 'locale': ttsLang});
        }
      }
    } catch (_) {
      // Ignore if not supported on platform/device
    }
  }

  // ───────────────────────── translation ─────────────────────────
  Future<String> _translateText(String text, String targetLang, String sourceLang) async {
    final t = text.trim();
    if (t.isEmpty || targetLang == sourceLang) return t;

    const endpoints = <String>[
      "https://translate.terraprint.co/translate",
      "https://libretranslate.de/translate",
      "https://translate.argosopentech.com/translate",
    ];

    for (final endpoint in endpoints) {
      try {
        final res = await http
            .post(
              Uri.parse(endpoint),
              headers: {"Content-Type": "application/json"},
              body: jsonEncode({
                "q": t,
                "source": sourceLang,
                "target": targetLang,
                "format": "text",
              }),
            )
            .timeout(const Duration(seconds: 6));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final out = data["translatedText"];
          if (out is String && out.isNotEmpty) return out;
        }
      } catch (_) {
        // try next endpoint
      }
    }

    // Unofficial Google fallback
    try {
      final res = await http
          .get(Uri.parse(
              "https://translate.googleapis.com/translate_a/single?client=gtx&sl=$sourceLang&tl=$targetLang&dt=t&q=${Uri.encodeComponent(t)}"))
          .timeout(const Duration(seconds: 6));
      final data = jsonDecode(res.body);
      return (data[0] as List).map((seg) => seg[0] as String).join("");
    } catch (_) {
      return t; // graceful degrade
    }
  }

  // ───────────────────────── voice in ─────────────────────────
  Future<void> _toggleListen() async {
    if (_listening) {
      await _stt.stop();
      setState(() => _listening = false);
      return;
    }

    final available = await _stt.initialize(
      onStatus: (s) => debugPrint("stt status: $s"),
      onError: (e) => debugPrint("stt error: $e"),
    );
    if (!available) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Speech recognition not available")),
      );
      return;
    }

    // Find best locale match
    final wanted = _speechLocaleFor(_lang); // e.g. zh-CN
    final locales = await _stt.locales();
    stt.LocaleName chosen = locales.firstWhere(
      (l) => l.localeId.toLowerCase() == wanted.toLowerCase(),
      orElse: () => locales.firstWhere(
        (l) => l.localeId.toLowerCase().startsWith(wanted.split('-').first.toLowerCase()),
        orElse: () => locales.isNotEmpty ? locales.first : stt.LocaleName('en-US', 'English (US)'),
      ),
    );

    setState(() => _listening = true);

    await _stt.listen(
      localeId: chosen.localeId,
      onResult: (result) async {
        final txt = result.recognizedWords.trim();
        if (txt.isEmpty) return;
        _controller.text = txt;
        setState(() {}); // refresh send button
        if (result.finalResult) {
          await _stt.stop();
          setState(() => _listening = false);
          await _sendMessage(txt); // auto-send on final result
        }
      },
    );
  }

  // ───────────────────────── voice out ─────────────────────────
  Future<void> _speak(String text) async {
    final t = text.trim();
    if (t.isEmpty) return;
    await _configureTtsLanguage();
    await _tts.stop();
    await _tts.speak(t);
  }

  // ───────────────────────── send ─────────────────────────
  Future<void> _sendMessage(String messageText) async {
    final trimmed = messageText.trim();
    if (trimmed.isEmpty) return;

    setState(() {
      _messages.add(Message(Sender.user, trimmed));
      _isLoading = true;
      _controller.clear();
    });

    // 1) Translate to English if needed
    String msgInEnglish = trimmed;
    try {
      if (_lang != "en") {
        msgInEnglish = await _translateText(trimmed, "en", _lang);
      }
    } catch (_) {
      // If translation fails, proceed with original text
      msgInEnglish = trimmed;
    }

    // 2) Call callable function
    Map data = const {};
    try {
      final callable = _functions.httpsCallable('dialogflowGateway');
      final callResult = await callable.call({
        'userId': widget.userEmail,
        'message': msgInEnglish,
        // If your CF expects languageCode, you can send 'en' since we translate.
        'languageCode': 'en',
      });
      data = (callResult.data as Map?) ?? const {};
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(const Message(
            Sender.bot, "⚠️ I ran into a network error (call). Please try again."));
        _isLoading = false;
      });
      return;
    }

    // 3) Extract and translate back
    final raw = (data['reply'] as String?) ?? "Sorry, I didn't understand.";
    String reply = raw;
    try {
      if (_lang != "en") {
        reply = await _translateText(raw, _lang, "en");
      }
    } catch (_) {
      reply = raw; // fallback to EN
    }

    if (!mounted) return;
    setState(() {
      _messages.add(Message(Sender.bot, reply));
      _isLoading = false;
    });
    unawaited(_speak(reply));
  }

  // ───────────────────────── UI ─────────────────────────
  @override
  Widget build(BuildContext context) {
    final canSend = _controller.text.trim().isNotEmpty && !_isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text("AI Assistant"),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.language),
            initialValue: _lang,
            onSelected: _setLang,
            itemBuilder: (context) => const [
              PopupMenuItem(value: "en", child: Text("English")),
              PopupMenuItem(value: "zh", child: Text("Chinese")),
              PopupMenuItem(value: "ms", child: Text("Malay")),
              PopupMenuItem(value: "ta", child: Text("Tamil")),
              PopupMenuItem(value: "ko", child: Text("Korean")),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // messages
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(10),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final m = _messages[index];
                  final isBot = m.sender == Sender.bot;
                  return Align(
                    alignment: isBot ? Alignment.centerLeft : Alignment.centerRight,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isBot ? Colors.blue.shade200 : Colors.blue.shade400,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(m.text),
                    ),
                  );
                },
              ),
            ),

            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text("AI is thinking...", style: TextStyle(fontStyle: FontStyle.italic)),
              ),

            // input row
            Row(
              children: [
                IconButton(
                  tooltip: _listening ? "Stop" : "Speak",
                  onPressed: _isLoading ? null : _toggleListen,
                  icon: Icon(_listening ? Icons.mic : Icons.mic_none),
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textInputAction: TextInputAction.send,
                    onChanged: (_) => setState(() {}), // keeps send button in sync
                    onSubmitted: _sendMessage,
                    decoration: const InputDecoration(
                      hintText: "Type your message or tap the mic...",
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: canSend ? () => _sendMessage(_controller.text) : null,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
