import '../models/user_profile.dart';

abstract class AuthService {
  Stream<UserProfile?> get authStateChanges;
  UserProfile? get currentUser;
  bool get isAuthenticated => currentUser != null;

  Future<UserProfile?> signInWithGoogle();
  Future<UserProfile?> signInAnonymously({String? displayName});
  Future<UserProfile?> signInWithEmail(String email, String password);
  Future<UserProfile?> signUpWithEmail(
    String email,
    String password,
    String displayName,
  );
  Future<void> signOut();
  Future<void> syncUserProfile(UserProfile user);
}

class ProfileSyncException implements Exception {
  final UserProfile user;
  final Object cause;

  const ProfileSyncException({required this.user, required this.cause});

  @override
  String toString() => cause.toString();
}
