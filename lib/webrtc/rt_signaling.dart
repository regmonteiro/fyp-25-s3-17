import 'dart:async';
import 'package:firebase_database/firebase_database.dart';

class RTSignaling {
  final DatabaseReference _root;
  final String consultationId;
  final String myself; // uid or email for "by" attribution

  late final DatabaseReference _roomRef;
  late final DatabaseReference _offerRef;
  late final DatabaseReference _answerRef;
  late final DatabaseReference _candidatesRef;

  StreamSubscription<DatabaseEvent>? _offerSub;
  StreamSubscription<DatabaseEvent>? _answerSub;
  StreamSubscription<DatabaseEvent>? _candsChildAddedSub;

  RTSignaling({
    required this.consultationId,
    required this.myself,
    FirebaseDatabase? db,
  }) : _root = (db ?? FirebaseDatabase.instance).ref() {
    _roomRef       = _root.child('consultations/$consultationId/webrtc');
    _offerRef      = _roomRef.child('offer');
    _answerRef     = _roomRef.child('answer');
    _candidatesRef = _roomRef.child('candidates');
  }

  Future<void> clearRoom() async {
    await _roomRef.remove();
  }

  Future<void> postOffer(Map<String, dynamic> desc) async {
    await _offerRef.set({...desc, 'by': myself});
  }

  Future<void> postAnswer(Map<String, dynamic> desc) async {
    await _answerRef.set({...desc, 'by': myself});
  }

  Future<void> postCandidate(Map<String, dynamic> cand) async {
    await _candidatesRef.push().set({...cand, 'by': myself});
  }

  void onOffer(void Function(Map<String, dynamic> data) handler) {
    _offerSub?.cancel();
    _offerSub = _offerRef.onValue.listen((e) {
      final v = e.snapshot.value;
      if (v is Map) handler(Map<String, dynamic>.from(v));
    });
  }

  void onAnswer(void Function(Map<String, dynamic> data) handler) {
    _answerSub?.cancel();
    _answerSub = _answerRef.onValue.listen((e) {
      final v = e.snapshot.value;
      if (v is Map) handler(Map<String, dynamic>.from(v));
    });
  }

  void onCandidate(void Function(Map<String, dynamic> cand) handler) {
    _candsChildAddedSub?.cancel();
    _candsChildAddedSub = _candidatesRef.onChildAdded.listen((e) {
      final v = e.snapshot.value;
      if (v is Map) handler(Map<String, dynamic>.from(v));
    });
  }

  Future<void> dispose() async {
    await _offerSub?.cancel();
    await _answerSub?.cancel();
    await _candsChildAddedSub?.cancel();
  }
}
