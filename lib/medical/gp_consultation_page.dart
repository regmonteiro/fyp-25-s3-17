import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'controller/gp_consultation_controller.dart';
import '../../models/user_profile.dart';
import '../webrtc/video_call_widgets.dart';

class GPConsultationPage extends StatefulWidget {
  final UserProfile userProfile;
  /// Optional override; defaults to userProfile.uid (elderly self)
  final String? elderlyId;

  const GPConsultationPage({
    Key? key,
    required this.userProfile,
    this.elderlyId,
  }) : super(key: key);

  @override
  State<GPConsultationPage> createState() => _GPConsultationPageState();
}

class _GPConsultationPageState extends State<GPConsultationPage> {
  late final ElderlyGPController _gpController;
  late final Stream<UserProfile?> _elderlyAcct$;

  final TextEditingController _symptomsController = TextEditingController();
  final Set<String> _includedCaregivers = <String>{};

  bool _isLoading = false;

  // call overlay state
  bool _showCallInit = false;
  bool _showCall = false;
  String _callType = 'video';
  String? _activeConsultationId;
  Map<String, dynamic>? _activeConsultation;

  String get _elderlyId => widget.elderlyId ?? widget.userProfile.uid;

  @override
  void initState() {
    super.initState();
    _gpController = ElderlyGPController(elderlyId: _elderlyId);
    _elderlyAcct$ = _gpController.elderlyAccountStream();
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

    // Pass the first selected caregiver for now (API supports single caregiver)
    final String? caregiverUid = _includedCaregivers.isNotEmpty ? _includedCaregivers.first : null;

    final id = await _gpController.startConsultation(
      reason: reason,
      caregiverUid: caregiverUid,
    );

    setState(() => _isLoading = false);

    if (id.isNotEmpty) {
      _activeConsultationId = id;
      _activeConsultation = {
        'uid': id,
        'reason': reason,
        'elderlyName': widget.userProfile.displayName ?? 'Patient',
      };
      setState(() => _showCallInit = true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to start consultation. Please try again.')),
      );
    }
  }

  Future<bool?> _showVerificationDialog(BuildContext context) {
    final safePreview = _elderlyId.length > 8 ? _elderlyId.substring(0, 8) : _elderlyId;
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Identity'),
        content: Text(
          'Are you $safePreview…? Please confirm you wish to start a consultation now.',
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

  Future<void> _onStartCall(String type) async {
    setState(() {
      _callType = type;
      _showCallInit = false;
      _showCall = true;
    });
  }

  Future<void> _onEndCall(int seconds) async {
    if (!mounted) return;
    setState(() => _showCall = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Call ended. Duration: ${seconds}s')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scaffold = Scaffold(
      appBar: AppBar(
        title: const Text('Immediate GP Consultation'),
        backgroundColor: Colors.teal,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Elderly header (name/email from Account)
            StreamBuilder<UserProfile?>(
              stream: _elderlyAcct$,
              builder: (context, snap) {
                final elderly = snap.data;
                final title = elderly == null
                    ? 'Consult a GP Now'
                    : 'Consult a GP Now — ${[
                        elderly.firstName,
                        elderly.lastName
                      ].where((s) => (s ?? '').trim().isNotEmpty).join(' ').trim()}';
                return Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  color: Colors.teal.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal,
                            )),
                        const SizedBox(height: 8),
                        const Text(
                          'Enter your current symptoms below. An online doctor will connect with you immediately.',
                          style: TextStyle(fontSize: 16, color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 24),
            const Text('1. Describe your symptoms:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _symptomsController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText:
                    'E.g., "I have a persistent cough and feel short of breath since yesterday."',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.teal, width: 2),
                ),
              ),
            ),

            const SizedBox(height: 32),
            const Text('2. Three-Way Call Option:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),

            // ✅ Caregivers are queried from Account where linkedElderUids contains elderly UID
            StreamBuilder<List<UserProfile>>(
              stream: _gpController.caregiversForElderlyStream(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const LinearProgressIndicator();
                }

                final caregivers = snap.data ?? const <UserProfile>[];
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
                    final cgUid = cg.uid;
                    final name = [
                      (cg.firstName ?? '').trim(),
                      (cg.lastName ?? '').trim(),
                    ].where((s) => s.isNotEmpty).join(' ');
                    final fallback = cgUid.length > 8 ? '${cgUid.substring(0, 8)}…' : cgUid;
                    final label = name.isNotEmpty ? name : fallback;

                    final checked = _includedCaregivers.contains(cgUid);
                    return CheckboxListTile(
                      title: Text('Invite caregiver: $label?'),
                      subtitle: const Text('They can assist with medical details remotely.'),
                      value: checked,
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
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
                        width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
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
          ],
        ),
      ),
    );

    // overlays
    return _overlay(
      scaffold,
      _showCallInit,
      CallInitiationDialog(
        consultation: _activeConsultation,
        onCancel: () => setState(() => _showCallInit = false),
        onStart: _onStartCall,
      ),
    )._thenOverlay(
      _showCall,
      VideoCallDialog(
        callType: _callType,
        onEnd: _onEndCall,
        withWhom: (widget.userProfile.displayName ?? 'GP'),
        topic: (_activeConsultation?['reason'] ?? 'Consultation').toString(),
        consultationId: _activeConsultationId ?? '',
      ),
    );
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
