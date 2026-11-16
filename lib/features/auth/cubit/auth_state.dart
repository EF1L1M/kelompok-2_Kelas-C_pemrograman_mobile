import '../../../models/erd_models.dart';

// ============================================================================
// ADVANCE DART: SEALED CLASS & PATTERN MATCHING (DART 3)
// Penanggung Jawab: Anggota 1 (Bab 2.9 & Bab 6)
// Digunakan untuk switch expression pada UI dan Auth Guard di GoRouter.
// ============================================================================

sealed class AuthState {
  const AuthState();
}

final class AuthInitial extends AuthState {
  const AuthInitial();
}

final class AuthLoading extends AuthState {
  final String message;
  const AuthLoading([this.message = 'Memverifikasi kredensial...']);
}

final class AuthAuthenticated extends AuthState {
  final AppUser user;
  final String fcmToken;

  const AuthAuthenticated({
    required this.user,
    required this.fcmToken,
  });
}

final class AuthUnauthenticated extends AuthState {
  final bool showOnboardingFirst;
  const AuthUnauthenticated({this.showOnboardingFirst = false});
}

final class AuthError extends AuthState {
  final String message;
  const AuthError(this.message);
}
