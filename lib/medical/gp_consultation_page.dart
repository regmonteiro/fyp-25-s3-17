import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'controller/gp_consultation_controller.dart';
import '../../models/user_profile.dart';
import '../webrtc/video_call_widgets.dart';

class GPConsultationPage extends StatefulWidget {
  final UserProfile userProfile;
  final String? elderlyUid; // optional override; defaults to userProfile.uid

  const GPConsultationPage({
    Key? key,
    required this.userProfile,
    this.elderlyUid,
  }) : super(key: key);

  @override
  State<GPConsultationPage> createState() => _GPConsultationPageState();
}

class _GPConsultationPageState extends State<GPConsultationPage> {
  late ElderlyGPController _gpController;
  final TextEditingController _symptomsController = TextEditingController();

  // Selection state for inviting caregivers
  final Set<String> _includedCaregivers = <String>{};

  bool _isLoading = false;

  // 👇 ADD: call state
  bool _showCallInit = false;
  bool _showCall = false;
  String _callType = 'video';
  String? _activeConsultationId;
  Map<String, dynamic>? _activeConsultation;

  String get _elderlyUid => widget.elderlyUid ?? widget.userProfile.uid;

  @override
  void initState() {
    super.initState();
    _gpController = ElderlyGPController(elderlyUid: _elderlyUid);
  }

  @override
  void dispose() {
    _symptomsController.dispose();
    super.dispose();
  }

