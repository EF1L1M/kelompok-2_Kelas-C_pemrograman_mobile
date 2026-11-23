// ============================================================================
// ADVANCE DART: EXTENSION METHODS
// Penanggung Jawab: Anggota 2 (Tabel 1.3 & Bab 2.9)
// - CurrencyFormatter on num: Mengubah angka menjadi format Rupiah (Rp 25.000)
//   atau mata uang asing (USD 12.50).
// - DateFormatter on DateTime: Mengubah tanggal menjadi format Indonesia.
// ============================================================================

extension CurrencyFormatter on num {
  /// Format ke Rupiah dengan titik pemisah ribuan tanpa desimal (contoh: Rp 25.000)
  /// Memenuhi spesifikasi Bab 2.9 & BR-03 (Pembulatan ke Rupiah).
  String toRupiah({bool withPrefix = true}) {
    final int rounded = round();
    final bool isNegative = rounded < 0;
    final String digits = rounded.abs().toString();
    final StringBuffer buffer = StringBuffer();

    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(digits[i]);
    }

    final String prefix = withPrefix ? 'Rp ' : '';
    return '${isNegative ? "-" : ""}$prefix${buffer.toString()}';
  }

  /// Format nominal sesuai kode mata uang asal (contoh: USD 14.50 atau Rp 25.000)
  String toCurrency(String currencyCode) {
    final String code = currencyCode.toUpperCase();
    if (code == 'IDR') {
      return toRupiah();
    }
    if (code == 'JPY') {
      return '$code ${round()}';
    }
    return '$code ${toStringAsFixed(2)}';
  }
}

extension DateFormatter on DateTime {
  static const List<String> _bulanPendek = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];

  /// Contoh output: "16 Nov 2026"
  String toIndoDate() {
    final String bulan = _bulanPendek[month - 1];
    return '$day $bulan $year';
  }

  /// Contoh output: "16 Nov 2026, 14:30"
  String toIndoDateTime() {
    final String hh = hour.toString().padLeft(2, '0');
    final String mm = minute.toString().padLeft(2, '0');
    return '${toIndoDate()}, $hh:$mm';
  }

  /// Contoh output: "Baru saja", "5 menit lalu", "2 jam lalu"
  String toRelativeTime() {
    final Duration diff = DateTime.now().difference(this);
    if (diff.inSeconds < 60) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    if (diff.inDays < 7) return '${diff.inDays} hari lalu';
    return toIndoDate();
  }
}
