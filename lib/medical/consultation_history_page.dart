import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ConsultationHistoryPage extends StatefulWidget {
  const ConsultationHistoryPage({Key? key}) : super(key: key);

  @override
  State<ConsultationHistoryPage> createState() => _ConsultationHistoryPageState();
}

class _ConsultationHistoryPageState extends State<ConsultationHistoryPage> {
  final _auth = FirebaseAuth.instance;
  final _fs   = FirebaseFirestore.instance;

  bool _loading = true;
  String? _elderlyUid;
  String? _elderlyEmail;
  String? _elderlyName;

  // Data
  List<_Consultation> _consultations = [];
  List<_Caregiver> _caregivers = [];

  // Invite modal state
  bool _showInviteModal = false;
  bool _showConfirmation = false;
  bool _inviteLoading = false;
  int  _inviteStep = 1;
  String _currentConsultationId = '';
  final List<String> _selectedCaregivers = [];

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _consultationsSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSub;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _consultationsSub?.cancel();
    _userSub?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final u = _auth.currentUser;
    if (u == null) {
      setState(() => _loading = false);
      return;
    }

    _elderlyUid = u.uid;

    // Listen user profile (for name/email & caregiver links)
    _userSub = _fs.collection('Account').doc(_elderlyUid).snapshots().listen((snap) async {
      final data = snap.data() ?? {};
      final email = (data['email'] as String?) ?? u.email;
      final first = (data['firstname'] as String?) ?? '';
      final last  = (data['lastname']  as String?) ?? '';
      final displayName = [first, last].where((e) => (e ?? '').toString().trim().isNotEmpty).join(' ').trim();

      setState(() {
        _elderlyEmail = email;
        _elderlyName  = displayName.isNotEmpty ? displayName : (data['displayName'] as String?) ?? email ?? 'You';
      });

      // Resolve caregiver UIDs: accept either array field
      final List<dynamic> rawA = (data['linkedCaregivers'] as List?) ?? const [];
      final List<dynamic> rawB = (data['linkedCaregiversUids'] as List?) ?? const [];
      final Set<String> caregiverUids = {
        ...rawA.map((e) => e?.toString()).whereType<String>(),
        ...rawB.map((e) => e?.toString()).whereType<String>(),
      };

      // Fetch caregiver profiles (small lists; if large, paginate)
      final List<_Caregiver> list = [];
      for (final cgUid in caregiverUids) {
        try {
          final cgDoc = await _fs.collection('Account').doc(cgUid).get();
          if (!cgDoc.exists) continue;
          final d = cgDoc.data() ?? {};
          final cgEmail = d['email'] as String?;
          final cgName  = (d['displayName'] as String?) ??
              '${(d['firstname'] ?? '')} ${(d['lastname'] ?? '')}'.trim();
          list.add(_Caregiver(uid: cgUid, email: cgEmail ?? 'unknown', name: cgName.isEmpty ? (cgEmail ?? cgUid) : cgName));
        } catch (_) {}
      }
      if (mounted) setState(() => _caregivers = list);
    });

    
    _consultationsSub = _fs
        .collection('Account')
        .doc(_elderlyUid)
        .collection('consultations')
        .orderBy('requestedAt', descending: true)
        .snapshots()
        .listen((qs) {
      final items = qs.docs.map((d) => _Consultation.fromMap(d.id, d.data())).toList();
      if (mounted) {
        setState(() {
          _consultations = items;
          _loading = false;
        });
      }
    }, onError: (_) {
      if (mounted) setState(() => _loading = false);
    });
  }

  // ---------- Invite flow ----------
  void _openInviteModal(String consultationId) {
    setState(() {
      _currentConsultationId = consultationId;
      _selectedCaregivers.clear();
      _inviteStep = 1;
      _showInviteModal = true;
      _showConfirmation = false;
      _inviteLoading = false;
    });
  }

  void _closeInviteModal() {
    setState(() {
      _showInviteModal = false;
      _showConfirmation = false;
      _selectedCaregivers.clear();
      _inviteStep = 1;
      _inviteLoading = false;
      _currentConsultationId = '';
    });
  }

  void _handleInviteTypeSelection(String type) {
    if (type == 'primary' && _caregivers.isNotEmpty) {
      _selectedCaregivers
        ..clear()
        ..add(_caregivers.first.email);
    } else {
      _selectedCaregivers.clear();
    }
    setState(() => _inviteStep = 2);
  }

  void _toggleCaregiver(String email, bool selected) {
    setState(() {
      if (selected) {
        if (!_selectedCaregivers.contains(email)) _selectedCaregivers.add(email);
      } else {
        _selectedCaregivers.remove(email);
      }
    });
  }

  Future<void> _sendInvites() async {
    if (_currentConsultationId.isEmpty || _selectedCaregivers.isEmpty) {
      _snack('Please select at least one caregiver.');
      return;
    }
    setState(() => _inviteLoading = true);

    try {
      final docRef = _fs
          .collection('Account')
          .doc(_elderlyUid)
          .collection('consultations')
          .doc(_currentConsultationId);

      // Merge invitedCaregivers into existing map
      await _fs.runTransaction((tx) async {
        final snap = await tx.get(docRef);
        if (!snap.exists) throw Exception('Consultation not found.');

        final data = snap.data() as Map<String, dynamic>;
        final Map<String, dynamic> invited =
            Map<String, dynamic>.from((data['invitedCaregivers'] as Map?) ?? {});

        final nowIso = DateTime.now().toIso8601String();
        for (final email in _selectedCaregivers) {
          final key = _normalizeEmailKey(email);
          invited[key] = {
            'invitedAt': nowIso,
            'status': 'pending',
            'elderlyEmail': _elderlyEmail,
            'caregiverEmail': email,
            'originalEmail': email,
          };
        }

        tx.update(docRef, {
          'invitedCaregivers': invited,
          'elderlyEmail': _elderlyEmail,
          'elderlyName': _elderlyName,
          'lastUpdated': nowIso,
        });
      });

      _snack('Invited ${_selectedCaregivers.length} caregiver(s).');
      _closeInviteModal();
    } catch (e) {
      _snack('Failed to invite caregivers.');
      setState(() => _inviteLoading = false);
    }
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('GP Consultation History')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final caregiversCount = _caregivers.length;

    final page = Scaffold(
      appBar: AppBar(
        title: const Text('GP Consultation History'),
        backgroundColor: Colors.indigo.shade700,
      ),
      body: Column(
        children: [
          if (caregiversCount > 0)
            Container(
              width: double.infinity,
              color: Colors.indigo.shade50,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text(
                '👥 You have $caregiversCount caregiver(s) linked',
                style: TextStyle(color: Colors.indigo.shade900, fontWeight: FontWeight.w600),
              ),
            ),
          Expanded(
            child: _consultations.isEmpty
                ? const _EmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _consultations.length,
                    itemBuilder: (_, i) {
                      final c = _consultations[i];
                      return _ConsultationCard(
                        id: c.id,
                        dateText: _fmtTs(c.requestedAt ?? c.startedAt),
                        status: c.status ?? 'Pending',
                        reason: c.reason ?? c.symptoms ?? 'No reason provided.',
                        invitedCaregivers: c.invitedCaregivers ?? const {},
                        attendedCaregivers: c.attendedCaregivers ?? const {},
                        denormalizeKey: _denormalizeEmailKey,
                        onViewDetails: () {
                          final msg = [
                            'Date: ${_fmtTs(c.requestedAt ?? c.startedAt)}',
                            'Status: ${c.status ?? '-'}',
                            'Reason: ${c.reason ?? c.symptoms ?? '-'}',
                            'Elderly: ${_elderlyName ?? '-'} (${_elderlyEmail ?? '-'})',
                            'Invited: ${(c.invitedCaregivers ?? {}).length}',
                            'Attended: ${(c.attendedCaregivers ?? {}).length}',
                          ].join('\n');
                          showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Consultation Details'),
                              content: Text(msg),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
                              ],
                            ),
                          );
                        },
                        onInvite: () => _openInviteModal(c.id),
                        canInvite: (c.status ?? '').toLowerCase() != 'completed',
                      );
                    },
                  ),
          ),
        ],
      ),
    );

    return page
        .addOverlay(
          visible: _showInviteModal,
          child: _InviteModal(
            elderlyEmail: _elderlyEmail,
            consultation: _consultations.firstWhere(
              (e) => e.id == _currentConsultationId,
              orElse: () => _Consultation.empty(_currentConsultationId),
            ),
            caregivers: _caregivers,
            step: _inviteStep,
            selected: _selectedCaregivers,
            onClose: _closeInviteModal,
            onSelectType: _handleInviteTypeSelection,
            onToggle: _toggleCaregiver,
            onConfirm: () => setState(() => _showConfirmation = true),
            inviteLoading: _inviteLoading,
            onSend: _sendInvites,
            showConfirmation: _showConfirmation,
            onHideConfirmation: () => setState(() => _showConfirmation = false),
          ),
        );
  }

  // ---------- helpers ----------
  String _fmtTs(Timestamp? ts) {
    if (ts == null) return 'Unknown';
    final dt = ts.toDate();
    return DateFormat('MMM d, yyyy @ h:mm a').format(dt);
  }

  String _normalizeEmailKey(String email) => email
      .toLowerCase()
      .trim()
      .replaceAll('.', '_dot_')
      .replaceAll('#', '_hash_')
      .replaceAll('\$', '_dollar_')
      .replaceAll('/', '_slash_')
      .replaceAll('[', '_lbracket_')
      .replaceAll(']', '_rbracket_');

  String _denormalizeEmailKey(String key) => key
      .replaceAll('_dot_', '.')
      .replaceAll('_hash_', '#')
      .replaceAll('_dollar_', '\$')
      .replaceAll('_slash_', '/')
      .replaceAll('_lbracket_', '[')
      .replaceAll('_rbracket_', ']');

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

