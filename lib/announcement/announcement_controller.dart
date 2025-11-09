import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/announcement.dart';

class AnnouncementController {
  final _col = FirebaseFirestore.instance.collection('Announcements');


  Future<List<Announcement>> fetchAll() async {
    final qs = await _col.orderBy('createdAt', descending: true).get();
    return qs.docs.map((d) => Announcement.fromDoc(d)).toList();
  }


  Future<List<Announcement>> fetchForUserType(String userType) async {

    final all = await fetchAll();
    final lower = userType.trim().toLowerCase();
    return all.where((a) {
      final groups = a.userGroups.map((g) => g.trim().toLowerCase()).toList();
      final isAll = groups.any((g) => g == 'all users');
      final isMatch = groups.contains(lower);
      return isAll || isMatch;
    }).toList();
  }


  Future<int> unreadCount(String uid, String userType) async {
    final list = await fetchForUserType(userType);
    return list.where((a) => !(a.readBy[uid] == true)).length;
  }


  Future<void> markRead(String uid, String announcementId) async {
    await _col.doc(announcementId).set({
      'readBy': {uid: true}
    }, SetOptions(merge: true));
  }

  Stream<List<Announcement>> streamForUserType(String userType) {
    return _col.orderBy('createdAt', descending: true).snapshots().map((snap) {
      final mapped = snap.docs.map((d) => Announcement.fromDoc(d)).toList();
      final lower = userType.trim().toLowerCase();
      return mapped.where((a) {
        final groups = a.userGroups.map((g) => g.trim().toLowerCase()).toList();
        return groups.contains('all users') || groups.contains(lower);
      }).toList();
    });
  }
}
