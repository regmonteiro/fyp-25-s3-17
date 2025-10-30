import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class WalletTransaction {
  final String id;
  final String type;             // "TopUp", "Purchase", "Refund"
  final double amount;
  final DateTime createdAt;
  final String description;      // e.g. "Top-up via Card (•••• 1234)"
  final String? method;          // "Card(1234)", "PayNow", etc.
  final String? payerUid;        // who paid (caregiver or self)
  final String? payerName;       // display name (optional)

  WalletTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.createdAt,
    required this.description,
    this.method,
    this.payerUid,
    this.payerName,
  });

  factory WalletTransaction.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final ts = d['createdAt'];
    return WalletTransaction(
      id: doc.id,
      type: (d['type'] as String?) ?? 'Unknown',
      amount: (d['amount'] as num?)?.toDouble() ?? 0.0,
      createdAt: ts is Timestamp ? ts.toDate() : DateTime.fromMillisecondsSinceEpoch(0),
      description: (d['description'] as String?) ?? '',
      method: d['method'] as String?,
      payerUid: d['payerUid'] as String?,
      payerName: d['payerName'] as String?,
    );
  }
}

class WalletController with ChangeNotifier {
  final String userId; // wallet owner (elderly’s uid)
  final FirebaseFirestore _db;

  WalletController({required this.userId, FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance {
    _init();
  }

  // ---- State ----
  double _currentBalance = 0.0;
  double get currentBalance => _currentBalance;

  // ---- Refs (moved under Account/{uid}) ----
  late final DocumentReference<Map<String, dynamic>> _balanceRef;
  late final CollectionReference<Map<String, dynamic>> _txRef;

  void _init() {
    _balanceRef = _db
        .collection('Account')
        .doc(userId)
        .collection('wallet')
        .doc('balance');

    _txRef = _db
        .collection('Account')
        .doc(userId)
        .collection('transactions');

    _listenToBalance();
  }

  void _listenToBalance() {
    _balanceRef.snapshots().listen((snap) async {
      if (!snap.exists) {
        // bootstrap the balance doc
        await _balanceRef.set({
          'amount': 0.0,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        _currentBalance = 0.0;
        notifyListeners();
        return;
      }
      final data = snap.data() ?? {};
      _currentBalance = (data['amount'] as num?)?.toDouble() ?? 0.0;
      notifyListeners();
    }, onError: (e) {
      if (kDebugMode) {
        print('Wallet balance listen error: $e');
      }
    });
  }

  /// Recent transactions stream (newest first)
  Stream<List<WalletTransaction>> get transactionsStream {
    return _txRef
        .orderBy('createdAt', descending: true)
        .limit(30)
        .snapshots()
        .map((q) => q.docs.map((d) => WalletTransaction.fromDoc(d)).toList());
  }

  /// Top up the wallet.
  Future<void> topUpWallet({
    required double amount,
    required String paymentMethod,  // "PayNow", "Card(1234)", etc.
    String? payerUid,
    String? payerName,
  }) async {
    if (amount <= 0) throw 'Amount must be > 0';

    await _db.runTransaction((txn) async {
      final snap = await txn.get(_balanceRef);
      final current = (snap.data()?['amount'] as num?)?.toDouble() ?? 0.0;
      final next = current + amount;

      txn.set(_balanceRef, {
        'amount': next,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      txn.set(_txRef.doc(), {
        'type': 'TopUp',
        'amount': amount,
        'method': paymentMethod,
        'description': 'Top-up via $paymentMethod',
        'createdAt': FieldValue.serverTimestamp(),
        'targetUid': userId, // wallet owner
        if (payerUid != null) 'payerUid': payerUid,
        if (payerName != null) 'payerName': payerName,
      });
    });

    notifyListeners();
  }

  /// Charge wallet for purchases.
  Future<void> spend({
    required double amount,
    required String description,
  }) async {
    if (amount <= 0) throw 'Amount must be > 0';

    await _db.runTransaction((txn) async {
      final snap = await txn.get(_balanceRef);
      final current = (snap.data()?['amount'] as num?)?.toDouble() ?? 0.0;
      if (current < amount) throw 'Insufficient balance';
      final next = current - amount;

      txn.set(_balanceRef, {
        'amount': next,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      txn.set(_txRef.doc(), {
        'type': 'Purchase',
        'amount': -amount,
        'method': 'Wallet',
        'description': description,
        'createdAt': FieldValue.serverTimestamp(),
        'targetUid': userId,
      });
    });

    notifyListeners();
  }
}
