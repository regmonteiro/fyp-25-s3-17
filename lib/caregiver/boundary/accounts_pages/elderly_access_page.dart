import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../controller/account/elderly_access_controller.dart';

class ElderlyAccessPage extends StatefulWidget {
  const ElderlyAccessPage({Key? key}) : super(key: key);
  @override
  State<ElderlyAccessPage> createState() => _ElderlyAccessPageState();
}

class _ElderlyAccessPageState extends State<ElderlyAccessPage> {
  final _ctrl = ElderlyAccessController();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('User not authenticated.')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Elderly Accessibility (Caregiver)")),
      body: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.person_add),
            title: const Text("Link Elderly"),
            subtitle: const Text("Enter elderlyId (preferred) or email to resolve"),
            onTap: _showLinkDialog,
          ),
          const Divider(height: 1),
          Expanded(
  child: StreamBuilder<List<Map<String, dynamic>>>(
    stream: _ctrl.linkedElderlyStream(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }
      final items = snapshot.data ?? const <Map<String, dynamic>>[];
      if (items.isEmpty) {
        return const Center(child: Text("No elderly linked."));
      }

      return ListView(
        children: items.map((m) {
          final id    = m['id'] as String; // elderlyId
          final name  = (m['elderlyName']  ?? 'Elderly').toString();
          final email = (m['elderlyEmail'] ?? '').toString();
          final phone = (m['elderlyPhone'] ?? '').toString();
          final access = Map<String, dynamic>.from(m['access'] ?? {});

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: ExpansionTile(
              leading: const Icon(Icons.elderly),
              title: Text(name),
              subtitle: Text([email, phone].where((x) => x.isNotEmpty).join(' | ')),
              children: [
                _toggle("Allow Elderly to View Reminders",
                    access['elderlyViewReminders'] ?? true, (v) {
                  access['elderlyViewReminders'] = v;
                  _ctrl.updateAccess(id, access);
                }),
                _toggle("Allow Elderly to Create Reminders",
                    access['elderlyCreateReminders'] ?? true, (v) {
                  access['elderlyCreateReminders'] = v;
                  _ctrl.updateAccess(id, access);
                }),
                _toggle("Allow Elderly to View Health",
                    access['elderlyViewHealth'] ?? false, (v) {
                  access['elderlyViewHealth'] = v;
                  _ctrl.updateAccess(id, access);
                }),
                _toggle("Allow Elderly to Use Chat",
                    access['elderlyChat'] ?? true, (v) {
                  access['elderlyChat'] = v;
                  _ctrl.updateAccess(id, access);
                }),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: () => _ctrl.removeLink(id),
                      icon: const Icon(Icons.link_off, color: Colors.red),
                      label: const Text("Unlink", style: TextStyle(color: Colors.red)),
                    ),
                    TextButton(
                      onPressed: () => _ctrl.refreshLinkedElderlyInfo(id),
                      child: const Text("Refresh Info"),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        }).toList(),
      );
    },
  ),
),

        ],
      ),
    );
  }

  Widget _toggle(String label, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(title: Text(label), value: value, onChanged: onChanged);
  }

  Future<void> _showLinkDialog() async {
    final elderlyId    = TextEditingController();
    final elderlyEmail = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Link Elderly"),
        content: Form(
          key: formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(
              controller: elderlyId,
              decoration: const InputDecoration(
                labelText: "elderlyId (uid) — preferred",
              ),
            ),
            const SizedBox(height: 8),
            const Text("or"),
            const SizedBox(height: 8),
            TextFormField(
              controller: elderlyEmail,
              decoration: const InputDecoration(labelText: "Elderly email"),
              keyboardType: TextInputType.emailAddress,
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: ()=>Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              final id = elderlyId.text.trim();
              final email = elderlyEmail.text.trim().toLowerCase();
              if (id.isEmpty && email.isEmpty) return;
              await _ctrl.linkElderly(elderlyId: id.isEmpty ? null : id,
                                      elderlyEmail: email.isEmpty ? null : email);
              if (context.mounted) Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Elderly linked")),
              );
            },
            child: const Text("Link"),
          ),
        ],
      ),
    );
  }
}
