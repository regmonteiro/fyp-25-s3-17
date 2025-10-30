import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/user_profile.dart';
import 'controller/health_records_controller.dart';
import 'health_upload_page.dart';

class HealthRecordsPage extends StatelessWidget {
  final UserProfile userProfile;
  const HealthRecordsPage({super.key, required this.userProfile});

  @override
  Widget build(BuildContext context) {
    final isCaregiver = userProfile.userType == 'caregiver';
    final elderlyUid = isCaregiver && (userProfile.elderlyId ?? '').isNotEmpty
        ? userProfile.elderlyId!
        : userProfile.uid;

    final controller = HealthRecordsController(
      elderlyUid: elderlyUid,
      currentUserUid: userProfile.uid,
      currentUserName: userProfile.safeDisplayName,
    );

    return ChangeNotifierProvider.value(
      value: controller,
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text("Health Records"),
            backgroundColor: Colors.blue.shade800,
            foregroundColor: Colors.white,
            bottom: const TabBar(
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              tabs: [
                Tab(text: "Your records", icon: Icon(Icons.description)),
                Tab(text: "Upload", icon: Icon(Icons.cloud_upload)),
              ],
            ),
          ),
          body: const TabBarView(
            children: [
              _YourRecordsView(),
              HealthUploadPage(),
            ],
          ),
        ),
      ),
    );
  }
}

class _YourRecordsView extends StatelessWidget {
  const _YourRecordsView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.read<HealthRecordsController>();

    return StreamBuilder<List<HealthRecord>>(
      stream: controller.recordsStream(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text("Error loading records: ${snap.error}"));
        }
        final records = snap.data ?? const <HealthRecord>[];
        if (records.isEmpty) {
          return _EmptyState();
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16.0),
          itemCount: records.length,
          itemBuilder: (context, i) {
            final r = records[i];
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              elevation: 1,
              child: ListTile(
                leading: _typeIcon(r.recordType),
                title: Text(r.recordName, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Type: ${r.recordType}"),
                    Text("Dated: ${DateFormat('MMM dd, yyyy').format(r.documentDate)}"),
                    Text(
                      "Uploaded by: ${r.uploadedByName} on ${DateFormat('MM/dd').format(r.uploadedAt)}",
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
                isThreeLine: true,
                trailing: const Icon(Icons.open_in_new, color: Colors.blue),
                onTap: () {
                  // TODO: open a viewer / url_launcher
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Open: ${r.fileUrl}')),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _EmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_off, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 20),
            const Text("No Health Records Found", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              "Upload lab results, immunisations, and other documents to keep them safe and accessible.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Icon _typeIcon(String type) {
    switch (type) {
      case 'Lab Results':
        return const Icon(Icons.science, color: Colors.red);
      case 'Radiology':
        return const Icon(Icons.medical_information, color: Colors.blue);
      case 'Immunisations':
        return const Icon(Icons.vaccines, color: Colors.green);
      case 'Consultation Documents':
        return const Icon(Icons.folder_shared, color: Colors.orange);
      default:
        return const Icon(Icons.description, color: Colors.grey);
    }
  }
}
