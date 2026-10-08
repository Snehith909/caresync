import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

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

class SupabaseAuthGateway implements AuthGateway {
  SupabaseAuthGateway({supabase.SupabaseClient? client})
    : _client = client ?? supabase.Supabase.instance.client;

  final supabase.SupabaseClient _client;

  @override
  Stream<CareUser?> get authStateChanges => _client.auth.onAuthStateChange.map(
    (event) => _mapUser(event.session?.user),
  );

  @override
  CareUser? get currentUser => _mapUser(_client.auth.currentUser);

  @override
  Future<CareUser> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    return _requireUser(response.user);
  }

  @override
  Future<CareUser> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'display_name': displayName},
    );
    return _requireUser(response.user);
  }

  @override
  Future<void> signOut() => _client.auth.signOut();

  CareUser? _mapUser(supabase.User? user) {
    if (user == null) return null;
    return CareUser(
      id: user.id,
      email: user.email ?? '',
      displayName: user.userMetadata?['display_name'] as String?,
    );
  }

  CareUser _requireUser(supabase.User? user) {
    final mapped = _mapUser(user);
    if (mapped == null) {
      throw StateError('Supabase did not return an authenticated user.');
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
  if (error is supabase.AuthException) {
    switch (error.code) {
      case 'invalid_credentials':
      case 'invalid_grant':
        return 'The email or password is incorrect.';
      case 'user_already_exists':
        return 'An account already exists for this email.';
      default:
        return error.message;
    }
  }
  return 'Authentication failed. Please try again.';
}
