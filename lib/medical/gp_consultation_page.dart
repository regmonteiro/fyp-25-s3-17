import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'controller/gp_consultation_controller.dart';
import '../../models/user_profile.dart';
import '../webrtc/video_call_widgets.dart';


enum _ConsultMode { consult, prescription }
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

  final TextEditingController _medicationController = TextEditingController();
  final TextEditingController _dosageController = TextEditingController();
  final TextEditingController _daysController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  _ConsultMode _mode = _ConsultMode.consult;
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
    _medicationController.dispose();
    _dosageController.dispose();
    _daysController.dispose();
    _notesController.dispose();
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
  final String? caregiverUid =
      _includedCaregivers.isNotEmpty ? _includedCaregivers.first : null;

  try {
  final id = await _gpController.startConsultation(
    reason: reason,
    caregiverUid: caregiverUid,
  );
  if (!mounted) return; // prevent setState after widget disposal
  if (id.isEmpty) throw Exception('Consultation could not be started.');

  setState(() {
    _activeConsultationId = id;
    _activeConsultation = {
      'uid': id,
      'reason': reason,
      'elderlyName': widget.userProfile.displayName ?? 'Patient',
    };
    _showCallInit = true;
    _isLoading = false;
  });
} catch (e, st) {
  if (!mounted) return;
  debugPrint('startConsultation failed: $e\n$st');
  setState(() => _isLoading = false);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Error starting consultation: ${e.toString()}')),
  );
}
}

Future<void> _submitPrescriptionRequest() async {
  final reason = _symptomsController.text.trim(); // short clinical context
  final med    = _medicationController.text.trim();
  final dose   = _dosageController.text.trim();
  final days   = int.tryParse(_daysController.text.trim().isEmpty ? '0' : _daysController.text.trim()) ?? 0;
  if (med.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Medication name is required.')),
    );
    return;
  }

  setState(() => _isLoading = true);

  try {
    // pick first caregiver if any (same as your consult)
    final String? caregiverUid = _includedCaregivers.isNotEmpty ? _includedCaregivers.first : null;

    final reqId = await _gpController.createPrescriptionRequest(
      elderlyId: _elderlyId,
      medicationName: med,
      dosage: dose,
      supplyDays: days,
      reason: reason,
      caregiverUid: caregiverUid,
      notes: _notesController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    // optional: clear fields
    _medicationController.clear();
    _dosageController.clear();
    _daysController.clear();
    _notesController.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Prescription request submitted. Ref: $reqId')),
    );
  } catch (e, st) {
    debugPrint('createPrescriptionRequest failed: $e\n$st');
    if (!mounted) return;
    setState(() => _isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: ${e.toString()}')),
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
                        elderly.firstname,
                        elderly.lastname
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
            Row(
                children: [
                  ChoiceChip(
                    label: const Text('Consult GP now'),
                    selected: _mode == _ConsultMode.consult,
                    onSelected: (_) => setState(() => _mode = _ConsultMode.consult),
                  ),
                  const SizedBox(width: 12),
                  ChoiceChip(
                    label: const Text('Request prescription'),
                    selected: _mode == _ConsultMode.prescription,
                    onSelected: (_) => setState(() => _mode = _ConsultMode.prescription),
                  ),
                ],
              ),
              const SizedBox(height: 16),
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
            if (_mode == _ConsultMode.prescription) ...[
              const SizedBox(height: 24),
              const Text('Prescription details',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _medicationController,
                decoration: const InputDecoration(
                  labelText: 'Medication name (required)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _dosageController,
                decoration: const InputDecoration(
                  labelText: 'Dosage & frequency (e.g., 5mg, 1 tab twice daily)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _daysController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Days of supply (e.g., 30)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Notes to GP (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 32),
            const Text('2. Three-Way Call Option:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),

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
                      (cg.firstname ?? '').trim(),
                      (cg.lastname ?? '').trim(),
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
                onPressed: _isLoading
                  ? null
                  : () {

                      if (_mode == _ConsultMode.consult) {
                        _startConsultationProcess();
                      } else {
                        _submitPrescriptionRequest();
                      }
                    },
                icon: _isLoading
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                    : Icon(_mode == _ConsultMode.consult ? Icons.video_call : Icons.medical_services, size: 28),
                label: Text(
                  _isLoading
                      ? (_mode == _ConsultMode.consult ? 'Starting Consultation...' : 'Submitting...')
                      : (_mode == _ConsultMode.consult ? 'Start Immediate GP Call' : 'Request Prescription'),
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