// ---------- Models ----------
class _Consultation {
  final String id;
  final Timestamp? requestedAt;
  final Timestamp? startedAt;
  final String? reason;
  final String? symptoms;
  final String? status;
  final Map<String, dynamic>? invitedCaregivers;
  final Map<String, dynamic>? attendedCaregivers;

  _Consultation({
    required this.id,
    this.requestedAt,
    this.startedAt,
    this.reason,
    this.symptoms,
    this.status,
    this.invitedCaregivers,
    this.attendedCaregivers,
  });

  factory _Consultation.fromMap(String id, Map<String, dynamic> m) {
    return _Consultation(
      id: id,
      requestedAt: m['requestedAt'] as Timestamp?,
      startedAt: m['startedAt'] as Timestamp?,
      reason: m['reason'] as String?,
      symptoms: m['symptoms'] as String?,
      status: m['status'] as String?,
      invitedCaregivers: (m['invitedCaregivers'] as Map?)?.cast<String, dynamic>(),
      attendedCaregivers: (m['attendedCaregivers'] as Map?)?.cast<String, dynamic>(),
    );
  }

  factory _Consultation.empty(String id) => _Consultation(id: id);
}

class _Caregiver {
  final String uid;
  final String email;
  final String name;
  _Caregiver({required this.uid, required this.email, required this.name});
}

