import 'package:google_sign_in/google_sign_in.dart';
import 'api_client.dart';

class AuthService {
  // ── Session state ─────────────────────────────────────────────
  Future<bool> get isLoggedIn => ApiClient.isLoggedIn;

  Future<String?> get currentUserId async {
    final payload = await ApiClient.getTokenPayload();
    return payload?['id'] as String?;
  }

  Future<String?> get currentUserEmail async {
    final payload = await ApiClient.getTokenPayload();
    return payload?['email'] as String?;
  }

  // ── Sign up ───────────────────────────────────────────────────
  Future<String?> signUpWithEmail({
    required String email,
    required String password,
    String? fullName,
  }) async {
    final res = await ApiClient.post('/api/auth/register', {
      'email': email,
      'password': password,
      if (fullName != null) 'full_name': fullName,
    }, auth: false);
    if (!res.isSuccess) return res.error;
    await ApiClient.saveTokens(
      res.data!['access_token'] as String,
      res.data!['refresh_token'] as String?,
    );
    return null;
  }

  // ── Login ─────────────────────────────────────────────────────
  Future<String?> loginWithEmail({
    required String email,
    required String password,
  }) async {
    final res = await ApiClient.post('/api/auth/login', {
      'email': email,
      'password': password,
    }, auth: false);
    if (!res.isSuccess) return res.error;
    await ApiClient.saveTokens(
      res.data!['access_token'] as String,
      res.data!['refresh_token'] as String?,
    );
    return null;
  }

  // ── Reset password ───────────────────────────────────────────
  Future<String?> resetPassword({required String email}) async {
    final res = await ApiClient.post(
      '/api/auth/forgot-password',
      {'email': email},
      auth: false,
    );
    if (!res.isSuccess) return res.error;
    return null;
  }

  // ── Google Sign-In ───────────────────────────────────────────
  // Uses the standalone google_sign_in package (no Firebase Auth).
  // Flow: GoogleSignIn().signIn() → get idToken → POST /api/auth/google
  Future<String?> signInWithGoogle({String mode = 'login'}) async {
    try {
      // serverClientId tells google_sign_in to include an ID token
      // signed for the Web OAuth client — this is what the backend verifies.
      // Must match GOOGLE_CLIENT_ID in backend .env
      final googleSignIn = GoogleSignIn(
        clientId: '63800510010-lc2qvk6puch3680vmtirtufbvqa58gsm.apps.googleusercontent.com',
        serverClientId: '63800510010-svlp95uvhl1ot37c9vaummbir065putk.apps.googleusercontent.com',
      );
      // Sign out first so the account picker always appears
      await googleSignIn.signOut();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) return null; // user dismissed — not an error

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final idToken = googleAuth.idToken;
      if (idToken == null) {
        return 'Could not obtain Google ID token. Ensure SHA-1 is configured.';
      }

      // Exchange Google ID token for Savaan backend JWT
      final res = await ApiClient.post(
        '/api/auth/google',
        {'id_token': idToken, 'mode': mode},
        auth: false,
      );
      if (!res.isSuccess) return res.error;
      await ApiClient.saveTokens(
        res.data!['access_token'] as String,
        res.data!['refresh_token'] as String?,
      );
      return null; // null = success
    } catch (e) {
      return e.toString();
    }
  }

  // ── Sign out ──────────────────────────────────────────────────
  Future<void> signOut() async {
    final refresh = await ApiClient.getRefreshToken();
    if (refresh != null) {
      await ApiClient.post('/api/auth/logout', {'refresh_token': refresh},
          auth: false);
    }
    await ApiClient.clearTokens();
    // Sign out of Google as well (no-op if user didn't sign in with Google)
    try {
      await GoogleSignIn(
        clientId: '63800510010-lc2qvk6puch3680vmtirtufbvqa58gsm.apps.googleusercontent.com',
        serverClientId: '63800510010-svlp95uvhl1ot37c9vaummbir065putk.apps.googleusercontent.com',
      ).signOut();
    } catch (_) {}
  }
}
