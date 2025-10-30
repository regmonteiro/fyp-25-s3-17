// lib/learning/learning_resources_page_rt.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:url_launcher/url_launcher.dart';
import '../controller/learning_page_controller.dart';

/// -------- Models --------

class LearningResource {
  final String id;
  final String title;
  final String description;
  final String? url;
  final String category; // simplified

  LearningResource({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    this.url,
  });

  static const Map<String, String> _categoryMap = {
    "Health": "Health",
    "Legal": "Legal",
    "Mental Health": "Mental Health",
    "Recreational": "Recreational",
    "Safety": "Safety",
    "Safety / Fraud Prevention": "Safety",
    "Exercise / Wellness": "Exercise",
    "Technology / Cybersecurity": "Technology",
    "Exercise": "Exercise",
    "Technology": "Technology",
  };

  factory LearningResource.fromRtdb(String id, Map data) {
    final origCat = (data['category'] ?? 'Other').toString();
    final simplified = _categoryMap[origCat] ?? 'Other';
    return LearningResource(
      id: id,
      title: (data['title'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      url: (data['url'] as String?)?.trim().isEmpty == true ? null : data['url'],
      category: simplified,
    );
  }
}

class PointsData {
  final int currentPoints;
  final int totalEarned;
  final List<Map<String, dynamic>> pointHistory;
  final int dailyStreak;
  final String? lastLearningDateISO;
  final int totalLearningTime; // seconds
  final List<String> resourcesClicked;
  final List<Map<String, dynamic>> learningSessions;
  final int totalResources;
  final int completedResources;
  final int averageTimePerSession;

  PointsData({
    this.currentPoints = 0,
    this.totalEarned = 0,
    this.pointHistory = const [],
    this.dailyStreak = 0,
    this.lastLearningDateISO,
    this.totalLearningTime = 0,
    this.resourcesClicked = const [],
    this.learningSessions = const [],
    this.totalResources = 0,
    this.completedResources = 0,
    this.averageTimePerSession = 0,
  });

  PointsData copyWith({
    int? currentPoints,
    int? totalEarned,
    List<Map<String, dynamic>>? pointHistory,
    int? dailyStreak,
    String? lastLearningDateISO,
    int? totalLearningTime,
    List<String>? resourcesClicked,
    List<Map<String, dynamic>>? learningSessions,
    int? totalResources,
    int? completedResources,
    int? averageTimePerSession,
  }) {
    return PointsData(
      currentPoints: currentPoints ?? this.currentPoints,
      totalEarned: totalEarned ?? this.totalEarned,
      pointHistory: pointHistory ?? this.pointHistory,
      dailyStreak: dailyStreak ?? this.dailyStreak,
      lastLearningDateISO: lastLearningDateISO ?? this.lastLearningDateISO,
      totalLearningTime: totalLearningTime ?? this.totalLearningTime,
      resourcesClicked: resourcesClicked ?? this.resourcesClicked,
      learningSessions: learningSessions ?? this.learningSessions,
      totalResources: totalResources ?? this.totalResources,
      completedResources: completedResources ?? this.completedResources,
      averageTimePerSession: averageTimePerSession ?? this.averageTimePerSession,
    );
  }

  Map<String, dynamic> toMap() => {
        'currentPoints': currentPoints,
        'totalEarned': totalEarned,
        'pointHistory': pointHistory,
        'dailyStreak': dailyStreak,
        'lastLearningDate': lastLearningDateISO,
        'totalLearningTime': totalLearningTime,
        'resourcesClicked': resourcesClicked,
        'learningSessions': learningSessions,
        'totalResources': totalResources,
        'completedResources': completedResources,
        'averageTimePerSession': averageTimePerSession,
      };

  factory PointsData.fromMap(Map? m) {
    if (m == null) return PointsData();

    List<Map<String, dynamic>> _asListMap(dynamic v) {
      if (v is List) {
        return v.cast<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      } else if (v is Map) {
        // in case it was stored as keyed map
        return Map<String, dynamic>.from(v)
            .values
            .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      return [];
    }

    List<String> _asStringList(dynamic v) {
      if (v is List) return v.map((e) => e.toString()).toList();
      if (v is Map) return Map<String, dynamic>.from(v).values.map((e) => e.toString()).toList();
      return [];
    }

    return PointsData(
      currentPoints: (m['currentPoints'] ?? 0) as int,
      totalEarned: (m['totalEarned'] ?? 0) as int,
      pointHistory: _asListMap(m['pointHistory']),
      dailyStreak: (m['dailyStreak'] ?? 0) as int,
      lastLearningDateISO: (m['lastLearningDate'] as String?),
      totalLearningTime: (m['totalLearningTime'] ?? 0) as int,
      resourcesClicked: _asStringList(m['resourcesClicked']),
      learningSessions: _asListMap(m['learningSessions']),
      totalResources: (m['totalResources'] ?? 0) as int,
      completedResources: (m['completedResources'] ?? 0) as int,
      averageTimePerSession: (m['averageTimePerSession'] ?? 0) as int,
    );
  }
}

class LearningResourcesPageRT extends StatefulWidget {
  const LearningResourcesPageRT({Key? key}) : super(key: key);
  @override
  State<LearningResourcesPageRT> createState() => _LearningResourcesPageRTState();
}

class _LearningResourcesPageRTState extends State<LearningResourcesPageRT>
    with WidgetsBindingObserver {
  final _auth = FirebaseAuth.instance;
  final _rtdb = FirebaseDatabase.instance;

  // Controller for selection/error (matches your JS controller semantics)
  late final ViewLearningResourceController _ctrl;

  // data
  List<LearningResource> _allResources = [];
  bool _loading = true;
  String? _error;

  // user points/state
  PointsData _points = PointsData();
  bool _pointsLoading = true;

  // ui state
  String _search = '';
  String _selectedCategory = 'All';
  String? _hoveredId;

  // time tracking
  final Map<String, int> _startTimes = {}; // resourceId -> epoch ms
  bool _showPointsPopup = false;
  int _popupPoints = 0;
  String _popupMsg = '';

  static const categories = [
    'All',
    'Health',
    'Legal',
    'Mental Health',
    'Recreational',
    'Safety',
    'Technology',
    'Exercise',
  ];

  String? get _emailSanitized {
    final email = _auth.currentUser?.email;
    if (email == null) return null;
    return email.replaceAll(RegExp(r'[.@]'), '_');
  }

  DatabaseReference? get _accountRef {
    final id = _emailSanitized;
    if (id == null) return null;
    return _rtdb.ref('Account/$id');
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ctrl = ViewLearningResourceController();
    _init();
  }

  Future<void> _init() async {
    await _loadResources();
    await _loadUserPoints();
  }

  Future<void> _loadResources() async {
    try {
      final snap = await _rtdb.ref('resources').get();
      if (snap.exists && snap.value is Map) {
        final map = Map<String, dynamic>.from(snap.value as Map);
        final list = map.entries.map((e) {
          final data = Map<String, dynamic>.from(e.value as Map);
          return LearningResource.fromRtdb(e.key, data);
        }).toList();

        // Feed controller for selection/error API
        _ctrl.setResources(list
            .map((r) => LearningResourceMini(
                  id: r.id,
                  title: r.title,
                  description: r.description,
                  category: r.category,
                  url: r.url,
                ))
            .toList());

        setState(() {
          _allResources = list;
          _loading = false;
        });
      } else {
        _ctrl.setResources(const []);
        setState(() {
          _allResources = [];
          _loading = false;
        });
      }
    } catch (e) {
      _ctrl.setResources(const []);
      setState(() {
        _error = 'Failed to load resources.'; // optional
        _loading = false;
      });
    }
  }

  Future<void> _loadUserPoints() async {
    if (_accountRef == null) {
      setState(() => _pointsLoading = false);
      return;
    }
    try {
      final snap = await _accountRef!.get();
      if (snap.exists && snap.value is Map) {
        final map = Map<String, dynamic>.from(snap.value as Map);
        final pd = PointsData.fromMap(map['pointsData'] as Map?);
        setState(() {
          _points = pd.copyWith(totalResources: _allResources.length);
          _pointsLoading = false;
        });
      } else {
        // initialize
        final uid = _auth.currentUser!.uid;
        _points = PointsData(totalResources: _allResources.length);
        await _accountRef!.set({
          'ownerUid': uid,                        // ← NEW (enables secure rules)
          'email': _auth.currentUser?.email ?? '',
          'pointsData': _points.toMap(),
          'lastUpdated': DateTime.now().toIso8601String(),
        });
        setState(() => _pointsLoading = false);
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load user data.';
        _pointsLoading = false;
      });
    }
  }

  Future<void> _writePoints(PointsData newPd) async {
    if (_accountRef == null) return;
    setState(() => _points = newPd);
    await _accountRef!.update({
      'pointsData': newPd.toMap(),
      'lastUpdated': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _mergeIntoPoints(Map<String, dynamic> partial) async {
    final merged = _points.toMap()..addAll(partial);
    final newPd = PointsData.fromMap(merged);
    await _writePoints(newPd);
  }

  Future<int> _addPoints(int delta, {String reason = 'Learning activity'}) async {
    final now = DateTime.now().toIso8601String();
    final newCurrent = _points.currentPoints + delta;
    final newTotal = _points.totalEarned + (delta > 0 ? delta : 0);

    final history = List<Map<String, dynamic>>.from(_points.pointHistory)
      ..add({
        'points': delta,
        'reason': reason,
        'timestamp': now,
        'type': delta > 0 ? 'earning' : 'redemption',
      });
    final trimmed = history.length > 50 ? history.sublist(history.length - 50) : history;

    await _writePoints(_points.copyWith(
      currentPoints: newCurrent,
      totalEarned: newTotal,
      pointHistory: trimmed,
    ));

    if (delta > 0) _showPopup(delta, reason);
    return newCurrent;
  }

  void _showPopup(int pts, String msg) {
    setState(() {
      _popupPoints = pts;
      _popupMsg = msg;
      _showPointsPopup = true;
    });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showPointsPopup = false);
    });
  }

  Future<void> _updateDailyStreak() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastISO = _points.lastLearningDateISO;

    int newStreak = _points.dailyStreak;
    int bonus = 0;

    if (lastISO == null) {
      newStreak = 1;
    } else {
      final last = DateTime.tryParse(lastISO);
      if (last != null) {
        final lastDay = DateTime(last.year, last.month, last.day);
        final yest = today.subtract(const Duration(days: 1));
        if (lastDay == yest) {
          newStreak += 1;
        } else if (lastDay != today) {
          newStreak = 1;
        }
      } else {
        newStreak = 1;
      }
    }

    if (newStreak >= 7 && _points.dailyStreak < 7) {
      bonus = 10;
    } else if (newStreak > _points.dailyStreak) {
      bonus = 2;
    }

    await _mergeIntoPoints({
      'dailyStreak': newStreak,
      'lastLearningDate': now.toIso8601String(),
    });

    if (bonus > 0) {
      await _addPoints(bonus, reason: newStreak >= 7 ? '7-day streak bonus! 🎉' : 'Daily learning bonus!');
    }
  }

  Future<void> _startTracking(LearningResource r) async {
    final id = r.id;
    final isNew = !_points.resourcesClicked.contains(id);

    _startTimes[id] = DateTime.now().millisecondsSinceEpoch;

    if (isNew) {
      await _addPoints(1, reason: 'Clicked learning resource');
      final updated = List<String>.from(_points.resourcesClicked)..add(id);
      await _mergeIntoPoints({'resourcesClicked': updated});
    }

    await _updateDailyStreak();
  }

  Future<void> _stopTracking(String resourceId) async {
    final start = _startTimes[resourceId];
    if (start == null) return;
    final end = DateTime.now().millisecondsSinceEpoch;
    final secs = ((end - start) / 1000).floor();
    final mins = (secs / 60).floor();

    int award = 0;
    if (mins >= 10) {
      award = 10;
    } else if (mins >= 5) {
      award = 7;
    } else if (mins >= 2) {
      award = 5;
    } else if (mins >= 1) {
      award = 2;
    }

    if (award > 0) {
      await _addPoints(award, reason: 'Learned for $mins minutes');

      final newSession = {
        'resourceId': resourceId,
        'startTime': DateTime.fromMillisecondsSinceEpoch(start).toIso8601String(),
        'endTime': DateTime.fromMillisecondsSinceEpoch(end).toIso8601String(),
        'duration': secs,
        'pointsEarned': award,
      };

      final sessions = List<Map<String, dynamic>>.from(_points.learningSessions)..add(newSession);
      if (sessions.length > 100) {
        sessions.removeRange(0, sessions.length - 100);
      }

      final newTotal = _points.totalLearningTime + secs;
      final avg = sessions.isEmpty ? 0 : (newTotal ~/ sessions.length);

      await _mergeIntoPoints({
        'totalLearningTime': newTotal,
        'learningSessions': sessions,
        'averageTimePerSession': avg,
      });
    }

    _startTimes.remove(resourceId);
  }

  Future<void> _stopAll() async {
    final ids = _startTimes.keys.toList(growable: false);
    for (final id in ids) {
      await _stopTracking(id);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopAll(); // best-effort
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _stopAll();
    }
    super.didChangeAppLifecycleState(state);
  }

  // -------- UI helpers --------

  IconData _iconForCategory(String c) {
    switch (c) {
      case 'Health':
        return Icons.favorite;
      case 'Legal':
        return Icons.shield;
      case 'Mental Health':
        return Icons.psychology;
      case 'Recreational':
        return Icons.group;
      case 'Safety':
        return Icons.verified_user;
      case 'Technology':
        return Icons.bolt;
      case 'Exercise':
        return Icons.fitness_center;
      default:
        return Icons.menu_book;
    }
  }

  List<LearningResource> get _filtered {
    return _allResources.where((r) {
      final t = _search.toLowerCase();
      final matchesText =
          r.title.toLowerCase().contains(t) || r.description.toLowerCase().contains(t);
      final matchesCat = _selectedCategory == 'All' || r.category == _selectedCategory;
      return matchesText && matchesCat;
    }).toList();
  }

  // -------- Actions --------

  Future<void> _openResource(LearningResource r) async {
    final raw = r.url!;
      final uri = Uri.tryParse(raw);
      if (uri == null) return;
      final fixed = uri.hasScheme ? uri : Uri.parse('https://$raw');
      await _startTracking(r);
      final ok = await launchUrl(fixed, mode: LaunchMode.externalApplication);
if (!ok) _snack('Could not open: ${fixed.toString()}');

    _ctrl.selectResource(r.id);  // highlight in grid
    setState(() {});             // repaint
  }

  Future<void> _redeem() async {
    final current = _points.currentPoints;
    if (current < 50) {
      _snack('You need ${50 - current} more points to redeem a voucher.');
      return;
    }
    final voucherValue = (current ~/ 50) * 5;
    final redeemPoints = (current ~/ 50) * 50;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Redeem points'),
        content: Text('Redeem $redeemPoints points for a \$$voucherValue voucher?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Redeem')),
        ],
      ),
    );

    if (ok == true) {
      await _addPoints(-redeemPoints,
          reason: 'Redeemed $redeemPoints for \$$voucherValue voucher');
      _snack('🎉 Redeemed \$$voucherValue voucher!');
    }
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  // -------- Build --------

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Learning Resource Hub')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _hero(),
              const SizedBox(height: 12),
              _rewardsCard(),
              const SizedBox(height: 16),
              _searchBar(),
              const SizedBox(height: 8),
              _categoryChips(),

              // Show controller error (preferred)
              if (_ctrl.errorMessage.isNotEmpty) ...[
                const SizedBox(height: 8),
                _errorBox(_ctrl.errorMessage),
              ],
              // Optional: show data-loading error (from _loadUserPoints etc.)
              if (_error != null) ...[
                const SizedBox(height: 8),
                _errorBox(_error!),
              ],

              const SizedBox(height: 8),
              _grid(),
              const SizedBox(height: 100),
            ],
          ),
          if (_showPointsPopup) _pointsToast(),
        ],
      ),
    );
  }

  Widget _hero() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF667EEA), Color(0xFF764BA2)]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Learning Resource Hub',
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text('Discover curated resources and earn rewards while learning.',
              style: TextStyle(color: Colors.white70, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _rewardsCard() {
    if (_pointsLoading) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: _cardDeco(),
        child: const Center(child: Text('Loading rewards...')),
      );
    }

    final current = _points.currentPoints;
    final redeemable = current >= 50;
    final remainder = current % 50;
    final pointsToNext = redeemable && remainder == 0 ? 0 : (50 - remainder);
    final progress = (remainder / 50.0).clamp(0.0, 1.0);
    final voucherValue = (current ~/ 50) * 5;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDeco(),
      child: Column(
        children: [
          if (_points.dailyStreak > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3CD),
                border: Border.all(color: const Color(0xFFFFEAA7)),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.local_fire_department, size: 16, color: Color(0xFFFF6B6B)),
                  const SizedBox(width: 6),
                  Text('${_points.dailyStreak}-day learning streak!'),
                  if (_points.dailyStreak >= 7)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6B6B),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('🔥 7-day streak!',
                          style: TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          LayoutBuilder(builder: (context, c) {
            return GridView.count(
              crossAxisCount: c.maxWidth > 700 ? 4 : 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _statCard(Icons.schedule, '${(_points.totalLearningTime / 60).floor()}m',
                    'Total Learning'),
                _statCard(Icons.menu_book, '${_points.resourcesClicked.length}',
                    'Resources Viewed'),
                _statCard(Icons.track_changes, '${_points.completedResources}', 'Completed'),
                _statCard(Icons.bolt, '${_points.learningSessions.length}', 'Sessions'),
              ],
            );
          }),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.emoji_events),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('My Learning Rewards',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              ),
              _pointsCircle(current),
            ],
          ),
          const SizedBox(height: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Progress to next reward'),
                Text('$pointsToNext points needed'),
              ]),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(value: progress, minHeight: 8),
              ),
              const SizedBox(height: 6),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Session avg: ${_points.averageTimePerSession}s'),
                Text('${current % 50}/50 points'),
              ]),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3CD),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.card_giftcard),
                    const SizedBox(width: 8),
                    Text('\$$voucherValue Voucher Available'),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: redeemable ? _redeem : null,
                icon: const Icon(Icons.card_giftcard),
                label: Text(redeemable
                    ? 'Redeem ${(current ~/ 50) * 50} Points'
                    : 'Need 50 Points'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _badge(Icons.star, 'Total Earned: ${_points.totalEarned}'),
              const SizedBox(width: 8),
              _badge(Icons.menu_book,
                  'Resources: ${_points.resourcesClicked.length}/${_allResources.length}'),
              const SizedBox(width: 8),
              _badge(Icons.local_fire_department, 'Streak: ${_points.dailyStreak}'),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () => _snack('Redemption history coming soon'),
                icon: const Icon(Icons.history, size: 16),
                label: const Text('View History'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDeco() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEEEE)),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))],
      );

  Widget _statCard(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration:
          BoxDecoration(color: const Color(0xFFF8F9FA), borderRadius: BorderRadius.circular(10)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF667EEA))),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ],
      ),
    );
  }

  Widget _pointsCircle(int p) {
    return Container(
      width: 72,
      height: 72,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [Color(0xFF5377F6), Color(0xFF0154ED)]),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$p', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const Text('POINTS', style: TextStyle(color: Colors.white70, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _badge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration:
          BoxDecoration(color: const Color(0xFFE9ECEF), borderRadius: BorderRadius.circular(14)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, size: 14, color: const Color(0xFF495057)), const SizedBox(width: 6), Text(text)],
      ),
    );
  }

  Widget _searchBar() {
    return TextField(
      decoration: InputDecoration(
        hintText: 'Search learning topics...',
        prefixIcon: const Icon(Icons.search),
        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(32)),
      ),
      onChanged: (v) => setState(() => _search = v),
    );
  }

  Widget _categoryChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: categories.map((c) {
        final selected = _selectedCategory == c;
        return ChoiceChip(
          label: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(_iconForCategory(c), size: 16),
            const SizedBox(width: 6),
            Text(c),
          ]),
          selected: selected,
          onSelected: (_) => setState(() => _selectedCategory = c),
        );
      }).toList(),
    );
  }

  Widget _errorBox(String msg) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration:
          BoxDecoration(color: const Color(0xFFFFEDEE), borderRadius: BorderRadius.circular(12)),
      child: Text(msg, style: const TextStyle(color: Colors.red)),
    );
  }

  Widget _grid() {
    final list = _filtered;
    if (list.isEmpty) {
      return _errorBox('No matching learning topics found.');
    }

    return LayoutBuilder(builder: (context, c) {
      final cross = c.maxWidth >= 1200 ? 3 : c.maxWidth >= 800 ? 2 : 1;
      return GridView.builder(
        itemCount: list.length,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cross,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.8,
        ),
        itemBuilder: (_, i) {
          final r = list[i];
          final beingTracked = _startTimes.containsKey(r.id);
          final viewed = _points.resourcesClicked.contains(r.id);

          // selection from controller
          final isSelected = _ctrl.selectedResource?.id == r.id;

          return MouseRegion(
            onEnter: (_) => setState(() => _hoveredId = r.id),
            onExit: (_) => setState(() => _hoveredId = null),
            child: GestureDetector(
              onTap: () => _openResource(r),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: beingTracked ? const Color(0xFFFFF5F5) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: beingTracked
                        ? const Color(0xFFFF6B6B)
                        : isSelected
                            ? Colors.green
                            : const Color(0xFFF0F0F0),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (_hoveredId == r.id) ? Colors.black26 : Colors.black12,
                      blurRadius: (_hoveredId == r.id) ? 12 : 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(
                          r.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (beingTracked)
                        const Icon(Icons.access_time, size: 16, color: Color(0xFFFF6B6B)),
                    ]),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Text(
                        r.description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.black87),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE9ECEF),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_iconForCategory(r.category), size: 14),
                              const SizedBox(width: 6),
                              Text(r.category, style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                        if (viewed)
                          const Text('✓ Viewed',
                              style: TextStyle(fontSize: 12, color: Colors.green)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    });
  }

  Widget _pointsToast() {
    return Positioned(
      right: 16,
      top: 16,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(8),
        color: const Color(0xFF4CAF50),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.auto_awesome, color: Colors.white),
              const SizedBox(width: 8),
              // ✅ fixed interpolation
              Text('+$_popupPoints points! $_popupMsg',
                  style: const TextStyle(color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}
