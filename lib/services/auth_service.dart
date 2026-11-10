import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Represents an authenticated user profile (supports both Firebase and verified OTP sessions)
class AppUserProfile {
  final String uid;
  final String? email;
  final String? displayName;
  final String? photoURL;

  const AppUserProfile({
    required this.uid,
    this.email,
    this.displayName,
    this.photoURL,
  });

  factory AppUserProfile.fromFirebaseUser(User user) {
    return AppUserProfile(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
      photoURL: user.photoURL,
    );
  }

  factory AppUserProfile.fromJson(Map<String, dynamic> json) {
    return AppUserProfile(
      uid: json['uid'] as String? ?? '',
      email: json['email'] as String?,
      displayName: json['displayName'] as String?,
      photoURL: json['photoURL'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'email': email,
        'displayName': displayName,
        'photoURL': photoURL,
      };
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _kLocalUserKey = 'flowtake_active_user_session';
  final StreamController<AppUserProfile?> _authStateController =
      StreamController<AppUserProfile?>.broadcast();

  AuthService() {
    _initAuthState();
  }

  Future<void> _initAuthState() async {
    // Listen to Firebase native auth changes
    _auth.authStateChanges().listen((user) async {
      if (user != null) {
        final profile = AppUserProfile.fromFirebaseUser(user);
        await _saveLocalSession(profile);
        _authStateController.add(profile);
      } else {
        // Check if there is a verified OTP session stored locally
        final local = await _loadLocalSession();
        _authStateController.add(local);
      }
    });
  }

  Stream<AppUserProfile?> get appAuthStateChanges =>
      _authStateController.stream;

  AppUserProfile? get currentProfile {
    if (_auth.currentUser != null) {
      return AppUserProfile.fromFirebaseUser(_auth.currentUser!);
    }
    return null;
  }

  Future<void> _saveLocalSession(AppUserProfile profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kLocalUserKey, jsonEncode(profile.toJson()));
    } catch (e) {
      debugPrint('Local session save error: $e');
    }
  }

  Future<AppUserProfile?> _loadLocalSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_kLocalUserKey);
      if (str != null && str.isNotEmpty) {
        final data = jsonDecode(str) as Map<String, dynamic>;
        return AppUserProfile.fromJson(data);
      }
    } catch (e) {
      debugPrint('Local session load error: $e');
    }
    return null;
  }

  Future<void> _clearLocalSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kLocalUserKey);
    } catch (e) {
      debugPrint('Local session clear error: $e');
    }
  }

  /// Sign in with Google
  Future<UserCredential> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw FirebaseAuthException(
          code: 'ERROR_ABORTED_BY_USER',
          message: 'Google sign-in was cancelled by the user.',
        );
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);

      // Create or update user profile in Firestore
      if (userCredential.user != null) {
        final profile = AppUserProfile.fromFirebaseUser(userCredential.user!);
        await _saveLocalSession(profile);
        _authStateController.add(profile);
        await _syncUserProfile(profile.uid, email: profile.email, displayName: profile.displayName, photoURL: profile.photoURL);
      }

      return userCredential;
    } catch (e) {
      debugPrint('Google Sign-In error: $e');
      rethrow;
    }
  }

  /// Production Next.js Resend OTP backend URL
  static const String _backendUrl = 'https://otp-generator-bice.vercel.app';

  /// Request 6-digit Email OTP delivered via the Next.js Resend backend
  Future<void> sendEmailOtp(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    try {
      final uri = Uri.parse('$_backendUrl/api/auth/request-otp');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': cleanEmail}),
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          debugPrint('[FlowTake Auth] OTP successfully dispatched to $cleanEmail');
          return;
        } else {
          throw Exception(data['error'] ?? 'Server error');
        }
      } else if (response.statusCode == 429) {
        final data = jsonDecode(response.body);
        throw Exception(data['error'] ?? 'Too many attempts. Please wait before retrying.');
      } else {
        try {
          final data = jsonDecode(response.body);
          throw Exception(data['error'] ?? 'Server responded with status ${response.statusCode}');
        } catch (e) {
          if (e is Exception) rethrow;
          throw Exception('Server error (${response.statusCode})');
        }
      }
    } catch (e) {
      final errStr = e.toString().replaceAll('Exception: ', '');
      throw Exception(errStr);
    }
  }

  /// Verify 6-digit Email OTP via the backend and establish authenticated app session
  Future<AppUserProfile> verifyEmailOtp(String email, String otp) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanOtp = otp.trim();

    try {
      final uri = Uri.parse('$_backendUrl/api/auth/verify-otp');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': cleanEmail, 'otp': cleanOtp}),
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final userJson = data['user'] as Map<String, dynamic>?;
          final uid = userJson?['uid'] as String? ??
              'usr_${cleanEmail.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}';
          final name = cleanEmail.split('@')[0];

          final profile = AppUserProfile(
            uid: uid,
            email: cleanEmail,
            displayName: name,
          );

          // Save session locally for persistence
          await _saveLocalSession(profile);
          _authStateController.add(profile);

          // Non-blocking Firestore sync (doesn't stall screen navigation if Firestore isn't provisioned)
          unawaited(_syncUserProfile(profile.uid, email: profile.email, displayName: profile.displayName));

          return profile;
        } else {
          throw Exception(data['error'] ?? 'Verification failed.');
        }
      } else if (response.statusCode == 400 ||
          response.statusCode == 409 ||
          response.statusCode == 410 ||
          response.statusCode == 429) {
        try {
          final data = jsonDecode(response.body);
          throw Exception(data['error'] ?? 'Verification rejected by server.');
        } catch (e) {
          if (e is Exception) rethrow;
          throw Exception('Verification failed (${response.statusCode})');
        }
      } else {
        try {
          final data = jsonDecode(response.body);
          throw Exception(data['error'] ?? 'Server error (${response.statusCode})');
        } catch (e) {
          if (e is Exception) rethrow;
          throw Exception('Verification failed (${response.statusCode})');
        }
      }
    } catch (e) {
      final errStr = e.toString().replaceAll('Exception: ', '');
      throw Exception(errStr);
    }
  }

  /// Sync user profile into Firestore if available
  Future<void> _syncUserProfile(
    String uid, {
    String? email,
    String? displayName,
    String? photoURL,
  }) async {
    try {
      final userEmail = email ?? '';
      final docRef = _firestore.collection('users').doc(uid);
      await docRef.set({
        'uid': uid,
        'email': userEmail,
        'displayName': displayName ?? (userEmail.isNotEmpty ? userEmail.split('@')[0] : 'User'),
        'photoURL': photoURL,
        'lastLoginAt': FieldValue.serverTimestamp(),
        'authProvider': 'email_otp',
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Firestore profile sync note: $e');
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await _clearLocalSession();
      _authStateController.add(null);
      await Future.wait([
        _auth.signOut(),
        _googleSignIn.signOut(),
      ]);
    } catch (e) {
      debugPrint('Sign-out error: $e');
    }
  }

  void dispose() {
    _authStateController.close();
  }
}
