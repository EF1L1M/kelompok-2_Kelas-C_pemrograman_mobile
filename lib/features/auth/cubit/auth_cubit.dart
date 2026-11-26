import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/exceptions/auth_exception.dart';
import '../../../models/erd_models.dart';
import '../../../repositories/auth_repository.dart';
import 'auth_state.dart';

// ============================================================================
// AUTH CUBIT (FIREBASE AUTH STATE MANAGEMENT)
// Memantau Stream sesi Firebase Auth secara real-time, menyimpan perangkat
// ke USER_DEVICES, dan menyediakan ChangeNotifier untuk GoRouter Auth Guard.
// ============================================================================

class AuthCubit extends Cubit<AuthState> with ChangeNotifier {
  final AuthRepository _authRepository;
  StreamSubscription<AppUser?>? _authSub;

  AuthCubit(this._authRepository) : super(const AuthInitial()) {
    _authSub = _authRepository.authStateChanges.listen(
      (user) {
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
      },
      onError: (_) {
        emit(
          AuthUnauthenticated(
            showOnboardingFirst: !_authRepository.hasSeenOnboarding,
          ),
        );
        notifyListeners();
      },
    );
  }

  AppUser? get currentUser {
    final current = state;
    if (current is AuthAuthenticated) return current.user;
    return _authRepository.currentUser;
  }

  Future<void> completeOnboarding() async {
    await _authRepository.markOnboardingComplete();
    if (state is! AuthAuthenticated) {
      emit(const AuthUnauthenticated(showOnboardingFirst: false));
      notifyListeners();
    }
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    emit(const AuthLoading('Masuk ke akun BagiTigaKan...'));
    try {
      final user = await _authRepository.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final current = state;
      if (current is! AuthAuthenticated ||
          current.user.uid != user.uid ||
          current.user.fullName != user.fullName) {
        emit(
          AuthAuthenticated(
            user: user,
            fcmToken: _authRepository.getActiveFcmToken(user.uid),
          ),
        );
        notifyListeners();
      }
    } on AppAuthException catch (e) {
      emit(AuthError(e.message));
      emit(const AuthUnauthenticated(showOnboardingFirst: false));
      notifyListeners();
    } catch (e) {
      emit(AuthError('Gagal masuk: $e'));
      emit(const AuthUnauthenticated(showOnboardingFirst: false));
      notifyListeners();
    }
  }

  Future<void> registerWithEmail({
    required String fullName,
    required String email,
    required String password,
  }) async {
    emit(const AuthLoading('Mendaftarkan akun & menyiapkan profil...'));
    try {
      final user = await _authRepository.registerWithEmailAndPassword(
        fullName: fullName,
        email: email,
        password: password,
      );
      final current = state;
      if (current is! AuthAuthenticated ||
          current.user.uid != user.uid ||
          current.user.fullName != user.fullName) {
        emit(
          AuthAuthenticated(
            user: user,
            fcmToken: _authRepository.getActiveFcmToken(user.uid),
          ),
        );
        notifyListeners();
      }
    } on AppAuthException catch (e) {
      emit(AuthError(e.message));
      emit(const AuthUnauthenticated(showOnboardingFirst: false));
      notifyListeners();
    } catch (e) {
      emit(AuthError('Gagal mendaftar: $e'));
      emit(const AuthUnauthenticated(showOnboardingFirst: false));
      notifyListeners();
    }
  }

  Future<String?> sendPasswordResetEmail(String email) async {
    try {
      await _authRepository.sendPasswordResetEmail(email);
      return null;
    } on AppAuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Gagal mengirim tautan reset kata sandi: $e';
    }
  }

  Future<void> signOut() async {
    await _authRepository.markOnboardingComplete();
    await _authRepository.signOut();
  }

  @override
  Future<void> close() {
    _authSub?.cancel();
    return super.close();
  }
}
