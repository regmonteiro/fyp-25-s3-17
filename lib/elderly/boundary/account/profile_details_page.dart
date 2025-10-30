import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../controller/account/profile_controller.dart';

class ProfileDetailsPage extends StatefulWidget {
  const ProfileDetailsPage({Key? key}) : super(key: key);

  @override
  State<ProfileDetailsPage> createState() => _ProfileDetailsPageState();
}

class _ProfileDetailsPageState extends State<ProfileDetailsPage> {
  final _ctrl = ProfileController();
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

  // caregiver linkage
  // supports both single elderlyId and array elderlyIds
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
    String userType = pickS(profile, ['userType', 'role', 'user_type'], def: '').toLowerCase();

    // Fill controllers with tolerant keys; email falls back to Auth
    setState(() {
      _firstname.text = pickS(profile, ['firstname', 'firstName', 'first_name']);
      _lastname.text  = pickS(profile, ['lastname', 'lastName', 'last_name']);
      _phoneNum.text  = pickS(profile, ['phoneNum', 'phone', 'mobile']);
      _email.text     = pickS(profile, ['email'], def: (auth?.email ?? ''));

      _accountStatus = pickS(profile, ['subscriptionStatus', 'status'], def: 'inactive');
      _profilePictureUrl = pickS(profile, ['profilePictureUrl', 'photoURL', 'photoUrl']);

      _userType = userType.isEmpty ? null : userType;

      _dob = parseDob(profile?['dob']);

      // Collect elderly links under multiple possible keys
      _elderlyIds.clear();
      final rawKeys = [
        'elderlyIds', 'linkedElderUids', 'linkedElders',
      ];
      final singleKeys = ['elderlyId', 'elderUid'];

      for (final k in rawKeys) {
        final v = profile?[k];
        if (v is List) {
          for (final e in v) {
            final s = e?.toString().trim();
            if (s != null && s.isNotEmpty) _elderlyIds.add(s);
          }
        }
      }
      for (final k in singleKeys) {
        final v = profile?[k];
        if (v is String && v.trim().isNotEmpty) _elderlyIds.add(v.trim());
      }

      // de-dupe
      final set = {..._elderlyIds};
      _elderlyIds
        ..clear()
        ..addAll(set);
    });

    // If caregiver, hydrate linked profiles
    if ((_userType == 'caregiver' || _userType == 'cg') && _elderlyIds.isNotEmpty) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Elderly Profile Details")),
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
                    _readonly("Account Status",
                        _accountStatus.toUpperCase()),

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
                      decoration: const InputDecoration(
                          labelText: "Phone Number"),
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
  if (url != null && url.isNotEmpty && (url.startsWith('http://') || url.startsWith('https://'))) {
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
                  style: const TextStyle(fontWeight: FontWeight.w600))),
          Flexible(child: Text(value, textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}
