import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../controller/account/caregiver_controller.dart';

class CaregiverAccessPage extends StatefulWidget {
  const CaregiverAccessPage({Key? key}) : super(key: key);

  @override
  State<CaregiverAccessPage> createState() => _CaregiverAccessPageState();
}

class _CaregiverAccessPageState extends State<CaregiverAccessPage> {
  final _ctrl = CaregiverController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Caregiver Accessibility")),
      body: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.person_add_alt_1),
            title: const Text("Add Caregiver"),
            subtitle: const Text("Redirects to payment to add caregiver (+\$25/mo)"),
            onTap: _showAddCaregiverFlow,
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _ctrl.caregiversStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Error: ${snapshot.error}', textAlign: TextAlign.center),
                    ),
                  );
                }

                final docs = snapshot.data?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                if (docs.isEmpty) {
                  return const Center(child: Text("No caregivers added."));
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final d = docs[i];
                    final data = d.data();

                    // Basic caregiver fields (defensive)
                    final name     = (data['name'] ?? '').toString().trim();
                    final email    = (data['email'] ?? '').toString().trim();
                    final phone    = (data['phone'] ?? '').toString().trim();
                    final photoUrl = (data['photoUrl'] ?? data['photoURL'] ?? '').toString().trim();
                    final since    = (data['since'] ?? data['createdAt'] ?? '').toString().trim();
                    final lastSeen = (data['lastActive'] ?? '').toString().trim();
                    final role     = (data['role'] ?? 'caregiver').toString().trim();

                    // Access map (clone to avoid mutating the Map view from snapshot)
                    final access = Map<String, dynamic>.from(data['access'] ?? {});
                    bool viewReminders   = (access['viewReminders'] ?? true) == true;
                    bool createReminders = (access['createReminders'] ?? true) == true;
                    bool viewHealth      = (access['viewHealth'] ?? false) == true;
                    bool chat            = (access['chat'] ?? true) == true;

                    return Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ExpansionTile(
                        leading: _avatar(photoUrl, name),
                        title: Text(name.isEmpty ? 'Caregiver' : name,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          [
                            if (role.isNotEmpty) role,
                            if (email.isNotEmpty) email,
                            if (phone.isNotEmpty) phone,
                          ].join(' • '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        children: [
                          // Linked caregiver details
                          _detailRow('Email', email.isEmpty ? '—' : email),
                          _detailRow('Phone', phone.isEmpty ? '—' : phone),
                          _detailRow('Since', since.isEmpty ? '—' : since),
                          _detailRow('Last active', lastSeen.isEmpty ? '—' : lastSeen),
                          const SizedBox(height: 8),
                          const Divider(),

                          // Access toggles
                          _toggle(
                            "View Reminders", viewReminders, (v) {
                              final next = {
                                ...access,
                                'viewReminders': v,
                              };
                              _ctrl.updateCaregiverAccess(d.id, next);
                            },
                          ),
                          _toggle(
                            "Create Reminders", createReminders, (v) {
                              final next = {
                                ...access,
                                'createReminders': v,
                              };
                              _ctrl.updateCaregiverAccess(d.id, next);
                            },
                          ),
                          _toggle(
                            "View Health", viewHealth, (v) {
                              final next = {
                                ...access,
                                'viewHealth': v,
                              };
                              _ctrl.updateCaregiverAccess(d.id, next);
                            },
                          ),
                          _toggle(
                            "Chat", chat, (v) {
                              final next = {
                                ...access,
                                'chat': v,
                              };
                              _ctrl.updateCaregiverAccess(d.id, next);
                            },
                          ),

                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () => _confirmRemove(d.id, name),
                              icon: const Icon(Icons.delete, color: Colors.red),
                              label: const Text("Remove", style: TextStyle(color: Colors.red)),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ------- Widgets & Helpers

  Widget _avatar(String photoUrl, String fallbackName) {
    if (photoUrl.isNotEmpty) {
      return CircleAvatar(backgroundImage: NetworkImage(photoUrl));
    }
    final initial = (fallbackName.isNotEmpty ? fallbackName[0] : 'C').toUpperCase();
    return CircleAvatar(child: Text(initial));
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(color: Colors.black54)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _toggle(String label, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      value: value,
      onChanged: onChanged,
    );
  }

  Future<void> _confirmRemove(String caregiverId, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove caregiver'),
        content: Text(
          'Are you sure you want to remove ${name.isEmpty ? 'this caregiver' : name}?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok == true) {
      await _ctrl.removeCaregiver(caregiverId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Caregiver removed')));
    }
  }

  Future<void> _showAddCaregiverFlow() async {
    final name = TextEditingController();
    final email = TextEditingController();
    final phone = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Add Caregiver (+\$25/mo)"),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: name,
                  decoration: const InputDecoration(labelText: "Name", border: OutlineInputBorder()),
                  validator: (v) => (v == null || v.trim().isEmpty) ? "Required" : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: email,
                  decoration: const InputDecoration(labelText: "Email", border: OutlineInputBorder()),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    final s = v?.trim() ?? '';
                    return (s.contains('@') && s.contains('.')) ? null : "Valid email";
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phone,
                  decoration: const InputDecoration(labelText: "Phone", border: OutlineInputBorder()),
                  keyboardType: TextInputType.phone,
                  validator: (v) => (v == null || v.trim().isEmpty) ? "Required" : null,
                ),
                const SizedBox(height: 12),
                const Text(
                  "You will be charged \$25/month for this additional caregiver.",
                  style: TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            child: const Text("Confirm & Pay"),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              await _ctrl.addCaregiverAndCharge({
                'name': name.text.trim(),
                'email': email.text.trim(),
                'phone': phone.text.trim(),
              });
              if (mounted) Navigator.pop(context);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Caregiver added")));
            },
          ),
        ],
      ),
    );

    name.dispose();
    email.dispose();
    phone.dispose();
  }
}
