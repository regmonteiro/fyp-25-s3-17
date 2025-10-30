import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import '../../controller/account/settings_controller.dart';
import '../../../controller/app_settings.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final SettingsController _controller = SettingsController();
  final _auth = FirebaseAuth.instance;

  int _reminderTimeInMinutes = 15;
  double _fontScale = 1.0;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final reminder = await _controller.getReminderSettings(user.uid);
    final fontScale = await _controller.getFontScale(user.uid);

    if (!mounted) return;
    setState(() {
      _reminderTimeInMinutes = reminder?['reminderTimeInMinutes'] ?? 15;
      _fontScale = fontScale;
    });

    // reflect to provider so whole app scales
    context.read<AppSettings>().setTextScale(_fontScale);
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('User not authenticated.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Settings'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Reminders', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          const Text('Set how long before an appointment you would like to receive a notification reminder.'),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Remind me'),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: _reminderTimeInMinutes,
                items: const [5, 10, 15, 30, 60, 120]
                    .map((m) => DropdownMenuItem<int>(value: m, child: Text('$m minutes')))
                    .toList(),
                onChanged: (value) async {
                  if (value == null) return;
                  setState(() => _reminderTimeInMinutes = value);
                  await _controller.saveReminderSettings(user.uid, value);
                },
              ),
              const SizedBox(width: 8),
              const Text('before'),
            ],
          ),

          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),

          const Text('Font Size', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text('Adjust text size across the app. Current: ${(100 * _fontScale).round()}%'),
          Slider(
            min: 0.8, max: 1.6, divisions: 8,
            value: _fontScale,
            label: '${(100 * _fontScale).round()}%',
            onChanged: (v) {
              setState(() => _fontScale = v);
              context.read<AppSettings>().setTextScale(v); // live update
            },
            onChangeEnd: (v) async {
              await _controller.saveFontScale(user.uid, v);
            },
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [Text('Smaller'), Text('Default'), Text('Larger')],
          ),
        ],
      ),
    );
  }
}