// ---------- UI small pieces ----------
class _ConsultationCard extends StatelessWidget {
  final String id, dateText, status, reason;
  final Map<String, dynamic> invitedCaregivers, attendedCaregivers;
  final String Function(String) denormalizeKey;
  final VoidCallback onViewDetails;
  final VoidCallback onInvite;
  final bool canInvite;

  const _ConsultationCard({
    required this.id,
    required this.dateText,
    required this.status,
    required this.reason,
    required this.invitedCaregivers,
    required this.attendedCaregivers,
    required this.onViewDetails,
    required this.onInvite,
    required this.canInvite,
    required this.denormalizeKey,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 6,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(dateText, style: TextStyle(fontWeight: FontWeight.w700, color: Colors.indigo.shade800)),
              _StatusChip(status: status),
            ],
          ),
          const Divider(height: 18, color: Colors.black12),
          const Text('Reason for Consultation:', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black54)),
          const SizedBox(height: 4),
          Text(reason),
          const SizedBox(height: 10),
          if (invitedCaregivers.isNotEmpty) ...[
            Text('Invited Caregivers (${invitedCaregivers.length}):', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: invitedCaregivers.entries.map((e) {
                final data = (e.value is Map) ? Map<String, dynamic>.from(e.value) : const <String, dynamic>{};
                final email = (data['originalEmail'] ?? denormalizeKey(e.key)).toString();
                final st = (data['status'] ?? 'pending').toString();
                final attended = st.toLowerCase() == 'attended';
                return Chip(
                  label: Text('$email ($st)'),
                  avatar: Icon(attended ? Icons.check : Icons.hourglass_bottom, size: 18),
                  backgroundColor: attended ? Colors.green.shade50 : Colors.orange.shade50,
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
          ],
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            TextButton(onPressed: onViewDetails, child: const Text('View Full Details')),
            if (canInvite) ...[
              const SizedBox(width: 8),
              OutlinedButton(onPressed: onInvite, child: const Text('Invite Caregiver')),
            ],
          ]),
        ]),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});
  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;
    switch (status) {
      case 'Completed':
        color = Colors.green.shade600; icon = Icons.check_circle; break;
      case 'Cancelled':
        color = Colors.red.shade600; icon = Icons.cancel; break;
      default:
        color = Colors.orange.shade600; icon = Icons.pending_actions;
    }
    return Chip(
      label: Text(status, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
      backgroundColor: color,
      avatar: Icon(icon, color: Colors.white, size: 18),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.history_toggle_off, size: 80, color: Colors.grey.shade400),
        const SizedBox(height: 16),
        const Text('No past consultations found.',
            style: TextStyle(fontSize: 18, color: Colors.black54, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
        const SizedBox(height: 8),
        const Text('Your call history will appear here after your first GP consultation.',
            style: TextStyle(fontSize: 14, color: Colors.black45), textAlign: TextAlign.center),
      ]),
    ),
  );
}

