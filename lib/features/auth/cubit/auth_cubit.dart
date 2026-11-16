import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/exceptions/auth_exception.dart';
import '../../../models/erd_models.dart';
import '../../../repositories/auth_repository.dart';
import 'auth_state.dart';

// ============================================================================
// AUTH CUBIT (STATE MANAGEMENT - ANGGOTA 1)
// Memantau Stream sesi secara real-time, menyimpan fcm_token ke USER_DEVICES,
// dan menyediakan ChangeNotifier untuk GoRouter Auth Guard redirect.
// ============================================================================

class AuthCubit extends Cubit<AuthState> with ChangeNotifier {
  final AuthRepository _authRepository;
  StreamSubscription<AppUser?>? _authSub;

  AuthCubit(this._authRepository) : super(const AuthInitial()) {
    _authSub = _authRepository.authStateChanges.listen((user) {
      if (user != null) {
        emit(
          AuthAuthenticated(
            user: user,
            fcmToken: _authRepository.getActiveFcmToken(user.uid),
          ),
        );
      } else {
        emit(
          AuthUnauthenticated(
            showOnboardingFirst: !_authRepository.hasSeenOnboarding,
          ),
        );
      }
      notifyListeners();
    });
  }

  AppUser? get currentUser => _authRepository.currentUser;
  List<AppUser> get allUsers => _authRepository.allRegisteredUsers;

  void completeOnboarding() {
    _authRepository.markOnboardingComplete();
    emit(const AuthUnauthenticated(showOnboardingFirst: false));
    notifyListeners();
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    emit(const AuthLoading('Masuk dengan Email & Kata Sandi...'));
    try {
      await _authRepository.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on AppAuthException catch (e) {
      emit(AuthError(e.message));
      emit(const AuthUnauthenticated(showOnboardingFirst: false));
    } catch (e) {
      emit(AuthError('Gagal masuk: $e'));
      emit(const AuthUnauthenticated(showOnboardingFirst: false));
    }
  }

  Future<void> registerWithEmail({
    required String fullName,
    required String email,
    required String password,
  }) async {
    emit(const AuthLoading('Mendaftarkan akun & menyimpan fcm_token...'));
    try {
      await _authRepository.registerWithEmailAndPassword(
        fullName: fullName,
        email: email,
        password: password,
      );
    } on AppAuthException catch (e) {
      emit(AuthError(e.message));
      emit(const AuthUnauthenticated(showOnboardingFirst: false));
    } catch (e) {
      emit(AuthError('Gagal mendaftar: $e'));
      emit(const AuthUnauthenticated(showOnboardingFirst: false));
    }
  }

  Future<void> signInWithGoogle() async {
    emit(const AuthLoading('Menghubungkan Google Sign-In...'));
    try {
      await _authRepository.signInWithGoogle();
    } catch (e) {
      emit(AuthError('Google Sign-In gagal: $e'));
      emit(const AuthUnauthenticated(showOnboardingFirst: false));
    }
  }

  Future<void> switchDemoUser(String uid) async {
    await _authRepository.switchActiveUserForDemo(uid);
  }

  Future<void> signOut() async {
    _authRepository.markOnboardingComplete();
    await _authRepository.signOut();
  }

  @override
  Future<void> close() {
    _authSub?.cancel();
    return super.close();
  }
}
