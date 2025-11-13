import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../controller/account/cg_profile_controller.dart';

class ProfileDetailsPage extends StatefulWidget {
  const ProfileDetailsPage({Key? key}) : super(key: key);

  @override
  State<ProfileDetailsPage> createState() => _ProfileDetailsPageState();
}

class _ProfileDetailsPageState extends State<ProfileDetailsPage> {
  final _ctrl = CgProfileController();
  final _formKey = GlobalKey<FormState>();

  // editable fields
  final _firstname = TextEditingController();
  final _lastname = TextEditingController();
  final _phoneNum = TextEditingController();
  final _email = TextEditingController();

  DateTime? _dob;
  String _accountStatus = 'inactive';
  String? _profilePictureUrl;

  // new: display uid & userType
  String _uid = '';
  String? _userType;

  final List<String> _elderlyIds = [];
  List<Map<String, dynamic>> _linkedElderlies = [];

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final auth = FirebaseAuth.instance.currentUser;
      _uid = auth?.uid ?? '';

      final profile = await _ctrl.fetchProfile(); // Map<String, dynamic>? (may be null)

      if (!mounted) return;

      // Helper to read multiple possible keys
      String pickS(Map<String, dynamic>? m, List<String> keys, {String def = ''}) {
        if (m == null) return def;
        for (final k in keys) {
          final v = m[k];
          if (v is String && v.trim().isNotEmpty) return v.trim();
        }
        return def;
      }

      // Try to parse DOB from multiple formats
      DateTime? parseDob(dynamic raw) {
        if (raw == null) return null;
        if (raw is DateTime) return raw;
        if (raw is String) {
          // Try strict yyyy-MM-dd then fallback to DateTime.tryParse
          return DateFormat('yyyy-MM-dd').tryParse(raw) ?? DateTime.tryParse(raw);
        }
        // Firestore Timestamp?
        try {
          final ts = raw as dynamic;
          if (ts?.toDate != null) return ts.toDate() as DateTime;
        } catch (_) {}
        return null;
      }

      // Role / userType normalization
      String userType =
          pickS(profile, ['userType', 'role', 'user_type'], def: '').toLowerCase();

      // Fill controllers with tolerant keys; email falls back to Auth
      setState(() {
        _firstname.text =
            pickS(profile, ['firstname', 'firstName', 'first_name']);
        _lastname.text =
            pickS(profile, ['lastname', 'lastName', 'last_name']);
        _phoneNum.text = pickS(profile, ['phoneNum', 'phone', 'mobile']);
        _email.text = pickS(profile, ['email'], def: (auth?.email ?? ''));

        _accountStatus =
            pickS(profile, ['subscriptionStatus', 'status'], def: 'inactive');
        _profilePictureUrl =
            pickS(profile, ['profilePictureUrl', 'photoURL', 'photoUrl']);

        _userType = userType.isEmpty ? null : userType;

        _dob = parseDob(profile?['dob']);

        // Collect elderly links under multiple possible keys
        _elderlyIds.clear();
        final list = profile?['elderlyIds'];
        if (list is List) {
          for (final e in list) {
            final s = e?.toString().trim();
            if (s != null && s.isNotEmpty) _elderlyIds.add(s);
          }
        }

        // (optional legacy) single id support
        final single = (profile?['elderlyId'] as String?)?.trim();
        if (single != null && single.isNotEmpty) _elderlyIds.add(single);

        // de-dupe
        final set = <String>{..._elderlyIds};
        _elderlyIds
          ..clear()
          ..addAll(set);
      });

