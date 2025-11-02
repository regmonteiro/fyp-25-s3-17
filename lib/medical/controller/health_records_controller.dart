import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '../../models/user_profile.dart';

class HealthRecord {
  final String id;
  final String recordName;
  final String recordType;
  final DateTime documentDate;
  final String uploadedByUid;
  final String uploadedByName;
  final DateTime uploadedAt;
  final String fileUrl;

  HealthRecord({
    required this.id,
    required this.recordName,
    required this.recordType,
    required this.documentDate,
    required this.uploadedByUid,
    required this.uploadedByName,
    required this.uploadedAt,
    required this.fileUrl,
  });

  factory HealthRecord.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final tsDoc = data['documentDate'];
    final tsUp  = data['uploadedAt'];
    return HealthRecord(
      id: doc.id,
      recordName: (data['recordName'] as String?) ?? 'Untitled Record',
      recordType: (data['recordType'] as String?) ?? 'Unknown',
      documentDate: tsDoc is Timestamp ? tsDoc.toDate() : DateTime.fromMillisecondsSinceEpoch(0),
      uploadedByUid: (data['uploadedByUid'] as String?) ?? '',
      uploadedByName: (data['uploadedByName'] as String?) ?? 'Unknown User',
      uploadedAt: tsUp is Timestamp ? tsUp.toDate() : DateTime.fromMillisecondsSinceEpoch(0),
      fileUrl: (data['fileUrl'] as String?) ?? '',
    );
  }
}

class HealthRecordsController extends ChangeNotifier {
  /// The elder whose records we’re manipulating/viewing.
  final String elderlyId;

  final FirebaseFirestore _db;
  final FirebaseStorage _storage;

  HealthRecordsController({
    required this.elderlyId,
    FirebaseFirestore? db,
    FirebaseStorage? storage,
  })  : _db = db ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  /// Account/{elderlyId}/health_records
  Stream<List<HealthRecord>> recordsStream() {
    return _db
        .collection('Account')
        .doc(elderlyId)
        .collection('health_records')
        .orderBy('documentDate', descending: true)
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (snap, _) => snap.data() ?? {},
          toFirestore: (data, _) => data,
        )
        .snapshots()
        .map((snap) => snap.docs.map(HealthRecord.fromDoc).toList());
  }

  /// Upload documents to Account/{elderlyId}/health_records.
  /// This method resolves the current uploader (uid & display name) internally.
  Future<bool> uploadRecords({
    required String recordName,
    required String recordType,
    required DateTime documentDate,
    required List<File> files,
  }) async {
    if (files.isEmpty) return false;

    // Resolve current uploader
    final user = FirebaseAuth.instance.currentUser;
    final uploaderUid = user?.uid ?? '';
    String uploaderName = 'Unknown User';

    if (uploaderUid.isNotEmpty) {
      try {
        final acc = await _db.collection('Account').doc(uploaderUid).get();
        final m = acc.data() ?? {};
        final safe = (m['safeDisplayName'] ?? m['displayName'])?.toString().trim() ?? '';
        final first = (m['firstName'] ?? m['firstname'])?.toString().trim() ?? '';
        final last  = (m['lastName']  ?? m['lastname']) ?.toString().trim() ?? '';
        final full  = [first, last].where((s) => s.isNotEmpty).join(' ').trim();
        uploaderName = safe.isNotEmpty ? safe : (full.isNotEmpty ? full : (m['email'] ?? 'Unknown User').toString());
      } catch (_) {
        // keep defaults
      }
    }

    final col = _db.collection('Account').doc(elderlyId).collection('health_records');

    try {
      for (final file in files) {
        final name = file.path.split('/').last;
        final storagePath = 'health_records/$elderlyId/${DateTime.now().millisecondsSinceEpoch}_$name';
        final ref = _storage.ref().child(storagePath);

        final snap = await ref.putFile(
          file,
          SettableMetadata(contentType: _guessMime(name)),
        );
        final url = await snap.ref.getDownloadURL();

        await col.add({
          'recordName': recordName,
          'recordType': recordType,
          'documentDate': Timestamp.fromDate(documentDate),
          'uploadedByUid': uploaderUid,
          'uploadedByName': uploaderName,
          'uploadedAt': FieldValue.serverTimestamp(),
          'fileUrl': url,
          'fileName': name,
        });
      }
      return true;
    } on FirebaseException catch (e) {
      debugPrint('Upload failed: ${e.code} ${e.message}');
      return false;
    }
  }

  // Pick which elder the current user is acting on.
// elderly  -> self.uid
// caregiver -> first ID in Account/{uid}.elderlyIds (with legacy fallbacks)
static Future<String?> resolveElderUidFor(UserProfile me) async {
  final type = (me.userType ?? '').toLowerCase();
  if (type == 'elderly') return me.uid;

  // caregiver path
  final doc = await FirebaseFirestore.instance
      .collection('Account')
      .doc(me.uid)
      .get();
  final data = doc.data() ?? {};

  List<String> _asStringList(Object? raw) {
    if (raw is List) {
      return raw
          .map((e) => e is String ? e.trim() : e?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return const [];
  }

  // Preferred
  final ids = _asStringList(data['elderlyIds']);
  if (ids.isNotEmpty) return ids.first;

  // Legacy single
  final single = (data['elderlyId'] as String?)?.trim();
  if (single != null && single.isNotEmpty) return single;

  // Legacy array
  final legacyMany = _asStringList(data['linkedElderlyIds']);
  if (legacyMany.isNotEmpty) return legacyMany.first;

  return null;
}


  static List<String> _asStringList(Object? raw) {
    if (raw is List) {
      return raw
          .map((e) => e is String ? e.trim() : e?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return const [];
  }

  String _guessMime(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.png')) return 'image/png';
    return 'application/octet-stream';
  }
}
