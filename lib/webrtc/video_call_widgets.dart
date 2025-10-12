import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'rt_signaling.dart';

/// Optional hint for labeling the other participant
enum UserType { elderly, caregiver, doctor }

/// ------------------------------
/// Call Initiation (select type)
/// ------------------------------
class CallInitiationDialog extends StatefulWidget {
  final Map<String, dynamic>? consultation; // {elderlyName, reason, ...}
  final VoidCallback onCancel;
  final Future<void> Function(String type) onStart; // 'video' | 'audio'

  const CallInitiationDialog({
    super.key,
    required this.consultation,
    required this.onCancel,
    required this.onStart,
  });

  @override
  State<CallInitiationDialog> createState() => _CallInitiationDialogState();
}

class _CallInitiationDialogState extends State<CallInitiationDialog> {
  String _type = 'video';

  @override
  Widget build(BuildContext context) {
    final elderlyName = (widget.consultation?['elderlyName'] ?? 'Elderly User').toString();
    final reason = (widget.consultation?['reason'] ?? widget.consultation?['symptoms'] ?? 'General Checkup').toString();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Material(
          color: Colors.white,
          elevation: 16,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                const Expanded(
                  child: Text('Start Consultation Call',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                ),
                IconButton(onPressed: widget.onCancel, icon: const Icon(Icons.close)),
              ]),
              const SizedBox(height: 8),

              // Consultation snippet
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.black12),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _kv('Patient:', elderlyName),
                  const SizedBox(height: 6),
                  _kv('Reason:', reason),
                ]),
              ),

              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Select Call Type', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 8),

              _typeOption(
                selected: _type == 'video',
                icon: '📹',
                title: 'Video Call',
                subtitle: 'Face-to-face consultation with video',
                onTap: () => setState(() => _type = 'video'),
              ),
              const SizedBox(height: 10),
              _typeOption(
                selected: _type == 'audio',
                icon: '📞',
                title: 'Voice Call',
                subtitle: 'Audio-only consultation',
                onTap: () => setState(() => _type = 'audio'),
              ),

              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Call Features', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 6),
              const Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• 🔒 Secure encrypted connection'),
                    Text('• 🎤 Real-time audio communication'),
                    Text('• ⏱️ Call duration tracking'),
                    Text('• 💾 Automatic call logging'),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(onPressed: widget.onCancel, child: const Text('Cancel')),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () async => widget.onStart(_type),
                  child: Text('Start ${_type == 'video' ? 'Video' : 'Voice'} Call'),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _typeOption({
    required bool selected,
    required String icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: selected ? Colors.indigo : Colors.black12),
          borderRadius: BorderRadius.circular(12),
          color: selected ? Colors.indigo.withOpacity(0.06) : Colors.white,
        ),
        child: Row(children: [
          Text(icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(color: Colors.black54)),
            ]),
          ),
          if (selected) const Icon(Icons.check_circle, color: Colors.indigo),
        ]),
      ),
    );
  }

  Widget _kv(String k, String v) => Row(children: [
        SizedBox(width: 90, child: Text(k, style: const TextStyle(fontWeight: FontWeight.w700))),
        Expanded(child: Text(v)),
      ]);
}

/// ------------------------------
/// Video/Audio Call (WebRTC)
/// ------------------------------
class VideoCallDialog extends StatefulWidget {
  /// 'video' or 'audio'
  final String callType;

  /// Called when the call ends; gives duration in seconds
  final Future<void> Function(int seconds) onEnd;

  /// Display info
  final String withWhom;
  final String topic;

  /// Room id key used by RTDB signaling: consultations/{id}/webrtc/...
  final String consultationId;

  const VideoCallDialog({
    super.key,
    required this.callType,
    required this.onEnd,
    required this.withWhom,
    required this.topic,
    required this.consultationId,
  });

  @override
  State<VideoCallDialog> createState() => _VideoCallDialogState();
}

class _VideoCallDialogState extends State<VideoCallDialog> {
  String _type = 'video';
  String _status = 'connecting'; // connecting | active | ended
  int _seconds = 0;

  bool _micOn = true;
  bool _camOn = true;

  Timer? _durationTimer;

  RTCPeerConnection? _pc;
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();
  MediaStream? _localStream;

