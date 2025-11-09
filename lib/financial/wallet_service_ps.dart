
import 'package:cloud_firestore/cloud_firestore.dart';

String emailKey(String email) =>
    email.trim().toLowerCase().replaceAll(RegExp(r'[.#$/\[\]]'), '_');

class WalletTxn {
  final String id;
  final String type; // "purchase" or "topup"
  final double amount;
  final DateTime createdAt;
  final String description;
  final String? paymentMethod;

  WalletTxn({
    required this.id,
    required this.type,
    required this.amount,
    required this.createdAt,
    required this.description,
    this.paymentMethod,
  });
}

class WalletServicePs {
  final FirebaseFirestore _db;
  final String _docId; // paymentsubscriptions/{email_key}

  WalletServicePs({required String email, FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance,
        _docId = emailKey(email);

  DocumentReference<Map<String, dynamic>> get _ref =>
      _db.collection('paymentsubscriptions').doc(_docId);

  Future<void> initialize() async {
    final snap = await _ref.get();
    if (!snap.exists) {
      await _ref.set({
        'walletBalance': 0.0,
        'paymentHistory': [],
        'topUpHistory': [],
        'active': true,
        'autoPayment': false,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
      }, SetOptions(merge: true));
    }
  }

  Future<double> getWalletBalance() async {
    final s = await _ref.get();
    return ((s.data()?['walletBalance'] as num?)?.toDouble()) ?? 0.0;
  }

  Future<bool> hasSufficientBalance(double amount) async {
    return (await getWalletBalance()) >= amount;
  }

  /// Record a purchase and deduct walletBalance.
  /// `paymentMethod` will appear in paymentHistory (e.g., "wallet", "paynow", "credit").
  Future<bool> makePayment(double amount, String description,
      {String recipient = 'AllCare Shop',
      String paymentMethod = 'wallet'}) async {
    return _db.runTransaction<bool>((txn) async {
      final doc = await txn.get(_ref);
      final data = doc.data() ?? {};
      final current = ((data['walletBalance'] as num?)?.toDouble()) ?? 0.0;
      if (current < amount) {
        throw StateError('INSUFFICIENT_FUNDS');
      }
      final newBal = current - amount;

      final hist = List<Map<String, dynamic>>.from(
          (data['paymentHistory'] as List?) ?? const []);

      final id = 'payment_${DateTime.now().millisecondsSinceEpoch}';
      hist.add({
        'id': id,
        'type': 'purchase',
        'amount': amount,
        'description': description,
        'recipient': recipient,
        'paymentMethod': paymentMethod,
        'previousBalance': current,
        'newBalance': newBal,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      });

      txn.set(
        _ref,
        {
          'walletBalance': newBal,
          'paymentFailed': false,
          'paymentHistory': hist,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      return true;
    });
  }

  /// Top up and append to `topUpHistory`.
  Future<void> topUp(
    double amount, {
    required String paymentMethod, // "credit" | "debit" | "paynow"...
    Map<String, String>? cardDetails, // {cardNumber, cvv, expiryDate}
  }) async {
    await _db.runTransaction((txn) async {
      final doc = await txn.get(_ref);
      final data = doc.data() ?? {};
      final current = ((data['walletBalance'] as num?)?.toDouble()) ?? 0.0;
      final newBal = current + amount;

      final hist = List<Map<String, dynamic>>.from(
          (data['topUpHistory'] as List?) ?? const []);

      final id = 'topup_${DateTime.now().millisecondsSinceEpoch}';
      hist.add({
        'id': id,
        'amount': amount,
        'paymentMethod': paymentMethod,
        'cardDetails': cardDetails,
        'previousBalance': current,
        'newBalance': newBal,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      });

      txn.set(
        _ref,
        {
          'walletBalance': newBal,
          'topUpHistory': hist,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
  }

  /// Stream recent transactions merged (topups + purchases), newest first.
  Stream<List<WalletTxn>> transactionsStream() {
    return _ref.snapshots().map((snap) {
      final d = snap.data() ?? {};
      final purchases = List<Map<String, dynamic>>.from(
          (d['paymentHistory'] as List?) ?? const []);
      final topups = List<Map<String, dynamic>>.from(
          (d['topUpHistory'] as List?) ?? const []);

      final txs = <WalletTxn>[
        ...purchases.map((m) => WalletTxn(
              id: '${m['id']}',
              type: 'purchase',
              amount: ((m['amount'] as num?)?.toDouble()) ?? 0.0,
              createdAt: DateTime.tryParse('${m['timestamp']}') ??
                  DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
              description: '${m['description'] ?? 'Purchase'}',
              paymentMethod: '${m['paymentMethod'] ?? ''}',
            )),
        ...topups.map((m) => WalletTxn(
              id: '${m['id']}',
              type: 'topup',
              amount: ((m['amount'] as num?)?.toDouble()) ?? 0.0,
              createdAt: DateTime.tryParse('${m['timestamp']}') ??
                  DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
              description: 'Top up',
              paymentMethod: '${m['paymentMethod'] ?? ''}',
            )),
      ];

      txs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return txs;
    });
  }
}
