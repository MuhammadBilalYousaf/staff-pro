import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:staffpro/core/errors/app_exception.dart';
import 'package:staffpro/firebase_options.dart';

class FirebaseAuthService {
  FirebaseAuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  User? get currentUser => _auth.currentUser;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  Future<UserCredential> signIn(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapAuthError(e));
    }
  }

  Future<UserCredential> signUp(String email, String password) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapAuthError(e));
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<void> changePassword({
    required String email,
    required String current,
    required String next,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw AuthException('Please sign in to continue.');
    try {
      final cred = EmailAuthProvider.credential(email: email.trim().toLowerCase(), password: current);
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(next);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapAuthError(e));
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim().toLowerCase());
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapAuthError(e));
    }
  }

  /// Creates an Auth user via Identity Toolkit REST so the signed-in admin
  /// session (especially on web) is never replaced by a secondary Auth app.
  Future<String> createAuthUser({
    required String email,
    required String password,
  }) async {
    final apiKey = DefaultFirebaseOptions.currentPlatform.apiKey;
    final uri = Uri.parse(
      'https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$apiKey',
    );
    final response = await http.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email.trim().toLowerCase(),
        'password': password,
        'returnSecureToken': false,
      }),
    );
    final body = jsonDecode(response.body);
    if (body is! Map) {
      throw AuthException('Failed to create authentication account.');
    }
    final map = Map<String, dynamic>.from(body);
    if (response.statusCode >= 400) {
      final err = map['error'];
      final message = err is Map ? err['message']?.toString() : null;
      throw AuthException(_mapRestError(message));
    }
    final localId = map['localId']?.toString();
    if (localId == null || localId.isEmpty) {
      throw AuthException('Failed to create authentication account.');
    }
    return localId;
  }

  String _mapRestError(String? message) {
    switch (message) {
      case 'EMAIL_EXISTS':
        return 'An account with this email already exists.';
      case 'INVALID_EMAIL':
        return 'Invalid email address.';
      case 'WEAK_PASSWORD':
        return 'Password is too weak. Use at least 6 characters.';
      case 'TOO_MANY_ATTEMPTS_TRY_LATER':
        return 'Too many attempts. Try again later.';
      default:
        return message == null || message.isEmpty
            ? 'Authentication failed.'
            : message;
    }
  }

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Invalid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Invalid email or password.';
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      case 'requires-recent-login':
        return 'Please sign in again before changing your password.';
      default:
        return e.message ?? 'Authentication failed.';
    }
  }
}