  Future<void> _startConsultationProcess() async {
    final reason = _symptomsController.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please describe your symptoms before starting.')),
      );
      return;
    }

    final bool? isVerified = await _showVerificationDialog(context);
    if (isVerified != true) return;

    setState(() => _isLoading = true);

    // If multiple are selected, we pass the first (matches your controller signature).
    final String? cgUid = _includedCaregivers.isNotEmpty ? _includedCaregivers.first : null;

    final id = await _gpController.startConsultation(
      reason: reason,
      caregiverUid: _includedCaregivers.isNotEmpty ? _includedCaregivers.first : null,
    );

    setState(() => _isLoading = false);

    if (id.isNotEmpty) {
      // 👇 ADD: prepare minimal consultation data for dialogs
      _activeConsultationId = id;
      _activeConsultation = {
        'id': id,
        'reason': reason,
        'elderlyName': widget.userProfile.firstName ?? 'Patient',
      };

      // 👇 OPEN: call initiation dialog instead of the old “connecting” alert
      setState(() => _showCallInit = true);
    } else {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to start consultation. Please try again.')),
      );
    }
  }

  Future<bool?> _showVerificationDialog(BuildContext context) {
    final safePreview = _elderlyUid.length > 8 ? _elderlyUid.substring(0, 8) : _elderlyUid;
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Identity'),
        content: Text(
          'Are you $safePreview...? Please confirm you wish to start a consultation now.',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.pink.shade600),
            child: const Text('Verify & Proceed', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // 👇 ADD: start call from CallInitiationDialog
  Future<void> _onStartCall(String type) async {
    setState(() {
      _callType = type;
      _showCallInit = false;
      _showCall = true;
    });
    // (Optional) if you want to log to RTDB, you can do it here.
  }

  // 👇 ADD: end call handler from VideoCallDialog
  Future<void> _onEndCall(int seconds) async {
    if (!mounted) return;
    setState(() => _showCall = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Call ended. Duration: ${seconds}s')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = widget.userProfile.uid;

    final scaffold = Scaffold(
      appBar: AppBar(
        title: const Text('Immediate GP Consultation'),
        backgroundColor: Colors.teal,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            color: Colors.teal.shade50,
            child: const Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Consult a GP Now',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.teal)),
                  SizedBox(height: 8),
                  Text(
                    'Enter your current symptoms below. An online doctor will connect with you immediately.',
                    style: TextStyle(fontSize: 16, color: Colors.black87),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          const Text('1. Describe your symptoms:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextFormField(
            controller: _symptomsController,
            maxLines: 5,
            decoration: InputDecoration(
              hintText: 'E.g., "I have a persistent cough and feel short of breath since yesterday."',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.teal, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 32),

          const Text('2. Three-Way Call Option:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),

          // Linked caregiver selector (multi-select; passes first one for now)
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LinearProgressIndicator();
              }
              if (!snapshot.hasData || !snapshot.data!.exists) {
                return const Card(
                  elevation: 1,
                  color: Colors.orange,
                  child: ListTile(
                    title: Text('No Caregiver Linked', style: TextStyle(color: Colors.white)),
                    subtitle: Text(
                      'Please link a caregiver to enable the 3-way call option.',
                      style: TextStyle(color: Colors.white),
                    ),
                    leading: Icon(Icons.person_off, color: Colors.white),
                  ),
                );
              }

              final data = snapshot.data!.data() ?? {};
              final raw = (data['linkedCaregivers'] as List?) ?? const [];

              // Normalize: accept either List<String> or List<Map<String,dynamic>>
              final caregivers = raw.map<Map<String, dynamic>>((e) {
                if (e is String) return {'uid': e, 'displayName': null, 'role': 'caregiver'};
                if (e is Map) {
                  return {
                    'uid': e['uid'],
                    'displayName': e['displayName'],
                    'role': e['role'] ?? 'caregiver',
                  };
                }
                return {'uid': null, 'displayName': null, 'role': 'caregiver'};
              }).where((m) => (m['uid'] as String?)?.isNotEmpty == true).toList();

              if (caregivers.isEmpty) {
                return const Card(
                  elevation: 1,
                  color: Colors.orange,
                  child: ListTile(
                    title: Text('No Caregiver Linked', style: TextStyle(color: Colors.white)),
                    subtitle: Text(
                      'Please link a caregiver to enable the 3-way call option.',
                      style: TextStyle(color: Colors.white),
                    ),
                    leading: Icon(Icons.person_off, color: Colors.white),
                  ),
                );
              }

              return Column(
                children: caregivers.map((cg) {
                  final cgUid = cg['uid'] as String;
                  final cgName = (cg['displayName'] as String?) ?? 'Caregiver';
                  final cgRole = (cg['role'] as String?) ?? 'caregiver';

                  final checked = _includedCaregivers.contains(cgUid);

                  return CheckboxListTile(
                    title: Text('Invite $cgRole: $cgName to the call?'),
                    subtitle: const Text('They can assist with medical details remotely.'),
                    value: checked,
                    onChanged: (bool? value) {
                      setState(() {
                        if (value == true) {
                          _includedCaregivers.add(cgUid);
                        } else {
                          _includedCaregivers.remove(cgUid);
                        }
                      });
                    },
                    activeColor: Colors.purple.shade600,
                    secondary: const Icon(Icons.group_add, color: Colors.purple),
                  );
                }).toList(),
              );
            },
          ),

          const SizedBox(height: 40),

          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _startConsultationProcess,
              icon: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                    )
                  : const Icon(Icons.video_call, size: 28),
              label: Text(
                _isLoading ? 'Starting Consultation...' : 'Start Immediate GP Call',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.pink.shade600,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                elevation: 6,
              ),
            ),
          ),
        ]),
      ),
    );

    // 👇 ADD: Overlays for call initiation + call window
    return _overlay(scaffold, _showCallInit, CallInitiationDialog(
      consultation: _activeConsultation,
      onCancel: () => setState(() => _showCallInit = false),
      onStart: _onStartCall,
    ))._thenOverlay(_showCall, VideoCallDialog(
      callType: _callType,
      onEnd: _onEndCall,
      withWhom: (widget.userProfile.firstName ?? 'GP'),
      topic: (_activeConsultation?['reason'] ?? 'Consultation').toString(),
      consultationId: _activeConsultationId ?? '',
    ));
  }

  // ----- small helpers -----
  Widget _overlay(Widget base, bool visible, Widget child) {
    if (!visible) return base;
    return Stack(children: [
      base,
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

extension _OverlayChain on Widget {
  Widget _thenOverlay(bool visible, Widget child) {
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
