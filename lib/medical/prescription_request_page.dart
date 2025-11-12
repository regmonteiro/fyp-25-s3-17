import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../financial/payment_confirmation_page.dart';
import '../../models/user_profile.dart';
import 'consultation_request_page.dart';
import 'controller/prescription_controller.dart';


class PrescriptionRequestPage extends StatefulWidget {
  final String? elderlyId;
  const PrescriptionRequestPage({Key? key, this.elderlyId}) : super(key: key);

  @override
  State<PrescriptionRequestPage> createState() => _PrescriptionRequestPageState();
}

class _PrescriptionRequestPageState extends State<PrescriptionRequestPage> {
  bool _loading = false;
  Prescription? _active;
  UserProfile? _currentProfile;
  late final String _patientUid;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() => _loading = true);
    try {
      // 1) Load current user profile from Firestore
      final authUid = FirebaseAuth.instance.currentUser?.uid;
      if (authUid == null) {
        throw 'No signed-in user';
      }
      final userDoc = await FirebaseFirestore.instance.collection('Account').doc(authUid).get();
      final profile = UserProfile.fromDocumentSnapshot(userDoc);

      // 2) Determine patient UID (elder if caregiver and linked, else self)
      final patientUid = (profile.userType == 'caregiver' && (profile.elderlyId?.isNotEmpty ?? false))
          ? profile.elderlyId!
          : (widget.elderlyId ?? profile.uid);

      // 3) Load active prescription
      final presc = await PrescriptionController.loadActivePrescription(patientUid);

      setState(() {
        _currentProfile = profile;
        _patientUid = patientUid;
        _active = presc;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load data: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleRefillPurchase() async {
    if (_active == null || _active!.refillsRemaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No refills available.')),
      );
      return;
    }
    if (_currentProfile == null) return;

    final refillItem = {
      'id': _active!.id,
      'name': _active!.medicationName,
      'description': '30-day supply refill',
      'price': _active!.price,
    };

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PaymentConfirmationPage(
          totalAmount: _active!.price,
          cartItems: [refillItem],
          userProfile: _currentProfile!,
          targetUid: _patientUid,
        ),
      ),
    );

    // After payment returns, decrement refills
    try {
  final current = _active;
  if (current == null) return;

  final remaining =
      await PrescriptionController.decrementRefillCount(current.ref);

  final refreshed =
      await PrescriptionController.loadActivePrescription(_patientUid);

  if (!mounted) return;
  setState(() => _active = refreshed);

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Refill successful. Remaining: $remaining')),
  );
} catch (e) {
  if (!mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Failed to update refills: $e')),
  );
}
  }

  void _navigateToConsultation() {
    if (_currentProfile == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ConsultationRequestPage(
          userProfile: _currentProfile!,
          patientUid: _patientUid, // <-- REQUIRED named arg
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasActive = _active != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Prescribed Treatment Refills'),
        backgroundColor: Colors.red.shade700,
        elevation: 0,
      ),
      body: _loading
          ? _buildLoading()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoCard(
                    title: 'Prescription Policy',
                    content:
                        'All medicated drugs require a valid prescription after a GP video consultation. Refills are available only while the prescription is valid.',
                    icon: Icons.policy,
                    color: Colors.red.shade100,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Your Current Prescription Status',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (hasActive) _buildActiveCard() else _buildNoneCard(),
                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 16),
                  Text(
                    'Need a New Prescription?',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildActionCard(
                    title: 'Book a GP Consultation',
                    subtitle:
                        'Consult a doctor to discuss new medication or renew an expired prescription.',
                    icon: FontAwesomeIcons.userMd, // ignore: deprecated_member_use
                    color: Colors.blue.shade50,
                    iconColor: Colors.blue.shade700,
                    onTap: _navigateToConsultation,
                  ),
                ],
              ),
            ),
    );
  }

  // ---------- UI helpers ----------

  Widget _buildLoading() => Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: const Padding(
          padding: EdgeInsets.all(20),
          child: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Checking medical records...', style: TextStyle(fontSize: 16)),
            ],
          ),
        ),
      );

  Widget _buildInfoCard({
    required String title,
    required String content,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.grey.shade700, size: 30),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87)),
                const SizedBox(height: 5),
                Text(content, style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        color: color,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 28, color: iconColor),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 18, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveCard() {
    final p = _active!;
    return Card(
      elevation: 6,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: Colors.green.shade400, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.check_circle, color: Colors.green.shade600, size: 30),
              const SizedBox(width: 10),
              Text('Active Prescription Found',
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
            ]),
            const Divider(height: 24),
            _detail('Medication:', p.medicationName, Colors.black),
            _detail(
              'Refills Remaining:',
              '${p.refillsRemaining}',
              p.refillsRemaining > 1 ? Colors.green : Colors.orange,
            ),
            _detail(
              'Next Refill Date:',
              '${p.nextRefillDate.month}/${p.nextRefillDate.day}/${p.nextRefillDate.year}',
              Colors.grey.shade700,
            ),
            _detail('Price:', 'S\$${p.price.toStringAsFixed(2)}', Colors.grey.shade800),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: p.refillsRemaining > 0 ? _handleRefillPurchase : null,
                icon: const Icon(Icons.credit_card),
                label: Text(
                  p.refillsRemaining > 0
                      ? 'Purchase Refill (S\$${p.price.toStringAsFixed(2)})'
                      : 'No Refills Left',
                  style: const TextStyle(fontSize: 18),
                ),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor:
                      p.refillsRemaining > 0 ? Colors.pink.shade600 : Colors.grey.shade400,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoneCard() {
    return Card(
      elevation: 6,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: Colors.red.shade400, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.warning, color: Colors.red.shade600, size: 30),
            const SizedBox(width: 10),
            Text('No Active Prescription',
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red.shade700)),
          ]),
          const Divider(height: 24),
          Text(
            'Your prescription has expired or has no remaining refills.',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _navigateToConsultation,
              icon: Icon(FontAwesomeIcons.stethoscope),
              label: const Text('Book Consultation to Renew', style: TextStyle(fontSize: 18)),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.blue.shade600,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _detail(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 150,
          child: Text(label,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
        ),
        Expanded(
          child: Text(value,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        ),
      ]),
    );
  }
}
