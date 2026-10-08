import 'package:firebase_auth/firebase_auth.dart' as firebase;

class CareUser {
  const CareUser({required this.id, required this.email, this.displayName});

  final String id;
  final String email;
  final String? displayName;
}

abstract class AuthGateway {
  Stream<CareUser?> get authStateChanges;
  CareUser? get currentUser;

  Future<CareUser> signIn({required String email, required String password});

  Future<CareUser> signUp({
    required String email,
    required String password,
    required String displayName,
  });

  Future<void> signOut();
}

class FirebaseAuthGateway implements AuthGateway {
  FirebaseAuthGateway({firebase.FirebaseAuth? auth})
    : _auth = auth ?? firebase.FirebaseAuth.instance;

  final firebase.FirebaseAuth _auth;

  @override
  Stream<CareUser?> get authStateChanges =>
      _auth.authStateChanges().map(_mapUser);

  @override
  CareUser? get currentUser => _mapUser(_auth.currentUser);

  @override
  Future<CareUser> signIn({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return _requireUser(credential.user);
  }

  @override
  Future<CareUser> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await credential.user?.updateDisplayName(displayName);
    return _requireUser(credential.user);
  }

  @override
  Future<void> signOut() => _auth.signOut();

  CareUser? _mapUser(firebase.User? user) {
    if (user == null) return null;
    return CareUser(
      id: user.uid,
      email: user.email ?? '',
      displayName: user.displayName,
    );
  }

  CareUser _requireUser(firebase.User? user) {
    final mapped = _mapUser(user);
    if (mapped == null) {
      throw StateError('Firebase did not return an authenticated user.');
    }
    return mapped;
  }
}

class FakeAuthGateway implements AuthGateway {
  FakeAuthGateway({CareUser? initialUser}) : _user = initialUser;

  CareUser? _user;

  @override
  Stream<CareUser?> get authStateChanges async* {
    yield _user;
  }

  @override
  CareUser? get currentUser => _user;

  @override
  Future<CareUser> signIn({
    required String email,
    required String password,
  }) async {
    _user = CareUser(id: 'fake-user', email: email);
    return _user!;
  }

  @override
  Future<CareUser> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    _user = CareUser(id: 'fake-user', email: email, displayName: displayName);
    return _user!;
  }

  @override
  Future<void> signOut() async {
    _user = null;
  }
}

String authErrorMessage(Object error) {
  if (error is firebase.FirebaseAuthException) {
    switch (error.code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'The email or password is incorrect.';
      case 'email-already-in-use':
        return 'An account already exists for this email.';
      case 'weak-password':
        return 'Choose a stronger password with at least 6 characters.';
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'network-request-failed':
        return 'Firebase could not verify this Android app. Add the debug SHA-1 and SHA-256 fingerprints in Firebase Console, then reinstall the app.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is disabled. Enable it in the Firebase Console.';
      default:
        return error.message ?? 'Authentication failed. Please try again.';
    }
  }
  return 'Authentication failed. Please try again.';
}
