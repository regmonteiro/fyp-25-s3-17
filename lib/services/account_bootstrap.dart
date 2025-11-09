import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

String emailKeyFrom(String email) {
  final lower = email.trim().toLowerCase();
  final at = lower.indexOf('@');
  if (at < 0) return lower.replaceAll('.', '_');
  final local  = lower.substring(0, at);
  final domain = lower.substring(at + 1).replaceAll('.', '_');
  return '$local@$domain';
}

bool _ranThisSession = false;

Future<void> upsertAccountMapping() async {
  if (_ranThisSession) return;

  final u  = FirebaseAuth.instance.currentUser;
  if (u == null) return;

  final email = (u.email ?? '').trim().toLowerCase();
  if (email.isEmpty) return;

  final emailKey = emailKeyFrom(email);
  final fs = FirebaseFirestore.instance;

  final batch = fs.batch();

  final accountRef = fs.collection('Account').doc(emailKey);
  batch.set(accountRef, {
    'uid': u.uid,
    'email': email,
  }, SetOptions(merge: true));

  final byUidRef = fs.collection('AccountByUid').doc(u.uid);
  batch.set(byUidRef, {
    'emailKey': emailKey,
  }, SetOptions(merge: true));

  final byEmailKeyRef = fs.collection('AccountByEmailKey').doc(emailKey);
  batch.set(byEmailKeyRef, {
    'uid': u.uid,
  }, SetOptions(merge: true));

  await batch.commit();
  _ranThisSession = true;
}

Future<void> verifyReminderAccess() async {
  final u = FirebaseAuth.instance.currentUser;
  print('AUTH UID=${u?.uid} email=${u?.email}');

  final email = (u?.email ?? '').trim().toLowerCase();
  final k = emailKeyFrom(email);
  final fs = FirebaseFirestore.instance;

  final byKey = await fs.collection('AccountByEmailKey').doc(k).get();
  final byUid = await fs.collection('AccountByUid').doc(u!.uid).get();
  final acct  = await fs.collection('Account').doc(k).get();

  print('AccountByEmailKey[$k].uid = ${byKey.data()?['uid']}');
  print('AccountByUid[${u.uid}].emailKey = ${byUid.data()?['emailKey']}');
  print('Account[$k].uid = ${acct.data()?['uid']}');

  try {
    await fs.collection('reminders').doc(k).set({'_ping': DateTime.now().toIso8601String()}, SetOptions(merge: true));
    print('reminders/$k write OK');
  } catch (e) {
    print('reminders/$k write FAILED: $e');
  }
}

