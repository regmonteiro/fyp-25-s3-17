import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../controller/communicate_controller.dart';
import '../../models/user_profile.dart';
import '../boundary/models/chat_message.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../webrtc/video_call_widgets.dart';

class CommunicatePage extends StatefulWidget {
  final UserProfile userProfile;
  final String? partnerUid;

  const CommunicatePage({
    super.key,
    required this.userProfile,
    this.partnerUid,
  });

  @override
  State<CommunicatePage> createState() => _CommunicatePageState();
}

class _CommunicatePageState extends State<CommunicatePage> {
  late final CommunicateController _controller;
  final _textCtrl = TextEditingController();

  String? _partnerUid;
  String? _myUid;
  bool _loading = true;

  // call UI
  bool _showCallInit = false;
  bool _showCall = false;
  String _callType = 'video';
  String _roomId = ''; // signaling room id for elder-caregiver direct calls

  @override
  void initState() {
    super.initState();
    _controller = CommunicateController(currentUser: widget.userProfile);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final profile = widget.userProfile;

    final firebaseUser = _controller.firebaseUser;
    _myUid = firebaseUser?.uid ?? profile.uid;

    String? partner = widget.partnerUid;
    partner ??= await _controller.resolvePartnerUid(profile);

    if (!mounted) return;
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

  // ---------- calling (shared UI) ----------
  void _openCallInit() {
    if (_myUid == null || _partnerUid == null) return;
    // Make a deterministic room id for this pair
    final a = _myUid!;
    final b = _partnerUid!;
    _roomId = (a.compareTo(b) < 0) ? 'chat_${a}_$b' : 'chat_${b}_$a';
    setState(() => _showCallInit = true);
  }

  Future<void> _onStartCall(String type) async {
    setState(() {
      _callType = type;
      _showCallInit = false;
      _showCall = true;
    });

    // optional log
    await FirebaseDatabase.instance.ref('calls').push().set({
      'consultationId': _roomId, // using same field name for simplicity
      'callType': type,
      'startedAt': DateTime.now().toIso8601String(),
      'status': 'active',
      'context': 'elder-caregiver-chat',
      'from': _myUid,
      'to': _partnerUid,
    });
  }

  Future<void> _onEndCall(int seconds) async {
    // best-effort: mark last active matching room as completed
    final callsSnap = await FirebaseDatabase.instance.ref('calls').get();
    if (callsSnap.value is Map) {
      final map = callsSnap.value as Map;
      for (final e in map.entries) {
        final v = e.value;
        if (v is Map && v['consultationId'] == _roomId && v['status'] == 'active') {
          await FirebaseDatabase.instance.ref('calls/${e.key}').update({
            'endedAt': DateTime.now().toIso8601String(),
            'duration': seconds,
            'status': 'completed',
          });
          break;
        }
      }
    }

    if (!mounted) return;
    setState(() => _showCall = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Call ended. Duration: ${seconds}s')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.userProfile;

    final scaffold = Scaffold(
      appBar: AppBar(
        title: const Text('Communication Hub'),
        actions: [
          if (!_loading && _partnerUid != null)
            IconButton(
              tooltip: 'Start call',
              onPressed: _openCallInit,
              icon: const Icon(Icons.call),
            ),
        ],
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

    return scaffold
        ._overlay(
          visible: _showCallInit,
          child: CallInitiationDialog(
            consultation: {
              'elderlyName': profile.role == 'caregiver' ? 'Elder' : 'Caregiver',
              'reason': 'Direct communication',
            },
            onCancel: () => setState(() => _showCallInit = false),
            onStart: _onStartCall,
          ),
        )
        ._overlay(
          visible: _showCall,
          child: VideoCallDialog(
            callType: _callType,
            onEnd: _onEndCall,
            withWhom: profile.role == 'caregiver' ? 'Elder' : 'Caregiver',
            topic: 'Direct communication',
            consultationId: _roomId,
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
    final prefixLen = partnerUid.length < 6 ? partnerUid.length : 6;
    final subtitle = 'Partner UID: ${partnerUid.substring(0, prefixLen)}...';

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.indigo.shade50,
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo.shade800)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(color: Colors.indigo.shade400)),
        ],
      ),
    );
  }

  Widget _buildMessageList(String myUid, String partnerUid) {
    final stream = _controller.messagesStream(myUid: myUid, partnerUid: partnerUid);

    return StreamBuilder<List<ChatMessage>>(
      stream: stream,
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final messages = snap.data ?? const <ChatMessage>[];
        if (messages.isEmpty) {
          return const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Say hello 👋')));
        }
        return ListView.builder(
          reverse: true,
          padding: const EdgeInsets.all(12),
          itemCount: messages.length,
          itemBuilder: (_, i) {
            final m = messages[i];
            final isMe = m.senderUid == myUid;
            return _bubble(m, isMe);
          },
        );
      },
    );
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
                  hintText: 'Type a message…',
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
    final message = _textCtrl.text.trim();
    if (message.isEmpty) return;

    try {
      await _controller.send(myUid: myUid, partnerUid: partnerUid, text: message);
      _textCtrl.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error sending message: $e')));
    }
  }
}

extension _OverlayX on Widget {
  Widget _overlay({required bool visible, required Widget child}) {
    if (!visible) return this;
    return Stack(children: [
      this,
      Positioned.fill(
        child: Container(
          color: Colors.black.withOpacity(0.4),
          alignment: Alignment.center,
          child: child,
        ),
      ),
    ]);
  }
}
