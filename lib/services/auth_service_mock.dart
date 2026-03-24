class AuthService {
  AuthService._();
  static final instance = AuthService._();

  // Simple mock stream - always null (not signed in)
  Stream<String?> get userChanges async* {
    yield null;
  }

  Future<void> signInWithEmail(String email, String password) async {
    // Simulate network delay and accept any credentials for local development.
    await Future.delayed(const Duration(milliseconds: 400));
    return;
  }

  Future<void> registerWithEmail(String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return;
  }

  Future<void> signOut() async {
    return;
  }
}
