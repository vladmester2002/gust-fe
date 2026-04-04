import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class SocialSignInResult {
  const SocialSignInResult({
    required this.idToken,
    this.email,
    this.displayName,
  });

  final String idToken;
  final String? email;
  final String? displayName;
}

class FirebaseAuthService {
  FirebaseAuthService({
    FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn();

  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;

  Future<SocialSignInResult> signInWithGoogle() async {
    UserCredential credential;
    if (kIsWeb) {
      credential = await _firebaseAuth.signInWithPopup(GoogleAuthProvider());
    } else {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw Exception('Google sign-in was cancelled.');
      }
      final googleAuth = await googleUser.authentication;
      final authCredential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      credential = await _firebaseAuth.signInWithCredential(authCredential);
    }

    final user = credential.user;
    if (user == null) {
      throw Exception('Unable to fetch Google user profile.');
    }
    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw Exception('Firebase did not return an ID token.');
    }
    return SocialSignInResult(
      idToken: token,
      email: user.email,
      displayName: user.displayName,
    );
  }

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
    if (!kIsWeb) {
      await _googleSignIn.signOut();
    }
  }

  Future<SocialSignInResult> signInAnonymously() async {
    final credential = await _firebaseAuth.signInAnonymously();
    final user = credential.user;
    if (user == null) {
      throw Exception('Unable to create anonymous Firebase session.');
    }
    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw Exception('Firebase did not return an ID token.');
    }
    return SocialSignInResult(
      idToken: token,
      email: user.email,
      displayName: user.displayName,
    );
  }

  Future<SocialSignInResult?> currentAnonymousUser() async {
    final current = _firebaseAuth.currentUser;
    if (current == null || !current.isAnonymous) {
      return null;
    }
    final token = await current.getIdToken(true);
    if (token == null || token.isEmpty) {
      return null;
    }
    return SocialSignInResult(
      idToken: token,
      email: current.email,
      displayName: current.displayName,
    );
  }

  Future<SocialSignInResult> registerWithEmail(
      {required String email, required String password}) async {
    final credential = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = credential.user;
    if (user == null) {
      throw Exception('Unable to create Firebase account.');
    }
    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw Exception('Firebase did not return an ID token.');
    }
    return SocialSignInResult(
      idToken: token,
      email: user.email,
      displayName: user.displayName ?? email,
    );
  }

  Future<SocialSignInResult> signInWithEmail(
      {required String email, required String password}) async {
    final credential = await _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = credential.user;
    if (user == null) {
      throw Exception('Unable to sign in with Firebase.');
    }
    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw Exception('Firebase did not return an ID token.');
    }
    return SocialSignInResult(
      idToken: token,
      email: user.email,
      displayName: user.displayName ?? email,
    );
  }

  Future<SocialSignInResult> signInWithYahoo() async {
    UserCredential credential;
    final provider = OAuthProvider('yahoo.com');
    provider.setScopes(<String>['profile', 'email']);
    if (kIsWeb) {
      credential = await _firebaseAuth.signInWithPopup(provider);
    } else {
      credential = await _firebaseAuth.signInWithProvider(provider);
    }
    final user = credential.user;
    if (user == null) {
      throw Exception('Unable to fetch Yahoo user profile.');
    }
    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw Exception('Firebase did not return an ID token.');
    }
    return SocialSignInResult(
      idToken: token,
      email: user.email,
      displayName: user.displayName,
    );
  }
}
