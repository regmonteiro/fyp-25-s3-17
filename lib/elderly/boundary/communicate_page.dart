import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controller/communicate_controller.dart';
import '../../models/user_profile.dart';

class CommunicatePage extends StatefulWidget {
  const CommunicatePage({super.key});

  @override
  State<CommunicatePage> createState() => _CommunicatePageState();
}

class _CommunicatePageState extends State<CommunicatePage> {
  late final CommunicateController _controller;
  final _textCtrl = TextEditingController();
  String? _partnerUid;
  String? _myUid;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final profile = Provider.of<UserProfile>(context, listen: false);
    _controller = CommunicateController(currentUser: profile);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final profile = context.read<UserProfile>();
    final firebaseUser = _controller.firebaseUser;
    _myUid = firebaseUser?.uid ?? profile.uid;

    final partner = await _controller.resolvePartnerUid(profile);
    setState(() {
      _partnerUid = partner;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<UserProfile>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Communication Hub'),
        backgroundColor: Colors.indigo.shade700,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_partnerUid == null || _myUid == null)
              ? _buildNoPartner(profile)
              : Column(
                  children: [
                    _buildHeader(profile, _partnerUid!),
                    const Divider(height: 1),
                    Expanded(child: _buildMessageList(_myUid!, _partnerUid!)),
                    _buildComposer(_myUid!, _partnerUid!),
                  ],
                ),
    );
  }

  Widget _buildNoPartner(UserProfile user) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Text(
          user.role == 'caregiver'
              ? 'No elder is linked to your account yet.'
              : 'No caregiver is linked to your account yet.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildHeader(UserProfile user, String partnerUid) {
    final isCaregiver = user.role == 'caregiver';
    final title = isCaregiver ? 'Chat with Elder' : 'Chat with Caregiver';
    final subtitle = 'Partner UID: ${partnerUid.substring(0, partnerUid.length.clamp(0, 6))}...';

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.indigo.shade50,
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.indigo.shade800,
              )),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(color: Colors.indigo.shade400)),
        ],
      ),
    );
  }

  Widget _buildMessageList(String myUid, String partnerUid) {
    return StreamBuilder<List<ChatMessage>>(
      stream: _controller.messagesStream(myUid: myUid, partnerUid: partnerUid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error loading messages: ${snapshot.error}'));
        }
        final messages = snapshot.data ?? const <ChatMessage>[];
        if (messages.isEmpty) {
          return const Center(child: Text('Say hello 👋'));
        }
        return ListView.builder(
          reverse: true,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          itemCount: messages.length,
          itemBuilder: (_, i) {
            final m = messages[i];
            final isMe = m.senderId == myUid;
            return _bubble(m, isMe);
          },
        );
    });
  }

  Widget _bubble(ChatMessage m, bool isMe) {
    final bg = isMe ? Colors.indigo.shade300 : Colors.grey.shade300;
    final fg = isMe ? Colors.white : Colors.black87;
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 300),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(16),
            bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(0),
          ),
        ),
        child: Text(m.text, style: TextStyle(color: fg)),
      ),
    );
  }

  Widget _buildComposer(String myUid, String partnerUid) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _textCtrl,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(myUid, partnerUid),
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: Colors.indigo.shade600,
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white),
                onPressed: () => _send(myUid, partnerUid),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _send(String myUid, String partnerUid) async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    _textCtrl.clear();
    try {
      await _controller.send(myUid: myUid, partnerUid: partnerUid, text: text);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send: $e')),
      );
    }
  }
}
