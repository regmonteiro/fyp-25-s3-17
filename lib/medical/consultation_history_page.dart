import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ConsultationHistoryPage extends StatelessWidget {
  // NOTE: This UID should be the elderly user's UID passed from the navigation context.
  final String elderlyUid = 'simulated_elderly_uid_123';

  const ConsultationHistoryPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GP Consultation History'),
        backgroundColor: Colors.indigo.shade700,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Query the 'consultations' collection filtered by the elderly user's UID
        stream: FirebaseFirestore.instance
            .collection('consultations')
            .where('elderlyUid', isEqualTo: elderlyUid)
            .orderBy('requestedAt', descending: true) // Newest consultations first
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error loading history: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history_toggle_off, size: 80, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    const Text(
                      'No past consultations found.',
                      style: TextStyle(fontSize: 18, color: Colors.black54, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Your call history will appear here after your first GP consultation.',
                      style: TextStyle(fontSize: 14, color: Colors.black45),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          // Data is present, build the list
          final consultations = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: consultations.length,
            itemBuilder: (context, index) {
              final data = consultations[index].data() as Map<String, dynamic>;
              final timestamp = data['requestedAt'] as Timestamp?;
              final date = timestamp != null
                  ? DateFormat('MMM d, yyyy @ h:mm a').format(timestamp.toDate())
                  : 'Date Unavailable';
              
              final status = data['status'] ?? 'Completed'; // Default to Completed
              final symptoms = data['symptoms'] ?? 'No symptoms recorded.';
              final includeCaregiver = data['includeCaregiver'] as bool? ?? false;
              
              // Simulate finding the GP/Outcome based on status
              final gpName = (status == 'Completed') ? 'Dr. Smith' : 'N/A';
              final diagnosis = (status == 'Completed') ? 'Mild seasonal allergy' : 'Awaiting Outcome';

              return ConsultationCard(
                date: date,
                status: status,
                symptoms: symptoms,
                gpName: gpName,
                diagnosis: diagnosis,
                includeCaregiver: includeCaregiver,
              );
            },
          );
        },
      ),
    );
  }
}

// Custom Widget for displaying a single consultation record
class ConsultationCard extends StatelessWidget {
  final String date;
  final String status;
  final String symptoms;
  final String gpName;
  final String diagnosis;
  final bool includeCaregiver;

  const ConsultationCard({
    required this.date,
    required this.status,
    required this.symptoms,
    required this.gpName,
    required this.diagnosis,
    required this.includeCaregiver,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 6,
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date and Status Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  date,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo.shade800,
                  ),
                ),
                _buildStatusChip(status),
              ],
            ),
            const Divider(height: 20, color: Colors.black12),

            // Symptoms
            const Text(
              'Initial Symptoms:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black54),
            ),
            const SizedBox(height: 4),
            Text(
              symptoms,
              style: const TextStyle(fontSize: 15),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            
            if (status == 'Completed') ...[
              const SizedBox(height: 12),
              // GP and Diagnosis
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.medical_services, size: 20, color: Colors.green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('GP Attended: $gpName', style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text('Diagnosis: $diagnosis', style: const TextStyle(fontStyle: FontStyle.italic)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            
            if (includeCaregiver) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.supervisor_account, size: 20, color: Colors.purple),
                  const SizedBox(width: 8),
                  Text(
                    'Caregiver Joined Call',
                    style: TextStyle(fontSize: 14, color: Colors.purple.shade700, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  // TODO: Implement a modal/page to view full consultation notes
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Viewing full details for call on ${date.split('@')[0].trim()}')),
                  );
                },
                child: const Text('View Full Details'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    IconData icon;
    
    switch (status) {
      case 'Completed':
        color = Colors.green.shade600;
        icon = Icons.check_circle;
        break;
      case 'Pending GP Connection':
        color = Colors.orange.shade600;
        icon = Icons.pending_actions;
        break;
      case 'Cancelled':
        color = Colors.red.shade600;
        icon = Icons.cancel;
        break;
      default:
        color = Colors.grey;
        icon = Icons.info;
    }

    return Chip(
      label: Text(
        status,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
      ),
      backgroundColor: color,
      avatar: Icon(icon, color: Colors.white, size: 18),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
    );
  }
}
