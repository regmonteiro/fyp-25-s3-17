import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
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
    final tsUp = data['uploadedAt'];
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
  final String elderlyUid;        // whose records we’re viewing
  final String currentUserUid;    // uploader’s uid (elder or caregiver)
  final String currentUserName;   // uploader’s display name

  final FirebaseFirestore _db;
  final FirebaseStorage _storage;

  HealthRecordsController({
    required this.elderlyUid,
    required this.currentUserUid,
    required this.currentUserName,
    FirebaseFirestore? db,
    FirebaseStorage? storage,
  })  : _db = db ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  /// Resolve elder uid for a given logged-in user profile.
  /// - elderly: return self.uid
  /// - caregiver: return first from Account/{uid}.elderlyIds (if any)
  static Future<String?> resolveElderUidFor(UserProfile me) async {
    if (me.userType == 'elderly') return me.uid;

    // caregiver
    final doc = await FirebaseFirestore.instance.collection('Account').doc(me.uid).get();
    final data = doc.data() ?? {};
    final list = _asStringList(data['elderlyIds']);
    if (list.isNotEmpty) return list.first;

    // Legacy fallbacks (if present in your DB)
    final legacySingle = (data['elderlyId'] as String?)?.trim();
    if (legacySingle != null && legacySingle.isNotEmpty) return legacySingle;

    final legacyMany = _asStringList(data['linkedElderlyIds']);
    if (legacyMany.isNotEmpty) return legacyMany.first;

    return null;
  }

  /// Account/{elderUid}/health_records
  Stream<List<HealthRecord>> recordsStream() {
    return _db
        .collection('Account')
        .doc(elderlyUid)
        .collection('health_records')
        .orderBy('documentDate', descending: true)
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (snap, _) => snap.data() ?? {},
          toFirestore: (data, _) => data,
        )
        .snapshots()
        .map((snap) => snap.docs.map(HealthRecord.fromDoc).toList());
  }

  /// Upload documents (creates docs under Account/{elderUid}/health_records).
  /// Your rules allow CREATE when isOwnerOrLinked(elderUid) is true.
  Future<bool> uploadRecords({
    required String recordName,
    required String recordType,
    required DateTime documentDate,
    required List<File> files,
  }) async {
    if (files.isEmpty) return false;

    final col = _db.collection('Account').doc(elderlyUid).collection('health_records');

    try {
      for (final file in files) {
        final name = file.path.split('/').last;
        final storagePath = 'health_records/$elderlyUid/${DateTime.now().millisecondsSinceEpoch}_$name';
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
          'uploadedByUid': currentUserUid,
          'uploadedByName': currentUserName,
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
