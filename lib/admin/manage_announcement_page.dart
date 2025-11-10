// lib/admin/admin_announcement_page.dart (replace the whole file with this)
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ✅ shared shell + routes + model
import 'admin_shell.dart';
import 'admin_routes.dart';
import '../models/user_profile.dart';

class AdminAnnouncementPage extends StatefulWidget {
  final UserProfile userProfile;

  const AdminAnnouncementPage({
    Key? key,
    required this.userProfile,
  }) : super(key: key);

  @override
  _AdminAnnouncementState createState() => _AdminAnnouncementState();
}

class _AdminAnnouncementState extends State<AdminAnnouncementPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Form controllers
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  // Checkbox states
  bool _elderlyChecked = false;
  bool _caregiverChecked = false;
  bool _adminChecked = false;

  // State variables
  bool _isLoading = false;
  bool _isFormVisible = false;
  String _successMessage = '';
  String _errorMessage = '';

  // Announcements list
  List<Announcement> _announcementsList = [];

  // Colors
  final Color _purpleColor = Colors.purple.shade500;
  final Color _whiteColor = Colors.white;
  final Color _redColor = Colors.red;
  final Color _greenColor = Colors.green;
  final Color _blueColor = const Color(0xFF003366);
  final Color _lightBlueColor = const Color(0xFFe6f0fa);
  final Color _buttonBlueColor = const Color(0xFF4a90e2);
  final Color _darkBlueColor = const Color(0xFF004080);

  static const String _TAG = "AdminAnnouncement";

  @override
  void initState() {
    super.initState();
    _loadAnnouncements();
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Use the shared AdminShell: top bar, menu/drawer, nav row, logout handled globally
    return AdminShell(
      profile: widget.userProfile,
      currentKey: 'adminAnnouncement',      // highlight the Announcement tab
      title: 'System Announcements',        // title in top bar
      body: _buildMainContent(),            // your content below the shell nav
    );
  }

  // ───────────────────── Content (no local Scaffold/AppBar/ADNavigation) ─────────────────────
  Widget _buildMainContent() {
    return Container(
      color: _lightBlueColor,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _whiteColor,
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              _buildTitle(),
              const SizedBox(height: 24),

              _buildToggleFormButton(),
              const SizedBox(height: 20),

              if (_isFormVisible) _buildFormSection(),

              if (_isLoading) _buildLoadingIndicator(),
              if (_successMessage.isNotEmpty) _buildSuccessMessage(),
              if (_errorMessage.isNotEmpty) _buildErrorMessage(),

              _buildPreviousAnnouncementsSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return Text(
      "System Announcements",
      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _blueColor),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildToggleFormButton() {
    return ElevatedButton(
      onPressed: _toggleFormVisibility,
      style: ElevatedButton.styleFrom(
        backgroundColor: _isFormVisible ? _redColor : _buttonBlueColor,
        foregroundColor: _whiteColor,
        elevation: 4,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      child: Text(_isFormVisible ? "Cancel" : "New Announcement"),
    );
  }

  Widget _buildFormSection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        children: [
          _buildTitleInput(),
          const SizedBox(height: 16),
          _buildDescriptionInput(),
          const SizedBox(height: 16),
          _buildUserGroupsSection(),
          const SizedBox(height: 16),
          _buildSubmitButton(),
        ],
      ),
    );
  }

  Widget _buildTitleInput() {
    return TextField(
      controller: _titleController,
      decoration: _blueInputDecoration("Title"),
      style: const TextStyle(fontSize: 16),
    );
  }

  Widget _buildDescriptionInput() {
    return SizedBox(
      height: 120,
      child: TextField(
        controller: _descriptionController,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        decoration: _blueInputDecoration("Description"),
        style: const TextStyle(fontSize: 16),
      ),
    );
  }

  InputDecoration _blueInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _blueColor)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _blueColor)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _blueColor)),
      hintStyle: TextStyle(color: _blueColor),
      contentPadding: const EdgeInsets.all(16),
    );
  }

  Widget _buildUserGroupsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Send To User Groups", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _darkBlueColor)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(color: Color(0xFFf7faff)),
          child: Column(
            children: [
              _buildCheckbox(value: _elderlyChecked,  onChanged: (v) => setState(() => _elderlyChecked = v!),  label: "Elderly"),
              const SizedBox(height: 8),
              _buildCheckbox(value: _caregiverChecked,onChanged: (v) => setState(() => _caregiverChecked = v!),label: "Caregiver"),
              const SizedBox(height: 8),
              _buildCheckbox(value: _adminChecked,    onChanged: (v) => setState(() => _adminChecked = v!),    label: "Admin"),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCheckbox({
    required bool value,
    required ValueChanged<bool?> onChanged,
    required String label,
  }) {
    return Row(
      children: [
        Checkbox(value: value, onChanged: onChanged, activeColor: _blueColor),
        Text(label, style: TextStyle(color: _blueColor, fontSize: 16)),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _handleSubmitAnnouncement,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF007acc),
        foregroundColor: _whiteColor,
        elevation: 4,
        minimumSize: const Size(double.infinity, 50),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      child: Text(_isLoading ? "Sending..." : "Send Announcement"),
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

  Widget _buildPreviousAnnouncementsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _announcementsList.isEmpty
              ? "Previous Announcements"
              : "Previous Announcements (${_announcementsList.length})",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _darkBlueColor),
        ),
        const SizedBox(height: 16),

        if (_announcementsList.isEmpty)
          Text(
            "No announcements found. Create your first announcement above.",
            style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),

        if (_announcementsList.isNotEmpty)
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _announcementsList.length,
            itemBuilder: (_, i) => _buildAnnouncementItem(_announcementsList[i]),
          ),
      ],
    );
  }

  Widget _buildAnnouncementItem(Announcement a) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFFdbe9ff), borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: title + date
          Row(
            children: [
              Expanded(
                flex: 7,
                child: Text(a.title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _darkBlueColor)),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  _formatDate(a.createdAt),
                  textAlign: TextAlign.end,
                  style: const TextStyle(fontSize: 14, color: Color(0xFF336699), fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(a.description, style: TextStyle(fontSize: 16, color: _blueColor)),
          const SizedBox(height: 10),
          Text(_buildFooterText(a), style: TextStyle(fontSize: 14, color: _blueColor)),
        ],
      ),
    );
  }

  String _buildFooterText(Announcement a) {
    final sb = StringBuffer();

    if (a.userGroups.isNotEmpty) {
      sb.write("To: ");
      for (var i = 0; i < a.userGroups.length; i++) {
        if (i > 0) sb.write(", ");
        sb.write(_capitalizeFirstLetter(a.userGroups[i]));
      }
    }

    if (a.createdBy.isNotEmpty) {
      if (sb.isNotEmpty) sb.write(" | ");
      sb.write("By: ${a.createdBy.replaceAll('_', '.')}");
    }

    if (sb.isNotEmpty) sb.write(" | ");
    sb.write("Read by: ${a.readBy.length}");

    return sb.toString();
    }

  String _capitalizeFirstLetter(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
  String _padZero(int n) => n.toString().padLeft(2, '0');
  String _getMonthName(int m) => const [
        'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'
      ][m - 1];
  String _formatDate(DateTime d) => "${_padZero(d.day)} ${_getMonthName(d.month)} ${d.year}, "
      "${_padZero(d.hour)}:${_padZero(d.minute)}";

  // ───────────────────── Actions ─────────────────────

  void _toggleFormVisibility() {
    setState(() {
      _isFormVisible = !_isFormVisible;
      if (!_isFormVisible) {
        _clearForm();
        _hideMessages();
      }
    });
  }

  void _handleSubmitAnnouncement() {
    final title = _titleController.text.trim();
    final desc  = _descriptionController.text.trim();
    _hideMessages();

    if (title.isEmpty) { _showError("Please fill in the title."); return; }
    if (desc.isEmpty)  { _showError("Please fill in the description."); return; }

    final groups = _getSelectedUserGroups();
    if (groups.isEmpty) { _showError("Please select at least one user group."); return; }

    _createAnnouncement(title, desc, groups);
  }

  List<String> _getSelectedUserGroups() {
    final list = <String>[];
    if (_elderlyChecked)  list.add("elderly");
    if (_caregiverChecked)list.add("caregiver");
    if (_adminChecked)    list.add("admin");
    return list;
  }

  void _createAnnouncement(String title, String description, List<String> userGroups) {
    _setLoading(true);

    var createdBy = "admin";
    final u = _auth.currentUser;
    if (u?.email != null) createdBy = u!.email!.replaceAll(".", "_");

    final now = DateTime.now();

    final data = {
      "title": title,
      "description": description,
      "userGroups": userGroups,
      "createdBy": createdBy,
      // Note: ordering uses string ISO here to match your current codepath.
      // If you want server ordering, store a Firestore Timestamp instead.
      "createdAt": now.toIso8601String(),
      "readBy": <String, bool>{},
    };

    _db.collection("Announcements").add(data).then((ref) {
      _setLoading(false);
      _showSuccess("Announcement sent successfully!");
      _clearForm();
      _toggleFormVisibility();
      _loadAnnouncements(); // refresh list
      print("$_TAG: Announcement created id=${ref.id}");
    }).catchError((e) {
      _setLoading(false);
      _showError("Failed to send announcement: $e");
      print("$_TAG: Error creating announcement: $e");
    });
  }

  void _loadAnnouncements() {
    _setLoading(true);

    _db.collection("Announcements")
        .orderBy("createdAt", descending: true)   // works with ISO strings; for best results use Timestamp
        .get()
        .then((qs) {
          final list = <Announcement>[];
          for (final d in qs.docs) {
            final a = _parseAnnouncementDocument(d);
            if (a != null) {
              a.id = d.id;
              list.add(a);
            }
          }
          setState(() => _announcementsList = list);
          _setLoading(false);
          print("$_TAG: Loaded ${list.length} announcements");
        })
        .catchError((e) {
          _setLoading(false);
          _showError("Failed to load announcements: $e");
          setState(() => _announcementsList = []);
        });
  }

  Announcement? _parseAnnouncementDocument(DocumentSnapshot doc) {
    try {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return null;

      final title       = data["title"] ?? "";
      final description = data["description"] ?? "";
      final createdBy   = data["createdBy"] ?? "admin";
      final createdAt   = data["createdAt"] ?? "";

      final userGroups = (data["userGroups"] as List<dynamic>?)?.cast<String>() ?? <String>[];
      final readBy     = (data["readBy"]     as Map<String, dynamic>?)
                          ?.map((k, v) => MapEntry(k, v as bool)) ?? <String, bool>{};

      if (title.isEmpty || description.isEmpty) return null;

      DateTime createdDate;
      try {
        createdDate = DateTime.parse(createdAt);
      } catch (_) {
        createdDate = DateTime.now();
      }

      return Announcement(
        title: title,
        description: description,
        createdBy: createdBy,
        createdAt: createdDate,
        userGroups: userGroups,
        readBy: readBy,
      );
    } catch (e) {
      print("$_TAG: parse error: $e");
      return null;
    }
  }

  // ───────────────────── UI helpers ─────────────────────
  void _setLoading(bool v) => setState(() => _isLoading = v);
  void _showSuccess(String m) => setState(() { _successMessage = m; _errorMessage = ''; });
  void _showError(String m)   => setState(() { _errorMessage = m; _successMessage = ''; });
  void _hideMessages()        => setState(() { _successMessage = ''; _errorMessage = ''; });
  void _clearForm() {
    _titleController.clear();
    _descriptionController.clear();
    _elderlyChecked = false;
    _caregiverChecked = false;
    _adminChecked = false;
    setState(() {});
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}

// ───────────────────── Model ─────────────────────
class Announcement {
  String id;
  String title;
  String description;
  String createdBy;
  DateTime createdAt;
  List<String> userGroups;
  Map<String, bool> readBy;

  Announcement({
    this.id = '',
    required this.title,
    required this.description,
    required this.createdBy,
    required this.createdAt,
    required this.userGroups,
    required this.readBy,
  });
}