      // If caregiver, hydrate linked profiles
      if ((_userType == 'caregiver' || _userType == 'cg') &&
          _elderlyIds.isNotEmpty) {
        final elderlies = await _ctrl.fetchElderlyProfilesByIds(_elderlyIds);
        if (mounted) setState(() => _linkedElderlies = elderlies);
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to load profile: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final update = <String, dynamic>{
      // use your Firestore schema keys
      'firstname': _firstname.text.trim(),
      'lastname': _lastname.text.trim(),
      'phoneNum': _phoneNum.text.trim(),
      'dob': _dob != null ? DateFormat('yyyy-MM-dd').format(_dob!) : null,
      // do not let users edit email here; it’s read-only
    };

    try {
      await _ctrl.updateProfile(update);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile updated")),
        );
      }
    } catch (e) {
      debugPrint('updateProfile error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to update profile.")),
        );
      }
    }
  }

  Future<void> _uploadProfilePicture() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    final file = File(pickedFile.path);
    setState(() => _loading = true);

    try {
      final downloadUrl = await _ctrl.uploadProfilePicture(file);
      await _ctrl.updateProfile({'profilePictureUrl': downloadUrl});
      if (mounted) {
        setState(() => _profilePictureUrl = downloadUrl);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile picture uploaded!")),
        );
      }
    } catch (e) {
      debugPrint('uploadProfilePicture error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to upload image.")),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ─────────────── LOGIN HISTORY HELPERS ───────────────

  String _emailKeyFrom(String email) {
    final lower = email.trim().toLowerCase();
    final at = lower.indexOf('@');
    if (at < 0) return lower.replaceAll('.', '_');
    final local = lower.substring(0, at);
    final domain = lower.substring(at + 1).replaceAll('.', '_');
    return '$local@$domain';
  }

  Future<List<DateTime>> _loadLoginHistory() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null || user.email!.isEmpty) {
      throw Exception('User not signed in or missing email');
    }

    final emailKey = _emailKeyFrom(user.email!);
    final doc = await FirebaseFirestore.instance
        .collection('Account')
        .doc(emailKey)
        .get();

    final data = doc.data() ?? {};
    final rawLogs = data['loginLogs'];

    if (rawLogs == null || rawLogs is! Map<String, dynamic>) {
      return [];
    }

    final List<DateTime> out = [];
    rawLogs.forEach((_, value) {
      try {
        // value is expected to be { date: "2025-11-05T06:26:05.122Z" }
        String? dateStr;
        if (value is Map<String, dynamic>) {
          dateStr = value['date']?.toString();
        } else {
          dateStr = value.toString();
        }
        if (dateStr != null && dateStr.isNotEmpty) {
          out.add(DateTime.parse(dateStr));
        }
      } catch (_) {
        // ignore bad entries
      }
    });

    // Sort newest first
    out.sort((a, b) => b.compareTo(a));
    return out;
  }

  String _relativeTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inDays >= 1) {
      return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
    } else if (diff.inHours >= 1) {
      return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
    } else if (diff.inMinutes >= 1) {
      return '${diff.inMinutes} min${diff.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'just now';
    }
  }

  Future<void> _showLoginHistorySheet() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FutureBuilder<List<DateTime>>(
              future: _loadLoginHistory(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 120,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return SizedBox(
                    height: 120,
                    child: Center(
                      child: Text(
                        'Failed to load login history.\n${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                final logs = snapshot.data ?? [];
                if (logs.isEmpty) {
                  return const SizedBox(
                    height: 120,
                    child: Center(child: Text('No login history recorded yet.')),
                  );
                }

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Login History',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: logs.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final dt = logs[index].toLocal();
                          final formatted =
                              DateFormat.yMMMd().add_jm().format(dt);
                          final rel = _relativeTime(dt);
                          return ListTile(
                            leading: const Icon(Icons.login),
                            title: Text(formatted),
                            subtitle: Text(rel),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Profile Details")),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildProfilePictureSection(),
                    const SizedBox(height: 24),

                    // NEW: UID & account status
                    _readonly("UID", _uid.isEmpty ? '-' : _uid),
                    const SizedBox(height: 8),
                    _readonly("Account Status", _accountStatus.toUpperCase()),

                    const SizedBox(height: 8),
                    // NEW: view login history button
                    OutlinedButton.icon(
                      onPressed: _showLoginHistorySheet,
                      icon: const Icon(Icons.history),
                      label: const Text("View Login History"),
                    ),

                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _firstname,
                      decoration:
                          const InputDecoration(labelText: "First Name"),
                      validator: (v) => v!.isEmpty ? "Required" : null,
                    ),
                    TextFormField(
                      controller: _lastname,
                      decoration:
                          const InputDecoration(labelText: "Last Name"),
                      validator: (v) => v!.isEmpty ? "Required" : null,
                    ),
                    TextFormField(
                      controller: _phoneNum,
                      decoration:
                          const InputDecoration(labelText: "Phone Number"),
                      validator: (v) => v!.isEmpty ? "Required" : null,
                    ),
                    TextFormField(
                      controller: _email,
                      readOnly: true,
                      decoration: const InputDecoration(
                          labelText: "Email (locked)"),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Text(_dob == null
                              ? "DOB: not set"
                              : "DOB: ${DateFormat.yMMMd().format(_dob!)}"),
                        ),
                        TextButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _dob ?? DateTime(1950),
                              firstDate: DateTime(1900),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) setState(() => _dob = picked);
                          },
                          child: const Text("Select DOB"),
                        )
                      ],
                    ),

                    const Divider(height: 32),

                    // caregiver linkage section
                    if (_userType == 'caregiver') ...[
                      const Text("Linked Elderly",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      if (_elderlyIds.isEmpty)
                        const Text("No elderly linked.")
                      else ...[
                        // show the raw elderlyId(s)
                        _readonly(
                            _elderlyIds.length == 1
                                ? "elderlyId"
                                : "elderlyIds",
                            _elderlyIds.join(", ")),
                        const SizedBox(height: 8),
                        // show loaded elderly profiles
                        ..._linkedElderlies
                            .map((e) => _elderCard(e))
                            .toList(),
                      ],
                      const SizedBox(height: 12),
                    ],

                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _save,
                      child: const Text("Save Changes"),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildProfilePictureSection() {
    ImageProvider? img;
    final url = _profilePictureUrl?.trim();
    if (url != null &&
        url.isNotEmpty &&
        (url.startsWith('http://') || url.startsWith('https://'))) {
      img = NetworkImage(url);
    }

    return Center(
      child: Column(
        children: [
          CircleAvatar(
            radius: 60,
            backgroundImage: img,
            child: img == null ? const Icon(Icons.person, size: 60) : null,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _uploadProfilePicture,
            icon: const Icon(Icons.camera_alt),
            label: const Text('Upload Profile Picture'),
          ),
        ],
      ),
    );
  }

  Widget _readonly(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Flexible(child: Text(value, textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  // Card for each linked elderly profile
  // Expected fields in map: firstname/lastname/email/phoneNum/uid
  Widget _elderCard(Map<String, dynamic> e) {
    final name = [
      (e['firstname'] ?? '').toString().trim(),
      (e['lastname'] ?? '').toString().trim(),
    ].where((s) => s.isNotEmpty).join(' ');
    final email = (e['email'] ?? '-').toString();
    final phone = (e['phoneNum'] ?? '-').toString();
    final uid = (e['uid'] ?? '-').toString();

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        dense: true,
        title: Text(name.isEmpty ? '(No name)' : name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Email: $email'),
            Text('Phone: $phone'),
            Text('UID: $uid'),
          ],
        ),
      ),
    );
  }
}
