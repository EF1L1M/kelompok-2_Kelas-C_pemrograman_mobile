// ============================================================================
// ADVANCE DART: MIXIN VALIDASI FORM
// Penanggung Jawab: Anggota 1 (Bab 2.9 & UFD-1)
// Digunakan pada LoginScreen, RegisterScreen, dan dialog pembuatan Grup/Tagihan.
// ============================================================================

mixin FormValidatorMixin {
  static final RegExp _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  String? validateEmail(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Alamat email wajib diisi';
    }
    if (!_emailRegex.hasMatch(trimmed)) {
      return 'Format email tidak valid (contoh: nama@kampus.ac.id)';
    }
    return null;
  }

  String? validatePassword(String? value) {
    final text = value ?? '';
    if (text.isEmpty) {
      return 'Kata sandi wajib diisi';
    }
    if (text.length < 6) {
      return 'Kata sandi minimal terdiri dari 6 karakter';
    }
    return null;
  }

  String? validateFullName(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Nama lengkap wajib diisi';
    }
    if (trimmed.length < 3) {
      return 'Nama lengkap minimal 3 karakter';
    }
    return null;
  }

  String? validateInviteCode(String? value) {
    final trimmed = value?.trim().toUpperCase() ?? '';
    if (trimmed.isEmpty) {
      return 'Kode undangan wajib diisi';
    }
    if (trimmed.length < 5) {
      return 'Kode undangan minimal 5 karakter (contoh: KOS26A)';
    }
    return null;
  }

  String? validateRequiredText(String? value, {String fieldName = 'Kolom ini'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName tidak boleh kosong';
    }
    return null;
  }

  String? validatePositiveNumber(String? value, {String fieldName = 'Nominal'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName wajib diisi';
    }
    final parsed = double.tryParse(value.replaceAll(',', '.'));
    if (parsed == null || parsed <= 0) {
      return '$fieldName harus berupa angka lebih dari 0';
    }
    return null;
  }
}
