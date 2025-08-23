import 'package:firebase_auth/firebase_auth.dart';

class AuthController {
  final _auth = FirebaseAuth.instance;

  Future<void> changePassword(String currentEmail, String currentPassword, String newPassword) async {
    final user = _auth.currentUser!;
    final cred = EmailAuthProvider.credential(email: currentEmail, password: currentPassword);
    await user.reauthenticateWithCredential(cred);
    await user.updatePassword(newPassword);
  }
}
