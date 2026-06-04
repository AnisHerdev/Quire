import 'dart:convert';
import 'dart:io' show Platform;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../services/drive_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email', 
      'profile', 
      'https://www.googleapis.com/auth/drive.file',
      'https://www.googleapis.com/auth/drive.appdata'
    ],
  );
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  GoogleSignInAccount? _currentGoogleAccount;
  GoogleSignInAccount? get currentGoogleAccount => _currentGoogleAccount;

  // Linux auth state
  String? _linuxAccessToken;
  String? _linuxRefreshToken;

  String? get accessToken => _linuxAccessToken;
  bool get isSignedIn => Platform.isLinux
      ? _linuxAccessToken != null
      : _currentGoogleAccount != null;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  static const _scopes = [
    'email',
    'profile',
    'https://www.googleapis.com/auth/drive.file',
    'https://www.googleapis.com/auth/drive.appdata',
  ];

  Future<GoogleSignInAccount?> signInSilently() async {
    if (Platform.isLinux) {
      await _linuxSignInSilently();
      return null;
    }
    _currentGoogleAccount = await _googleSignIn.signInSilently();
    return _currentGoogleAccount;
  }

  Future<void> _linuxSignInSilently() async {
    final storedJson = await _storage.read(key: 'linux_credentials');
    if (storedJson == null) return;

    try {
      final credentials = auth.AccessCredentials.fromJson(
        jsonDecode(storedJson) as Map<String, Object?>,
      );
      final clientId = auth.ClientId(
        const String.fromEnvironment('GOOGLE_OAUTH_CLIENT_ID_QUIRE'),
        '',
      );
      final httpClient = http.Client();
      final refreshed = await auth.refreshCredentials(
        clientId,
        credentials,
        httpClient,
      );
      httpClient.close();

      _linuxAccessToken = refreshed.accessToken.data;
      _linuxRefreshToken = refreshed.refreshToken;
      await _storage.write(
        key: 'linux_credentials',
        value: jsonEncode(refreshed.toJson()),
      );
    } catch (e) {
      _linuxAccessToken = null;
      _linuxRefreshToken = null;
      await _storage.delete(key: 'linux_credentials');
    }
  }

  Future<bool> authenticateDriveService(DriveService driveService) async {
    if (Platform.isLinux) {
      if (_linuxAccessToken == null) {
        await _linuxSignInSilently();
      }
      if (_linuxAccessToken != null) {
        driveService.setAccessToken(_linuxAccessToken!);
        return true;
      }
      return false;
    }

    if (_currentGoogleAccount == null) {
      _currentGoogleAccount = await _googleSignIn.signInSilently();
    }
    if (_currentGoogleAccount != null) {
      driveService.setAccount(_currentGoogleAccount);
      return true;
    }
    return false;
  }

  Future<UserCredential?> signInWithGoogle() async {
    if (Platform.isLinux) {
      return _linuxSignInWithGoogle();
    }

    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return null;
      }

      _currentGoogleAccount = googleUser;
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      if (googleAuth.idToken == null) {
        throw Exception(
          'Google Sign-In did not return an ID token. '
          'On Android, this requires a serverClientId in GoogleSignIn config. '
          'Get it from Firebase Console -> Project Settings -> General -> '
          'Web apps -> Web client ID, then uncomment serverClientId in auth_service.dart.',
        );
      }

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

  Future<UserCredential?> _linuxSignInWithGoogle() async {
    try {
      final clientId = auth.ClientId(
        const String.fromEnvironment('GOOGLE_OAUTH_CLIENT_ID_QUIRE'),
        '',
      );

      final client = await auth.clientViaUserConsent(
        clientId,
        _scopes,
        (url) async {
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        },
      );

      final credentials = client.credentials;
      _linuxAccessToken = credentials.accessToken.data;
      _linuxRefreshToken = credentials.refreshToken;
      await _storage.write(
        key: 'linux_credentials',
        value: jsonEncode(credentials.toJson()),
      );

      UserCredential? userCredential;
      if (credentials.idToken != null) {
        final credential = GoogleAuthProvider.credential(
          accessToken: _linuxAccessToken,
          idToken: credentials.idToken,
        );
        userCredential = await _auth.signInWithCredential(credential);
        final user = userCredential.user;
        if (user != null) {
          await _storage.write(key: 'email', value: user.email);
          await _storage.write(key: 'displayName', value: user.displayName);
          await _storage.write(key: 'photoUrl', value: user.photoURL);
        }
      }

      client.close();
      return userCredential;
    } catch (e) {
      print('Error signing in with Google on Linux: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    if (Platform.isLinux) {
      _linuxAccessToken = null;
      _linuxRefreshToken = null;
      await _storage.delete(key: 'linux_credentials');
    } else {
      await _googleSignIn.signOut();
    }
    _currentGoogleAccount = null;
    await _auth.signOut();

    await _storage.delete(key: 'email');
    await _storage.delete(key: 'displayName');
    await _storage.delete(key: 'photoUrl');
  }
}
