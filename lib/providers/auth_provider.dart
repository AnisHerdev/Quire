import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

// Provider for the AuthService
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

// State for the AuthNotifier
class AuthState {
  final bool isLoading;
  final UserModel? user;
  
  const AuthState({this.isLoading = false, this.user});
  
  bool get isAuthenticated => user != null && user!.uid.isNotEmpty;
}

// Notifier to manage authentication state
class AuthNotifier extends Notifier<AuthState> {
  late final AuthService _authService;
  StreamSubscription? _subscription;

  @override
  AuthState build() {
    _authService = ref.watch(authServiceProvider);
    
    _subscription = _authService.authStateChanges.listen((firebaseUser) {
      state = AuthState(
        isLoading: false,
        user: firebaseUser != null ? UserModel.fromFirebaseUser(firebaseUser) : null,
      );
    });

    ref.onDispose(() {
      _subscription?.cancel();
    });

    // Check initial current user synchronously
    final firebaseUser = _authService.currentUser;
    if (firebaseUser != null) {
      return AuthState(
        isLoading: false,
        user: UserModel.fromFirebaseUser(firebaseUser),
      );
    }

    return const AuthState(
      isLoading: false,
      user: null,
    );
  }

  Future<void> signInWithGoogle() async {
    state = AuthState(isLoading: true, user: state.user);
    try {
      final userModel = await _authService.signInWithGoogle();
      if (userModel == null) {
        // Canceled
        state = const AuthState(isLoading: false, user: null);
      } else {
        state = AuthState(isLoading: false, user: userModel);
      }
    } catch (e) {
      state = const AuthState(isLoading: false, user: null);
      rethrow;
    }
  }

  Future<void> signOut() async {
    state = AuthState(isLoading: true, user: state.user);
    await _authService.signOut();
    state = const AuthState(isLoading: false, user: null);
  }
}

// Provider for the AuthNotifier
final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