  RTSignaling? _sig;
  final _auth = FirebaseAuth.instance;

  final Map<String, dynamic> _configuration = const {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
    ],
  };

  final Map<String, dynamic> _constraintsVideo = const {
    'audio': true,
    'video': {
      'facingMode': 'user',
      'width': {'ideal': 1280},
      'height': {'ideal': 720},
      'frameRate': {'ideal': 30},
    }
  };

  final Map<String, dynamic> _constraintsAudioOnly = const {
    'audio': true,
    'video': false,
  };

  @override
  void initState() {
    super.initState();
    _type = widget.callType;
    _init();
  }

  Future<void> _init() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();

    final me = _auth.currentUser?.uid ?? 'anonymous';
    _sig = RTSignaling(consultationId: widget.consultationId, myself: me);

    final pc = await createPeerConnection(_configuration);

    // Remote media
    pc.onTrack = (RTCTrackEvent e) {
      if (e.streams.isNotEmpty) {
        _remoteRenderer.srcObject = e.streams.first;
      }
    };

    // Local ICE -> RTDB (note: sdpMLineIndex with capital L)
    pc.onIceCandidate = (RTCIceCandidate cand) async {
      if (cand.candidate != null && _sig != null) {
        await _sig!.postCandidate({
          'candidate': cand.candidate,
          'sdpMid': cand.sdpMid,
          'sdpMLineIndex': cand.sdpMLineIndex,
        });
      }
    };

    pc.onConnectionState = (state) {
      if (!mounted) return;
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        setState(() => _status = 'active');
        _startTimer();
      }
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        // optional: handle reconnect/auto-end
      }
    };

    // Local media
    final media = await navigator.mediaDevices
        .getUserMedia(_type == 'video' ? _constraintsVideo : _constraintsAudioOnly);
    _localStream = media;
    _localRenderer.srcObject = media;

    // Add local tracks
    for (final t in media.getTracks()) {
      await pc.addTrack(t, media);
    }

    _pc = pc;
    _attachSignaling();
  }

  void _attachSignaling() {
    final sig = _sig!;
    final pc = _pc!;

    // Offer listener (callee path)
    sig.onOffer((offerData) async {
      final by = (offerData['by'] ?? '').toString();
      if (by == (_auth.currentUser?.uid ?? 'anonymous')) return;

      final String? sdp = offerData['sdp'] as String?;
      final String? type = offerData['type'] as String?;
      if (sdp != null && type == 'offer') {
        await pc.setRemoteDescription(RTCSessionDescription(sdp, type));
        final answer = await pc.createAnswer();
        await pc.setLocalDescription(answer);
        await sig.postAnswer({'sdp': answer.sdp, 'type': answer.type});
      }
    });

    // Answer listener (caller path)
    sig.onAnswer((answerData) async {
      final by = (answerData['by'] ?? '').toString();
      if (by == (_auth.currentUser?.uid ?? 'anonymous')) return;

      final String? sdp = answerData['sdp'] as String?;
      final String? type = answerData['type'] as String?;
      if (sdp != null && type == 'answer') {
        await pc.setRemoteDescription(RTCSessionDescription(sdp, type));
      }
    });

    // Candidate listener (both)
    sig.onCandidate((cand) async {
      final by = (cand['by'] ?? '').toString();
      if (by == (_auth.currentUser?.uid ?? 'anonymous')) return;

      final String? candidate = cand['candidate'] as String?;
      final String? sdpMid = cand['sdpMid'] as String?;
      final dynamic rawIdx = cand['sdpMLineIndex'];
      final int? sdpMLineIndex = rawIdx is int ? rawIdx : int.tryParse('$rawIdx');

      if (candidate != null) {
        final ice = RTCIceCandidate(candidate, sdpMid, sdpMLineIndex);
        await pc.addCandidate(ice);
      }
    });

    _beCallerOrCallee();
  }

  /// If an offer already exists in DB, we are callee; otherwise we create/post offer.
  Future<void> _beCallerOrCallee() async {
    final offerSnap = await FirebaseDatabase.instance
        .ref('consultations/${widget.consultationId}/webrtc/offer')
        .get();

    if (offerSnap.exists && offerSnap.value is Map) {
      setState(() => _status = 'connecting'); // callee path; onOffer will handle
      return;
    }

    // Caller
    final offer = await _pc!.createOffer();
    await _pc!.setLocalDescription(offer);
    await _sig!.postOffer({'sdp': offer.sdp, 'type': offer.type});
    setState(() => _status = 'connecting');
  }

  void _startTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _status != 'active') return;
      setState(() => _seconds++);
    });
  }

  Future<void> _endCall() async {
    setState(() => _status = 'ended');
    await Future.delayed(const Duration(milliseconds: 200));
    await widget.onEnd(_seconds);
  }

  void _toggleMic() {
    _micOn = !_micOn;
    for (final t in _localStream?.getAudioTracks() ?? const []) {
      t.enabled = _micOn;
    }
    setState(() {});
  }

  void _toggleCam() {
    if (_type != 'video') return;
    _camOn = !_camOn;
    for (final t in _localStream?.getVideoTracks() ?? const []) {
      t.enabled = _camOn;
    }
    setState(() {});
  }

  void _switchToAudio() {
    if (_type == 'audio') return;
    _type = 'audio';
    _camOn = false;
    for (final t in _localStream?.getVideoTracks() ?? const []) {
      t.stop();
    }
    setState(() {});
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _sig?.dispose();
    _pc?.close();
    _localStream?.getTracks().forEach((t) => t.stop());
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  String _fmt(int s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    return '$m:$ss';
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980, maxHeight: 680),
        child: Material(
          color: Colors.white,
          elevation: 18,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Expanded(
                  child: Text(
                    _type == 'video' ? '📹 Video Call' : '📞 Audio Call',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                Chip(
                  label: Text(_status.toUpperCase()),
                  backgroundColor: _status == 'active'
                      ? Colors.green.shade600
                      : (_status == 'connecting' ? Colors.orange.shade600 : Colors.grey),
                  labelStyle: const TextStyle(color: Colors.white),
                ),
              ]),
              const SizedBox(height: 12),

              // Remote view
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: _type == 'video' ? Colors.black : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: _type == 'video'
                      ? RTCVideoView(
                          _remoteRenderer,
                          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                        )
                      : const Text('Audio Only', style: TextStyle(color: Colors.black54)),
                ),
              ),

              if (_type == 'video') ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Container(
                    width: 160,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white10),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: RTCVideoView(
                      _localRenderer,
                      mirror: true,
                      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 10),
              Row(children: [
                Chip(label: Text(_type == 'video' ? '📹 Video' : '📞 Audio')),
                const SizedBox(width: 8),
                Chip(label: Text(_status == 'active' ? _fmt(_seconds) : '00:00')),
                const Spacer(),
                Flexible(
                  child: Text(
                    'With: ${widget.withWhom} • Consultation: ${widget.topic}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ]),
              const SizedBox(height: 12),

              Wrap(
                spacing: 10,
                children: [
                  ElevatedButton.icon(
                    onPressed: _toggleMic,
                    icon: Icon(_micOn ? Icons.mic : Icons.mic_off),
                    label: Text(_micOn ? 'Mic On' : 'Mic Off'),
                  ),
                  if (_type == 'video')
                    ElevatedButton.icon(
                      onPressed: _toggleCam,
                      icon: Icon(_camOn ? Icons.videocam : Icons.videocam_off),
                      label: Text(_camOn ? 'Camera On' : 'Camera Off'),
                    ),
                  if (_type == 'video')
                    OutlinedButton.icon(
                      onPressed: _switchToAudio,
                      icon: const Icon(Icons.call),
                      label: const Text('Switch to Audio'),
                    ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: _endCall,
                    icon: const Icon(Icons.call_end, color: Colors.white),
                    label: const Text('End Call', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// ------------------------------
/// Full-screen wrapper (easy push)
/// ------------------------------
class CallScreen extends StatelessWidget {
  final String callType; // 'video' | 'audio'
  final String withWhom;
  final String topic;
  final String consultationId;

  const CallScreen({
    super.key,
    required this.callType,
    required this.withWhom,
    required this.topic,
    required this.consultationId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: VideoCallDialog(
          callType: callType,
          withWhom: withWhom,
          topic: topic,
          consultationId: consultationId,
          onEnd: (secs) async {
            Navigator.of(context).pop(secs); // return duration if you want
          },
        ),
      ),
    );
  }
}
