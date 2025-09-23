import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
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
  final _firstName = TextEditingController();
  final _lastName  = TextEditingController();
  final _phone     = TextEditingController();
  final _email     = TextEditingController();
  DateTime? _dob;
  String _accountStatus = 'active';
  String? _profilePictureUrl;

  Map<String, dynamic>? _caregiver;

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      // Use Future.wait to fetch data concurrently for better performance
      final results = await Future.wait([
        _ctrl.fetchProfile(),
        _ctrl.fetchPrimaryCaregiver(),
      ]);

      final data = results[0];
      final cg   = results[1];
      if (mounted) {
        setState(() {
          _caregiver = cg;
          _firstName.text = (data?['firstName'] ?? '');
          _lastName.text  = (data?['lastName'] ?? '');
          _phone.text     = (data?['phone'] ?? '');
          _email.text     = (data?['email'] ?? '');
          _accountStatus  = (data?['subscriptionStatus'] ?? 'inactive');
          _profilePictureUrl = (data?['profilePictureUrl']);
          final dobIso    = data?['dob'];
          _dob = (dobIso != null) ? DateTime.tryParse(dobIso) : null;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() { _loading = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to load profile.")),
        );
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    await _ctrl.updateProfile({
      'firstName': _firstName.text.trim(),
      'lastName' : _lastName.text.trim(),
      'phone'    : _phone.text.trim(),
      'dob'      : _dob?.toIso8601String(),
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile updated")),
      );
    }
  }
  
  Future<void> _uploadProfilePicture() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final file = File(pickedFile.path);
      setState(() { _loading = true; });

      try {
        final downloadUrl = await _ctrl.uploadProfilePicture(file);
        await _ctrl.updateProfile({'profilePictureUrl': downloadUrl});
        setState(() { _profilePictureUrl = downloadUrl; });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile picture uploaded!")),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to upload image.")),
        );
      } finally {
        setState(() { _loading = false; });
      }
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
                    _buildProfilePictureSection(), // New section for profile picture
                    const SizedBox(height: 24),
                    _readonly("Account Status", _accountStatus.toUpperCase()),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _firstName,
                      decoration: const InputDecoration(labelText: "First Name"),
                      validator: (v) => v!.isEmpty ? "Required" : null,
                    ),
                    TextFormField(
                      controller: _lastName,
                      decoration: const InputDecoration(labelText: "Last Name"),
                      validator: (v) => v!.isEmpty ? "Required" : null,
                    ),
                    TextFormField(
                      controller: _phone,
                      decoration: const InputDecoration(labelText: "Phone Number"),
                      validator: (v) => v!.isEmpty ? "Required" : null,
                    ),
                    TextFormField(
                      controller: _email,
                      readOnly: true,
                      decoration: const InputDecoration(labelText: "Email (locked)"),
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
                    const Text("Linked Caregiver", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    if (_caregiver == null)
                      const Text("No caregiver linked.")
                    else
                      _readonly(
                        "Caregiver",
                        "${_caregiver?['name'] ?? '-'}  |  ${_caregiver?['email'] ?? '-'}  |  ${_caregiver?['phone'] ?? '-'}",
                      ),
                    const SizedBox(height: 24),
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
    return Center(
      child: Column(
        children: [
          CircleAvatar(
            radius: 60,
            backgroundImage: _profilePictureUrl != null
                ? NetworkImage(_profilePictureUrl!)
                : const AssetImage('assets/default_profile.png') as ImageProvider,
            child: _profilePictureUrl == null ? const Icon(Icons.person, size: 60) : null,
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
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
          Text(value),
        ],
      ),
    );
  }
}