import 'package:flutter/material.dart';
import '../../controller/account/auth_controller.dart';

class PasswordSettingsPage extends StatefulWidget {
  const PasswordSettingsPage({Key? key}) : super(key: key);

  @override
  State<PasswordSettingsPage> createState() => _PasswordSettingsPageState();
}

class _PasswordSettingsPageState extends State<PasswordSettingsPage> {
  final _ctrl = AuthController();
  final _formKey = GlobalKey<FormState>();

  final _email = TextEditingController();
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();

  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Password Settings")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(children: [
            TextFormField(controller: _email, decoration: const InputDecoration(labelText: "Email"), validator: (v)=> v!=null && v.contains("@") ? null : "Valid email"),
            TextFormField(controller: _current, decoration: const InputDecoration(labelText: "Current Password"), obscureText: true, validator: (v)=> v!.isEmpty? "Required":null),
            TextFormField(controller: _new, decoration: const InputDecoration(labelText: "New Password (min 8)"), obscureText: true, validator: (v)=> v!=null && v.length>=8 ? null : "Min 8 chars"),
            TextFormField(controller: _confirm, decoration: const InputDecoration(labelText: "Confirm New Password"), obscureText: true, validator: (v)=> v==_new.text ? null : "Passwords do not match"),
            const SizedBox(height: 16),
            _busy ? const CircularProgressIndicator() : ElevatedButton(
              onPressed: () async {
                if (!_formKey.currentState!.validate()) return;
                setState(()=>_busy=true);
                try {
                  await _ctrl.changePassword(_email.text.trim(), _current.text.trim(), _new.text.trim());
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Password updated")));
                    Navigator.pop(context);
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                  }
                } finally {
                  if (mounted) setState(()=>_busy=false);
                }
              },
              child: const Text("Change Password"),
            ),
          ]),
        ),
      ),
    );
  }
}
