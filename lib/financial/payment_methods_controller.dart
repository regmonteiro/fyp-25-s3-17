import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// What the caller gets back after the user taps "Confirm".
class PaymentSelection {
  /// 'card-user', 'card-caregiver', 'paynow', 'applepay', 'googlepay'
  final String method;
  /// Firestore doc id of the chosen card (if method starts with 'card-').
  final String? cardId;
  /// Who pays: the current user or a linked caregiver (uid of payer).
  final String payerUid;
  /// Which wallet to credit (the elderly’s uid).
  final String targetElderUid;

  PaymentSelection({
    required this.method,
    required this.payerUid,
    required this.targetElderUid,
    this.cardId,
  });

  Map<String, dynamic> toMap() => {
        'method': method,
        'cardId': cardId,
        'payerUid': payerUid,
        'targetElderUid': targetElderUid,
      };
}

class SavedCard {
  final String id;         // doc id
  final String brand;      // Visa / MasterCard …
  final String masked;     // **** **** **** 1234
  final String expiry;     // MM/YY
  final String holder;     // cardholder name

  SavedCard({required this.id, required this.brand, required this.masked, required this.expiry, required this.holder});

  factory SavedCard.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return SavedCard(
      id: d.id,
      brand: (m['brand'] as String?) ?? 'Card',
      masked: (m['masked'] as String?) ?? '**** **** **** ****',
      expiry: (m['expiry'] as String?) ?? '--/--',
      holder: (m['holder'] as String?) ?? '',
    );
  }
}

/// Controller that:
/// - Lists the current user’s cards
/// - Optionally lists a linked caregiver’s cards (for paying on elderly’s behalf)
/// - Saves/updates a card inline
/// - Emits the chosen payment selection back to the caller
class PaymentMethodsController extends ChangeNotifier {
  final FirebaseFirestore _db;
  final String currentUserUid;  // who is using the app right now
  final String targetElderUid;  // wallet to credit (elderly)
  final String? caregiverUid;   // if current user is a caregiver, you may pass currentUserUid here as well

  PaymentMethodsController({
    required this.currentUserUid,
    required this.targetElderUid,
    this.caregiverUid,
    FirebaseFirestore? db,
  }) : _db = db ?? FirebaseFirestore.instance;

  /// Read saved cards from /users/{uid}/cards
  Stream<List<SavedCard>> cardsFor(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('cards')
        .orderBy('addedAt', descending: true)
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (s, _) => s.data() ?? {},
          toFirestore: (m, _) => m,
        )
        .snapshots()
        .map((s) => s.docs.map(SavedCard.fromDoc).toList());
  }

  /// Current user’s cards
  Stream<List<SavedCard>> get myCards => cardsFor(currentUserUid);

  /// Caregiver’s cards (shown only when caregiverUid != null)
  Stream<List<SavedCard>>? get caregiverCards =>
      caregiverUid == null ? null : cardsFor(caregiverUid!);

  /// Add/Update card into /users/{uid}/cards
  Future<void> saveCard({
    required String forUid,
    required String brand,
    required String number16, // plain for demo; in real world, tokenize!
    required String holder,
    required String expiryMMYY,
  }) async {
    final masked = "**** **** **** ${number16.substring(number16.length - 4)}";
    await _db.collection('users').doc(forUid).collection('cards').add({
      'brand': brand,
      'masked': masked,
      'expiry': expiryMMYY,
      'holder': holder,
      'last4': number16.substring(number16.length - 4),
      'addedAt': FieldValue.serverTimestamp(),
    });
  }
}