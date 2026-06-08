import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'api_client.dart';

class AuthService {
  // Holds the verificationId between sendPhoneOtp() and verifyPhoneOtp() calls.
  // Lives as long as the AuthService instance (i.e., the auth screen state).
  String? _verificationId;

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
    return 'Password reset: please contact support@savaan.com';
  }

  // ── Google Sign-In ───────────────────────────────────────────
  // mode: 'login'  → only allows existing users (returns error if not found)
  // mode: 'signup' → creates account if user does not exist
  //
  // One-time setup (if not done):
  // 1. Enable "Google" sign-in method in Firebase Console → Auth → Sign-in methods
  // 2. Add SHA-1 fingerprint to Firebase project (see instructions in README)
  // 3. Download updated google-services.json → replace android/app/google-services.json
  Future<String?> signInWithGoogle({String mode = 'login'}) async {
    try {
      // Trigger the Google authentication flow
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return null; // user dismissed — not an error

      // Obtain auth details
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a Firebase credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase
      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);
      final idToken = await userCredential.user?.getIdToken();
      if (idToken == null) return 'Could not obtain Firebase token';

      // Exchange Firebase token for Savaan backend JWT
      return await _exchangeFirebaseToken(idToken, mode: mode);
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Google sign-in failed';
    } catch (e) {
      return e.toString();
    }
  }

  // ── Phone OTP — step 1: send OTP ────────────────────────────
  // Prerequisites (one-time Firebase Console setup):
  // 1. Enable "Phone" sign-in method in Firebase Console → Auth → Sign-in methods
  // 2. For testing on emulator, add test phone numbers in Firebase Console
  Future<String?> sendPhoneOtp({required String phone, String mode = 'login'}) async {
    final completer = Completer<String?>();
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        timeout: const Duration(seconds: 60),

        // Auto-verified (Android only, instant SMS interception)
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            final uc =
                await FirebaseAuth.instance.signInWithCredential(credential);
            final idToken = await uc.user?.getIdToken();
            if (idToken != null) {
              await _exchangeFirebaseToken(idToken, mode: mode);
            }
          } catch (_) {}
        },

        // OTP verification failed or quota exceeded
        verificationFailed: (FirebaseAuthException e) {
          if (!completer.isCompleted) {
            // Include the Firebase error code so we can diagnose the root cause
            final code = e.code.isNotEmpty ? '[${e.code}] ' : '';
            final msg  = e.message ?? 'Phone verification failed';
            completer.complete('$code$msg');
          }
        },

        // OTP sent — store verificationId for step 2
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          if (!completer.isCompleted) completer.complete(null); // null = success
        },

        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );

      return await completer.future
          .timeout(const Duration(seconds: 90),
              onTimeout: () => 'Timed out waiting for OTP. Try again.');
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Could not send OTP';
    } catch (e) {
      return e.toString();
    }
  }

  // ── Phone OTP — step 2: verify OTP ──────────────────────────
  // mode: 'login'  → rejects if account not found
  // mode: 'signup' → creates account if not found
  Future<String?> verifyPhoneOtp({
    required String phone,
    required String otp,
    String mode = 'login',
  }) async {
    try {
      if (_verificationId == null) {
        return 'Session expired. Please request a new OTP.';
      }
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );
      final uc = await FirebaseAuth.instance.signInWithCredential(credential);
      final idToken = await uc.user?.getIdToken();
      if (idToken == null) return 'Could not obtain Firebase token';

      return await _exchangeFirebaseToken(idToken, mode: mode);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'invalid-verification-code') {
        return 'Invalid OTP. Please try again.';
      }
      if (e.code == 'session-expired') {
        return 'OTP expired. Please request a new one.';
      }
      return e.message ?? 'OTP verification failed';
    } catch (e) {
      return e.toString();
    }
  }

  // ── Internal: exchange Firebase ID token for Savaan JWT ──────
  // mode is forwarded to the backend to control find-or-create behaviour.
  Future<String?> _exchangeFirebaseToken(String idToken,
      {String mode = 'signup'}) async {
    final res = await ApiClient.post(
      '/api/auth/firebase',
      {'id_token': idToken, 'mode': mode},
      auth: false,
    );
    if (!res.isSuccess) return res.error;
    await ApiClient.saveTokens(
      res.data!['access_token'] as String,
      res.data!['refresh_token'] as String?,
    );
    return null; // null = success
  }

  // ── Sign out ──────────────────────────────────────────────────
  Future<void> signOut() async {
    final refresh = await ApiClient.getRefreshToken();
    if (refresh != null) {
      await ApiClient.post('/api/auth/logout', {'refresh_token': refresh},
          auth: false);
    }
    await ApiClient.clearTokens();
    // Sign out of Firebase and Google as well
    try {
      await FirebaseAuth.instance.signOut();
      await GoogleSignIn().signOut();
    } catch (_) {}
  }
}
