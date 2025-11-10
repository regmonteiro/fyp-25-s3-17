import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'controller/gp_consultation_controller.dart';
import '../../models/user_profile.dart';
import '../webrtc/video_call_widgets.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  // ---- role helpers ----
  bool get _isCaregiver =>
      (widget.userProfile.userType ?? '').toLowerCase() == 'caregiver';
  bool get _isElderly =>
      (widget.userProfile.userType ?? '').toLowerCase() == 'elderly';

  // ---- dynamic elderly target (caregiver can switch) ----
  String? _activeElderlyId; // resolved elderly uid for this session
  List<Map<String, String>> _elderlyChoices = []; // [{uid, firstname, lastname, email}]
  bool _bootstrapping = true;
  String? _bootstrapError;

  // ---- controller + streams that depend on _activeElderlyId ----
  ElderlyGPController? _gpController;
  Stream<UserProfile?>? _elderlyAcct$;
  Stream<List<UserProfile>>? _caregivers$; // only used for elderly role
  Object _streamsKey = Object(); // forces StreamBuilder rebuilds after retargeting

  // ---- form controllers ----
  final TextEditingController _symptomsController = TextEditingController();

  final TextEditingController _medicationController = TextEditingController();
  final TextEditingController _dosageController = TextEditingController();
  final TextEditingController _daysController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  _ConsultMode _mode = _ConsultMode.consult;
  final Set<String> _includedCaregivers = <String>{}; // elderly role only

  bool _isLoading = false;

  // call overlay state
  bool _showCallInit = false;
  bool _showCall = false;
  String _callType = 'video';
  String? _activeConsultationId;
  Map<String, dynamic>? _activeConsultation;

  @override
  void initState() {
    super.initState();
    _bootstrap();
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

  Future<void> _bootstrap() async {
    setState(() {
      _bootstrapping = true;
      _bootstrapError = null;
    });

    try {
      final db = FirebaseFirestore.instance;
      final currentUser = FirebaseAuth.instance.currentUser;

      String? preferredElderly = widget.elderlyId;

      if (_isCaregiver) {
        final cgQ = await db
            .collection('Account')
            .where('uid', isEqualTo: widget.userProfile.uid)
            .limit(1)
            .get();

        if (cgQ.docs.isEmpty) {
          throw StateError('Caregiver account not found.');
        }
        final cgData = cgQ.docs.first.data();
        final ids = List<String>.from((cgData['elderlyIds'] as List?) ?? const []);

        _elderlyChoices = await _loadElderNames(ids);

        if ((preferredElderly ?? '').isNotEmpty &&
            !_elderlyChoices.any((e) => e['uid'] == preferredElderly)) {
          _elderlyChoices.insert(0, {
            'uid': preferredElderly!,
            'firstname': 'Elder',
            'lastname': '',
            'email': '',
          });
        }

        _activeElderlyId = preferredElderly ??
            (_elderlyChoices.isNotEmpty ? _elderlyChoices.first['uid'] : null);

        if (_activeElderlyId == null || _activeElderlyId!.isEmpty) {
          throw StateError('No linked elderly found for this caregiver.');
        }
      } else {
        _activeElderlyId = preferredElderly ?? widget.userProfile.uid;
        _elderlyChoices = [
          {
            'uid': _activeElderlyId!,
            'firstname': widget.userProfile.firstname ?? 'You',
            'lastname': widget.userProfile.lastname ?? '',
            'email': widget.userProfile.email ?? (currentUser?.email ?? ''),
          }
        ];
      }

      _rebuildControllerAndStreams();
    } catch (e) {
      _bootstrapError = e.toString();
    } finally {
      setState(() {
        _bootstrapping = false;
      });
    }
  }

  Future<List<Map<String, String>>> _loadElderNames(List<String> ids) async {
    final db = FirebaseFirestore.instance;
    final out = <Map<String, String>>[];
    for (final id in ids) {
      try {
        final q = await db.collection('Account').where('uid', isEqualTo: id).limit(1).get();
        if (q.docs.isEmpty) {
          out.add({'uid': id, 'firstname': 'Elder', 'lastname': '', 'email': ''});
          continue;
        }
        final m = q.docs.first.data();
        final first = (m['firstname'] ?? m['firstName'] ?? '').toString().trim();
        final last  = (m['lastname']  ?? m['lastName']  ?? '').toString().trim();
        final email = (m['email'] ?? '').toString();
        out.add({'uid': id, 'firstname': first, 'lastname': last, 'email': email});
      } catch (_) {
        out.add({'uid': id, 'firstname': 'Elder', 'lastname': '', 'email': ''});
      }
    }
    return out;
  }

  void _rebuildControllerAndStreams() {
    final elderlyId = _activeElderlyId!;
    _gpController = ElderlyGPController(elderlyId: elderlyId);

    _elderlyAcct$ = _gpController!.elderlyAccountStream().asBroadcastStream();
    _caregivers$ = _isElderly
        ? _gpController!.caregiversForElderlyStream().asBroadcastStream()
        : null;

    _streamsKey = Object();
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

    final String? caregiverUid = _isCaregiver ? widget.userProfile.uid
        : (_includedCaregivers.isNotEmpty ? _includedCaregivers.first : null);

    try {
      final id = await _gpController!.startConsultation(
        reason: reason,
        caregiverUid: caregiverUid,
      );
      if (!mounted) return;
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
      debugPrint('startConsultation failed: $e\n$st');
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error starting consultation: ${e.toString()}')),
      );
    }
  }

  Future<void> _submitPrescriptionRequest() async {
    final reason = _symptomsController.text.trim();
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
      final String? caregiverUid = _isCaregiver ? widget.userProfile.uid
          : (_includedCaregivers.isNotEmpty ? _includedCaregivers.first : null);

      final reqId = await _gpController!.createPrescriptionRequest(
        elderlyId: _activeElderlyId!,
        medicationName: med,
        dosage: dose,
        supplyDays: days,
        reason: reason,
        caregiverUid: caregiverUid,
        notes: _notesController.text.trim(),
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

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
    final id = _activeElderlyId ?? '';
    final safePreview = id.length > 8 ? id.substring(0, 8) : id;
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Identity'),
        content: Text(
          _isCaregiver
              ? 'Start a consultation for elderly $safePreview…?'
              : 'Are you $safePreview…? Please confirm you wish to start a consultation now.',
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

  String _shortId(String? id) {
    final s = (id ?? '').trim();
    if (s.isEmpty) return 'unknown';
    return s.length > 8 ? '${s.substring(0, 8)}…' : s;
    }

  @override
  Widget build(BuildContext context) {
    if (_bootstrapping) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_bootstrapError != null) {
      return Scaffold(body: Center(child: Text(_bootstrapError!)));
    }

    final scaffold = Scaffold(
      appBar: AppBar(
        title: const Text('Immediate GP Consultation'),
        backgroundColor: Colors.teal,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          key: ValueKey(_streamsKey),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isCaregiver) ...[
              const Text('Consultation for',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _activeElderlyId,
                items: _elderlyChoices.map((e) {
                  final name = '${(e['firstname'] ?? '').trim()} ${(e['lastname'] ?? '').trim()}'.trim();
                  final label = name.isEmpty ? (e['email'] ?? e['uid']!) : name;
                  return DropdownMenuItem(
                    value: e['uid'],
                    child: Text(label),
                  );
                }).toList(),
                onChanged: (v) {
                  if (v == null || v == _activeElderlyId) return;
                  setState(() {
                    _activeElderlyId = v;
                    _rebuildControllerAndStreams();
                    _includedCaregivers.clear();
                  });
                },
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
            ],

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
            if (_isElderly) ...[
              const Text('2. Invite a Caregiver (optional):',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              StreamBuilder<List<UserProfile>>(
                stream: _caregivers$,
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
                          'Link a caregiver to enable a 3-way call option.',
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
                              _includedCaregivers
                                ..clear()
                                ..add(cgUid); // keep single caregiver for now
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
            ] else ...[
              const Text('2. Three-way call:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Card(
                elevation: 1,
                color: const Color(0xFFEFF7F6),
                child: ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('You are joining as the caregiver.'),
                  subtitle: Text(
                    'Consultation will be started for elderly ${_shortId(_activeElderlyId)}.',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],

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
                    ? const SizedBox(
                        width: 24, height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                      )
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
