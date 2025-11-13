import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CareRoutineTemplateService {
  static const String _templates = 'careRoutineTemplateEntity';
  static const String _assigned = 'AssignedRoutines';
  static const String _accounts = 'Account';

  final FirebaseFirestore _fs = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _currentEmailLower =>
      _auth.currentUser?.email?.trim().toLowerCase();

  String? get _currentUid => _auth.currentUser?.uid;

  // ---------- Account helpers ----------

  Future<Map<String, dynamic>?> _fetchAccountDocByUid(String uid) async {
    // First try doc(uid)
    final doc = await _fs.collection(_accounts).doc(uid).get();
    if (doc.exists) return doc.data();

    // Fallback: where('uid'==uid)
    final qs = await _fs
        .collection(_accounts)
        .where('uid', isEqualTo: uid)
        .limit(1)
        .get();
    if (qs.docs.isNotEmpty) return qs.docs.first.data();

    return null;
  }

  Future<String> getCurrentUserType() async {
    final uid = _currentUid;
    if (uid == null) throw Exception('No logged-in user.');
    final acc = await _fetchAccountDocByUid(uid);
    if (acc == null) throw Exception('User not found in Account.');
    return (acc['userType'] as String?) ?? 'elderly';
  }

  /// First linked elder for caregiver, or own uid for elderly.
  Future<String> getLinkedElderlyId() async {
    final uid = _currentUid;
    if (uid == null) throw Exception('No logged-in user.');
    final acc = await _fetchAccountDocByUid(uid);
    if (acc == null) throw Exception('User not found in Account.');

    final type = (acc['userType'] as String?) ?? 'elderly';
    if (type == 'elderly') {
      final me = (acc['uid']?.toString().trim().isNotEmpty == true)
          ? acc['uid'].toString().trim()
          : uid;
      return me;
    }

    final ids = <String>{};
    void addList(dynamic v) {
      if (v is List) {
        for (final e in v) {
          final s = e?.toString().trim();
          if (s != null && s.isNotEmpty) ids.add(s);
        }
      }
    }

    addList(acc['elderlyIds']);
    final single = (acc['elderlyId'] as String?)?.trim();
    if (single != null && single.isNotEmpty) ids.add(single);

    if (ids.isEmpty) {
      throw Exception('No elderly linked to this caregiver account.');
    }
    return ids.first;
  }

  /// Returns minimal info for each linked elder.
  Future<List<Map<String, dynamic>>> getLinkedElderlyUsers() async {
    final uid = _currentUid;
    if (uid == null) throw Exception('No logged-in user.');
    final acc = await _fetchAccountDocByUid(uid);
    if (acc == null) throw Exception('User not found in Account.');

    final type = (acc['userType'] as String?) ?? 'elderly';

    if (type == 'elderly') {
      final name =
          '${(acc['firstname'] ?? '').toString()} ${(acc['lastname'] ?? '').toString()}'.trim();
      return [
        {
          'id': (acc['uid'] ?? uid).toString(),
          'uid': (acc['uid'] ?? uid).toString(),
          'email': _currentEmailLower ?? '',
          'name': name.isEmpty ? (_currentEmailLower ?? 'Me') : name,
          'age': _calculateAge(acc['dob']),
          'relationship': 'Self',
        }
      ];
    }

    // caregiver
    final ids = <String>{};
    void addList(dynamic v) {
      if (v is List) {
        for (final e in v) {
          final s = e?.toString().trim();
          if (s != null && s.isNotEmpty) ids.add(s);
        }
      }
    }
    addList(acc['elderlyIds']);
    final single = (acc['elderlyId'] as String?)?.trim();
    if (single != null && single.isNotEmpty) ids.add(single);

    // Enrich with Account lookups if possible
    final out = <Map<String, dynamic>>[];
    for (final id in ids) {
      final elderDoc = await _fs.collection(_accounts).doc(id).get();
      if (elderDoc.exists) {
        final m = elderDoc.data()!;
        final nm = (m['safeDisplayName'] ??
                m['displayName'] ??
                '${(m['firstName'] ?? m['firstname'] ?? '').toString()} ${(m['lastName'] ?? m['lastname'] ?? '').toString()}')
            .toString()
            .trim();
        out.add({
          'id': id,
          'uid': id,
          'email': m['email']?.toString() ?? '',
          'name': nm.isEmpty ? 'Linked Elderly' : nm,
          'age': _calculateAge(m['dob']),
          'relationship': 'Linked Elderly',
        });
      } else {
        out.add({
          'id': id,
          'uid': id,
          'email': '',
          'name': 'Linked Elderly',
          'age': 'Unknown',
          'relationship': 'Linked Elderly',
        });
      }
    }
    return out;
  }

  // ---------- Templates (created by current user) ----------

  Future<List<Map<String, dynamic>>> getUserCareRoutineTemplates() async {
    final email = _currentEmailLower;
    if (email == null || email.isEmpty) return [];
    final qs = await _fs
        .collection(_templates)
        .where('createdBy', isEqualTo: email)
        .get();
    return qs.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  Stream<List<Map<String, dynamic>>> subscribeToUserTemplates() {
    final email = _currentEmailLower;
    if (email == null || email.isEmpty) return const Stream.empty();
    return _fs
        .collection(_templates)
        .where('createdBy', isEqualTo: email)
        .snapshots()
        .map((qs) => qs.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  Future<String> createCareRoutineTemplate(Map<String, dynamic> template) async {
    final email = _currentEmailLower;
    if (email == null || email.isEmpty) {
      throw Exception('No logged-in user.');
    }
    final now = DateTime.now().toIso8601String();
    final payload = <String, dynamic>{
      'name': (template['name'] ?? '').toString(),
      'description': (template['description'] ?? '').toString(),
      'items': (template['items'] is List) ? template['items'] : <Map<String, dynamic>>[],
      'createdBy': email,
      'createdAt': now,
      'lastUpdatedAt': now,
    };
    final doc = await _fs.collection(_templates).add(payload);
    return doc.id;
  }

  Future<void> deleteCareRoutineTemplate(String templateId) async {
    if (await isTemplateAssigned(templateId)) {
      throw Exception('Cannot delete: template is currently assigned.');
    }
    await _fs.collection(_templates).doc(templateId).delete();
  }

  // ---------- Assignments ----------

  /// AssignedRoutines/{elderlyUid}/templates/{templateId}
  Future<void> assignRoutineToElderly(
    String elderlyUid,
    String templateId, {
    DateTime? startDate,
  }) async {
    if (elderlyUid.isEmpty) throw Exception('elderlyUid required');
    if (templateId.isEmpty) throw Exception('templateId required');

    final tplDoc = await _fs.collection(_templates).doc(templateId).get();
    if (!tplDoc.exists) throw Exception('Template not found.');
    final tpl = tplDoc.data()!;

    final payload = <String, dynamic>{
      'templateId': templateId,
      'elderlyId': elderlyUid,
      'assignedBy': _currentEmailLower ?? '',
      'assignedAt': FieldValue.serverTimestamp(),
      'startDate': (startDate ?? DateTime.now()).toIso8601String(),
      'isActive': true,
      'templateData': tpl, // denormalized for quick reads
    };

    await _fs
        .collection(_assigned)
        .doc(elderlyUid)
        .collection('templates')
        .doc(templateId)
        .set(payload, SetOptions(merge: true));
  }

  Future<void> removeAssignedRoutine(String elderlyUid, String templateId) async {
    await _fs
        .collection(_assigned)
        .doc(elderlyUid)
        .collection('templates')
        .doc(templateId)
        .delete();
  }

  Future<List<Map<String, dynamic>>> getAssignedRoutines(String elderlyUid) async {
    final qs = await _fs
        .collection(_assigned)
        .doc(elderlyUid)
        .collection('templates')
        .get();
    return qs.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  Stream<List<Map<String, dynamic>>> subscribeAssignedRoutines(String elderlyUid) {
    if (elderlyUid.isEmpty) return const Stream.empty();
    return _fs
        .collection(_assigned)
        .doc(elderlyUid)
        .collection('templates')
        .snapshots()
        .map((qs) => qs.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  /// Checks across all elderly via a collectionGroup on 'templates'.
  Future<bool> isTemplateAssigned(String templateId) async {
    final uid = _currentUid;
    if (uid == null) {
      throw Exception('No logged-in user.');
    }

    final acc = await _fetchAccountDocByUid(uid);
    if (acc == null) {
      throw Exception('User not found in Account.');
    }

    final type = (acc['userType'] as String?) ?? 'elderly';

    // Collect all elderly IDs we care about (for this user)
    final ids = <String>{};

    if (type == 'elderly') {
      // Elderly → just their own uid
      final me = (acc['uid']?.toString().trim().isNotEmpty == true)
          ? acc['uid'].toString().trim()
          : uid;
      ids.add(me);
    } else {
      // Caregiver → all linked elderly IDs
      void addList(dynamic v) {
        if (v is List) {
          for (final e in v) {
            final s = e?.toString().trim();
            if (s != null && s.isNotEmpty) ids.add(s);
          }
        }
      }

      addList(acc['elderlyIds']);
      final single = (acc['elderlyId'] as String?)?.trim();
      if (single != null && single.isNotEmpty) ids.add(single);
    }

    if (ids.isEmpty) {
      // No elderly linked – nothing can be assigned
      return false;
    }

    // For each elderly, check if doc AssignedRoutines/{elderlyUid}/templates/{templateId} exists
    for (final elderlyUid in ids) {
      final doc = await _fs
          .collection(_assigned)
          .doc(elderlyUid)
          .collection('templates')
          .doc(templateId)
          .get();

      if (doc.exists) {
        return true;
      }
    }

    return false;
  }

  // ---------- utils ----------
  int _calculateAge(dynamic dob) {
    try {
      DateTime? birth;
      if (dob is Timestamp) birth = dob.toDate();
      if (dob is String && dob.isNotEmpty) birth = DateTime.parse(dob);
      if (birth == null) return 0;
      final now = DateTime.now();
      var age = now.year - birth.year;
      if (now.month < birth.month || (now.month == birth.month && now.day < birth.day)) age--;
      return age;
    } catch (_) {
      return 0;
    }
  }
}
