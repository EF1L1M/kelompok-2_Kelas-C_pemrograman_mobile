// ============================================================================
// ADVANCE DART: CUSTOM EXCEPTION
// Menangani error Firebase Auth, Cloud Firestore, dan otorisasi RBAC
// dengan pesan Bahasa Indonesia yang ramah pengguna (NFR-04).
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
      'user-disabled' => const AppAuthException(
          code: 'user-disabled',
          message: 'Akun ini telah dinonaktifkan. Hubungi administrator.',
        ),
      'too-many-requests' => const AppAuthException(
          code: 'too-many-requests',
          message: 'Terlalu banyak percobaan. Silakan tunggu beberapa saat lalu coba lagi.',
        ),
      'network-request-failed' || 'unavailable' => const AppAuthException(
          code: 'network-request-failed',
          message:
              'Tidak dapat terhubung ke server Firebase. Pastikan Firebase Emulator sedang berjalan atau periksa koneksi internet Anda.',
        ),
      'operation-not-allowed' => const AppAuthException(
          code: 'operation-not-allowed',
          message: 'Metode autentikasi ini belum diaktifkan pada konfigurasi Firebase.',
        ),
      'permission-denied' || 'unauthorized-group' => const AppAuthException(
          code: 'permission-denied',
          message:
              'Akses ditolak: Anda belum terdaftar sebagai anggota grup atau tidak memiliki izin untuk tindakan ini.',
        ),
      _ => AppAuthException(
          code: code,
          message: 'Terjadi kesalahan ($code). Silakan coba lagi.',
        ),
    };
  }

  @override
  String toString() => message;
}
