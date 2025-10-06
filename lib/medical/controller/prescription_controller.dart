import 'package:cloud_firestore/cloud_firestore.dart';

class Prescription {
  final String id;
  final String medicationName;
  final int refillsRemaining;
  final DateTime nextRefillDate;
  final double price;
  final bool active;
  final DocumentReference<Map<String, dynamic>> ref;

  Prescription({
    required this.id,
    required this.medicationName,
    required this.refillsRemaining,
    required this.nextRefillDate,
    required this.price,
    required this.active,
    required this.ref,
  });

  factory Prescription.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final ts = d['nextRefillDate'];
    final dt = ts is Timestamp ? ts.toDate() : DateTime.now();

    return Prescription(
      id: doc.id,
      medicationName: (d['medicationName'] as String?) ?? 'Medication',
      refillsRemaining: (d['refillsRemaining'] as num?)?.toInt() ?? 0,
      nextRefillDate: dt,
      price: (d['price'] as num?)?.toDouble() ?? 0.0,
      active: (d['active'] as bool?) ?? false,
      ref: doc.reference,
    );
  }
}

class PrescriptionController {
  static const _kMedicationName = 'medicationName';
  static const _kRefillsRemaining = 'refillsRemaining';
  static const _kNextRefillDate = 'nextRefillDate';
  static const _kActive = 'active';
  static const _kPrice = 'price';
  static const _kUpdatedAt = 'updatedAt';

  /// Loads the most recent active prescription for a patient.
  static Future<Prescription?> loadActivePrescription(String patientUid) async {
    final q = await FirebaseFirestore.instance
        .collection('users')
        .doc(patientUid)
        .collection('prescriptions')
        .where(_kActive, isEqualTo: true)
        .orderBy(_kUpdatedAt, descending: true)
        .limit(1)
        .get();

    if (q.docs.isEmpty) return null;
    return Prescription.fromSnapshot(q.docs.first);
  }

  /// Decrement refills atomically and return the new count.
  static Future<int> decrementRefillCount(DocumentReference<Map<String, dynamic>> ref) async {
    return FirebaseFirestore.instance.runTransaction<int>((txn) async {
      final snap = await txn.get(ref);
      if (!snap.exists) return 0;

      final data = snap.data() as Map<String, dynamic>;
      final current = (data[_kRefillsRemaining] as num?)?.toInt() ?? 0;
      final next = current > 0 ? current - 1 : 0;

      txn.update(ref, {
        _kRefillsRemaining: next,
        _kUpdatedAt: FieldValue.serverTimestamp(),
      });
      return next;
    });
  }
}
