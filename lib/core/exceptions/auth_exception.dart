// ============================================================================
// ADVANCE DART: CUSTOM EXCEPTION
// Penanggung Jawab: Anggota 1 (Bab 2.9 & UFD-1)
// Menangani error autentikasi dan otorisasi dengan pesan Bahasa Indonesia (NFR-04).
// ============================================================================

class AppAuthException implements Exception {
  final String code;
  final String message;

  const AppAuthException({
    required this.code,
    required this.message,
  });

  factory AppAuthException.fromFirebaseCode(String code) {
    return switch (code) {
      'user-not-found' => const AppAuthException(
          code: 'user-not-found',
          message: 'Akun dengan email tersebut tidak ditemukan.',
        ),
      'wrong-password' || 'invalid-credential' => const AppAuthException(
          code: 'invalid-credential',
          message: 'Email atau kata sandi yang Anda masukkan salah.',
        ),
      'email-already-in-use' => const AppAuthException(
          code: 'email-already-in-use',
          message: 'Email sudah terdaftar. Silakan masuk atau gunakan email lain.',
        ),
      'weak-password' => const AppAuthException(
          code: 'weak-password',
          message: 'Kata sandi terlalu lemah (minimal 6 karakter).',
        ),
      'invalid-email' => const AppAuthException(
          code: 'invalid-email',
          message: 'Format alamat email tidak valid.',
        ),
      'permission-denied' || 'unauthorized-group' => const AppAuthException(
          code: 'permission-denied',
          message:
              'Akses ditolak: Anda belum terdaftar sebagai anggota grup atau tidak memiliki izin untuk tindakan ini.',
        ),
      _ => AppAuthException(
          code: code,
          message: 'Terjadi kesalahan autentikasi ($code). Silakan coba lagi.',
        ),
    };
  }

  @override
  String toString() => message;
}
