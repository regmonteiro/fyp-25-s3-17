import 'package:cloud_firestore/cloud_firestore.dart';

class Activity {
  final String id;
  final String title;
  final String summary;
  final String category;
  final String difficulty;
  final String duration;
  final String image;
  final String description;
  final bool requiresAuth;
  final List<String> tags;

  Activity({
    required this.id,
    required this.title,
    required this.summary,
    required this.category,
    required this.difficulty,
    required this.duration,
    required this.image,
    required this.description,
    required this.requiresAuth,
    required this.tags,
  });

  factory Activity.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return Activity(
      id: doc.id,
      title: (d['title'] ?? '').toString(),
      summary: (d['summary'] ?? '').toString(),
      category: (d['category'] ?? '').toString(),
      difficulty: (d['difficulty'] ?? '').toString(),
      duration: (d['duration'] ?? '').toString(),
      image: (d['image'] ?? '').toString(),
      description: (d['description'] ?? '').toString(),
      requiresAuth: (d['requiresAuth'] ?? false) == true,
      tags: (d['tags'] is List)
          ? (d['tags'] as List).map((e) => e.toString()).toList()
          : const <String>[],
    );
  }
}

class ActivityRegistration {
  final String registrationId;
  final String activityId;
  final String activityTitle;
  final String activityImage;
  final String date; // "yyyy-MM-dd"
  final String time; // "HH:mm"
  final String status;
  final DateTime? createdAt;

  ActivityRegistration({
    required this.registrationId,
    required this.activityId,
    required this.activityTitle,
    required this.activityImage,
    required this.date,
    required this.time,
    required this.status,
    required this.createdAt,
  });

  bool get isPast {
    final dt = DateTime.tryParse('${date}T${time}');
    return dt == null ? false : dt.isBefore(DateTime.now());
  }
}

class ActivitiesService {
  final _db = FirebaseFirestore.instance;

  /// Fetch all activities in `/Activities/*`
  Future<List<Activity>> fetchAllActivities() async {
    final snap = await _db.collection('Activities').get();
    return snap.docs.map((d) => Activity.fromDoc(d)).toList();
  }

  /// Register the user (by email) into `/Activities/{id}/registrations`
  Future<String> registerForActivity({
    required String activityId,
    required String userEmail,
    required String date, // "yyyy-MM-dd"
    required String time, // "HH:mm"
  }) async {
    // sanity checks
    if (userEmail.trim().isEmpty) {
      throw Exception('User not authenticated. Please log in again.');
    }
    if (date.isEmpty || time.isEmpty) {
      throw Exception('Please select a date and time.');
    }

    // ensure activity exists
    final actRef = _db.collection('Activities').doc(activityId);
    final actDoc = await actRef.get();
    if (!actDoc.exists) {
      throw Exception('Activity not found.');
    }

    // prevent duplicate registration (same activity + same email)
    final dup = await actRef
        .collection('registrations')
        .where('registeredEmail', isEqualTo: userEmail)
        .limit(1)
        .get();
    if (dup.docs.isNotEmpty) {
      throw Exception('You are already registered for this activity.');
    }

    await actRef.collection('registrations').add({
      'registeredEmail': userEmail,
      'date': date,
      'time': time,
      'timestamp': DateTime.now().toIso8601String(),
      'status': 'confirmed',
    });

    final title = (actDoc.data() ?? {})['title'] ?? 'Activity';
    return 'Successfully registered for "$title" on $date at $time.';
  }

  /// Get all registrations for this user, across all activities
  Future<List<ActivityRegistration>> getUserRegistrations(String userEmail) async {
    if (userEmail.trim().isEmpty) return [];

    // query all /registrations subcollections
    final q = await _db
        .collectionGroup('registrations')
        .where('registeredEmail', isEqualTo: userEmail)
        .get();

    final List<ActivityRegistration> out = [];
    for (final regDoc in q.docs) {
      final actRef = regDoc.reference.parent.parent as DocumentReference<Map<String, dynamic>>?;
      if (actRef == null) continue;

      final actSnap = await actRef.get();
      final act = actSnap.data() ?? {};

      out.add(
        ActivityRegistration(
          registrationId: regDoc.id,
          activityId: actRef.id,
          activityTitle: (act['title'] ?? 'Unknown Activity').toString(),
          activityImage: (act['image'] ?? '').toString(),
          date: (regDoc.data()['date'] ?? '').toString(),
          time: (regDoc.data()['time'] ?? '').toString(),
          status: (regDoc.data()['status'] ?? 'confirmed').toString(),
          createdAt: DateTime.tryParse((regDoc.data()['timestamp'] ?? '').toString()),
        ),
      );
    }
    // optional: sort by upcoming first
    out.sort((a, b) {
      final ad = DateTime.tryParse('${a.date}T${a.time}') ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bd = DateTime.tryParse('${b.date}T${b.time}') ?? DateTime.fromMillisecondsSinceEpoch(0);
      return ad.compareTo(bd);
    });
    return out;
  }

  /// Cancel a registration (delete the registration document)
  Future<void> cancelRegistration({
    required String activityId,
    required String registrationId,
  }) async {
    await _db
        .collection('Activities')
        .doc(activityId)
        .collection('registrations')
        .doc(registrationId)
        .delete();
  }
}
