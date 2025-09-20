import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../controller/learning_page_controller.dart';
import 'package:intl/intl.dart';

class LearningRewardHistoryPage extends StatelessWidget {
  const LearningRewardHistoryPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final LearningPageController controller = LearningPageController();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Redemption History'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: controller.getPointsHistoryStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading history.'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No redemption history found.'));
          }

          final historyDocs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: historyDocs.length,
            itemBuilder: (context, index) {
              final history = historyDocs[index].data() as Map<String, dynamic>;
              final int pointsRedeemed = history['pointsRedeemed'] ?? 0;
              final int voucherValue = history['voucherValue'] ?? 0;
              final Timestamp timestamp = history['timestamp'];

              final date = DateFormat('MMM d, yyyy').format(timestamp.toDate());
              final time = DateFormat('h:mm a').format(timestamp.toDate());

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: const Icon(Icons.star, color: Colors.amber),
                  title: Text('\$$voucherValue Hao Mart Voucher'),
                  subtitle: Text('Redeemed on $date at $time'),
                  trailing: Text(
                    '${pointsRedeemed} pts',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}