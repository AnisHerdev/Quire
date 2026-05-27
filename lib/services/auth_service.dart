import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile', 'https://www.googleapis.com/auth/drive.file'],
  );
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  GoogleSignInAccount? _currentGoogleAccount;
  GoogleSignInAccount? get currentGoogleAccount => _currentGoogleAccount;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return null;
      }

      _currentGoogleAccount = googleUser;
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user != null) {
        await _storage.write(key: 'email', value: user.email);
        await _storage.write(key: 'displayName', value: user.displayName);
        await _storage.write(key: 'photoUrl', value: user.photoURL);
      }

      return userCredential;
    } catch (e) {
      print('Error signing in with Google: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    _currentGoogleAccount = null;
    await _googleSignIn.signOut();
    await _auth.signOut();
    
    await _storage.delete(key: 'email');
    await _storage.delete(key: 'displayName');
    await _storage.delete(key: 'photoUrl');
  }
}
