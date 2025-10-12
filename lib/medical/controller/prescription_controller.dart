import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore keys used by prescriptions.
class PrescriptionKeys {
  static const String medicationName   = 'medicationName';
  static const String refillsRemaining = 'refillsRemaining';
  static const String nextRefillDate   = 'nextRefillDate';
  static const String active           = 'active';
  static const String price            = 'price';
  static const String updatedAt        = 'updatedAt';
}

/// Immutable prescription model, with a TYPED reference.
class Prescription {
  final String id;
  final String medicationName;
  final int refillsRemaining;
  final DateTime nextRefillDate;
  final double price;
  final DocumentReference<Map<String, dynamic>> ref;

  Prescription({
    required this.id,
    required this.medicationName,
    required this.refillsRemaining,
    required this.nextRefillDate,
    required this.price,
    required this.ref,
  });

  factory Prescription.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final ts = data[PrescriptionKeys.nextRefillDate];
    return Prescription(
      id: doc.id,
      medicationName: (data[PrescriptionKeys.medicationName] as String?) ?? 'Medication',
      refillsRemaining: (data[PrescriptionKeys.refillsRemaining] as num?)?.toInt() ?? 0,
      nextRefillDate: ts is Timestamp ? ts.toDate() : DateTime.now(),
      price: (data[PrescriptionKeys.price] as num?)?.toDouble() ?? 0.0,
      ref: doc.reference,
    );
  }
}

/// Static, stateless API used by your boundary.
/// (If you later want in-widget state via Provider, you can still add a ChangeNotifier wrapper.)
class PrescriptionController {
  /// Load the most recent *active* prescription for a patient.
  static Future<Prescription?> loadActivePrescription(String patientUid) async {
    final q = await FirebaseFirestore.instance
        .collection('users')
        .doc(patientUid)
        .collection('prescriptions')
        // Make the query typed for strong types downstream:
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (s, _) => s.data() ?? <String, dynamic>{},
          toFirestore: (m, _) => m,
        )
        .where(PrescriptionKeys.active, isEqualTo: true)
        .orderBy(PrescriptionKeys.updatedAt, descending: true)
        .limit(1)
        .get();

    if (q.docs.isEmpty) return null;
    return Prescription.fromDoc(q.docs.first);
  }


  static Future<int> decrementRefillCount(
      DocumentReference<Map<String, dynamic>> ref) async {
    return FirebaseFirestore.instance.runTransaction<int>((txn) async {
      final snap = await txn.get(ref);
      if (!snap.exists) return 0;

      final data = snap.data() as Map<String, dynamic>;
      final current = (data[PrescriptionKeys.refillsRemaining] as num?)?.toInt() ?? 0;
      final next = current > 0 ? current - 1 : 0;

      txn.update(ref, {
        PrescriptionKeys.refillsRemaining: next,
        PrescriptionKeys.updatedAt: FieldValue.serverTimestamp(),
      });
      return next;
    });
  }
}
