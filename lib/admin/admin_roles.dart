import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_shell.dart';
import 'admin_routes.dart';
import '../models/user_profile.dart';

class AdminRolesPage extends StatefulWidget {
  final UserProfile userProfile;

  const AdminRolesPage({
    Key? key,
    required this.userProfile,
  }) : super(key: key);

  @override
  _AdminRolesState createState() => _AdminRolesState();
}

class _AdminRolesState extends State<AdminRolesPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Form controllers
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _roleController  = TextEditingController();

  // State variables
  bool _isLoading = false;
  String _successMessage = '';
  String _errorMessage   = '';

  // Roles lists
  final List<String> _displayRoles   = ["Admin", "Elderly", "Caregiver"];
  final List<String> _databaseRoles  = ["admin", "elderly", "caregiver"];

  // Colors
  final Color _purpleColor = Colors.purple.shade500;
  final Color _whiteColor  = Colors.white;
  final Color _redColor    = Colors.red;
  final Color _greenColor  = Colors.green;
  final Color _blackColor  = Colors.black;

  static const String _TAG = "AdminRoles";

  @override
  Widget build(BuildContext context) {
    // ✅ Use the shared AdminShell (top bar menu, drawer, nav, logout handled globally)
    return AdminShell(
      profile: widget.userProfile,
      currentKey: 'adminRoles',               // highlight "Roles" in nav
      title: 'Assign Roles',                  // top bar title
      body: _buildMainContent(),              // page content below the shell nav
    );
  }

  // ---------- MAIN CONTENT (kept your UI; no local Scaffold/AppBar) ----------
  Widget _buildMainContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: _whiteColor,
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            _buildTitle(),
            const SizedBox(height: 32),

            _buildEmailInput(),
            const SizedBox(height: 24),

            _buildRoleDropdown(),
            const SizedBox(height: 32),

            _buildAssignButton(),
            const SizedBox(height: 16),

            if (_isLoading) _buildLoadingIndicator(),
            if (_successMessage.isNotEmpty) _buildSuccessMessage(),
            if (_errorMessage.isNotEmpty) _buildErrorMessage(),
          ],
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return Text(
      "Assign User Roles",
      style: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: _purpleColor,
        letterSpacing: 0.02,
      ),
      textAlign: TextAlign.center,
    ); 
  }

  Widget _buildEmailInput() {
    return TextField(
      controller: _emailController,
      decoration: InputDecoration(
        hintText: "User Email",
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _purpleColor)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _purpleColor)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _purpleColor)),
        hintStyle: TextStyle(color: _purpleColor),
        contentPadding: const EdgeInsets.all(16),
      ),
      keyboardType: TextInputType.emailAddress,
      style: const TextStyle(fontSize: 16),
    );
  }

  Widget _buildRoleDropdown() {
    return InputDecorator(
      decoration: InputDecoration(
        hintText: "Select Role",
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _purpleColor)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _purpleColor)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _purpleColor)),
        hintStyle: TextStyle(color: _purpleColor),
        contentPadding: const EdgeInsets.all(16),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _roleController.text.isEmpty ? null : _roleController.text,
          hint: Text("Select Role", style: TextStyle(color: _purpleColor)),
          isExpanded: true,
          items: _displayRoles.map((role) => DropdownMenuItem<String>(
            value: role, child: Text(role, style: const TextStyle(fontSize: 16)),
          )).toList(),
          onChanged: (val) => setState(() => _roleController.text = val ?? ''),
        ),
      ),
    );
  }

  Widget _buildAssignButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _handleAssignRole,
      style: ElevatedButton.styleFrom(
        backgroundColor: _purpleColor,
        foregroundColor: _whiteColor,
        elevation: 6,
        minimumSize: const Size(double.infinity, 50),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      child: Text(_isLoading ? "Assigning..." : "Assign Role"),
    );
  }

  Widget _buildLoadingIndicator() => const Center(child: CircularProgressIndicator());

  Widget _buildSuccessMessage() => Text(
        _successMessage,
        style: TextStyle(color: _greenColor, fontSize: 16),
        textAlign: TextAlign.center,
      );

  Widget _buildErrorMessage() => Text(
        _errorMessage,
        style: TextStyle(color: _redColor, fontSize: 16),
        textAlign: TextAlign.center,
      );

  // ---------- Role Assignment Logic ----------
  void _handleAssignRole() {
    final email = _emailController.text.trim();
    final selectedDisplayRole = _roleController.text.trim();

    _hideMessages();

    if (email.isEmpty) {
      _showError("Email is required.");
      return;
    }
    if (!_displayRoles.contains(selectedDisplayRole)) {
      _showError("Please select a valid role.");
      return;
    }

    final roleIndex   = _displayRoles.indexOf(selectedDisplayRole);
    final databaseRole = _databaseRoles[roleIndex];

    _assignRoleToUser(email, databaseRole, selectedDisplayRole);
  }

  void _assignRoleToUser(String email, String databaseRole, String displayRole) {
    _setLoading(true);
    print("$_TAG: Assign '$databaseRole' to $email");

    // Prefer the new 'users' collection
    _db.collection("users").where("email", isEqualTo: email).get().then((qs) {
      if (qs.docs.isNotEmpty) {
        final doc = qs.docs.first;
        _updateUserRoleWithNewStructure(doc, databaseRole, email, displayRole);
      } else {
        _searchInAccountCollection(email, databaseRole, displayRole);
      }
    }).catchError((e) {
      _setLoading(false);
      _showError("Error searching for user: $e");
    });
  }

  void _searchInAccountCollection(String email, String databaseRole, String displayRole) {
    _db.collection("Account").where("email", isEqualTo: email).get().then((qs) {
      if (qs.docs.isNotEmpty) {
        _updateAccountUserRole(qs.docs.first.id, databaseRole, email, displayRole);
      } else {
        _searchByUserEmailField(email, databaseRole, displayRole);
      }
    }).catchError((e) {
      _setLoading(false);
      _showError("Error searching Account: $e");
    });
  }

  void _searchByUserEmailField(String email, String databaseRole, String displayRole) {
    _db.collection("Account").where("userEmail", isEqualTo: email).get().then((qs) {
      if (qs.docs.isNotEmpty) {
        _updateAccountUserRole(qs.docs.first.id, databaseRole, email, displayRole);
      } else {
        _searchByEncodedEmail(email, databaseRole, displayRole);
      }
    }).catchError((e) {
      _setLoading(false);
      _showError("Error searching userEmail: $e");
    });
  }

  void _searchByEncodedEmail(String email, String databaseRole, String displayRole) {
    final encoded = _encodeEmailForFirebase(email);
    _db.collection("Account").doc(encoded).get().then((doc) {
      if (doc.exists) {
        _updateAccountUserRole(doc.id, databaseRole, email, displayRole);
      } else {
        _showError("No account found with email: $email");
      }
      _setLoading(false);
    }).catchError((e) {
      _setLoading(false);
      _showError("Error checking encoded email: $e");
    });
  }

  void _updateUserRoleWithNewStructure(DocumentSnapshot doc, String databaseRole, String originalEmail, String displayRole) {
    final userId = doc.id;
    final data = doc.data();
    final hasNew = data is Map<String, dynamic> &&
        data.containsKey("userType") &&
        data.containsKey("firstname") &&
        data.containsKey("lastname") &&
        data.containsKey("email");

    final update = () => _db.collection("users").doc(userId).update({"userType": databaseRole});

    (hasNew ? update() : update()).then((_) {
      _setLoading(false);
      _showSuccess('Role "$displayRole" assigned to $originalEmail');
      _clearForm();
      _logUserDetails(userId, databaseRole);
    }).catchError((e) {
      _setLoading(false);
      _showError("Error assigning role. Please try again.");
    });
  }

  void _updateAccountUserRole(String userId, String databaseRole, String originalEmail, String displayRole) {
    _db.collection("Account").doc(userId).update({"userType": databaseRole}).then((_) {
      _setLoading(false);
      _showSuccess('Role "$displayRole" assigned to $originalEmail');
      _clearForm();
    }).catchError((e) {
      _setLoading(false);
      _showError("Error assigning role. Please try again.");
    });
  }

  void _logUserDetails(String userId, String newRole) {
    _db.collection("users").doc(userId).get().then((doc) {
      if (!doc.exists) return;
      final data = (doc.data() as Map<String, dynamic>? ) ?? {};
      print("$_TAG: Updated User → id:$userId email:${data['email']} "
          "first:${data['firstname']} last:${data['lastname']} "
          "role:${data['userType']} status:${data['status']}");
    });
  }

  // ---------- misc helpers ----------
  String _encodeEmailForFirebase(String email) => email
      .replaceAll(".", "_")
      .replaceAll("@", "_")
      .replaceAll("#", "_")
      .replaceAll("\$", "_")
      .replaceAll("[", "_")
      .replaceAll("]", "_")
      .replaceAll("/", "_");

  void _setLoading(bool v) => setState(() => _isLoading = v);

  void _showSuccess(String m) => setState(() { _successMessage = m; _errorMessage = ''; });

  void _showError(String m)   => setState(() { _errorMessage = m; _successMessage = ''; });

  void _hideMessages()        => setState(() { _successMessage = ''; _errorMessage = ''; });

  void _clearForm()           => setState(() { _emailController.clear(); _roleController.clear(); });

  void _logoutUser() {
    _auth.signOut();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Logged out successfully")));
    _redirectToLogin();
  }

  void _redirectToLogin() {
    // hook up your login route here if needed
    print("$_TAG: Redirecting to login page");
  }

  @override
  void dispose() {
    _emailController.dispose();
    _roleController.dispose();
    super.dispose();
  }
}
