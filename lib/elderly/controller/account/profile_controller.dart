import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';

class ProfileController {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;


  // This method fetches the current user's profile data
  Future<Map<String, dynamic>?> fetchProfile() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    final userDoc = await _db.collection('users').doc(uid).get();
    return userDoc.data();
  }

  // This method fetches the data of the primary linked caregiver
  Future<Map<String, dynamic>?> fetchPrimaryCaregiver() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    final userDoc = await _db.collection('users').doc(uid).get();
    final linkedCaregivers = userDoc.data()?['linkedCaregivers'] as List<dynamic>?;

    if (linkedCaregivers != null && linkedCaregivers.isNotEmpty) {
      final primaryCaregiverId = linkedCaregivers.first;
      final caregiverDoc = await _db.collection('users').doc(primaryCaregiverId).get();
      
      if (caregiverDoc.exists) {
        final data = caregiverDoc.data();
        return {
          'name': data?['displayName'],
          'email': data?['email'],
          'phone': data?['phone'] ?? 'N/A',
        };
      }
    }
    return null;
  }

  Future<void> updateProfile(Map<String, dynamic> data) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      // Handle the case where the user is not authenticated
      throw Exception("User not authenticated.");
    }
    await _db.collection('users').doc(uid).update(data);
  }

  Future<String> uploadProfilePicture(File imageFile) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw Exception("User not authenticated.");
    }
    
    // Create a unique file path for the user's profile picture
    final storageRef = _storage.ref().child('profile_pictures/$uid.jpg');
    
    // Upload the file to Firebase Storage
    final uploadTask = storageRef.putFile(imageFile);
    
    // Wait for the upload to complete
    final snapshot = await uploadTask.whenComplete(() {});
    
    // Get the public download URL and return it
    return await snapshot.ref.getDownloadURL();
  }
}