import 'dart:async';
import '../core/exceptions/auth_exception.dart';
import '../models/erd_models.dart';
import 'mock_realtime_database.dart';

// ============================================================================
// AUTHENTICATION REPOSITORY (FR-01, UFD-1, BAB 6 ANGGOTA 1)
// Memantau sesi real-time dengan Stream, mengelola masuk/daftar (Email & Google),
// dan menyimpan fcm_token ke entitas USER_DEVICES saat login.
// ============================================================================

class AuthRepository {
  final RealtimeDatabaseStore _store = RealtimeDatabaseStore.instance;
  final StreamController<AppUser?> _authStateController =
      StreamController<AppUser?>.broadcast();

  AppUser? _currentUser;
  bool _hasSeenOnboarding = false;

  AuthRepository() {
    // Default masuk sebagai Andi Pratama (Anggota 1 - Group Admin & Bill Creator)
    // agar saat buka aplikasi bisa langsung dieksplorasi atau logout ke UFD-1.
    _currentUser = _store.users['u_andi'];
  }

  AppUser? get currentUser => _currentUser;
  bool get hasSeenOnboarding => _hasSeenOnboarding;

  void markOnboardingComplete() {
    _hasSeenOnboarding = true;
  }

  /// Stream real-time perubahan sesi autentikasi (FR-01)
  Stream<AppUser?> get authStateChanges async* {
    yield _currentUser;
    yield* _authStateController.stream;
  }

  /// Daftar semua pengguna terdaftar (untuk keperluan tampilan profil & demo switch)
  List<AppUser> get allRegisteredUsers => _store.users.values.toList();

  /// Masuk dengan Email & Kata Sandi (FR-01 & UFD-1)
  Future<AppUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 450));
    final normalizedEmail = email.trim().toLowerCase();

    AppUser? matchedUser;
    for (final u in _store.users.values) {
      if (u.email.toLowerCase() == normalizedEmail) {
        matchedUser = u;
        break;
      }
    }

    if (matchedUser == null) {
      throw AppAuthException.fromFirebaseCode('user-not-found');
    }

    final savedPass = _store.userPasswords[normalizedEmail] ?? '123456';
    if (password != savedPass) {
      throw AppAuthException.fromFirebaseCode('invalid-credential');
    }

    await _registerFcmDeviceToken(matchedUser.uid);
    _currentUser = matchedUser;
    _authStateController.add(_currentUser);
    _store.notifyChanges();
    return matchedUser;
  }

  /// Registrasi Akun Baru (FR-01 & UFD-1)
  Future<AppUser> registerWithEmailAndPassword({
    required String fullName,
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final normalizedEmail = email.trim().toLowerCase();

    final exists = _store.users.values.any(
      (u) => u.email.toLowerCase() == normalizedEmail,
    );
    if (exists) {
      throw AppAuthException.fromFirebaseCode('email-already-in-use');
    }

    final uid = 'u_${DateTime.now().millisecondsSinceEpoch}';
    final newUser = AppUser(
      uid: uid,
      fullName: fullName.trim(),
      email: normalizedEmail,
      photoUrl: '',
      createdAt: DateTime.now(),
    );

    _store.users[uid] = newUser;
    _store.userPasswords[normalizedEmail] = password;
    await _registerFcmDeviceToken(uid);

    _currentUser = newUser;
    _authStateController.add(_currentUser);
    _store.notifyChanges();
    return newUser;
  }

  /// Masuk dengan Akun Google (Google Sign-In - FR-01 & UFD-1)
  Future<AppUser> signInWithGoogle() async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final user = _store.users['u_andi']!;
    await _registerFcmDeviceToken(user.uid);
    _currentUser = user;
    _authStateController.add(_currentUser);
    _store.notifyChanges();
    return user;
  }

  /// Fitur Demo/Responsi: Berpindah antar akun (Admin, Creator, Debitur, Non-Anggota)
  /// secara instan untuk mendemonstrasikan RBAC & Multi-Device Real-Time Sync.
  Future<AppUser> switchActiveUserForDemo(String targetUid) async {
    final user = _store.users[targetUid];
    if (user == null) {
      throw AppAuthException.fromFirebaseCode('user-not-found');
    }
    await _registerFcmDeviceToken(user.uid);
    _currentUser = user;
    _authStateController.add(_currentUser);
    _store.notifyChanges();
    return user;
  }

  /// Simpan fcm_token perangkat ke koleksi USER_DEVICES saat login (FR-01, Erd #2)
  Future<void> _registerFcmDeviceToken(String uid) async {
    final deviceId = 'dev_${uid}_active';
    _store.userDevices.removeWhere(
      (d) => d.userUid == uid && d.deviceId == deviceId,
    );
    _store.userDevices.add(
      UserDevice(
        deviceId: deviceId,
        userUid: uid,
        fcmToken: 'fcm_live_${uid}_${DateTime.now().millisecondsSinceEpoch}',
        platform: 'android',
        updatedAt: DateTime.now(),
      ),
    );
  }

  /// Ambil FCM token aktif untuk ditampilkan pada informasi sesi
  String getActiveFcmToken(String uid) {
    final matches = _store.userDevices.where((d) => d.userUid == uid);
    if (matches.isEmpty) return 'fcm_token_unregistered';
    return matches.last.fcmToken;
  }

  Future<void> signOut() async {
    _currentUser = null;
    _authStateController.add(null);
    _store.notifyChanges();
  }
}