class _InviteModal extends StatelessWidget {
  final String? elderlyEmail;
  final _Consultation consultation;
  final List<_Caregiver> caregivers;
  final int step;
  final List<String> selected;
  final VoidCallback onClose;
  final void Function(String type) onSelectType;
  final void Function(String email, bool selected) onToggle;
  final VoidCallback onConfirm;
  final bool inviteLoading;
  final VoidCallback onSend;
  final bool showConfirmation;
  final VoidCallback onHideConfirmation;

  const _InviteModal({
    required this.elderlyEmail,
    required this.consultation,
    required this.caregivers,
    required this.step,
    required this.selected,
    required this.onClose,
    required this.onSelectType,
    required this.onToggle,
    required this.onConfirm,
    required this.inviteLoading,
    required this.onSend,
    required this.showConfirmation,
    required this.onHideConfirmation,
  });

  @override
  Widget build(BuildContext context) {
    final dateText = _fmt(consultation.requestedAt ?? consultation.startedAt);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Material(
          color: Colors.white,
          elevation: 16,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                const Expanded(child: Text('Invite Caregiver to Consultation',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
                IconButton(onPressed: onClose, icon: const Icon(Icons.close)),
              ]),
              const SizedBox(height: 8),
              _summary(dateText, elderlyEmail),
              const SizedBox(height: 12),

              if (caregivers.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text('No caregivers linked to your account.', textAlign: TextAlign.center),
                )
              else if (step == 1) ...[
                _optionCard(
                  icon: '👑',
                  title: 'Invite Primary Caregiver',
                  subtitle: 'Invite your main caregiver automatically',
                  trailing: '${caregivers.first.name} (${caregivers.first.email})',
                  onTap: () => onSelectType('primary'),
                ),
                const SizedBox(height: 10),
                _optionCard(
                  icon: '👥',
                  title: 'Choose Specific Caregivers',
                  subtitle: 'Select one or more caregivers to invite',
                  trailing: '${caregivers.length} caregiver(s) available',
                  onTap: () => onSelectType('choose'),
                ),
              ] else ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('${selected.length} selected of ${caregivers.length}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: caregivers.map((c) => FilterChip(
                    selected: selected.contains(c.email),
                    label: Text('${c.name} (${c.email})'),
                    onSelected: (v) => onToggle(c.email, v),
                  )).toList(),
                ),
                const SizedBox(height: 12),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  TextButton(onPressed: onClose, child: const Text('Cancel')),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: selected.isEmpty || inviteLoading ? null : onConfirm,
                    child: Text(inviteLoading ? 'Sending...' : 'Invite ${selected.length} Caregiver(s)'),
                  ),
                ]),
              ],

              if (showConfirmation) ...[
                const Divider(height: 20),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Confirm Invitation', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: selected.map((e) => Text('• $e')).toList(),
                  ),
                ),
                const SizedBox(height: 10),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  TextButton(onPressed: onHideConfirmation, child: const Text('Back')),
                  const SizedBox(width: 8),
                  ElevatedButton(onPressed: inviteLoading ? null : onSend,
                      child: Text(inviteLoading ? 'Sending...' : 'Yes, Send')),
                ]),
              ],
            ]),
          ),
        ),
      ),
    );
  }

  Widget _summary(String dateText, String? email) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const SizedBox(width: 110, child: Text('Date & Time:', style: TextStyle(fontWeight: FontWeight.w700))),
          Expanded(child: Text(dateText)),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          const SizedBox(width: 110, child: Text('Your Email:', style: TextStyle(fontWeight: FontWeight.w700))),
          Expanded(child: Text(email ?? 'Not set')),
        ]),
      ]),
    );
  }

  Widget _optionCard({
    required String icon,
    required String title,
    required String subtitle,
    required String trailing,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black12),
        ),
        child: Row(children: [
          Text(icon, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(color: Colors.black54)),
          ])),
          const SizedBox(width: 8),
          Text(trailing, style: const TextStyle(fontStyle: FontStyle.italic)),
          const Icon(Icons.chevron_right),
        ]),
      ),
    );
  }

  static String _fmt(Timestamp? ts) {
    if (ts == null) return 'Unknown';
    final dt = ts.toDate();
    return DateFormat('MMM d, yyyy @ h:mm a').format(dt);
  }
}

// ---------- Overlay helper ----------
extension _OverlayX on Widget {
  Widget addOverlay({required bool visible, required Widget child}) {
    if (!visible) return this;
    return Stack(children: [
      this,
      Positioned.fill(
        child: Container(color: Colors.black.withOpacity(0.4), alignment: Alignment.center, child: child),
      ),
    ]);
  }
}
