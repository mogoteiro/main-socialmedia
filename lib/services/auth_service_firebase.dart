import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  AuthService._();
  static final instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> get userChanges => _auth.authStateChanges();

  Future<User?> signInWithEmail(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return cred.user;
  }

  /// Registers a user and creates a Firestore profile document.
  Future<User?> registerWithEmail(String email, String password, {String? displayName, String? username, String? dateOfBirth}) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = cred.user;
    if (user != null) {
      // Update FirebaseAuth display name if provided
      if (displayName != null && displayName.isNotEmpty) {
        await user.updateDisplayName(displayName);
        await user.reload();
      }

      // create a Firestore document for the user
      final doc = _firestore.collection('users').doc(user.uid);
      await doc.set({
        'email': user.email,
        'displayName': displayName ?? user.displayName ?? '',
        'username': username ?? '',
        'username_lc': (username ?? '').toLowerCase(),
        'dateOfBirth': dateOfBirth ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    return user;
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<void> updateDisplayName(String displayName) async {
    final user = _auth.currentUser;
    if (user == null) throw FirebaseAuthException(code: 'no-current-user', message: 'No user signed in');
    await user.updateDisplayName(displayName);
    await user.reload();
    // keep Firestore profile in sync
    try {
      await _firestore.collection('users').doc(user.uid).update({'displayName': displayName});
    } catch (_) {}
  }

  Future<void> updateUsername(String username) async {
    final user = _auth.currentUser;
    if (user == null) throw FirebaseAuthException(code: 'no-current-user', message: 'No user signed in');
    // There is no dedicated 'username' field in FirebaseAuth; store it by embedding into displayName
    final currentDisplay = user.displayName ?? '';
    final newDisplay = currentDisplay.isNotEmpty ? '$currentDisplay (@$username)' : '@$username';
    await user.updateDisplayName(newDisplay);
    await user.reload();
    try {
      await _firestore.collection('users').doc(user.uid).update({'username': username, 'username_lc': username.toLowerCase()});
    } catch (_) {}
  }

  Future<void> changePassword(String currentPassword, String newPassword) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) throw FirebaseAuthException(code: 'no-current-user', message: 'No user signed in');
    final cred = EmailAuthProvider.credential(email: user.email!, password: currentPassword);
    await user.reauthenticateWithCredential(cred);
    await user.updatePassword(newPassword);
  }
}
