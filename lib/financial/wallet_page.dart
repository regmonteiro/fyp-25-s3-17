import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/user_profile.dart';
import 'wallet_controller.dart';
import 'top_up_page.dart';


class WalletPage extends StatelessWidget {
  final UserProfile userProfile;
  const WalletPage({super.key, required this.userProfile});

  @override
  Widget build(BuildContext context) {

    return ChangeNotifierProvider(
      create: (_) => WalletController(userId: userProfile.uid),
      child: Scaffold(
        appBar: AppBar(
          title: const Text("My Wallet"),
          backgroundColor: Colors.blue.shade800,
          foregroundColor: Colors.white,
        ),
        body: Consumer<WalletController>(
          builder: (context, controller, _) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _BalanceCard(controller: controller, userProfile: userProfile),
                  const SizedBox(height: 30),
                  const Text(
                    "Recent Transactions",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  _TransactionHistory(),
                  const SizedBox(height: 100),
                ],
              ),
            );
          },
        ),
        bottomSheet: _DiscoverButton(),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final WalletController controller;
  final UserProfile userProfile;
  const _BalanceCard({required this.controller, required this.userProfile});

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '\$').format(controller.currentBalance);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 5, offset: const Offset(0, 3))],
      ),
      child: Column(
        children: [
          const Text("Wallet Balance", style: TextStyle(fontSize: 16, color: Colors.black54)),
          const SizedBox(height: 8),
          Text(currency, style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.blue.shade800)),
          const SizedBox(height: 15),
          ElevatedButton(
            onPressed: () {
                final controller = context.read<WalletController>();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChangeNotifierProvider<WalletController>.value(
                      value: controller,
                      child: TopUpPage(userProfile: userProfile),
                    ),
                  ),
                );
              },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade50,
              foregroundColor: Colors.blue.shade800,
              shape: const CircleBorder(),
              padding: const EdgeInsets.all(12),
              elevation: 0,
            ),
            child: const Icon(Icons.add, size: 28),
          ),
          const Text("Top up", style: TextStyle(color: Colors.black87)),
        ],
      ),
    );
  }
}

class _TransactionHistory extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final controller = context.read<WalletController>();
    return StreamBuilder<List<WalletTransaction>>(
      stream: controller.transactionsStream,
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return const Center(child: Text("Error loading transactions."));
        }
        final txs = snap.data ?? const <WalletTransaction>[];
        if (txs.isEmpty) return _EmptyState();

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: txs.length,
          itemBuilder: (_, i) {
            final tx = txs[i];
            final isCredit = tx.type == 'TopUp' || tx.type == 'Refund';
            final color = isCredit ? Colors.green.shade700 : Colors.red.shade700;
            final icon = isCredit ? Icons.arrow_upward : Icons.arrow_downward;
            final symbol = isCredit ? '+' : '-';
            final amount = NumberFormat.currency(symbol: '\$').format(tx.amount);

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              elevation: 0.5,
              child: ListTile(
                leading: CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color)),
                title: Text(tx.description, style: const TextStyle(fontWeight: FontWeight.w500)),
                subtitle: Text(DateFormat('MMM dd, yyyy h:mm a').format(tx.createdAt)),
                trailing: Text('$symbol$amount', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
              ),
            );
          },
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(height: 200, alignment: Alignment.center, child: Icon(Icons.wallet, size: 80, color: Colors.grey.shade400)),
        const SizedBox(height: 20),
        const Text("No transactions yet", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text(
          "Ready to explore DA offering? Discover our products, services & pay with your Wallet",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 40),
      ],
    );
  }
}

class _DiscoverButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: ElevatedButton(
        onPressed: () {
          // Navigate to your shop/GP booking etc.
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue.shade800,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 55),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Text("Discover", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
