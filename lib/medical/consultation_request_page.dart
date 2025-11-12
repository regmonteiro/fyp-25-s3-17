import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile.dart';

class ConsultationRequestPage extends StatefulWidget {
  final UserProfile userProfile;
  final String patientUid;

  const ConsultationRequestPage({
    Key? key,
    required this.userProfile,
    required this.patientUid,
  }) : super(key: key);

  @override
  State<ConsultationRequestPage> createState() => _ConsultationRequestPageState();
}

class _ConsultationRequestPageState extends State<ConsultationRequestPage> {
  final _formKey = GlobalKey<FormState>();
  final _reasonCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  String get _patientUid {
    final isCaregiver = widget.userProfile.userType == 'caregiver';
    final elder = widget.userProfile.elderlyId;
    if (isCaregiver && elder != null && elder.isNotEmpty) {
      return elder;
    }
    return widget.userProfile.uid;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      final data = {
        'patientUid': _patientUid,
        'createdByUid': widget.userProfile.uid,
        'createdByName': widget.userProfile.displayName,
        'roleOfCreator': widget.userProfile.userType,
        'reason': _reasonCtrl.text.trim(),
        'status': 'pending', // pending | scheduled | completed | canceled
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };


      // Store under the patient document: users/{patientUid}/consultations/{autoId}
      final col = FirebaseFirestore.instance
          .collection('Account')
          .doc(_patientUid)
          .collection('consultations');

      await col.add(data);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Consultation request sent')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSelf = _patientUid == widget.userProfile.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('GP Consultation Request')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _InfoChip(
                label: 'Requesting for',
                value: isSelf ? 'Myself' : 'Elder (${widget.userProfile.elderlyId})',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _reasonCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Reason for consultation',
                  hintText: 'Describe symptoms or purpose',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Please enter a reason' : null,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: const Icon(Icons.medical_services),
                  label: Text(_submitting ? 'Submitting...' : 'Submit Request'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  const _InfoChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Chip(label: Text(label)),
        const SizedBox(width: 8),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}
