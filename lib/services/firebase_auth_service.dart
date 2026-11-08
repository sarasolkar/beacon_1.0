import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_profile.dart';
import 'auth_service.dart';

class FirebaseAuthService implements AuthService {
  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _googleSignIn;
  Future<void>? _googleSignInInitialization;

  FirebaseAuthService({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
    GoogleSignIn? googleSignIn,
  }) : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  @override
  Stream<UserProfile?> get authStateChanges {
    return _firebaseAuth.authStateChanges().map(_mapFirebaseUser);
  }

  @override
  UserProfile? get currentUser => _mapFirebaseUser(_firebaseAuth.currentUser);

  @override
  bool get isAuthenticated => _firebaseAuth.currentUser != null;

  UserProfile? _mapFirebaseUser(User? user) {
    if (user == null) return null;
    return UserProfile(
      uid: user.uid,
      displayName:
          user.displayName ?? user.email?.split('@').first ?? 'Explorer',
      email: user.email ?? '',
      photoUrl: user.photoURL,
      isAnonymous: user.isAnonymous,
    );
  }

  @override
  Future<UserProfile?> signInWithGoogle() async {
    try {
      final UserCredential credential;
      if (kIsWeb) {
        credential = await _firebaseAuth.signInWithPopup(GoogleAuthProvider());
      } else {
        await _initializeGoogleSignIn();
        final googleUser = await _googleSignIn.authenticate();
        final googleAuth = googleUser.authentication;
        final oauthCredential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
        );
        credential = await _firebaseAuth.signInWithCredential(oauthCredential);
      }

      final profile = _mapFirebaseUser(credential.user);
      if (profile != null) await _syncProfileAfterAuthentication(profile);
      return profile;
    } on ProfileSyncException {
      rethrow;
    } on FirebaseAuthException catch (e) {
      if (kIsWeb &&
          (e.code == 'popup-closed-by-user' ||
              e.code == 'cancelled-popup-request')) {
        return null;
      }
      throw _handleAuthException(e);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      throw 'Google Sign-In failed: ${e.description ?? e.code.name}';
    } on FirebaseException catch (e) {
      throw 'Google Sign-In failed: ${e.message ?? e.code}';
    } catch (e) {
      throw 'Google Sign-In failed: $e';
    }
  }

  @override
  Future<UserProfile?> signInAnonymously({String? displayName}) async {
    try {
      final credential = await _firebaseAuth.signInAnonymously();
      final resolvedName = displayName?.trim().isNotEmpty == true
          ? displayName!.trim()
          : 'Explorer ${credential.user?.uid.substring(0, 5) ?? ''}';

      if (credential.user != null) {
        await credential.user!.updateDisplayName(resolvedName);
      }

      final profile = UserProfile(
        uid: credential.user!.uid,
        displayName: resolvedName,
        email: '',
        isAnonymous: true,
      );

      await _syncProfileAfterAuthentication(profile);
      return profile;
    } on ProfileSyncException {
      rethrow;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'Guest Sign-In failed: $e';
    }
  }

  @override
  Future<UserProfile?> signInWithEmail(String email, String password) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final profile = _mapFirebaseUser(credential.user);
      if (profile != null) {
        await _syncProfileAfterAuthentication(profile);
      }
      return profile;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  @override
  Future<UserProfile?> signUpWithEmail(
    String email,
    String password,
    String displayName,
  ) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      // Best-effort display name update — does not block account creation.
      final resolvedName = displayName.trim().isNotEmpty
          ? displayName.trim()
          : email.trim().split('@').first;
      if (credential.user != null) {
        try {
          await credential.user!.updateDisplayName(resolvedName);
        } catch (_) {
          // Non-fatal: the Firebase account exists even if the display name
          // update fails. We'll use the resolved name from local state.
        }
      }

      final profile = UserProfile(
        uid: credential.user!.uid,
        displayName: resolvedName,
        email: email.trim(),
        photoUrl: credential.user?.photoURL,
      );

      await _syncProfileAfterAuthentication(profile);
      return profile;
    } on ProfileSyncException {
      rethrow;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'Account creation failed: $e';
    }
  }

  @override
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
    if (!kIsWeb) {
      await _initializeGoogleSignIn();
      await _googleSignIn.signOut();
    }
  }

  Future<void> _initializeGoogleSignIn() =>
      _googleSignInInitialization ??= _googleSignIn.initialize();

  @override
  Future<void> syncUserProfile(UserProfile user) async {
    final docRef = _firestore.collection('users').doc(user.uid);
    await docRef.set({
      'uid': user.uid,
      'displayName': user.displayName,
      'email': user.email,
      'photoUrl': user.photoUrl,
      'isAnonymous': user.isAnonymous,
      'lastSeen': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _syncProfileAfterAuthentication(UserProfile user) async {
    try {
      await syncUserProfile(user).timeout(const Duration(seconds: 10));
    } catch (error) {
      throw ProfileSyncException(user: user, cause: error);
    }
  }

  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email address.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'operation-not-allowed':
        return 'This sign-in method is disabled in Firebase Console. Enable it under Authentication > Sign-in method.';
      case 'configuration-not-found':
        return 'Firebase Authentication is not configured for this project. Enable Email/Password in Firebase Console under Authentication > Sign-in method.';
      case 'invalid-api-key':
        return 'Firebase rejected this app configuration. Verify the Web app API key in Firebase Console > Project settings and lib/firebase_options.dart.';
      case 'invalid-credential':
        return 'The email or password is incorrect. Check your details and try again.';
      case 'too-many-requests':
        return 'There have been too many attempts. Wait a moment and try again.';
      case 'unauthorized-domain':
        return 'This web address is not authorized in Firebase Authentication settings.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with this email using another sign-in method. Sign in with that method first.';
      case 'user-disabled':
        return 'This account has been disabled. Contact support for help.';
      case 'network-request-failed':
        return 'Network connection failed. Please check your internet.';
      default:
        final message = e.message?.trim();
        if (message != null && message.isNotEmpty && message != 'Error') {
          return 'Firebase Authentication error (${e.code}): $message';
        }
        return 'Firebase Authentication error (${e.code}). Check that the '
            'Email/Password provider is enabled in Firebase Console and that '
            'localhost is listed under Authentication > Settings > Authorized domains.';
    }
  }
}
