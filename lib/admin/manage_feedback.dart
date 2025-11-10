
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'admin_shell.dart';
import '../models/user_profile.dart';

class AdminFeedbackPage extends StatefulWidget {
  final UserProfile userProfile;

  const AdminFeedbackPage({
    Key? key,
    required this.userProfile,
  }) : super(key: key);

  @override
  _AdminFeedbackState createState() => _AdminFeedbackState();
}

class _AdminFeedbackState extends State<AdminFeedbackPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // State variables
  bool _isLoading = true;
  bool _showAll = false;
  List<AppFeedback> _allFeedbacks = [];
  List<AppFeedback> _displayedFeedbacks = [];

  // Colors
  final Color _purpleColor = Colors.purple.shade500;
  final Color _whiteColor = Colors.white;
  final Color _blackColor = Colors.black;

  static const String _TAG = "AdminFeedback";

  @override
  void initState() {
    super.initState();
    _loadFeedbackData();
  }

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      profile: widget.userProfile,
      currentKey: 'adminFeedback',   // highlights Feedback in the top nav row
      title: 'Feedback',             // title in the app bar
      body: _buildMainContent(),     // your page content
    );
  }

  // ───────────────────── Content (no local Scaffold/AppBar/ADNavigation) ─────────────────────
  Widget _buildMainContent() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            "User Feedback",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _blackColor),
          ),
          const SizedBox(height: 16),

          if (_isLoading) _buildLoadingState(),
          if (!_isLoading && _allFeedbacks.isEmpty) _buildEmptyState(),
          if (!_isLoading && _allFeedbacks.isNotEmpty) _buildFeedbackList(),

          if (!_isLoading && _allFeedbacks.length > 5) _buildToggleButton(),
        ],
      ),
    );
  }

  Widget _buildLoadingState() => const Expanded(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text("Loading feedback...", style: TextStyle(fontSize: 16, color: Colors.grey)),
            ],
          ),
        ),
      );

  Widget _buildEmptyState() => const Expanded(
        child: Center(
          child: Text("No feedback available", style: TextStyle(fontSize: 18, color: Colors.grey)),
        ),
      );

  Widget _buildFeedbackList() => Expanded(
        child: ListView.builder(
          itemCount: _displayedFeedbacks.length,
          itemBuilder: (context, index) => FeedbackItem(feedback: _displayedFeedbacks[index]),
        ),
      );

  Widget _buildToggleButton() => SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _toggleShowMore,
          style: ElevatedButton.styleFrom(backgroundColor: _purpleColor),
          child: Text(_showAll ? "Show Less" : "Show More", style: TextStyle(color: _whiteColor)),
        ),
      );

  // ───────────────────── Data Loading ─────────────────────
  void _loadFeedbackData() {
    _setLoading(true);

    if (_auth.currentUser == null) {
      print("$_TAG: User not authenticated");
      _setLoading(false);
      return;
    }

    _db
        .collection("feedback")
        .get()
        .then(_processFeedbackData)
        .catchError((error) {
      print("$_TAG: Firestore access failed: $error");
      _setLoading(false);
    });
  }

  void _processFeedbackData(QuerySnapshot querySnapshot) {
    _allFeedbacks.clear();

    if (querySnapshot.docs.isNotEmpty) {
      for (var document in querySnapshot.docs) {
        try {
          final f = _parseFeedbackDocument(document);
          if (f != null) {
            _allFeedbacks.add(f);
          }
        } catch (e) {
          print("$_TAG: Error parsing feedback document: $e");
        }
      }

      // Sort by date descending
      _allFeedbacks.sort((a, b) => b.date.compareTo(a.date));
      _updateDisplayedFeedbacks();

      _setLoading(false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Feedback data loaded successfully")),
      );
    } else {
      print("$_TAG: No data in Firestore");
      _setLoading(false);
    }
  }

  AppFeedback? _parseFeedbackDocument(DocumentSnapshot document) {
    try {
      final data = document.data() as Map<String, dynamic>?;

      if (data == null) return null;

      final comment   = (data["comment"] ?? "") as String;
      final dateStr   = (data["date"] ?? "") as String;
      final rating    = (data["rating"] ?? 0) as int;
      final userEmail = (data["userEmail"] ?? "") as String;
      final userId    = (data["userId"] ?? "") as String;

      if (comment.isEmpty || dateStr.isEmpty || userEmail.isEmpty) {
        print("$_TAG: Missing fields in feedback doc: ${document.id}");
        return null;
      }

      DateTime date;
      try {
        date = DateTime.parse(dateStr);
      } catch (_) {
        date = DateTime.now();
      }

      return AppFeedback(
        id: document.id,
        userId: userId,
        userEmail: userEmail,
        comment: comment,
        rating: rating,
        date: date,
      );
    } catch (e) {
      print("$_TAG: parse error: $e");
      return null;
    }
  }

  void _updateDisplayedFeedbacks() {
    setState(() {
      if (_showAll) {
        _displayedFeedbacks = List.from(_allFeedbacks);
      } else {
        _displayedFeedbacks = _pickPseudoRandom(_allFeedbacks, 5);
      }
    });
  }

  List<AppFeedback> _pickPseudoRandom(List<AppFeedback> list, int count) {
    if (list.length <= count) return List.from(list);

    final out = <AppFeedback>[];
    final used = <int>{};
    final base = DateTime.now().millisecondsSinceEpoch;

    while (out.length < count && used.length < list.length) {
      final i = base % list.length ^ out.length; // cheap deterministic-ish
      if (!used.contains(i)) {
        used.add(i);
        out.add(list[i]);
      }
    }
    return out;
  }

  void _toggleShowMore() {
    setState(() {
      _showAll = !_showAll;
      _updateDisplayedFeedbacks();
    });
  }

  void _setLoading(bool v) => setState(() => _isLoading = v);
}

// ───────────────────── Item widget ─────────────────────
class FeedbackItem extends StatelessWidget {
  final AppFeedback feedback;

  const FeedbackItem({Key? key, required this.feedback}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(0, 1))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAvatar(),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              feedback.userEmail,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Color(0xFF333333),
                              ),
                            ),
                          ),
                          Text(
                            _formatDate(feedback.date),
                            style: const TextStyle(fontSize: 14, color: Color(0xFF888888)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Comment
                      Text(
                        feedback.comment,
                        style: const TextStyle(fontSize: 16, color: Color(0xFF555555), height: 1.4),
                      ),
                      const SizedBox(height: 12),

                      // Rating
                      Text(
                        "⭐ ${feedback.rating} / 5",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFF2691f5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      width: 55,
      height: 55,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
        ),
        borderRadius: BorderRadius.circular(27.5),
      ),
      child: Center(
        child: Text(
          _initials(feedback.userEmail),
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  String _initials(String email) {
    if (email.isEmpty) return "?";
    final namePart = email.split("@").first;
    final parts = namePart.split(RegExp(r'[.\-_]')).where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return email[0].toUpperCase();
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  String _formatDate(DateTime d) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }
}

// ───────────────────── Entity ─────────────────────
// NOTE: Renamed from `Feedback` → `AppFeedback` to avoid clashing with Flutter's `Feedback` class.
class AppFeedback {
  String id;
  String userId;
  String userEmail;
  String comment;
  int rating;
  DateTime date;

  AppFeedback({
    required this.id,
    required this.userId,
    required this.userEmail,
    required this.comment,
    required this.rating,
    required this.date,
  });

  bool isPositive() => rating >= 4;

  @override
  String toString() => 'AppFeedback{id: $id, userEmail: $userEmail, rating: $rating, date: $date}';
}
