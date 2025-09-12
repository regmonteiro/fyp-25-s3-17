import 'package:flutter/material.dart';
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
            leading: const Icon(Icons.add),
            title: const Text("Add Caregiver"),
            subtitle: const Text("Redirects to payment to add caregiver (+\$25/mo)"),
            onTap: () => _showAddCaregiverFlow(),
          ),
          const Divider(),
          Expanded(
            child: StreamBuilder(
              stream: _ctrl.caregiversStream(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) return const Center(child: Text("No caregivers added."));
                return ListView(
                  children: docs.map((d) {
                    final data = d.data();
                    final access = Map<String, dynamic>.from(data['access'] ?? {});
                    return Card(
                      child: ExpansionTile(
                        leading: const Icon(Icons.person),
                        title: Text(data['name'] ?? 'Caregiver'),
                        subtitle: Text("${data['email'] ?? ''} | ${data['phone'] ?? ''}"),
                        children: [
                          _toggle("View Reminders", access['viewReminders'] ?? true, (v) {
                            access['viewReminders'] = v;
                            _ctrl.updateCaregiverAccess(d.id, access);
                          }),
                          _toggle("Create Reminders", access['createReminders'] ?? true, (v) {
                            access['createReminders'] = v;
                            _ctrl.updateCaregiverAccess(d.id, access);
                          }),
                          _toggle("View Health", access['viewHealth'] ?? false, (v) {
                            access['viewHealth'] = v;
                            _ctrl.updateCaregiverAccess(d.id, access);
                          }),
                          _toggle("Chat", access['chat'] ?? true, (v) {
                            access['chat'] = v;
                            _ctrl.updateCaregiverAccess(d.id, access);
                          }),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () => _ctrl.removeCaregiver(d.id),
                            icon: const Icon(Icons.delete, color: Colors.red),
                            label: const Text("Remove", style: TextStyle(color: Colors.red)),
                          ),
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
    return SwitchListTile(
      title: Text(label),
      value: value,
      onChanged: onChanged,
    );
  }

  Future<void> _showAddCaregiverFlow() async {
    // Simulate “redirect to payment” by showing a dialog to collect caregiver details,
    // then controller “charges” and saves (replace with real gateway as needed).
    final name = TextEditingController();
    final email = TextEditingController();
    final phone = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Add Caregiver (+\$25/mo)"),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(controller: name, decoration: const InputDecoration(labelText: "Name"), validator: (v)=>v!.isEmpty? "Required":null),
              TextFormField(controller: email, decoration: const InputDecoration(labelText: "Email"), keyboardType: TextInputType.emailAddress, validator: (v)=> (v!=null && v.contains("@"))? null : "Valid email"),
              TextFormField(controller: phone, decoration: const InputDecoration(labelText: "Phone"), keyboardType: TextInputType.phone, validator: (v)=>v!.isEmpty? "Required":null),
              const SizedBox(height: 8),
              const Text("You will be charged \$25/month for this additional caregiver."),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: ()=>Navigator.pop(context), child: const Text("Cancel")),
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
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Caregiver added")));
            },
          ),
        ],
      ),
    );
  }
}
