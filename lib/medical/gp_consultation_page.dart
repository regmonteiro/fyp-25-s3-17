import 'package:flutter/material.dart';
import 'controller/gp_consultation_controller.dart';
import '../../models/user_profile.dart';

class GPConsultationPage extends StatefulWidget {
  final String elderlyUid = 'simulated_elderly_uid_123';
  const GPConsultationPage({Key? key}) : super(key: key);

  @override
  _GPConsultationPageState createState() => _GPConsultationPageState();
}

class _GPConsultationPageState extends State<GPConsultationPage> {
  late ElderlyGPController _gpController;
  final TextEditingController _symptomsController = TextEditingController();
  bool _includeCaregiver = false;
  String? _primaryCaregiverUid;
  String? _primaryCaregiverName;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _gpController = ElderlyGPController(elderlyUid: widget.elderlyUid);
  }

  @override
  void dispose() {
    _symptomsController.dispose();
    super.dispose();
  }

  void _startConsultationProcess() async {
    if (_symptomsController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please describe your symptoms before starting.')),
      );
      return;
    }

    final bool? isVerified = await _showVerificationDialog(context);
    if (isVerified != true) return;

    setState(() => _isLoading = true);

    final String? cgUid = _includeCaregiver ? _primaryCaregiverUid : null;

    final id = await _gpController.startConsultation(
      caregiverUid: cgUid,
      reason: _symptomsController.text.trim(),
    );

    setState(() => _isLoading = false);

    if (id.isNotEmpty) {
      _showCallConnectionDialog();
    } else {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to start consultation. Please try again.')),
      );
    }
  }

  Future<bool?> _showVerificationDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Identity'),
        content: Text(
          'Are you ${_gpController.elderlyUid.substring(0, 8)}...? '
          'Please confirm you wish to start a consultation now.',
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

  void _showCallConnectionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Consultation Initiated'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6A1B9A))),
            const SizedBox(height: 16),
            const Text('Connecting you to the next available GP...', textAlign: TextAlign.center, style: TextStyle(fontSize: 16)),
            if (_includeCaregiver)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'Caregiver ${_primaryCaregiverName ?? "..."} is being invited to join the 3-way call.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // close dialog
              Navigator.of(context).pop(); // back to previous page
            },
            child: const Text('Minimize Call (Back to Home)'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Immediate GP Consultation'), backgroundColor: Colors.teal, elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            color: Colors.teal.shade50,
            child: const Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Consult a GP Now', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.teal)),
                SizedBox(height: 8),
                Text('Enter your current symptoms below. An online doctor will connect with you immediately.',
                    style: TextStyle(fontSize: 16, color: Colors.black87)),
              ]),
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
                borderSide: BorderSide(color: Colors.teal.shade400, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 32),

          const Text('2. Three-Way Call Option:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),

          // 👇 Now uses UserProfile
          StreamBuilder<UserProfile?>(
            stream: _gpController.getPrimaryCaregiverStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const LinearProgressIndicator();

              final caregiver = snapshot.data;
              _primaryCaregiverUid = caregiver?.uid;
              _primaryCaregiverName = caregiver?.displayName;

              if (caregiver != null && _primaryCaregiverUid != null && _primaryCaregiverUid!.isNotEmpty) {
                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: CheckboxListTile(
                    title: Text('Invite ${_primaryCaregiverName!} to the call?'),
                    subtitle: const Text('Your caregiver can join the call remotely to assist with medical details.'),
                    value: _includeCaregiver,
                    onChanged: (v) => setState(() => _includeCaregiver = v ?? false),
                    activeColor: Colors.purple.shade600,
                    secondary: const Icon(Icons.group_add, color: Colors.purple),
                  ),
                );
              }

              return const Card(
                elevation: 1,
                color: Colors.orange,
                child: ListTile(
                  title: Text('No Caregiver Linked'),
                  subtitle: Text('Please link a caregiver to enable the 3-way call option.', style: TextStyle(color: Colors.white)),
                  leading: Icon(Icons.person_off, color: Colors.white),
                ),
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
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
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
  }
}
