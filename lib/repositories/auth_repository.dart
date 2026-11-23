import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/exceptions/auth_exception.dart';
import '../core/firebase/firebase_config.dart';
import '../models/erd_models.dart';

// ============================================================================
// AUTHENTICATION REPOSITORY (FIREBASE AUTH + CLOUD FIRESTORE)
// Memantau sesi real-time melalui FirebaseAuth.authStateChanges(), mengelola
// registrasi & login Email/Kata Sandi, menyimpan profil ke users/{uid}, serta
// mencatat perangkat aktif ke users/{uid}/devices/{deviceId}.
// ============================================================================

class AuthRepository {
  static const String _onboardingPrefKey = 'patungin_has_seen_onboarding';

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  AppUser? _currentUser;
  String _activeFcmToken = 'fcm_token_unregistered';
  bool _hasSeenOnboarding = false;

  AuthRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  AppUser? get currentUser => _currentUser;
  bool get hasSeenOnboarding => _hasSeenOnboarding;
  bool get isUsingEmulator => FirebaseAppConfig.useEmulator;

  /// Muat status onboarding dari penyimpanan lokal perangkat
  Future<void> loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _hasSeenOnboarding = prefs.getBool(_onboardingPrefKey) ?? false;
    } catch (_) {
      _hasSeenOnboarding = false;
    }
  }

  Future<void> markOnboardingComplete() async {
    _hasSeenOnboarding = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_onboardingPrefKey, true);
    } catch (_) {}
  }

  /// Stream real-time perubahan sesi autentikasi dari FirebaseAuth (FR-01)
  Stream<AppUser?> get authStateChanges {
    return _auth.authStateChanges().asyncMap((firebaseUser) async {
      if (firebaseUser == null) {
        _currentUser = null;
        _activeFcmToken = 'fcm_token_unregistered';
        return null;
      }

      final profile = await _fetchOrCreateUserProfile(firebaseUser);
      await _registerDeviceToken(profile.uid);
      _currentUser = profile;
      return profile;
    });
  }

  /// Masuk dengan Email & Kata Sandi via FirebaseAuth
  Future<AppUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
      final fbUser = credential.user;
      if (fbUser == null) {
        throw AppAuthException.fromFirebaseCode('user-not-found');
      }

      final profile = await _fetchOrCreateUserProfile(fbUser);
      await _registerDeviceToken(profile.uid);
      _currentUser = profile;
      return profile;
    } on FirebaseAuthException catch (e) {
      throw AppAuthException.fromFirebaseCode(e.code);
    } on FirebaseException catch (e) {
      throw AppAuthException.fromFirebaseCode(e.code);
    }
  }

  /// Registrasi Akun Baru via FirebaseAuth + simpan profil ke Firestore `users/{uid}`
  Future<AppUser> registerWithEmailAndPassword({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final trimmedName = fullName.trim();

    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
      final fbUser = credential.user;
      if (fbUser == null) {
        throw AppAuthException.fromFirebaseCode('unknown');
      }

      await fbUser.updateDisplayName(trimmedName);

      final newUser = AppUser(
        uid: fbUser.uid,
        fullName: trimmedName,
        email: normalizedEmail,
        photoUrl: fbUser.photoURL ?? '',
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection('users')
          .doc(newUser.uid)
          .set(newUser.toMap(), SetOptions(merge: true));

      await _registerDeviceToken(newUser.uid);
      await markOnboardingComplete();
      _currentUser = newUser;
      return newUser;
    } on FirebaseAuthException catch (e) {
      throw AppAuthException.fromFirebaseCode(e.code);
    } on FirebaseException catch (e) {
      throw AppAuthException.fromFirebaseCode(e.code);
    }
  }

  /// Kirim email reset kata sandi via FirebaseAuth
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim().toLowerCase());
    } on FirebaseAuthException catch (e) {
      throw AppAuthException.fromFirebaseCode(e.code);
    }
  }

  /// Ambil profil pengguna dari koleksi `users/{uid}` atau buat jika belum ada
  Future<AppUser> _fetchOrCreateUserProfile(User fbUser) async {
    final docRef = _firestore.collection('users').doc(fbUser.uid);
    try {
      final snapshot = await docRef.get();
      if (snapshot.exists && snapshot.data() != null) {
        return AppUser.fromMap(snapshot.data()!, docId: fbUser.uid);
      }
    } catch (_) {
      // Fallback jika Firestore sedang tidak dapat dijangkau sesaat
    }

    final fallbackName = (fbUser.displayName ?? '').trim().isNotEmpty
        ? fbUser.displayName!.trim()
        : (fbUser.email ?? 'Pengguna').split('@').first;

    final user = AppUser(
      uid: fbUser.uid,
      fullName: fallbackName,
      email: (fbUser.email ?? '').toLowerCase(),
      photoUrl: fbUser.photoURL ?? '',
      createdAt: fbUser.metadata.creationTime ?? DateTime.now(),
    );

    try {
      await docRef.set(user.toMap(), SetOptions(merge: true));
    } catch (_) {}
    return user;
  }

  /// Catat perangkat aktif pengguna ke `users/{uid}/devices/{deviceId}`
  Future<void> _registerDeviceToken(String uid) async {
    final String platform = kIsWeb
        ? 'web'
        : switch (defaultTargetPlatform) {
            TargetPlatform.android => 'android',
            TargetPlatform.iOS => 'ios',
            _ => 'desktop',
          };
    final deviceId = 'dev_${platform}_active';
    final token =
        'fcm_${FirebaseAppConfig.useEmulator ? 'emulator' : 'live'}_${platform}_${uid.substring(0, uid.length >= 6 ? 6 : uid.length)}';
    _activeFcmToken = token;

    final device = UserDevice(
      deviceId: deviceId,
      userUid: uid,
      fcmToken: token,
      platform: platform,
      updatedAt: DateTime.now(),
    );

    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('devices')
          .doc(deviceId)
          .set(device.toMap(), SetOptions(merge: true));
    } catch (_) {}
  }

  /// Ambil FCM token aktif untuk ditampilkan pada informasi sesi
  String getActiveFcmToken(String uid) => _activeFcmToken;

  Future<void> signOut() async {
    await _auth.signOut();
    _currentUser = null;
    _activeFcmToken = 'fcm_token_unregistered';
  }
}
