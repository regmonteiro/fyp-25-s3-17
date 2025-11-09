import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'wallet_service_ps.dart';

class WalletTransaction {
  final String id;
  final String type; // "TopUp" | "Purchase" | "Refund"
  final double amount;
  final DateTime createdAt;
  final String description;

  WalletTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.createdAt,
    required this.description,
  });
}

class WalletController extends ChangeNotifier {
  final String userEmail;
  final String? userId;

  late final WalletServicePs _svc;
  double _balance = 0.0;

  WalletController({required this.userEmail, this.userId}) {
    _svc = WalletServicePs(email: userEmail, db: FirebaseFirestore.instance);
    _init();
  }

  double get currentBalance => _balance;

  Future<void> _init() async {
    await _svc.initialize();
    _balance = await _svc.getWalletBalance();
    notifyListeners();
  }

  Stream<List<WalletTransaction>> get transactionsStream =>
      _svc.transactionsStream().map((list) => list.map((t) {
            return WalletTransaction(
              id: t.id,
              type: t.type == 'topup' ? 'TopUp' : 'Purchase',
              amount: t.amount,
              createdAt: t.createdAt.toLocal(),
              description: t.description,
            );
          }).toList());

  Future<void> refresh() async {
    _balance = await _svc.getWalletBalance();
    notifyListeners();
  }

  Future<void> topUpWallet({
    required double amount,
    required String paymentMethod,
    Map<String, String>? cardDetails,
  }) async {
    await _svc.topUp(amount, paymentMethod: paymentMethod, cardDetails: cardDetails);
    await refresh();
  }

  Future<bool> pay(double amount, {required String description, String method = 'wallet'}) async {
    final ok = await _svc.makePayment(amount, description, paymentMethod: method);
    await refresh();
    return ok;
  }

  Future<bool> hasSufficientBalance(double amount) => _svc.hasSufficientBalance(amount);
}
