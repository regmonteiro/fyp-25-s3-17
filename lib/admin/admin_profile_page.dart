import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_shell.dart';
import '../models/user_profile.dart';

class AdminProfilePage extends StatefulWidget {
  final UserProfile userProfile;

  const AdminProfilePage({Key? key, required this.userProfile})
    : super(key: key);

  @override
  _AdminProfileState createState() => _AdminProfileState();
}

class _AdminProfileState extends State<AdminProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  User? _currentUser;

  // Text Editing Controllers
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _birthDateController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  // State variables
  bool _isEditMode = false;
  bool _isLoading = true;
  bool _isDisposed = false;
  String _originalFirstName = '';
  String _originalLastName = '';
  String _originalBirthDate = '';
  String _originalPhoneNumber = '';
  String _accountCreated = 'Loading...';
  String _lastLogin = 'Loading...';

  // Colors
  final Color _purpleColor = Colors.purple.shade500;
  final Color _whiteColor = Colors.white;
  final Color _blackColor = Colors.black;
  final Color _grayColor = Colors.grey;
  final Color _redColor = Colors.red;

  static const String _TAG = "AdminProfile";

  @override
  void initState() {
    super.initState();
    print('$_TAG: initState started');
    _currentUser = _auth.currentUser;
    _initializeData();
  }

  void _safeSetState(VoidCallback fn) {
    if (!_isDisposed && mounted) {
      setState(fn);
    }
  }

  void _initializeData() {
    print('$_TAG: Checking passed profile data...');
    print('$_TAG: Profile UID: ${widget.userProfile.uid}');
    print('$_TAG: Profile firstname: ${widget.userProfile.firstname}');
    print('$_TAG: Profile email: ${widget.userProfile.email}');

    // Always use passed data first for immediate display
    _initializeWithUserProfile();

    // Then try to load from Firestore to get latest data
    _loadUserDataFromFirestore();
  }

  void _initializeWithUserProfile() {
    if (!mounted) return;

    final firstName = widget.userProfile.firstname ?? 'Not provided';
    final lastName = widget.userProfile.lastname ?? 'Not provided';
    final birthDate = widget.userProfile.dob != null
        ? _formatDate(widget.userProfile.dob!)
        : 'Not provided';
    final phone = widget.userProfile.phoneNum ?? 'Not provided';
    final accountCreated = widget.userProfile.createdAt != null
        ? _formatDate(widget.userProfile.createdAt!)
        : 'Not available';

    _safeSetState(() {
      _firstNameController.text = firstName;
      _lastNameController.text = lastName;
      _birthDateController.text = birthDate;
      _phoneController.text = phone;
      _accountCreated = accountCreated;
      _lastLogin = 'Recently';
    });

    // Save original values for cancel functionality
    _originalFirstName = _firstNameController.text;
    _originalLastName = _lastNameController.text;
    _originalBirthDate = _birthDateController.text;
    _originalPhoneNumber = _phoneController.text;

    print('$_TAG: Profile initialized successfully');
  }

  void _loadUserDataFromFirestore() {
    if (_currentUser == null) {
      print('$_TAG: No current user found');
      _safeSetState(() {
        _isLoading = false;
      });
      return;
    }

    print('$_TAG: Loading from Firestore path: Account/${_currentUser!.uid}');

    _db
        .collection("Account")
        .doc(_currentUser!.uid)
        .get()
        .then((doc) {
          print('$_TAG: Firestore document exists: ${doc.exists}');

          if (!doc.exists) {
            print(
              '$_TAG: Document does not exist for UID: ${_currentUser!.uid}',
            );
            print('$_TAG: Using passed profile data instead');
            _safeSetState(() {
              _isLoading = false;
            });
            return;
          }

          final data = doc.data() as Map<String, dynamic>? ?? {};
          print('$_TAG: Firestore data keys: ${data.keys}');

          final userProfile = UserProfile.fromMap(data, _currentUser!.uid);

          _safeSetState(() {
            _firstNameController.text =
                userProfile.firstname ?? _firstNameController.text;
            _lastNameController.text =
                userProfile.lastname ?? _lastNameController.text;
            _birthDateController.text = userProfile.dob != null
                ? _formatDate(userProfile.dob!)
                : _birthDateController.text;
            _phoneController.text =
                userProfile.phoneNum ?? _phoneController.text;

            _accountCreated = userProfile.createdAt != null
                ? _formatDate(userProfile.createdAt!)
                : _accountCreated;

            _isLoading = false;
          });

          // Update original values
          _originalFirstName = _firstNameController.text;
          _originalLastName = _lastNameController.text;
          _originalBirthDate = _birthDateController.text;
          _originalPhoneNumber = _phoneController.text;

          print('$_TAG: Firestore data loaded successfully');
        })
        .catchError((e) {
          print('$_TAG: Error loading data: $e');
          _safeSetState(() {
            _isLoading = false;
          });
        });
  }

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      profile: widget.userProfile,
      currentKey: 'adminProfile',
      title: 'Profile',
      body: _buildMainContent(),
    );
  }

  Widget _buildMainContent() {
    return _isLoading
        ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading profile data...'),
              ],
            ),
          )
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildHeader(),
                const SizedBox(height: 20),
                _buildProfileDetailsCard(),
                const SizedBox(height: 30),
                _buildActionButtonsCard(),
                const SizedBox(height: 30),
                _buildDangerZoneCard(),
              ],
            ),
          );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        CircleAvatar(
          radius: 40,
          backgroundColor: _purpleColor,
          child: Text(
            _getInitials(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: _whiteColor,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          "Profile Details",
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: _blackColor,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Manage your admin account information",
          style: TextStyle(fontSize: 16, color: _grayColor),
        ),
      ],
    );
  }

  String _getInitials() {
    final first = _firstNameController.text.isNotEmpty
        ? _firstNameController.text[0]
        : 'A';
    final last = _lastNameController.text.isNotEmpty
        ? _lastNameController.text[0]
        : 'D';
    return '$first$last';
  }

  Widget _buildProfileDetailsCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLabel("First Name"),
            _buildEditableField(_firstNameController, "First Name"),
            const SizedBox(height: 16),
            _buildLabel("Last Name"),
            _buildEditableField(_lastNameController, "Last Name"),
            const SizedBox(height: 16),
            _buildLabel("Email Address"),
            _buildNonEditableField(_currentUser?.email ?? "Not available"),
            const SizedBox(height: 16),
            _buildLabel("Birth Date"),
            _buildEditableField(_birthDateController, "Birth Date"),
            const SizedBox(height: 16),
            _buildLabel("Phone Number"),
            _buildEditableField(
              _phoneController,
              "Phone Number",
              isPhone: true,
            ),
            const SizedBox(height: 16),
            _buildLabel("User Type"),
            _buildNonEditableField("Admin"),
            const SizedBox(height: 16),
            _buildLabel("Account Created"),
            _buildNonEditableField(_accountCreated, isSmall: true),
            const SizedBox(height: 16),
            _buildLabel("Last Login"),
            _buildNonEditableField(_lastLogin, isSmall: true),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: _blackColor,
      ),
    ),
  );

  Widget _buildEditableField(
    TextEditingController controller,
    String hint, {
    bool isPhone = false,
  }) {
    return TextField(
      controller: controller,
      enabled: _isEditMode,
      decoration: InputDecoration(
        hintText: hint,
        contentPadding: const EdgeInsets.all(12),
        border: const OutlineInputBorder(),
        filled: !_isEditMode,
        fillColor: !_isEditMode ? Colors.grey.shade100 : null,
      ),
      keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
    );
  }

  Widget _buildNonEditableField(String text, {bool isSmall = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(4),
        color: Colors.grey.shade100,
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: isSmall ? 14 : 16,
          color: Colors.grey.shade700,
        ),
      ),
    );
  }

  Widget _buildActionButtonsCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: _isEditMode ? _saveChanges : _enterEditMode,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isEditMode ? Colors.green : _purpleColor,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: Text(
                _isEditMode ? "Save Changes" : "Edit Profile",
                style: TextStyle(color: _whiteColor, fontSize: 16),
              ),
            ),
            const SizedBox(height: 12),
            if (_isEditMode)
              ElevatedButton(
                onPressed: _cancelEditMode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _grayColor,
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: Text(
                  "Cancel",
                  style: TextStyle(color: _whiteColor, fontSize: 16),
                ),
              ),
            if (_isEditMode) const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _viewLoginHistory,
              style: ElevatedButton.styleFrom(
                backgroundColor: _purpleColor,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: Text(
                "View Login History",
                style: TextStyle(color: _whiteColor, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDangerZoneCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning, color: _redColor),
                const SizedBox(width: 8),
                Text(
                  "Danger Zone",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _redColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              "Permanently delete your account and all associated data. This action cannot be undone.",
              style: TextStyle(color: _grayColor),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _showDeleteAccountConfirmation,
              style: ElevatedButton.styleFrom(
                backgroundColor: _redColor,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: Text(
                "Delete Account",
                style: TextStyle(color: _whiteColor, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- EDIT MODE ----------
  void _enterEditMode() {
    _safeSetState(() {
      _isEditMode = true;
    });
  }

  void _exitEditMode() => _safeSetState(() => _isEditMode = false);

  void _cancelEditMode() {
    _safeSetState(() {
      _firstNameController.text = _originalFirstName;
      _lastNameController.text = _originalLastName;
      _birthDateController.text = _originalBirthDate;
      _phoneController.text = _originalPhoneNumber;
      _isEditMode = false;
    });
  }

  void _saveChanges() {
    final newFirstName = _firstNameController.text.trim();
    final newLastName = _lastNameController.text.trim();
    final newBirthDate = _birthDateController.text.trim();
    final newPhone = _phoneController.text.trim();

    if (_validateInputs(newFirstName, newLastName, newBirthDate, newPhone)) {
      _updateUserProfileInFirebase(
        newFirstName,
        newLastName,
        newBirthDate,
        newPhone,
      );
    }
  }

  bool _validateInputs(
    String firstName,
    String lastName,
    String birthDate,
    String phoneNumber,
  ) {
    if (firstName.isEmpty) {
      _showError("First name cannot be empty");
      return false;
    }
    if (lastName.isEmpty) {
      _showError("Last name cannot be empty");
      return false;
    }
    if (phoneNumber.isNotEmpty && !_isValidPhoneNumber(phoneNumber)) {
      _showError("Phone number must be 8 digits starting with 6, 8, or 9");
      return false;
    }
    return true;
  }

  bool _isValidPhoneNumber(String phoneNumber) {
    if (phoneNumber.length != 8) return false;
    if (!RegExp(r'^\d+$').hasMatch(phoneNumber)) return false;
    final first = phoneNumber[0];
    return first == '6' || first == '8' || first == '9';
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: _redColor,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _updateUserProfileInFirebase(
    String firstName,
    String lastName,
    String birthDate,
    String phoneNumber,
  ) {
    if (_currentUser == null) {
      _showError("No user logged in");
      return;
    }

    final updates = <String, dynamic>{
      "firstname": firstName,
      "lastname": lastName,
      "dob": birthDate,
      "phoneNum": phoneNumber,
      "lastUpdated": FieldValue.serverTimestamp(),
    };

    _safeSetState(() {
      _isLoading = true;
    });

    _db
        .collection("Account")
        .doc(_currentUser!.uid)
        .update(updates)
        .then((_) {
          print("$_TAG: Profile updated for ${_currentUser!.uid}");
          _exitEditMode();
          _safeSetState(() {
            _isLoading = false;
          });
        })
        .catchError((e) {
          _safeSetState(() {
            _isLoading = false;
          });
          _showError("Failed to update profile: $e");
        });
  }

  void _viewLoginHistory() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Login history feature coming soon')),
    );
  }

  void _showDeleteAccountConfirmation() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Account"),
        content: const Text(
          "Are you sure you want to delete your account? This action cannot be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteUserAccount();
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  void _deleteUserAccount() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Account deletion feature coming soon')),
    );
  }

  @override
  void dispose() {
    _isDisposed = true;
    _firstNameController.dispose();
    _lastNameController.dispose();
    _birthDateController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // -------- Helpers --------
  String _formatDate(DateTime d) =>
      "${d.day.toString().padLeft(2, '0')} ${_month(d.month)} ${d.year}";

  String _month(int m) => const [
    "Jan",
    "Feb",
    "Mar",
    "Apr",
    "May",
    "Jun",
    "Jul",
    "Aug",
    "Sep",
    "Oct",
    "Nov",
    "Dec",
  ][m - 1];
}
