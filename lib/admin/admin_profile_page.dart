import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_shell.dart';
import 'admin_routes.dart';
import '../models/user_profile.dart';

class AdminProfilePage extends StatefulWidget {
  /// Pass the signed-in admin's profile here from your shell/router.
  final UserProfile userProfile;

  const AdminProfilePage({
    Key? key,
    required this.userProfile,
  }) : super(key: key);

  @override
  _AdminProfileState createState() => _AdminProfileState();
}

class _AdminProfileState extends State<AdminProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  User? _currentUser;

  // Text Editing Controllers
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController  = TextEditingController();
  final TextEditingController _birthDateController = TextEditingController();
  final TextEditingController _phoneController     = TextEditingController();

  // State variables
  bool _isEditMode = false;
  String _originalFirstName = '';
  String _originalLastName  = '';
  String _originalBirthDate = '';
  String _originalPhoneNumber = '';

  // Colors
  final Color _purpleColor = Colors.purple.shade500;
  final Color _whiteColor  = Colors.white;
  final Color _blackColor  = Colors.black;
  final Color _grayColor   = Colors.grey;
  final Color _redColor    = Colors.red;

  static const String _TAG = "AdminProfile";

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    _initializeFirebase();
    _loadUserData();
    _recordLogin();
  }

  void _initializeFirebase() {
    // Any one-time setup you need
    print("$_TAG: Firebase initialized");
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

  // ---------- MAIN CONTENT (unchanged, just not inside its own Scaffold) ----------
  Widget _buildMainContent() {
    return SingleChildScrollView(
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
    return Text(
      "Profile Details",
      style: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: _blackColor,
      ),
    );
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
            _buildNonEditableField(_currentUser?.email ?? "Loading..."),
            const SizedBox(height: 16),

            _buildLabel("Birth Date"),
            _buildEditableField(_birthDateController, "Birth Date"),
            const SizedBox(height: 16),

            _buildLabel("Phone Number"),
            _buildEditableField(_phoneController, "Phone Number", isPhone: true),
            const SizedBox(height: 16),

            _buildLabel("User Type"),
            _buildNonEditableField("Admin"),
            const SizedBox(height: 16),

            _buildLabel("Account Created"),
            _buildNonEditableField("Loading...", isSmall: true), // (You can wire a live label if you want)
            const SizedBox(height: 16),

            _buildLabel("Last Login"),
            _buildNonEditableField("Loading...", isSmall: true), // (You can wire a live label if you want)
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) => Text(
    text,
    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _blackColor),
  );

  Widget _buildEditableField(TextEditingController controller, String hint, {bool isPhone = false}) {
    return TextField(
      controller: controller,
      enabled: _isEditMode,
      decoration: const InputDecoration(
        contentPadding: EdgeInsets.all(12),
        border: OutlineInputBorder(),
      ),
      keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
    );
    // (Optional) Hook up date pickers etc.
  }

  Widget _buildNonEditableField(String text, {bool isSmall = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: isSmall ? 14 : 18, color: _blackColor),
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
                child: Text("Cancel", style: TextStyle(color: _whiteColor, fontSize: 16)),
              ),

            if (_isEditMode) const SizedBox(height: 12),

            ElevatedButton(
              onPressed: _viewLoginHistory,
              style: ElevatedButton.styleFrom(
                backgroundColor: _purpleColor,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: Text("View Login History", style: TextStyle(color: _whiteColor, fontSize: 16)),
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
            Text("Danger Zone",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _redColor),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _showDeleteAccountConfirmation,
              style: ElevatedButton.styleFrom(
                backgroundColor: _redColor,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: Text("Delete Account", style: TextStyle(color: _whiteColor, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- EDIT MODE ----------
  void _enterEditMode() {
    setState(() {
      _isEditMode = true;
      _originalFirstName  = _firstNameController.text;
      _originalLastName   = _lastNameController.text;
      _originalBirthDate  = _birthDateController.text;
      _originalPhoneNumber= _phoneController.text;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("You can now edit your profile information")),
    );
  }

  void _exitEditMode() => setState(() => _isEditMode = false);

  void _cancelEditMode() {
    setState(() {
      _firstNameController.text = _originalFirstName;
      _lastNameController.text  = _originalLastName;
      _birthDateController.text = _originalBirthDate;
      _phoneController.text     = _originalPhoneNumber;
      _isEditMode               = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Changes cancelled")),
    );
  }

  void _saveChanges() {
    final newFirstName = _firstNameController.text.trim();
    final newLastName  = _lastNameController.text.trim();
    final newBirthDate = _birthDateController.text.trim();
    final newPhone     = _phoneController.text.trim();

    if (_validateInputs(newFirstName, newLastName, newBirthDate, newPhone)) {
      _updateUserProfileInFirebase(newFirstName, newLastName, newBirthDate, newPhone);
    }
  }

  bool _validateInputs(String firstName, String lastName, String birthDate, String phoneNumber) {
    if (firstName.isEmpty) { _showError("First name cannot be empty"); return false; }
    if (lastName.isEmpty)  { _showError("Last name cannot be empty");  return false; }
    if (birthDate.isEmpty) { _showError("Birth date cannot be empty"); return false; }
    if (phoneNumber.isEmpty) { _showError("Phone number cannot be empty"); return false; }
    if (!_isValidPhoneNumber(phoneNumber)) {
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _updateUserProfileInFirebase(String firstName, String lastName, String birthDate, String phoneNumber) {
    if (_currentUser == null) return;

    final updates = <String, Object>{
      "firstname": firstName,
      "lastname":  lastName,
      "dob":       birthDate,
      "phoneNum":  phoneNumber,
    };

    _db.collection("Account").doc(_currentUser!.uid)
      .update(updates)
      .then((_) {
        print("$_TAG: Profile updated for ${_currentUser!.uid}");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile updated successfully!")),
        );
        _exitEditMode();
        _loadUserData();
      })
      .catchError((e) {
        _showError("Failed to update profile: $e");
      });
  }

  // ---------- FIREBASE LOAD / HISTORY ----------
  void _loadUserData() {
    if (_currentUser == null) {
      _setDefaultValues();
      _showError("No user logged in");
      _redirectToLogin();
      return;
    }

    _db.collection("Account").doc(_currentUser!.uid).get().then((doc) {
      if (!doc.exists) {
        _setDefaultValues();
        _showError("User profile not found in database");
        return;
      }

      final data = (doc.data() as Map<String, dynamic>? ) ?? {};
      final firstName  = data["firstname"] ?? "Not provided";
      final lastName   = data["lastname"]  ?? "Not provided";
      final birthDate  = data["dob"]       ?? "Not provided";
      final phone      = data["phoneNum"]  ?? "Not provided";
      final createdAt  = _getDateFromDocument(data, "createdAt");
      final lastLogin  = _getDateFromDocument(data, "lastLoginDate");

      setState(() {
        _firstNameController.text = firstName;
        _lastNameController.text  = lastName;
        _birthDateController.text = birthDate.isNotEmpty ? birthDate : "Not provided";
        _phoneController.text     = phone.isNotEmpty ? phone : "Not provided";
      });

      _setTimestampsFromFirestore(createdAt, lastLogin);
    }).catchError((e) {
      _setDefaultValues();
      _showError("Failed to load user data: $e");
    });
  }

  DateTime? _getDateFromDocument(Map<String, dynamic> data, String field) {
    try {
      if (data[field] is Timestamp) return (data[field] as Timestamp).toDate();
      if (data[field] is String && (data[field] as String).isNotEmpty) {
        return DateTime.parse(data[field] as String);
      }
      return null;
    } catch (_) { return null; }
  }

  void _setTimestampsFromFirestore(DateTime? createdAt, DateTime? lastLogin) {
    // Wire to visible labels if you add them to the UI
    print("$_TAG: Created At: $createdAt, Last Login: $lastLogin");
  }

  void _setDefaultValues() {
    setState(() {
      _firstNameController.text = "Name not available";
      _lastNameController.text  = "";
      _birthDateController.text = "Not provided";
      _phoneController.text     = "Not provided";
    });
  }

  void _recordLogin() {
    if (_currentUser == null) return;

    final loginRecord = {
      "date": DateTime.now(),
      "device": "Flutter App",
      "action": "login",
      "timestamp": DateTime.now().millisecondsSinceEpoch,
    };

    _db.collection("Account").doc(_currentUser!.uid).update({
      "lastLoginDate": DateTime.now(),
      "loginHistory": FieldValue.arrayUnion([loginRecord]),
    }).catchError((e) {
      print("$_TAG: Failed to record login: $e");
    });
  }

  void _viewLoginHistory() {
    if (_currentUser == null) {
      _showError("Please log in to view login history");
      return;
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Loading Login History"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text("Please wait while we retrieve your login history..."),
          ],
        ),
      ),
    );

    _db.collection("Account").doc(_currentUser!.uid).get().then((doc) {
      Navigator.of(context).pop(); // close loading

      final data = (doc.data() as Map<String, dynamic>? ) ?? {};
      final history = (data["loginHistory"] as List<dynamic>? ?? [])
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();

      if (history.isEmpty) {
        _showNoLoginHistoryDialog();
      } else {
        _showEnhancedLoginHistoryDialog(history);
      }
    }).catchError((e) {
      Navigator.of(context).pop();
      _showError("Failed to load login history: $e");
    });
  }

  void _showEnhancedLoginHistoryDialog(List<Map<String, dynamic>> loginHistory) {
    loginHistory.sort((a, b) => (b["timestamp"] ?? 0).compareTo(a["timestamp"] ?? 0));

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Login History (${loginHistory.length} records)"),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: loginHistory.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (_, i) {
              final rec = loginHistory[i];
              final ts  = _getTimestampFromRecord(rec);
              final dev = rec["device"] ?? "Unknown device";
              final act = rec["action"] ?? "login";
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("${i + 1}. ${ts != null ? _formatDate(ts) : 'Unknown date'}",
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text("Device: $dev | Action: $act"),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close")),
          TextButton(onPressed: () { Navigator.pop(context); _viewLoginHistory(); }, child: const Text("Refresh")),
        ],
      ),
    );
  }

  DateTime? _getTimestampFromRecord(Map<String, dynamic> rec) {
    if (rec["timestamp"] is int) return DateTime.fromMillisecondsSinceEpoch(rec["timestamp"] as int);
    if (rec["date"] is Timestamp)  return (rec["date"] as Timestamp).toDate();
    return null;
  }

  void _showNoLoginHistoryDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Login History"),
        content: const Text(
            "No login history found.\n\nWe’ll record:\n• App logins\n• Profile access\n• Other auth actions"),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))],
      ),
    );
  }

  void _showDeleteAccountConfirmation() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Account"),
        content: const Text(
          "Are you sure you want to delete your account? This action cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () { Navigator.pop(context); _deleteUserAccount(); },
            child: Text("Delete", style: TextStyle(color: _redColor)),
          ),
        ],
      ),
    );
  }

  void _deleteUserAccount() {
    if (_currentUser == null) return;

    _db.collection("Account").doc(_currentUser!.uid).delete().then((_) {
      _currentUser!.delete().then((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Account deleted successfully")),
        );
        _redirectToLogin();
      }).catchError((e) => _showError("Failed to delete account: $e"));
    }).catchError((e) => _showError("Failed to delete user data: $e"));
  }

  void _redirectToLogin() {
    // Replace with your login route
    print("$_TAG: Redirecting to login page");
    // Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => LoginPage()), (_) => false);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _birthDateController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // -------- Helpers --------
  String _formatDate(DateTime d) =>
      "${d.day.toString().padLeft(2, '0')} ${_month(d.month)} ${d.year}, ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}";

  String _month(int m) => const ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][m - 1];
}
