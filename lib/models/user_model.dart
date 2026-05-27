import 'package:firebase_auth/firebase_auth.dart' as fb_auth;

class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final String photoUrl;

  const UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.photoUrl,
  });

  factory UserModel.fromFirebaseUser(fb_auth.User user) {
    return UserModel(
      uid: user.uid,
      email: user.email ?? '',
      displayName: user.displayName ?? 'Unknown User',
      photoUrl: user.photoURL ?? '',
    );
  }

  factory UserModel.unauthenticated() {
    return const UserModel(
      uid: '',
      email: '',
      displayName: '',
      photoUrl: '',
    );
  }
}
